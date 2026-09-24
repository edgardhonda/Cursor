import 'package:flutter/services.dart';

class GameAudio {
  GameAudio();

  static const _channel = MethodChannel('com.edgard.sapos/audio');

  double _lastBuzzAt = 0;
  double _lastRibbitAt = 0;
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

  Future<void> playTongue() => _play('tongue');

  Future<void> playGulp() => _play('gulp');

  Future<void> playBoom() => _play('boom');

  Future<void> playCheer() => _play('cheer');

  Future<void> playBuzz({required double wallTime}) async {
    if (wallTime - _lastBuzzAt < 1.4) return;
    _lastBuzzAt = wallTime;
    await _play('buzz');
  }

  Future<void> playRibbit({required double wallTime}) async {
    if (wallTime - _lastRibbitAt < 1.1) return;
    _lastRibbitAt = wallTime;
    await _play('ribbit');
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
