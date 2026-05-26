import 'package:flutter_webrtc/flutter_webrtc.dart';

class LocalMedia {
  MediaStream? stream;

  Future<MediaStream> start({bool mic = true, bool cam = true}) async {
    stream = await navigator.mediaDevices.getUserMedia({
      'audio': mic,
      'video': cam
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
              'frameRate': {'ideal': 24},
            }
          : false,
    });
    return stream!;
  }

  void toggleMic() {
    for (final t in stream?.getAudioTracks() ?? const []) {
      t.enabled = !t.enabled;
    }
  }

  void toggleCam() {
    for (final t in stream?.getVideoTracks() ?? const []) {
      t.enabled = !t.enabled;
    }
  }

  bool get micOn => stream?.getAudioTracks().any((t) => t.enabled) ?? false;
  bool get camOn => stream?.getVideoTracks().any((t) => t.enabled) ?? false;

  Future<void> switchCamera() async {
    final t = stream?.getVideoTracks().firstOrNull;
    if (t != null) await Helper.switchCamera(t);
  }

  Future<void> stop() async {
    for (final t in stream?.getTracks() ?? const []) {
      await t.stop();
    }
    await stream?.dispose();
    stream = null;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
