import 'package:flutter/services.dart';

class GameAudioController {
  GameAudioController();

  static const _channel = MethodChannel('com.edgard.batalha/game_audio');

  bool _ready = false;
  bool _disposed = false;

  Future<void> init() async {
    if (_ready || _disposed) return;
    try {
      await _channel.invokeMethod<void>('init');
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> play(String sound) async {
    if (!_ready || _disposed) return;
    try {
      await _channel.invokeMethod<void>('play', {'sound': sound});
    } on MissingPluginException {
      // Tests and non-Android targets have no native audio channel.
    } on PlatformException {
      // Sound failures must not interrupt gameplay.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (!_ready) return;
    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {}
    _ready = false;
  }
}
