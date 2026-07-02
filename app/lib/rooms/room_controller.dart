import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../auth/auth_controller.dart';
import '../config.dart';
import '../services/device_fp_service.dart';
import '../signaling/signaling.dart';
import '../webrtc/media.dart';
import '../webrtc/peer.dart';

class RoomPreviewMember {
  RoomPreviewMember({required this.id, this.userId, required this.name});
  final String id;
  final String? userId;
  final String name;
}

class RoomInfo {
  RoomInfo({
    required this.id,
    required this.title,
    required this.topic,
    required this.count,
    required this.cap,
    required this.ownerName,
    this.preview = const [],
  });

  final String id;
  final String title;
  final String topic;
  final int count;
  final int cap;
  final String ownerName;

  /// First few members — powers the swipe-deck slot preview.
  final List<RoomPreviewMember> preview;

  static RoomInfo fromJson(Map<String, dynamic> j) => RoomInfo(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? 'Oda',
        topic: (j['topic'] as String?) ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        cap: (j['cap'] as num?)?.toInt() ?? 10,
        ownerName: (j['ownerName'] as String?) ?? '—',
        preview: ((j['preview'] as List?) ?? const [])
            .cast<Map>()
            .map((e) => RoomPreviewMember(
                  id: (e['id'] as String?) ?? '',
                  userId: e['userId'] as String?,
                  name: (e['name'] as String?) ?? 'Misafir',
                ))
            .toList(),
      );
}

class RoomMember {
  RoomMember({
    required this.id,
    this.userId,
    required this.name,
    this.gender,
    this.country,
    required this.muted,
    required this.isOwner,
    this.isAdmin = false,
  });

  final String id;       // ephemeral socket id
  final String? userId;  // Supabase uid (null for guests)
  final String name;
  final String? gender;
  final String? country;
  bool muted;
  bool isOwner;
  final bool isAdmin;    // platform admin — shown with a tag in rooms

  static RoomMember fromJson(Map<String, dynamic> j) => RoomMember(
        id: j['id'] as String,
        userId: j['userId'] as String?,
        name: (j['name'] as String?) ?? 'Misafir',
        gender: j['gender'] as String?,
        country: j['country'] as String?,
        muted: j['muted'] == true,
        isOwner: j['isOwner'] == true,
        isAdmin: j['isAdmin'] == true,
      );
}

class RoomChatMsg {
  RoomChatMsg({required this.name, required this.text, required this.fromMe, required this.isOwner, required this.at});
  final String name;
  final String text;
  final bool fromMe;
  final bool isOwner;
  final DateTime at;
}

enum RoomPhase {
  idle,        // rooms area not opened
  connecting,  // opening WS / mic
  list,        // browsing room list
  joining,     // create/join sent, waiting room_joined
  inRoom,      // live in a room
}

/// Clubhouse-style voice rooms — owns its own Signaling connection and a
/// full-mesh of audio-only PeerSessions (one per other member).
class RoomController extends ChangeNotifier {
  RoomController();

  final LocalMedia _media = LocalMedia();
  Signaling? _signaling;
  StreamSubscription? _msgSub;
  StreamSubscription? _connSub;

  RoomPhase phase = RoomPhase.idle;
  String? selfId;
  List<Map<String, dynamic>> _iceServers = const [];

  List<RoomInfo> roomList = const [];
  RoomInfo? room;
  String? ownerId;
  final List<RoomMember> members = [];
  final List<RoomChatMsg> chat = [];
  bool muted = true;
  String? errorMessage;

  /// Room expiry (server-authoritative). UI derives the countdown from this.
  DateTime? roomExpiresAt;

  /// Unread chat messages while the chat sheet is closed.
  int unreadChat = 0;
  bool chatOpen = false;

  /// UI feedback hook (toasts) — wired by KCContext.
  void Function(String msg)? onToast;

  final Map<String, PeerSession> _sessions = {};
  final Map<String, RTCVideoRenderer> _renderers = {};

  /// Renderers the room screen must mount (invisible) so audio plays on web.
  List<RTCVideoRenderer> get audioSinks => _renderers.values.toList();

  bool get isOwner => selfId != null && selfId == ownerId;
  bool get micStarted => _media.stream != null;

  String displayName = 'Misafir';
  String gender = 'X';

  // ── lifecycle ────────────────────────────────────────────────────────────

  /// Open the rooms area: connect WS (no mic yet) and fetch the list.
  Future<void> open() async {
    if (phase != RoomPhase.idle) {
      refresh();
      return;
    }
    phase = RoomPhase.connecting;
    notifyListeners();
    try {
      _signaling = Signaling(
        AppConfig.signalingUrl,
        accessToken: AuthController.instance.accessToken,
      );
      await _signaling!.connect();
      _msgSub = _signaling!.messages.listen(_onMessage);
      _connSub = _signaling!.connection.listen((up) {
        if (!up) _onSocketDown();
      });
      final deviceFp = await DeviceFingerprint.get();
      _signaling!.hello(name: displayName, gender: gender, deviceFp: deviceFp);
      _signaling!.roomList();
      phase = RoomPhase.list;
    } catch (e) {
      errorMessage = e.toString();
      phase = RoomPhase.idle;
      onToast?.call('Bağlantı kurulamadı');
      await _disposeSocket();
    }
    notifyListeners();
  }

  void refresh() => _signaling?.roomList();

  Future<void> createRoom({required String title, String? topic}) async {
    if (_signaling == null) return;
    if (!await _ensureMic()) return;
    phase = RoomPhase.joining;
    notifyListeners();
    _setSelfMuted(false); // creator speaks right away
    _signaling!.roomCreate(title: title, topic: topic);
  }

  Future<void> joinRoom(String roomId) async {
    if (_signaling == null) return;
    if (!await _ensureMic()) return;
    phase = RoomPhase.joining;
    notifyListeners();
    _setSelfMuted(true); // joiners land as muted listeners
    _signaling!.roomJoin(roomId);
  }

  /// Leave the current room but stay in the rooms area (list).
  Future<void> leaveRoom() async {
    _signaling?.roomLeave();
    await _teardownRoom();
    phase = RoomPhase.list;
    refresh();
    notifyListeners();
  }

  /// Fully close the rooms area (socket + mic).
  Future<void> close() async {
    if (phase == RoomPhase.inRoom || phase == RoomPhase.joining) {
      _signaling?.roomLeave();
    }
    await _teardownRoom();
    await _disposeSocket();
    phase = RoomPhase.idle;
    roomList = const [];
    notifyListeners();
  }

  // ── in-room actions ──────────────────────────────────────────────────────

  void toggleMute() {
    if (!micStarted) return;
    _setSelfMuted(!muted);
    _signaling?.roomState(muted: muted);
    notifyListeners();
  }

  void sendChat(String text) {
    final t = text.trim();
    if (t.isEmpty || _signaling == null) return;
    _signaling!.roomChat(t);
    // Server echoes to everyone except no one — we add ourselves locally
    // only if the server excluded us; it broadcasts to all, so skip local add.
  }

  void kick(String peerId) => _signaling?.roomKick(peerId);
  void muteMember(String peerId) => _signaling?.roomMute(peerId);

  /// Extend the room by 3 minutes using a time card or 20 diamonds.
  void extendRoom({required String method}) => _signaling?.roomExtend(method: method);

  void setChatOpen(bool open) {
    chatOpen = open;
    if (open) unreadChat = 0;
    notifyListeners();
  }

  // ── internals ────────────────────────────────────────────────────────────

  Future<bool> _ensureMic() async {
    if (micStarted) return true;
    try {
      await _media.start(cam: false);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      onToast?.call('Mikrofon izni gerekli');
      return false;
    }
  }

  void _setSelfMuted(bool m) {
    muted = m;
    for (final t in _media.stream?.getAudioTracks() ?? const []) {
      t.enabled = !m;
    }
    final self = _selfMember();
    if (self != null) self.muted = m;
  }

  RoomMember? _selfMember() {
    for (final m in members) {
      if (m.id == selfId) return m;
    }
    return null;
  }

  RoomMember? _memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> _onMessage(Map<String, dynamic> msg) async {
    switch (msg['type'] as String?) {
      case 'welcome':
        selfId = msg['selfId'] as String?;
        final ice = (msg['iceServers'] as List?)?.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        if (ice != null) _iceServers = ice;
        break;

      case 'room_list':
        roomList = ((msg['rooms'] as List?) ?? const [])
            .cast<Map>()
            .map((e) => RoomInfo.fromJson(e.cast<String, dynamic>()))
            .toList();
        notifyListeners();
        break;

      case 'room_joined':
        await _onRoomJoined(msg);
        break;

      case 'room_peer_joined':
        final j = (msg['member'] as Map?)?.cast<String, dynamic>();
        if (j != null && _memberById(j['id'] as String? ?? '') == null) {
          members.add(RoomMember.fromJson(j));
          // The new joiner initiates offers towards us; we wait politely.
          notifyListeners();
        }
        break;

      case 'room_peer_left':
        final pid = msg['peerId'] as String?;
        if (pid != null) {
          members.removeWhere((m) => m.id == pid);
          await _dropSession(pid);
        }
        final newOwner = msg['newOwnerId'] as String?;
        if (newOwner != null) {
          ownerId = newOwner;
          for (final m in members) {
            m.isOwner = m.id == newOwner;
          }
          if (newOwner == selfId) onToast?.call('Oda yöneticisi artık sensin 👑');
        }
        notifyListeners();
        break;

      case 'room_signal':
        final from = msg['from'] as String?;
        final payload = (msg['payload'] as Map?)?.cast<String, dynamic>();
        if (from == null || payload == null || phase != RoomPhase.inRoom) break;
        // Lazily create a polite/answering session for offers that arrive
        // before we processed room_peer_joined.
        var s = _sessions[from];
        s ??= await _createSession(from, initiator: false);
        if (s != null) await s.handleSignal(payload);
        break;

      case 'room_member_state':
        final pid = msg['peerId'] as String?;
        final m = pid == null ? null : _memberById(pid);
        if (m != null) {
          m.muted = msg['muted'] == true;
          notifyListeners();
        }
        break;

      case 'room_chat':
        final from = (msg['from'] as Map?)?.cast<String, dynamic>();
        if (from != null) {
          final fromMe = from['id'] == selfId;
          chat.add(RoomChatMsg(
            name: (from['name'] as String?) ?? 'Misafir',
            text: (msg['text'] as String?) ?? '',
            fromMe: fromMe,
            isOwner: from['isOwner'] == true,
            at: DateTime.now(),
          ));
          if (chat.length > 200) chat.removeRange(0, chat.length - 200);
          if (!chatOpen && !fromMe) unreadChat += 1;
          notifyListeners();
        }
        break;

      case 'room_extended':
        final exp = (msg['expiresAt'] as num?)?.toInt();
        if (exp != null) {
          roomExpiresAt = DateTime.fromMillisecondsSinceEpoch(exp);
        }
        final by = msg['byName'] as String? ?? 'Biri';
        onToast?.call('⏱ $by odayı 3 dk uzattı!');
        notifyListeners();
        break;

      case 'room_expired':
        onToast?.call('⏰ Oda süresi doldu');
        await _teardownRoom();
        phase = RoomPhase.list;
        refresh();
        notifyListeners();
        break;

      case 'room_force_muted':
        _setSelfMuted(true);
        onToast?.call('Yönetici seni susturdu');
        notifyListeners();
        break;

      case 'room_kicked':
        onToast?.call('Odadan çıkarıldın');
        await _teardownRoom();
        phase = RoomPhase.list;
        refresh();
        notifyListeners();
        break;

      case 'error':
        final code = msg['code'] as String?;
        errorMessage = (msg['message'] as String?) ?? 'Hata';
        if (code == 'no_time_card' || code == 'insufficient_coins' ||
            code == 'room_max' || code == 'not_authed' || code == 'extend_failed') {
          onToast?.call(errorMessage!);
          notifyListeners();
        } else if (code == 'room_full' || code == 'room_gone' || code == 'room_title') {
          onToast?.call(errorMessage!);
          if (phase == RoomPhase.joining) {
            phase = RoomPhase.list;
            refresh();
          }
          notifyListeners();
        } else if (code == 'banned' || code == 'ban_evasion') {
          onToast?.call(errorMessage!);
          await close();
        }
        break;
    }
  }

  Future<void> _onRoomJoined(Map<String, dynamic> msg) async {
    final roomJson = ((msg['room'] as Map?) ?? const {}).cast<String, dynamic>();
    room = RoomInfo.fromJson(roomJson);
    final exp = (roomJson['expiresAt'] as num?)?.toInt();
    roomExpiresAt = exp == null ? null : DateTime.fromMillisecondsSinceEpoch(exp);
    unreadChat = 0;
    chatOpen = false;
    ownerId = msg['ownerId'] as String?;
    members
      ..clear()
      ..addAll(((msg['members'] as List?) ?? const [])
          .cast<Map>()
          .map((e) => RoomMember.fromJson(e.cast<String, dynamic>())));
    chat.clear();
    phase = RoomPhase.inRoom;

    // We are the newcomer: initiate a session towards every existing member.
    for (final m in members) {
      if (m.id == selfId) continue;
      await _createSession(m.id, initiator: true);
    }
    notifyListeners();
  }

  Future<PeerSession?> _createSession(String peerId, {required bool initiator}) async {
    if (_sessions.containsKey(peerId)) return _sessions[peerId];
    final localStream = _media.stream;
    if (localStream == null) return null;

    final session = PeerSession(
      peerId: peerId,
      // Newcomer initiates (impolite); existing members answer (polite).
      polite: !initiator,
      iceServers: _iceServers,
      localStream: localStream,
      onSignal: (payload) => _signaling?.roomSignal(peerId, payload),
      onRemoteStream: (stream) async {
        final r = _renderers[peerId] ?? RTCVideoRenderer();
        if (_renderers[peerId] == null) {
          await r.initialize();
          _renderers[peerId] = r;
        }
        r.srcObject = stream;
        notifyListeners();
      },
      onStateChange: (s) {
        if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          // Mesh link died — drop it; the member may still relay via others' UI.
          _dropSession(peerId);
        }
      },
      onChatMessage: (_) {}, // room chat rides the WS, not data channels
    );
    _sessions[peerId] = session;
    await session.init(initiator: initiator);
    return session;
  }

  Future<void> _dropSession(String peerId) async {
    final s = _sessions.remove(peerId);
    if (s != null) await s.dispose();
    final r = _renderers.remove(peerId);
    if (r != null) {
      r.srcObject = null;
      await r.dispose();
    }
    notifyListeners();
  }

  Future<void> _teardownRoom() async {
    for (final id in _sessions.keys.toList()) {
      await _dropSession(id);
    }
    room = null;
    ownerId = null;
    roomExpiresAt = null;
    unreadChat = 0;
    chatOpen = false;
    members.clear();
    chat.clear();
    muted = true;
    await _media.stop();
  }

  void _onSocketDown() {
    if (phase == RoomPhase.idle) return;
    onToast?.call('Bağlantı koptu');
    _teardownRoom();
    _disposeSocket();
    phase = RoomPhase.idle;
    notifyListeners();
  }

  Future<void> _disposeSocket() async {
    await _msgSub?.cancel();
    _msgSub = null;
    await _connSub?.cancel();
    _connSub = null;
    await _signaling?.dispose();
    _signaling = null;
    selfId = null;
  }

  @override
  Future<void> dispose() async {
    await _teardownRoom();
    await _disposeSocket();
    super.dispose();
  }
}
