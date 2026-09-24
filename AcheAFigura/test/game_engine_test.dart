import 'dart:ui';

import 'package:ache_a_figura/audio/game_audio_controller.dart';
import 'package:ache_a_figura/game/game_engine.dart';
import 'package:ache_a_figura/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lays out 20 unique non-overlapping tiles around the center', () {
    final engine = GameEngine()..setBounds(const Size(400, 720));

    expect(engine.tiles, hasLength(20));
    expect(engine.tiles.map((tile) => tile.emoji).toSet(), hasLength(20));
    for (var first = 0; first < engine.tiles.length; first++) {
      expect(
        engine.tiles[first].bounds.overlaps(engine.centerTileBounds),
        isFalse,
      );
      for (var second = first + 1; second < engine.tiles.length; second++) {
        expect(
          engine.tiles[first].bounds.overlaps(engine.tiles[second].bounds),
          isFalse,
        );
      }
    }
    engine.dispose();
  });

  test('wrong and correct selections emit their respective sounds', () {
    final cues = <GameSoundCue>[];
    final engine = GameEngine(onSound: cues.add)
      ..setBounds(const Size(800, 480));
    final wrong = engine.tiles.firstWhere(
      (tile) => tile.emoji != engine.targetEmoji,
    );
    engine.pointerDown(1, wrong.bounds.center);
    engine.pointerUp(1, wrong.bounds.center);
    expect(cues.last, GameSoundCue.failure);

    final correct = engine.tiles.firstWhere(
      (tile) => tile.emoji == engine.targetEmoji,
    );
    engine.pointerDown(1, correct.bounds.center);
    engine.pointerUp(1, correct.bounds.center);
    expect(cues.last, GameSoundCue.tada);
    expect(engine.tiles, hasLength(19));
    engine.dispose();
  });

  test('finishing every tile shows completion and emits success', () {
    final cues = <GameSoundCue>[];
    final engine = GameEngine(onSound: cues.add)
      ..setBounds(const Size(800, 480));
    var frame = 0;

    while (engine.tiles.isNotEmpty) {
      final correct = engine.tiles.firstWhere(
        (tile) => tile.emoji == engine.targetEmoji,
      );
      engine.pointerDown(1, correct.bounds.center);
      engine.pointerUp(1, correct.bounds.center);
      for (var step = 0; step < 20; step++) {
        engine.tick(Duration(milliseconds: frame++ * 50));
      }
    }

    expect(engine.complete, isTrue);
    expect(cues.last, GameSoundCue.success);
    engine.dispose();
  });

  test('restart cycles animals, letters/numbers and varied emojis', () {
    final engine = GameEngine()..setBounds(const Size(400, 720));
    expect(engine.pack, EmojiPack.animals);
    expect(
      engine.tiles.map((tile) => tile.emoji).toSet(),
      GameEngine.animalEmojis.toSet(),
    );

    engine.restart();
    expect(engine.pack, EmojiPack.lettersAndNumbers);
    final letters = engine.tiles.map((tile) => tile.emoji).toSet();
    expect(letters, hasLength(20));
    expect(letters.every(GameEngine.letterNumberPool.contains), isTrue);

    engine.restart();
    expect(engine.pack, EmojiPack.varied);
    final varied = engine.tiles.map((tile) => tile.emoji).toSet();
    expect(varied, hasLength(20));
    expect(varied.every(GameEngine.variedEmojiPool.contains), isTrue);

    engine.restart();
    expect(engine.pack, EmojiPack.animals);
    engine.dispose();
  });

  test('drag draws colored strokes and tap selects tiles', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.pointerDown(7, const Offset(40, 40));
    engine.pointerMove(7, const Offset(120, 80));
    engine.pointerMove(7, const Offset(220, 140));
    engine.pointerUp(7, const Offset(250, 160));

    expect(engine.finishedStrokes.length, greaterThan(1));
    expect(engine.activeStrokes, isEmpty);
    expect(strokeSpeedColors, hasLength(greaterThanOrEqualTo(10)));
    expect(strokeTopSpeedPxPerSec, 1440);
    expect(
      engine.finishedStrokes.every((p) => p.width >= strokeWidthForSpeed(0)),
      isTrue,
    );

    final before = engine.tiles.length;
    final wrong = engine.tiles.firstWhere(
      (tile) => tile.emoji != engine.targetEmoji,
    );
    engine.pointerDown(2, wrong.bounds.center);
    engine.pointerUp(2, wrong.bounds.center);
    expect(engine.tiles, hasLength(before));
    engine.dispose();
  });
}
