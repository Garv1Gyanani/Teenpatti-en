import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'audio_backend.dart';

/// Pure-Dart Web Audio API backend (`package:web`) with decoded buffer caching,
/// overlapping SFX playback, gain ducking, and autoplay-policy unlock.
class WebAudioApiBackend implements AudioBackend {
  web.AudioContext? _context;
  final Map<String, web.AudioBuffer> _bufferCache = <String, web.AudioBuffer>{};
  final Map<String, Future<web.AudioBuffer?>> _inflightDecodes =
      <String, Future<web.AudioBuffer?>>{};

  web.AudioBufferSourceNode? _loopSource;
  web.GainNode? _loopGain;
  String? _pendingLoopAsset;
  double _loopVolume = 0.12;
  bool _loopWanted = false;
  int _loopGeneration = 0;
  bool _disposed = false;

  web.AudioContext? _ensureContext() {
    if (_disposed) return null;
    try {
      return _context ??= web.AudioContext();
    } catch (_) {
      return null;
    }
  }

  Future<web.AudioBuffer?> _loadBuffer(String assetPath) async {
    final cached = _bufferCache[assetPath];
    if (cached != null) return cached;

    final pending = _inflightDecodes[assetPath];
    if (pending != null) return pending;

    final future = () async {
      final ctx = _ensureContext();
      if (ctx == null) return null;
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = Uint8List.fromList(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final buffer = await ctx.decodeAudioData(bytes.buffer.toJS).toDart;
        _bufferCache[assetPath] = buffer;
        return buffer;
      } catch (_) {
        return null;
      } finally {
        _inflightDecodes.remove(assetPath);
      }
    }();

    _inflightDecodes[assetPath] = future;
    return future;
  }

  Future<void> _resumeIfNeeded(web.AudioContext ctx) async {
    if (ctx.state == 'suspended') {
      try {
        await ctx.resume().toDart;
      } catch (_) {}
    }
  }

  @override
  void notifyUserGesture() {
    final ctx = _ensureContext();
    if (ctx == null) return;
    unawaited(() async {
      await _resumeIfNeeded(ctx);
      if (_loopWanted && _loopSource == null && _pendingLoopAsset != null) {
        await _startLoopInternal(_pendingLoopAsset!, _loopVolume);
      }
    }());
  }

  @override
  Future<void> playSfx(String assetPath, {double volume = 0.6}) async {
    final ctx = _ensureContext();
    if (ctx == null) return;
    await _resumeIfNeeded(ctx);
    if (ctx.state != 'running') return;

    final buffer = await _loadBuffer(assetPath);
    if (buffer == null || _disposed) return;

    try {
      final source = ctx.createBufferSource();
      source.buffer = buffer;
      final gain = ctx.createGain();
      gain.gain.value = volume.clamp(0.0, 1.0);
      source.connect(gain);
      gain.connect(ctx.destination);
      source.start();
    } catch (_) {}
  }

  @override
  Future<void> startLoop(String assetPath, {double volume = 0.18}) async {
    _loopWanted = true;
    _pendingLoopAsset = assetPath;
    _loopVolume = volume.clamp(0.0, 1.0);

    final ctx = _ensureContext();
    if (ctx == null) return;
    await _resumeIfNeeded(ctx);
    if (ctx.state != 'running') {
      // Will resume seamlessly on first user interaction via notifyUserGesture().
      return;
    }
    await _startLoopInternal(assetPath, _loopVolume);
  }

  Future<void> _startLoopInternal(String assetPath, double volume) async {
    final ctx = _ensureContext();
    if (ctx == null || _disposed || !_loopWanted) return;

    final generation = ++_loopGeneration;
    final buffer = await _loadBuffer(assetPath);
    if (buffer == null ||
        _disposed ||
        !_loopWanted ||
        generation != _loopGeneration) {
      return;
    }

    _stopLoopNodes();
    try {
      final source = ctx.createBufferSource();
      source.buffer = buffer;
      source.loop = true;

      final gain = ctx.createGain();
      gain.gain.value = _loopVolume.clamp(0.0, 1.0);
      source.connect(gain);
      gain.connect(ctx.destination);
      source.start();

      _loopSource = source;
      _loopGain = gain;
    } catch (_) {}
  }

  void _stopLoopNodes() {
    try {
      _loopSource?.stop();
    } catch (_) {}
    try {
      _loopSource?.disconnect();
      _loopGain?.disconnect();
    } catch (_) {}
    _loopSource = null;
    _loopGain = null;
  }

  @override
  Future<void> stopLoop() async {
    _loopWanted = false;
    _loopGeneration += 1;
    _stopLoopNodes();
  }

  @override
  Future<void> setLoopVolume(double volume) async {
    _loopVolume = volume.clamp(0.0, 1.0);
    if (_loopGain != null) {
      _loopGain!.gain.value = _loopVolume;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loopWanted = false;
    _loopGeneration += 1;
    _stopLoopNodes();
    try {
      _context?.close();
    } catch (_) {}
    _context = null;
    _bufferCache.clear();
  }
}

AudioBackend createPlatformAudioBackend() => WebAudioApiBackend();
