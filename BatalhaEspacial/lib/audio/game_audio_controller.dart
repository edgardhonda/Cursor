import 'package:flutter/services.dart';

enum GameSoundCue { start, alert, laser, destroy, wrong, blast }

class GameAudioController {
  GameAudioController();

  static const _channel =
      MethodChannel('com.edgard.batalha_espacial/game_audio');

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

  Future<void> play(GameSoundCue cue) async {
    if (!_ready || _disposed) return;
    try {
      await _channel.invokeMethod<void>('play', {'sound': cue.name});
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
