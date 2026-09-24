import 'package:flutter/services.dart';

/// SFX via Android SoundPool.
class GameAudio {
  GameAudio();

  static const _channel = MethodChannel('com.destruir.destruir/audio');

  bool _ready = false;
  double _lastDragAt = 0;
  double _lastDestroyAt = 0;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _channel.invokeMethod<void>('init');
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> play(String sound) async {
    if (!_ready) return;
    final now = DateTime.now().microsecondsSinceEpoch / 1e6;
    if (sound == 'drag') {
      if (now - _lastDragAt < 0.05) return;
      _lastDragAt = now;
    } else if (sound == 'destroy') {
      if (now - _lastDestroyAt < 0.04) return;
      _lastDestroyAt = now;
    }
    try {
      await _channel.invokeMethod<void>('play', {'sound': sound});
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (!_ready) return;
    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {}
    _ready = false;
  }
}
