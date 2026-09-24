import 'package:flutter/services.dart';

/// SFX via Android SoundPool.
class GameAudio {
  GameAudio();

  static const _channel =
      MethodChannel('com.defendercastelo.defender_castelo/audio');

  bool _ready = false;
  double _lastSwipeAt = 0;

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
    if (sound == 'swipe') {
      final now = DateTime.now().microsecondsSinceEpoch / 1e6;
      if (now - _lastSwipeAt < 0.06) return;
      _lastSwipeAt = now;
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
