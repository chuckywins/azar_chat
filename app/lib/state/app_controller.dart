import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../auth/auth_controller.dart';
import '../config.dart';
import '../games/game_controller.dart';
import '../services/device_fp_service.dart';
import '../signaling/signaling.dart';
import '../webrtc/media.dart';
import '../webrtc/peer.dart';

class ChatMessage {
  ChatMessage({required this.text, required this.fromMe, required this.at});
  final String text;
  final bool fromMe;
  final DateTime at;
}

class EmojiBurst {
  EmojiBurst({required this.emoji, required this.fromMe, required this.at});
  final String emoji;
  final bool fromMe;
  final DateTime at;
}

enum AppPhase {
  idle,        // before pressing start
  connecting,  // opening WS / getUserMedia
  searching,   // queued, waiting for match
  inCall,      // matched + media flowing
  ended,       // peer left / leave pressed
  error,
}

/// Single source of truth — owns Signaling, LocalMedia, and the active PeerSession.
class AppController extends ChangeNotifier {
  AppController();

  final localRenderer  = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  final LocalMedia _media = LocalMedia();

  Signaling? _signaling;
  PeerSession? _peer;
  StreamSubscription? _msgSub;

  /// Wired by GameController so peer game-payloads can be routed without
  /// AppController having to know game internals.
  void Function(Map<String, dynamic> payload)? onGamePayload;
  void sendGame(Map<String, dynamic> payload) => _peer?.sendGame(payload);

  AppPhase phase = AppPhase.idle;

  /// '1-1' matchmaking mode: 'video' or 'voice' (BlindID-style, mic only).
  String mode = 'video';
  bool get isVoice => mode == 'voice';

  /// Voice-mode topic preference ('random' = anyone).
  String topic = 'random';

  /// Topic of the current match, as decided by the server (null = none).
  String? matchTopic;

  String? selfId;
  String? peerId;
  String? peerName;
  String? peerCountry;
  String? peerGenderInfo;
  DateTime? matchedAt;
  String? errorMessage;

  /// In-call chat (per match — cleared between matches).
  final List<ChatMessage> chatMessages = [];
  int unreadChatCount = 0;

  /// Emoji bursts visible during the current match (transient).
  final List<EmojiBurst> emojiBursts = [];

  /// Whether the local user has liked the current peer.
  bool likedCurrentPeer = false;
  bool likeBusy = false;

  String displayName = 'Misafir';
  String gender = 'X';      // M | F | X
  String peerGender = 'any'; // M | F | any

  List<Map<String, dynamic>> _iceServers = const [];

  bool get micOn => _media.micOn;
  bool get camOn => _media.camOn;

  Future<void> bootstrap() async {
    await Future.wait([localRenderer.initialize(), remoteRenderer.initialize()]);
  }

  void setProfile({String? name, String? gender, String? peerGender}) {
    if (name != null && name.trim().isNotEmpty) displayName = name.trim();
    if (gender != null) this.gender = gender;
    if (peerGender != null) this.peerGender = peerGender;
    notifyListeners();
  }

  Future<void> start({String mode = 'video', String topic = 'random'}) async {
    if (phase == AppPhase.connecting || phase == AppPhase.searching || phase == AppPhase.inCall) return;
    this.mode = mode;
    this.topic = topic;
    _setPhase(AppPhase.connecting);
    try {
      final stream = await _media.start(cam: mode == 'video');
      localRenderer.srcObject = stream;

      _signaling = Signaling(
        AppConfig.signalingUrl,
        accessToken: AuthController.instance.accessToken,
      );
      await _signaling!.connect();
      _msgSub = _signaling!.messages.listen(_onMessage);

      final deviceFp = await DeviceFingerprint.get();
      _signaling!.hello(name: displayName, gender: gender, peerGender: peerGender,
          deviceFp: deviceFp, mode: mode, topic: topic);
      _signaling!.enqueue(mode: mode, topic: topic);
    } catch (e) {
      errorMessage = e.toString();
      _setPhase(AppPhase.error);
    }
  }

  void next() {
    if (_signaling == null) return;
    _teardownPeer();
    _setPhase(AppPhase.searching);
    _signaling!.next();
  }

  Future<void> leave() async {
    _signaling?.leave();
    _teardownPeer();
    await _msgSub?.cancel();
    _msgSub = null;
    await _signaling?.dispose();
    _signaling = null;
    await _media.stop();
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _setPhase(AppPhase.idle);
  }

  void toggleMic() { _media.toggleMic(); notifyListeners(); }
  void toggleCam() { _media.toggleCam(); notifyListeners(); }
  Future<void> switchCamera() => _media.switchCamera();

  // ---------------------------------------------------------------- internal

  void _setPhase(AppPhase p) {
    phase = p;
    notifyListeners();
  }

  Future<void> _onMessage(Map<String, dynamic> msg) async {
    final type = msg['type'] as String?;
    switch (type) {
      case 'welcome':
        selfId = msg['selfId'] as String?;
        final ice = (msg['iceServers'] as List?)?.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        if (ice != null) _iceServers = ice;
        break;

      case 'searching':
        _setPhase(AppPhase.searching);
        break;

      case 'matched':
        await _onMatched(msg);
        break;

      case 'signal':
        final from = msg['from'] as String?;
        final payload = (msg['payload'] as Map?)?.cast<String, dynamic>();
        if (from != null && payload != null && _peer != null && _peer!.peerId == from) {
          await _peer!.handleSignal(payload);
        }
        break;

      case 'peer_left':
        _teardownPeer();
        _setPhase(AppPhase.ended);
        break;

      case 'error':
        errorMessage = (msg['message'] as String?) ?? 'unknown error';
        _setPhase(AppPhase.error);
        break;
    }
  }

  Future<void> _onMatched(Map<String, dynamic> msg) async {
    _teardownPeer();
    final pid = msg['peerId'] as String;
    final polite = msg['polite'] as bool;
    final info = (msg['peerInfo'] as Map?)?.cast<String, dynamic>();
    peerId = pid;
    peerName = info?['name'] as String? ?? 'Yabancı';
    peerCountry = info?['country'] as String?;
    peerGenderInfo = info?['gender'] as String?;
    _peerUserId = info?['userId'] as String?;
    matchTopic = msg['topic'] as String?;
    matchedAt = DateTime.now();

    final localStream = _media.stream;
    if (localStream == null) return;

    // Initiator = impolite peer (the one with smaller id under our convention).
    final initiator = !polite;

    _peer = PeerSession(
      peerId: pid,
      polite: polite,
      iceServers: _iceServers,
      localStream: localStream,
      onSignal: (payload) => _signaling?.signal(pid, payload),
      onRemoteStream: (stream) {
        remoteRenderer.srcObject = stream;
        notifyListeners();
      },
      onStateChange: (s) {
        if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          // ICE failed — TURN may be unreachable. End and let user retry.
          _teardownPeer();
          errorMessage = 'Bağlantı kurulamadı';
          _setPhase(AppPhase.error);
        }
      },
      onChatMessage: (text) {
        chatMessages.add(ChatMessage(text: text, fromMe: false, at: DateTime.now()));
        unreadChatCount += 1;
        notifyListeners();
      },
      onEmoji: (emoji) {
        emojiBursts.add(EmojiBurst(emoji: emoji, fromMe: false, at: DateTime.now()));
        notifyListeners();
        _pruneEmojis();
      },
      onGameMessage: (payload) {
        onGamePayload?.call(payload);
      },
    );
    await _peer!.init(initiator: initiator);
    chatMessages.clear();
    unreadChatCount = 0;
    emojiBursts.clear();
    likedCurrentPeer = false;
    _setPhase(AppPhase.inCall);
  }

  void sendEmoji(String emoji) {
    _peer?.sendEmoji(emoji);
    emojiBursts.add(EmojiBurst(emoji: emoji, fromMe: true, at: DateTime.now()));
    notifyListeners();
    _pruneEmojis();
  }

  Timer? _emojiPrune;
  void _pruneEmojis() {
    _emojiPrune?.cancel();
    _emojiPrune = Timer(const Duration(seconds: 3), () {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 3));
      emojiBursts.removeWhere((e) => e.at.isBefore(cutoff));
      notifyListeners();
    });
  }

  void sendChat(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _peer?.sendChat(t);
    chatMessages.add(ChatMessage(text: t, fromMe: true, at: DateTime.now()));
    notifyListeners();
  }

  void clearUnreadChat() {
    if (unreadChatCount == 0) return;
    unreadChatCount = 0;
    notifyListeners();
  }

  /// Like the current peer (if signed in and not already liked).  Returns mutual flag.
  Future<bool> likeCurrentPeer({required Future<bool> Function(String userId) likeFn}) async {
    final pid = _peer?.peerId;
    if (pid == null || likedCurrentPeer || likeBusy) return false;
    // Need the *user id* of the peer, not the socket id. Server sends peerInfo.userId.
    final peerUid = _peerUserId;
    if (peerUid == null) return false;
    likeBusy = true;
    notifyListeners();
    try {
      final mutual = await likeFn(peerUid);
      likedCurrentPeer = true;
      return mutual;
    } finally {
      likeBusy = false;
      notifyListeners();
    }
  }

  String? _peerUserId;
  String? get peerUserId => _peerUserId;

  void _teardownPeer() {
    final p = _peer;
    _peer = null;
    peerId = null;
    peerName = null;
    peerCountry = null;
    peerGenderInfo = null;
    _peerUserId = null;
    matchTopic = null;
    remoteRenderer.srcObject = null;
    // Any in-flight game belongs to the prior match — reset it.
    GameController.instance.resetAll();
    if (p != null) {
      // fire-and-forget; ignore close errors
      p.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    await leave();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    super.dispose();
  }
}
