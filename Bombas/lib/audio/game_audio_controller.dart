import 'package:flutter/services.dart';

enum GameSoundCue { construction, explosion, fire, collapse }

class GameAudioController {
  static const _channel = MethodChannel('com.edgard.bombas/game_audio');
  bool _disposed = false;

  Future<void> play(GameSoundCue cue) async {
    if (_disposed) return;
    await _invoke('playSound', cue.name);
  }

  Future<void> pauseAll() => _invoke('pauseAll');

  Future<void> resumeAll() => _invoke('resumeAll');

  Future<void> stopAll() => _invoke('stopAll');

  Future<void> dispose() async {
    _disposed = true;
    await stopAll();
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Tests and non-Android targets have no native audio channel.
    } on PlatformException {
      // A sound failure must never interrupt the game.
    }
  }
}
