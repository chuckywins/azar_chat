import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// 1-to-1 RTCPeerConnection wrapper with perfect-negotiation pattern.
/// Tied to the lifetime of a single match — dispose & re-create on "next".
class PeerSession {
  PeerSession({
    required this.peerId,
    required this.polite,
    required this.iceServers,
    required this.localStream,
    required this.onSignal,
    required this.onRemoteStream,
    required this.onStateChange,
    required this.onChatMessage,
  });

  final String peerId;
  final bool polite;
  final List<Map<String, dynamic>> iceServers;
  final MediaStream localStream;

  final void Function(Map<String, dynamic> payload) onSignal;
  final void Function(MediaStream stream) onRemoteStream;
  final void Function(RTCPeerConnectionState state) onStateChange;
  final void Function(String text) onChatMessage;

  RTCPeerConnection? _pc;
  RTCDataChannel? _chat;
  bool _makingOffer = false;
  bool _ignoreOffer = false;
  bool _disposed = false;

  Future<void> init({required bool initiator}) async {
    _pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });

    for (final t in localStream.getTracks()) {
      await _pc!.addTrack(t, localStream);
    }

    _pc!.onIceCandidate = (c) {
      if (_disposed || c.candidate == null) return;
      onSignal({
        'kind': 'ice',
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) onRemoteStream(event.streams.first);
    };

    _pc!.onConnectionState = (s) {
      if (!_disposed) onStateChange(s);
    };

    _pc!.onRenegotiationNeeded = () async {
      if (_disposed) return;
      try {
        _makingOffer = true;
        final offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);
        onSignal({'kind': 'offer', 'sdp': offer.sdp, 'sdpType': offer.type});
      } catch (_) {
        // swallow; renegotiation will retry on next trigger
      } finally {
        _makingOffer = false;
      }
    };

    _pc!.onDataChannel = (channel) {
      if (channel.label == 'chat') _bindChat(channel);
    };

    if (initiator) {
      // Create the chat channel on the initiator side; offer will be triggered automatically.
      final dc = await _pc!.createDataChannel(
        'chat',
        RTCDataChannelInit()..ordered = true,
      );
      _bindChat(dc);

      try {
        final offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);
        onSignal({'kind': 'offer', 'sdp': offer.sdp, 'sdpType': offer.type});
      } catch (_) {}
    }
  }

  void _bindChat(RTCDataChannel channel) {
    _chat = channel;
    channel.onMessage = (msg) {
      if (_disposed) return;
      onChatMessage(msg.text);
    };
  }

  void sendChat(String text) {
    final c = _chat;
    if (c == null) return;
    if (c.state != RTCDataChannelState.RTCDataChannelOpen) return;
    c.send(RTCDataChannelMessage(text));
  }

  Future<void> handleSignal(Map<String, dynamic> payload) async {
    final pc = _pc;
    if (pc == null || _disposed) return;
    final kind = payload['kind'] as String?;
    try {
      if (kind == 'offer' || kind == 'answer') {
        final desc = RTCSessionDescription(
          payload['sdp'] as String,
          payload['sdpType'] as String,
        );
        final sigState = await pc.getSignalingState();
        final offerCollision = kind == 'offer' &&
            (_makingOffer || sigState != RTCSignalingState.RTCSignalingStateStable);
        _ignoreOffer = !polite && offerCollision;
        if (_ignoreOffer) return;
        await pc.setRemoteDescription(desc);
        if (kind == 'offer') {
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          onSignal({'kind': 'answer', 'sdp': answer.sdp, 'sdpType': answer.type});
        }
      } else if (kind == 'ice') {
        final cand = RTCIceCandidate(
          payload['candidate'] as String?,
          payload['sdpMid'] as String?,
          payload['sdpMLineIndex'] as int?,
        );
        try {
          await pc.addCandidate(cand);
        } catch (_) {
          if (!_ignoreOffer) rethrow;
        }
      }
    } catch (_) {/* keep session alive on transient errors */}
  }

  Future<void> dispose() async {
    _disposed = true;
    try { await _chat?.close(); } catch (_) {}
    _chat = null;
    try { await _pc?.close(); } catch (_) {}
    _pc = null;
  }
}
