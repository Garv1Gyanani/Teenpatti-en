import 'audio_backend_io.dart'
    if (dart.library.js_interop) 'audio_backend_web.dart';

/// Platform abstraction for low-latency bundled asset audio playback.
abstract class AudioBackend {
  Future<void> playSfx(String assetPath, {double volume = 0.6});

  Future<void> startLoop(String assetPath, {double volume = 0.18});

  Future<void> stopLoop();

  Future<void> setLoopVolume(double volume);

  void notifyUserGesture();

  void dispose();
}

AudioBackend createDefaultAudioBackend() => createPlatformAudioBackend();
