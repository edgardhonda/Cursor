import 'package:flutter/services.dart';

/// SFX via Android SoundPool.
class GameAudio {
  GameAudio();

  static const _channel = MethodChannel('com.edgard.garras/audio');

  double _lastWhooshAt = 0;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _channel.invokeMethod<void>('init');
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> playWhoosh({required double wallTime}) async {
    if (wallTime - _lastWhooshAt < 0.35) return;
    _lastWhooshAt = wallTime;
    await _play('whoosh');
  }

  /// Nota distinta por cor de garra (0–7).
  Future<void> playTap(int colorId) async {
    if (colorId < 0 || colorId > 7) return;
    await _play('tap_$colorId');
  }

  Future<void> playSnap() => _play('snap');

  Future<void> playFall() => _play('fall');

  Future<void> playMiss() => _play('miss');

  Future<void> playChirp() => _play('chirp');

  Future<void> _play(String name) async {
    if (!_ready) return;
    try {
      await _channel.invokeMethod<void>('play', {'sound': name});
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
