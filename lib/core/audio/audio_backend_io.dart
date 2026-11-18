import 'package:flutter/services.dart';

import 'audio_backend.dart';

/// Native/test audio backend communicating over `ace_society/audio` when
/// available and failing silently when no platform handler is registered
/// (such as in `flutter test`).
class PlatformMethodAudioBackend implements AudioBackend {
  static const MethodChannel _channel = MethodChannel('ace_society/audio');

  @override
  Future<void> playSfx(String assetPath, {double volume = 0.6}) async {
    try {
      await _channel.invokeMethod<void>('playSfx', <String, dynamic>{
        'assetPath': assetPath,
        'volume': volume,
      });
    } on MissingPluginException {
      // Safe no-op in headless widget tests and unsupported desktop targets.
    } on PlatformException {
      // Ignore transient audio focus / decoder errors.
    }
  }

  @override
  Future<void> startLoop(String assetPath, {double volume = 0.18}) async {
    try {
      await _channel.invokeMethod<void>('startLoop', <String, dynamic>{
        'assetPath': assetPath,
        'volume': volume,
      });
    } on MissingPluginException {
      // Safe no-op.
    } on PlatformException {
      // Safe no-op.
    }
  }

  @override
  Future<void> stopLoop() async {
    try {
      await _channel.invokeMethod<void>('stopLoop');
    } on MissingPluginException {
      // Safe no-op.
    } on PlatformException {
      // Safe no-op.
    }
  }

  @override
  Future<void> setLoopVolume(double volume) async {
    try {
      await _channel.invokeMethod<void>('setLoopVolume', <String, dynamic>{
        'volume': volume,
      });
    } on MissingPluginException {
      // Safe no-op.
    } on PlatformException {
      // Safe no-op.
    }
  }

  @override
  void notifyUserGesture() {}

  @override
  void dispose() {
    // Nothing persistent held on Dart side.
  }
}

AudioBackend createPlatformAudioBackend() => PlatformMethodAudioBackend();
