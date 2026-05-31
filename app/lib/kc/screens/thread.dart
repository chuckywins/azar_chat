import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:image_picker/image_picker.dart';

import '../../auth/auth_controller.dart';
import '../../services/messages_service.dart';
import '../../services/photo_service.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../mock_data.dart';
import '../tokens.dart';
import 'photo_viewer.dart';

class KCThread extends StatefulWidget {
  const KCThread({super.key});

  @override
  State<KCThread> createState() => _KCThreadState();
}

class _KCThreadState extends State<KCThread> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<Message> _msgs = [];
  List<ChatPhoto> _photos = const [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _sub;
  RealtimeChannel? _photoSub;
  RealtimeChannel? _typingCh;
  String? _peerId;

  bool _peerTyping = false;
  Timer? _peerTypingTimer;
  Timer? _myTypingDebounce;
  bool _myTypingActive = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _sub?.unsubscribe();
    _photoSub?.unsubscribe();
    _typingCh?.unsubscribe();
    _peerTypingTimer?.cancel();
    _myTypingDebounce?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final peer = KCContext.instance.chatUser;
    if (peer == null) {
      setState(() { _loading = false; _error = 'Sohbet bulunamadı'; });
      return;
    }
    _peerId = peer.id;
    try {
      final list = await MessagesService.instance.threadWith(peer.id);
      final photos = await PhotoService.instance.threadWith(peer.id);
      if (!mounted) return;
      setState(() { _msgs = list; _photos = photos; _loading = false; });
      await MessagesService.instance.markRead(peer.id);
      KCContext.instance.clearInboxUnread();
      _scrollToEnd();
      _subscribe();
      _subscribeTyping();
      _subscribePhotos();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  void _subscribe() {
    final peerId = _peerId;
    if (peerId == null) return;
    _sub = MessagesService.instance.subscribeThread(peerId, (m) {
      if (!mounted) return;
      // Don't add duplicates if we already appended manually.
      if (_msgs.any((x) => x.id == m.id)) return;
      setState(() => _msgs = [..._msgs, m]);
      _scrollToEnd();
      final me = AuthController.instance.userId;
      if (m.senderId != me) {
        MessagesService.instance.markRead(peerId);
      }
    });
  }

  void _subscribePhotos() {
    final me = AuthController.instance.userId;
    if (me == null) return;
    _photoSub = PhotoService.instance.subscribeIncoming(me, (p) {
      if (!mounted) return;
      if (p.senderId != _peerId) return;       // ignore photos from someone else
      if (_photos.any((x) => x.id == p.id)) return;
      setState(() => _photos = [..._photos, p]);
      _scrollToEnd();
    });
  }

  void _subscribeTyping() {
    final me = AuthController.instance.userId;
    final peerId = _peerId;
    if (me == null || peerId == null) return;
    _typingCh = MessagesService.instance.typingChannelFor(me, peerId)
      ..onBroadcast(event: 'typing', callback: (payload) {
        final from = payload['from'] as String?;
        final isTyping = payload['typing'] as bool? ?? false;
        if (from == peerId) {
          if (!mounted) return;
          setState(() => _peerTyping = isTyping);
          _peerTypingTimer?.cancel();
          if (isTyping) {
            _peerTypingTimer = Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _peerTyping = false);
            });
          }
        }
      })
      ..subscribe();
  }

  void _onInputChanged() {
    final me = AuthController.instance.userId;
    final peerId = _peerId;
    if (me == null || peerId == null || _typingCh == null) return;
    final hasText = _input.text.trim().isNotEmpty;
    if (hasText && !_myTypingActive) {
      _myTypingActive = true;
      _typingCh!.sendBroadcastMessage(event: 'typing',
          payload: {'from': me, 'typing': true});
    }
    _myTypingDebounce?.cancel();
    _myTypingDebounce = Timer(const Duration(seconds: 3), () {
      if (!_myTypingActive) return;
      _myTypingActive = false;
      _typingCh?.sendBroadcastMessage(event: 'typing',
          payload: {'from': me, 'typing': false});
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _pickAndSendPhoto() async {
    final peerId = _peerId;
    if (peerId == null) return;
    final ctx = KCContext.instance;

    // 1) Big warning + confirm
    final confirmed = await showDialog<bool>(
      context: context, barrierDismissible: true,
      builder: (dCtx) => Dialog(
        backgroundColor: KC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 42, height: 42,
                decoration: BoxDecoration(
                  color: KC.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Icon(Icons.visibility_off_rounded, color: KC.accent, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text('Tek seferlik fotoğraf',
                style: kcSora(17, w: FontWeight.w700))),
            ]),
            const SizedBox(height: 16),
            _bullet('Karşı taraf yalnızca 1 kez görüntüleyebilir.'),
            _bullet('Görüntülendikten sonra sunucudan kalıcı olarak silinir.'),
            _bullet('Mobil cihazlarda ekran görüntüsü engellenir; alındığında foto otomatik kapanır.'),
            _bullet('Tarayıcıda ekran görüntüsü tam engellenemez — fotoğraf üzerinde alıcının kimliği watermark olarak yer alır.'),
            _bullet('Geri alınamaz. Göndermek istediğinden emin ol.'),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false),
                child: Text('Vazgeç', style: kcManrope(14, w: FontWeight.w600, color: KC.muted))),
              const SizedBox(width: 6),
              GestureDetector(onTap: () => Navigator.pop(dCtx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(gradient: KC.grad,
                    borderRadius: BorderRadius.all(Radius.circular(12))),
                  child: Text('Anladım, devam',
                    style: kcSora(13.5, w: FontWeight.w700, color: Colors.white)),
                )),
            ]),
          ]),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // 2) Pick source
    final source = await showModalBottomSheet<ImageSource?>(
      context: context, backgroundColor: KC.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sCtx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 38, height: 4, decoration: BoxDecoration(
          color: KC.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text('Kaynak seç', style: kcSora(17, w: FontWeight.w700))),
        const SizedBox(height: 8),
        ListTile(leading: const Icon(Icons.photo_library_rounded, color: KC.accent),
          title: Text('Galeriden seç', style: kcManrope(14, w: FontWeight.w600)),
          onTap: () => Navigator.pop(sCtx, ImageSource.gallery)),
        ListTile(leading: const Icon(Icons.camera_alt_rounded, color: KC.accent),
          title: Text('Kamera ile çek', style: kcManrope(14, w: FontWeight.w600)),
          onTap: () => Navigator.pop(sCtx, ImageSource.camera)),
        const SizedBox(height: 12),
      ])),
    );

    if (source == null || !mounted) return;
    try {
      final picked = await PhotoService.instance.pick(source: source);
      if (picked == null) return;
      ctx.toast('📷 Gönderiliyor...');
      final created = await PhotoService.instance.send(
        receiverId: peerId, bytes: picked.bytes, mime: picked.mime,
      );
      if (!mounted) return;
      setState(() => _photos = [..._photos, created]);
      _scrollToEnd();
      ctx.toast('✅ Fotoğraf gönderildi (1 kez göster)');
    } catch (e) {
      ctx.toast('Fotoğraf gönderilemedi: ${e.toString().split('\n').first}');
    }
  }

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(top: 6, right: 9),
        child: Icon(Icons.circle, size: 4, color: KC.muted)),
      Expanded(child: Text(text, style: kcManrope(13, height: 1.42, color: KC.text))),
    ]),
  );

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _peerId == null) return;
    _input.clear();
    // Stop typing immediately on send.
    if (_myTypingActive) {
      _myTypingActive = false;
      final me = AuthController.instance.userId;
      if (me != null) {
        _typingCh?.sendBroadcastMessage(event: 'typing',
            payload: {'from': me, 'typing': false});
      }
    }
    try {
      final m = await MessagesService.instance.send(_peerId!, body);
      if (!mounted) return;
      // Manually append so it shows even if realtime echo is delayed.
      if (!_msgs.any((x) => x.id == m.id)) {
        setState(() => _msgs = [..._msgs, m]);
      }
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e'), backgroundColor: KC.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    final p = ctx.chatUser ?? kcUsers.first;
    final me = AuthController.instance.userId;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(14, MediaQuery.of(context).padding.top + 8, 14, 12),
          decoration: const BoxDecoration(
            color: KC.surface,
            border: Border(bottom: BorderSide(color: KC.border)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => ctx.back(),
              child: Container(width: 38, height: 38,
                alignment: Alignment.center,
                child: Icon(
                  ctx.hasActiveCall ? Icons.videocam_rounded : Icons.chevron_left_rounded,
                  color: KC.text, size: 24,
                )),
            ),
            const SizedBox(width: 4),
            KCAvatar(user: p, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(p.name, style: kcSora(16, w: FontWeight.w700)),
                    const SizedBox(width: 5),
                    KCFlag(country: p.country, size: 13),
                  ]),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _peerTyping
                        ? const _TypingIndicator(key: ValueKey('t'))
                        : Text('Sohbet',
                            key: const ValueKey('s'),
                            style: kcManrope(12, w: FontWeight.w600, color: KC.muted)),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => ctx.toast('Görüntülü arama yakında'),
              child: Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(gradient: KC.grad, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4))
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(20),
                      child: Text(_error!, style: kcManrope(14, color: KC.danger))))
                  : (_msgs.isEmpty && _photos.isEmpty)
                      ? Center(child: Text('İlk mesajı sen at',
                          style: kcManrope(14, color: KC.muted)))
                      : _buildTimeline(me),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 18),
          decoration: const BoxDecoration(
            color: KC.surface,
            border: Border(top: BorderSide(color: KC.border)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: _pickAndSendPhoto,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: KC.surface2, shape: BoxShape.circle,
                  border: Border.all(color: KC.border),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.image_rounded, color: KC.accent, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: KC.surface2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: KC.border),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _input,
                  onSubmitted: (_) => _send(),
                  style: kcManrope(15),
                  cursorColor: KC.accent,
                  decoration: InputDecoration(
                    hintText: 'Mesaj yaz…',
                    hintStyle: kcManrope(15, color: KC.muted),
                    border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(gradient: KC.grad, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildTimeline(String? me) {
    final items = <_ThreadItem>[
      for (final m in _msgs)   _ThreadItem.msg(m,   m.senderId == me),
      for (final p in _photos) _ThreadItem.photo(p, p.senderId == me),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        if (it.message != null) return _bubble(it.message!, it.fromMe);
        return _photoBubble(it.photo!, it.fromMe);
      },
    );
  }

  Widget _photoBubble(ChatPhoto p, bool me) {
    final viewed = p.isViewed;
    final blocked = p.blocked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Align(
        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () async {
            if (me) return; // sender can't re-view
            if (blocked) {
              KCContext.instance.toast('Fotoğraf moderasyon tarafından engellendi');
              return;
            }
            if (viewed) {
              KCContext.instance.toast('Bu fotoğraf zaten görüntülendi');
              return;
            }
            await KCPhotoViewer.open(context, p.id);
            if (!mounted) return;
            setState(() {
              _photos = _photos.map((x) => x.id == p.id ? ChatPhoto(
                id: x.id, senderId: x.senderId, receiverId: x.receiverId,
                storagePath: x.storagePath, nsfwScore: x.nsfwScore,
                blocked: x.blocked, viewedAt: DateTime.now(), createdAt: x.createdAt,
              ) : x).toList();
            });
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: me ? KC.grad : null,
                color: me ? null : KC.surface2,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(me ? 20 : 6),
                  bottomRight: Radius.circular(me ? 6 : 20),
                ),
                border: me ? null : Border.all(color: KC.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: (me ? Colors.white : KC.accent).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Icon(
                    blocked ? Icons.block_rounded
                      : viewed ? Icons.visibility_off_rounded
                      : Icons.image_rounded,
                    color: me ? Colors.white : KC.accent, size: 22,
                  )),
                const SizedBox(width: 11),
                Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    me ? 'Fotoğraf gönderildi' : (blocked ? 'Engellendi'
                      : viewed ? 'Görüntülendi & silindi' : 'Fotoğraf • dokun → 1 kez göster'),
                    style: kcManrope(13.5, w: FontWeight.w700, color: me ? Colors.white : KC.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    me ? 'Karşı taraf 1 kez görür, sonra silinir' : (viewed ? 'Sunucudan kalıcı kaldırıldı' : 'Tek seferlik'),
                    style: kcManrope(11.5, color: (me ? Colors.white : KC.muted).withValues(alpha: 0.85)),
                  ),
                ])),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(Message m, bool me) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: me ? KC.grad : null,
            color: me ? null : KC.surface2,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(me ? 20 : 6),
              bottomRight: Radius.circular(me ? 6 : 20),
            ),
            border: me ? null : Border.all(color: KC.border),
          ),
          child: Text(m.body,
            style: kcManrope(14.5, height: 1.35, color: me ? Colors.white : KC.text)),
        ),
      ),
    ),
  );
}

class _ThreadItem {
  _ThreadItem._({this.message, this.photo, required this.fromMe, required this.at});
  factory _ThreadItem.msg(Message m, bool fromMe)   => _ThreadItem._(message: m, fromMe: fromMe, at: m.createdAt);
  factory _ThreadItem.photo(ChatPhoto p, bool fromMe) => _ThreadItem._(photo:   p, fromMe: fromMe, at: p.createdAt);
  final Message? message;
  final ChatPhoto? photo;
  final bool fromMe;
  final DateTime at;
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({super.key});
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_c.value + i * 0.2) % 1.0);
                final scale = 0.6 + 0.4 * (1 - (t * 2 - 1).abs());
                return Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 3),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 5, height: 5,
                      decoration: const BoxDecoration(color: KC.accent, shape: BoxShape.circle),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(width: 7),
        Text('yazıyor…', style: kcManrope(12, w: FontWeight.w600, color: KC.accent)),
      ],
    );
  }
}
