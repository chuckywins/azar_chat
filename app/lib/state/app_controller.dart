import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../auth/auth_controller.dart';
import '../config.dart';
import '../signaling/signaling.dart';
import '../webrtc/media.dart';
import '../webrtc/peer.dart';

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

  AppPhase phase = AppPhase.idle;
  String? selfId;
  String? peerId;
  String? peerName;
  String? errorMessage;

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

  Future<void> start() async {
    if (phase == AppPhase.connecting || phase == AppPhase.searching || phase == AppPhase.inCall) return;
    _setPhase(AppPhase.connecting);
    try {
      final stream = await _media.start();
      localRenderer.srcObject = stream;

      _signaling = Signaling(
        AppConfig.signalingUrl,
        accessToken: AuthController.instance.accessToken,
      );
      await _signaling!.connect();
      _msgSub = _signaling!.messages.listen(_onMessage);

      _signaling!.hello(name: displayName, gender: gender, peerGender: peerGender);
      _signaling!.enqueue();
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
    );
    await _peer!.init(initiator: initiator);
    _setPhase(AppPhase.inCall);
  }

  void _teardownPeer() {
    final p = _peer;
    _peer = null;
    peerId = null;
    peerName = null;
    remoteRenderer.srcObject = null;
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
