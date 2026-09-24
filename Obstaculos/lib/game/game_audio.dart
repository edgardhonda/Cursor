import 'package:flutter/services.dart';

class GameAudio {
  GameAudio();

  static const _channel = MethodChannel('com.edgard.obstaculos/audio');

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

  Future<void> play(String sound) async {
    if (!_ready) return;
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
