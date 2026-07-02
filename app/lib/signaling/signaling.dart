import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// Thin WebSocket client that speaks the azar_chat signaling protocol.
class Signaling {
  Signaling(this.url, {this.accessToken});
  final String url;
  final String? accessToken;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<bool> get connection => _connection.stream;

  bool _connected = false;
  bool get connected => _connected;

  Future<void> connect() async {
    if (_channel != null) return;
    var target = url;
    if (accessToken != null && accessToken!.isNotEmpty) {
      final sep = url.contains('?') ? '&' : '?';
      target = '$url${sep}token=${Uri.encodeQueryComponent(accessToken!)}';
    }
    final ch = WebSocketChannel.connect(Uri.parse(target));
    _channel = ch;
    await ch.ready;
    _connected = true;
    _connection.add(true);
    _sub = ch.stream.listen(
      (raw) {
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          _messages.add(msg);
        } catch (_) {/* ignore malformed */}
      },
      onDone: _markDisconnected,
      onError: (_) => _markDisconnected(),
      cancelOnError: true,
    );
  }

  void _markDisconnected() {
    if (!_connected) return;
    _connected = false;
    _connection.add(false);
  }

  void _send(Map<String, dynamic> msg) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(msg));
  }

  void hello({String? name, String? gender, String? peerGender, String? deviceFp, String? mode, String? topic}) =>
      _send({'type': 'hello',
        'name': ?name, 'gender': ?gender, 'peerGender': ?peerGender,
        'deviceFp': ?deviceFp, 'mode': ?mode, 'topic': ?topic});

  void enqueue({String? mode, String? topic}) =>
      _send({'type': 'enqueue', 'mode': ?mode, 'topic': ?topic});

  void signal(String to, Map<String, dynamic> payload) =>
      _send({'type': 'signal', 'to': to, 'payload': payload});

  void next() => _send({'type': 'next'});

  void leave() => _send({'type': 'leave'});

  // ── rooms ──────────────────────────────────────────────────────────────
  void roomCreate({required String title, String? topic}) =>
      _send({'type': 'room_create', 'title': title, 'topic': ?topic});

  void roomJoin(String roomId) => _send({'type': 'room_join', 'roomId': roomId});

  void roomLeave() => _send({'type': 'room_leave'});

  void roomList() => _send({'type': 'room_list'});

  void roomSignal(String to, Map<String, dynamic> payload) =>
      _send({'type': 'room_signal', 'to': to, 'payload': payload});

  void roomChat(String text) => _send({'type': 'room_chat', 'text': text});

  void roomState({required bool muted}) => _send({'type': 'room_state', 'muted': muted});

  void roomKick(String peerId) => _send({'type': 'room_kick', 'peerId': peerId});

  void roomMute(String peerId) => _send({'type': 'room_mute', 'peerId': peerId});

  void roomExtend({required String method}) =>
      _send({'type': 'room_extend', 'method': method});

  Future<void> dispose() async {
    await _sub?.cancel();
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
    if (!_messages.isClosed) await _messages.close();
    if (!_connection.isClosed) await _connection.close();
  }
}
