import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../auth/auth_controller.dart';
import '../services/friends_service.dart';
import '../services/report_service.dart';
import '../state/app_controller.dart';
import '../theme.dart';

class InCallScreen extends StatelessWidget {
  const InCallScreen({super.key, required this.controller, required this.onLeave});
  final AppController controller;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Remote full bleed
          Container(
            color: AzarPalette.bg,
            child: RTCVideoView(
              controller.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // Top gradient overlay for header readability
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: Container(
                height: topPad + 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AzarPalette.bg.withValues(alpha: 0.7),
                      AzarPalette.bg.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom gradient overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AzarPalette.bg.withValues(alpha: 0.85),
                      AzarPalette.bg.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Top-left peer chip + chat + heart + report
          Positioned(
            top: topPad + 14, left: 16, right: 130,
            child: Row(
              children: [
                Flexible(
                  child: _peerChip(context, controller.peerName ?? 'Yabancı')
                      .animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                ),
                const SizedBox(width: 8),
                _glassChatBtn(
                  unread: controller.unreadChatCount,
                  onTap: () => _showChatSheet(context, controller),
                ).animate().fadeIn(duration: 400.ms, delay: 60.ms),
                const SizedBox(width: 8),
                _HeartBtn(controller: controller)
                    .animate().fadeIn(duration: 400.ms, delay: 120.ms),
                const SizedBox(width: 8),
                _glassIconBtn(
                  icon: Icons.flag_outlined,
                  color: AzarPalette.danger,
                  onTap: () => _showReportSheet(context, controller),
                ).animate().fadeIn(duration: 400.ms, delay: 180.ms),
              ],
            ),
          ),

          // Floating emoji bursts overlay
          Positioned.fill(child: _EmojiBurstOverlay(controller: controller)),

          // Top-right local PIP
          Positioned(
            top: topPad + 14, right: 16,
            child: _LocalPreview(controller: controller)
                .animate().fadeIn(duration: 400.ms).slideX(begin: 0.1),
          ),

          // Bottom control bar
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ctrlBtn(
                          icon: controller.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                          on: controller.micOn,
                          onTap: controller.toggleMic,
                        ),
                        const SizedBox(width: 10),
                        _ctrlBtn(
                          icon: controller.camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                          on: controller.camOn,
                          onTap: controller.toggleCam,
                        ),
                        const SizedBox(width: 10),
                        _ctrlBtn(
                          icon: Icons.cameraswitch_rounded,
                          on: true,
                          onTap: controller.switchCamera,
                        ),
                        const SizedBox(width: 10),
                        _ctrlBtn(
                          icon: Icons.emoji_emotions_outlined,
                          on: true,
                          onTap: () => _showEmojiPicker(context, controller),
                        ),
                        const SizedBox(width: 10),
                        _ctrlBtn(
                          icon: Icons.call_end_rounded,
                          on: true,
                          danger: true,
                          onTap: onLeave,
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
                    const SizedBox(height: 14),
                    _SwipeNextButton(onTap: controller.next)
                        .animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _peerChip(BuildContext context, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AzarPalette.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AzarPalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              gradient: AzarPalette.brandGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AzarPalette.primary.withValues(alpha: 0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(color: AzarPalette.text, fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _glassIconBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AzarPalette.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _glassChatBtn({required int unread, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AzarPalette.surface.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AzarPalette.secondary.withValues(alpha: 0.45)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.chat_bubble_outline_rounded, color: AzarPalette.secondary, size: 16),
          ),
          if (unread > 0)
            Positioned(
              top: -4, right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  gradient: AzarPalette.brandGradient,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AzarPalette.bg, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ctrlBtn({
    required IconData icon,
    required bool on,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final Color bg = danger
        ? AzarPalette.danger
        : (on ? AzarPalette.surfaceHigh : AzarPalette.surface);
    final Color iconColor = danger
        ? Colors.white
        : (on ? AzarPalette.text : AzarPalette.textDim);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: danger ? Colors.transparent : AzarPalette.line,
            width: 1,
          ),
          boxShadow: danger
              ? [BoxShadow(color: AzarPalette.danger.withValues(alpha: 0.4), blurRadius: 18, spreadRadius: -2)]
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _LocalPreview extends StatelessWidget {
  const _LocalPreview({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.shortestSide;
    final w = (size * 0.28).clamp(110.0, 180.0);
    final h = w * 4 / 3;
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: AzarPalette.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AzarPalette.line.withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: RTCVideoView(
        controller.localRenderer,
        mirror: true,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }
}

/// Wide gradient pill — primary "next" CTA.
class _SwipeNextButton extends StatelessWidget {
  const _SwipeNextButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GradientButton(
        label: 'SIRADAKİ',
        icon: Icons.skip_next_rounded,
        height: 56,
        onTap: onTap,
      ),
    );
  }
}

// ============================================================================
// Heart button (like) — turns to mutual snackbar
// ============================================================================

class _HeartBtn extends StatelessWidget {
  const _HeartBtn({required this.controller});
  final AppController controller;

  Future<void> _onTap(BuildContext context) async {
    if (controller.likedCurrentPeer) return;
    final mutual = await controller.likeCurrentPeer(
      likeFn: (uid) => FriendsService.instance.like(uid),
    );
    if (!context.mounted) return;
    final color = mutual ? AzarPalette.success : AzarPalette.primary;
    final icon = mutual ? Icons.handshake_rounded : Icons.favorite_rounded;
    final text = mutual ? 'Arkadaş oldunuz!' : 'Beğendin — karşı taraf da beğenirse arkadaş olursunuz';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AzarPalette.surfaceUp,
      content: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: AzarPalette.text))),
      ]),
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final liked = controller.likedCurrentPeer;
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: liked ? AzarPalette.brandGradient : null,
          color: liked ? null : AzarPalette.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: liked ? Colors.transparent : AzarPalette.primary.withValues(alpha: 0.45)),
        ),
        alignment: Alignment.center,
        child: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          color: liked ? Colors.white : AzarPalette.primary, size: 16,
        ),
      ),
    );
  }
}

// ============================================================================
// Emoji picker bottom sheet + floating burst overlay
// ============================================================================

const _emojiSet = ['🔥','❤️','😂','😮','👏','🎉','🌹','💯','😍','🙌','💀','✨'];

Future<void> _showEmojiPicker(BuildContext context, AppController controller) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: const BoxDecoration(
        gradient: AzarPalette.surfaceGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AzarPalette.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AzarPalette.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _emojiSet.map((e) => GestureDetector(
              onTap: () {
                controller.sendEmoji(e);
                Navigator.of(ctx).maybePop();
              },
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AzarPalette.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AzarPalette.line),
                ),
                alignment: Alignment.center,
                child: Text(e, style: const TextStyle(fontSize: 28)),
              ),
            )).toList(),
          ),
        ],
      ),
    ),
  );
}

class _EmojiBurstOverlay extends StatelessWidget {
  const _EmojiBurstOverlay({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.emojiBursts.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: controller.emojiBursts.map((b) => _FloatingEmoji(burst: b, key: ValueKey(b.at.microsecondsSinceEpoch))).toList(),
      ),
    );
  }
}

class _FloatingEmoji extends StatefulWidget {
  const _FloatingEmoji({super.key, required this.burst});
  final EmojiBurst burst;
  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  late final double _xOffset;

  @override
  void initState() {
    super.initState();
    // semi-random horizontal offset based on micros
    final m = widget.burst.at.microsecondsSinceEpoch;
    _xOffset = ((m % 200) - 100) / 100.0; // -1..1
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = _ctrl.value;
        // Start at bottom (from-me) or anchor from the peer (right side).
        final startX = widget.burst.fromMe ? size.width * 0.5 : size.width * 0.78;
        final dx = startX + _xOffset * 80;
        final dy = size.height * 0.85 - (size.height * 0.55) * Curves.easeOut.transform(t);
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        final scale = 0.7 + 0.6 * Curves.easeOutBack.transform(t.clamp(0.0, 0.6) / 0.6);
        return Positioned(
          left: dx - 24, top: dy - 24,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Text(widget.burst.emoji, style: const TextStyle(fontSize: 56)),
    );
  }
}

// ============================================================================
// Chat bottom sheet
// ============================================================================

Future<void> _showChatSheet(BuildContext context, AppController controller) async {
  controller.clearUnreadChat();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ChatSheet(controller: controller),
  );
  controller.clearUnreadChat();
}

class _ChatSheet extends StatefulWidget {
  const _ChatSheet({required this.controller});
  final AppController controller;

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    widget.controller.clearUnreadChat();
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
    }
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    widget.controller.sendChat(t);
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final h = MediaQuery.of(context).size.height * 0.7;
    final msgs = widget.controller.chatMessages;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        height: h,
        decoration: const BoxDecoration(
          gradient: AzarPalette.surfaceGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AzarPalette.line)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AzarPalette.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AzarPalette.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: AzarPalette.secondary, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sohbet • ${widget.controller.peerName ?? "Yabancı"}',
                      style: const TextStyle(color: AzarPalette.text, fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AzarPalette.textDim, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AzarPalette.line),
            Expanded(
              child: msgs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: AzarPalette.surfaceHigh,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.chat_outlined, color: AzarPalette.textDim, size: 24),
                          ),
                          const SizedBox(height: 12),
                          const Text('İlk mesajı sen at',
                              style: TextStyle(color: AzarPalette.textDim, fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: m.fromMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: m.fromMe ? AzarPalette.brandGradient : null,
                                  color: m.fromMe ? null : AzarPalette.surfaceHigh,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(m.fromMe ? 18 : 4),
                                    bottomRight: Radius.circular(m.fromMe ? 4 : 18),
                                  ),
                                ),
                                child: Text(
                                  m.text,
                                  style: TextStyle(
                                    color: m.fromMe ? Colors.white : AzarPalette.text,
                                    fontSize: 14.5, height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AzarPalette.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: AzarPalette.text, fontSize: 14.5),
                      cursorColor: AzarPalette.primary,
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz...',
                        hintStyle: const TextStyle(color: AzarPalette.textFaint),
                        filled: true,
                        fillColor: AzarPalette.surfaceHigh,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: AzarPalette.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: AzarPalette.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: AzarPalette.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: AzarPalette.brandGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AzarPalette.primary.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: -3),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Report bottom sheet
// ============================================================================

Future<void> _showReportSheet(BuildContext context, AppController controller) async {
  final peerSocketId = controller.peerId;
  if (peerSocketId == null) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => _ReportSheet(
      peerSocketId: peerSocketId,
      onSubmitted: () {
        Navigator.of(sheetCtx).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AzarPalette.surfaceUp,
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AzarPalette.success, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Raporun alındı. Sıradakine geçiyoruz.',
                    style: TextStyle(color: AzarPalette.text))),
              ],
            ),
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AzarPalette.line),
            ),
          ),
        );
        controller.next();
      },
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.peerSocketId, required this.onSubmitted});
  final String peerSocketId;
  final VoidCallback onSubmitted;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  bool _busy = false;
  String? _error;
  final _note = TextEditingController();

  static const _reasons = [
    ('nsfw',       'NSFW içerik', Icons.no_adult_content),
    ('harassment', 'Taciz / hakaret', Icons.report_problem_outlined),
    ('spam',       'Spam / reklam', Icons.block_rounded),
    ('minor',      'Küçük yaş', Icons.child_care_outlined),
    ('other',      'Diğer', Icons.more_horiz),
  ];

  @override
  void dispose() { _note.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _error = 'Bir sebep seç');
      return;
    }
    final reporterId = AuthController.instance.userId;
    if (reporterId == null) {
      setState(() => _error = 'Rapor için giriş gerekli');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await ReportService.instance.submit(
        reporterId: reporterId,
        reportedPeerId: widget.peerSocketId,
        reason: _reason!,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      widget.onSubmitted();
    } catch (e) {
      setState(() { _busy = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(
          gradient: AzarPalette.surfaceGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AzarPalette.line)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AzarPalette.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AzarPalette.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_rounded, color: AzarPalette.danger, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Kullanıcıyı raporla',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AzarPalette.textDim, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Column(
              children: _reasons.map((r) {
                final selected = _reason == r.$1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _reason = r.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AzarPalette.danger.withValues(alpha: 0.15) : AzarPalette.surfaceHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? AzarPalette.danger : AzarPalette.line,
                          width: selected ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(r.$3, color: selected ? AzarPalette.danger : AzarPalette.textDim, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(r.$2,
                                style: TextStyle(
                                  color: selected ? AzarPalette.text : AzarPalette.textDim,
                                  fontSize: 14.5,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                )),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded, color: AzarPalette.danger, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLength: 200,
              maxLines: 2,
              style: const TextStyle(color: AzarPalette.text, fontSize: 14),
              cursorColor: AzarPalette.primary,
              decoration: InputDecoration(
                hintText: 'Not (opsiyonel)',
                hintStyle: const TextStyle(color: AzarPalette.textFaint),
                counterText: '',
                filled: true,
                fillColor: AzarPalette.surfaceHigh,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AzarPalette.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AzarPalette.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AzarPalette.primary, width: 1.5),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AzarPalette.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AzarPalette.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AzarPalette.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AzarPalette.text, fontSize: 13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            GradientButton(
              label: 'RAPORU GÖNDER',
              icon: Icons.send_rounded,
              busy: _busy,
              gradient: const LinearGradient(
                colors: [AzarPalette.danger, Color(0xFFFF7A8A)],
              ),
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
