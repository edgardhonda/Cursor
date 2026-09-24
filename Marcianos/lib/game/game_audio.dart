import 'package:flutter/services.dart';

/// Sci-fi SFX via Android SoundPool (laser / explosion / lightsaber whoosh).
class GameAudio {
  GameAudio();

  static const _channel = MethodChannel('com.edgard.marcianos/audio');

  double _lastSaberAt = 0;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _channel.invokeMethod<void>('init');
      _ready = true;
    } catch (_) {
      // Desktop/tests or missing platform impl — silent no-op.
      _ready = false;
    }
  }

  Future<void> playLaser() => _play('laser');

  Future<void> playExplosion() => _play('explosion');

  Future<void> playChirp() => _play('chirp');

  /// Lightsaber-like whoosh while scratching; rate-limited to avoid spam.
  Future<void> playSaber({required double wallTime}) async {
    if (wallTime - _lastSaberAt < 0.09) return;
    _lastSaberAt = wallTime;
    await _play('saber');
  }

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
