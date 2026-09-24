import 'package:flutter/services.dart';

class GameAudio {
  GameAudio();

  static const _channel = MethodChannel('com.edgard.mapa/audio');

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

  Future<void> playStep() => _play('step');

  Future<void> playBump() => _play('bump');

  Future<void> playVictory() => _play('victory');

  Future<void> playTick() => _play('tick');

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
