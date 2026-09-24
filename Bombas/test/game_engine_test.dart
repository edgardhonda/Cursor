import 'dart:ui';

import 'package:bombas/audio/game_audio_controller.dart';
import 'package:bombas/game/game_engine.dart';
import 'package:bombas/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts with five trees and three worker groups', () {
    final engine = GameEngine()..setBounds(const Size(800, 600));

    expect(engine.trees, hasLength(5));
    expect(engine.workers, hasLength(3));
    expect(engine.houses, isEmpty);
    engine.dispose();
  });

  test('supports simultaneous bomb placement and fuse activation', () {
    final engine = GameEngine()..setBounds(const Size(800, 600));

    engine.pointerDown(1, const Offset(100, 100));
    engine.pointerUp(1, const Offset(100, 100));
    engine.pointerDown(2, const Offset(700, 500));
    engine.pointerUp(2, const Offset(700, 500));
    expect(engine.bombs, hasLength(2));
    expect(engine.bombs.every((bomb) => bomb.phase == BombPhase.idle), isTrue);

    engine.pointerDown(3, const Offset(100, 100));
    engine.pointerUp(3, const Offset(100, 100));
    expect(engine.bombs, hasLength(2));
    expect(engine.bombs.first.phase, BombPhase.fuse);
    engine.dispose();
  });

  test('restart restores the initial world', () {
    final engine = GameEngine()..setBounds(const Size(800, 600));
    engine.pointerDown(1, const Offset(100, 100));
    engine.pointerUp(1, const Offset(100, 100));

    engine.reset();

    expect(engine.trees, hasLength(5));
    expect(engine.workers, hasLength(3));
    expect(engine.bombs, isEmpty);
    expect(engine.houses, isEmpty);
    expect(engine.ashes, isEmpty);
    expect(engine.finishedStrokes, isEmpty);
    engine.dispose();
  });

  test('explosion ignites nearby idle bombs', () {
    final engine = GameEngine()..setBounds(const Size(800, 600));
    const posA = Offset(200, 300);
    const posB = Offset(250, 300);

    engine.pointerDown(1, posA);
    engine.pointerUp(1, posA);
    engine.pointerDown(2, posB);
    engine.pointerUp(2, posB);
    engine.pointerDown(3, posA);
    engine.pointerUp(3, posA);

    for (var ms = 0; ms <= 3500; ms += 50) {
      engine.tick(Duration(milliseconds: ms));
    }

    final bombB = engine.bombs.firstWhere(
      (bomb) => (bomb.position - posB).distance < 1,
    );
    expect(bombB.phase, BombPhase.fuse);
    engine.dispose();
  });

  test('emits explosion, fire and collapse sounds in sequence', () {
    final cues = <GameSoundCue>[];
    final engine = GameEngine(onSound: cues.add)
      ..setBounds(const Size(800, 600));
    final target = engine.trees.first.position;
    engine.pointerDown(1, target);
    engine.pointerUp(1, target);
    engine.pointerDown(2, target);
    engine.pointerUp(2, target);

    for (var frame = 0; frame < 160; frame++) {
      engine.tick(Duration(milliseconds: frame * 50));
    }

    expect(cues, contains(GameSoundCue.explosion));
    expect(cues, contains(GameSoundCue.fire));
    expect(cues, contains(GameSoundCue.collapse));
    engine.dispose();
  });

  test('drag draws thick speed-colored strokes that fade after 10s', () {
    final engine = GameEngine()..setBounds(const Size(800, 600));
    engine.pointerDown(7, const Offset(40, 40));
    engine.pointerMove(7, const Offset(140, 90));
    engine.pointerMove(7, const Offset(260, 170));
    engine.pointerUp(7, const Offset(300, 200));

    expect(engine.finishedStrokes.length, greaterThan(1));
    expect(strokeSpeedColors, hasLength(10));
    expect(
      engine.finishedStrokes.every((p) => p.width >= strokeWidthForSpeed(0)),
      isTrue,
    );

    final aged = DateTime.now().subtract(const Duration(seconds: 11));
    engine.finishedStrokes
      ..clear()
      ..add(
        StrokePoint(
          position: const Offset(10, 10),
          color: strokeSpeedColors.first,
          width: 12,
          createdAt: aged,
        ),
      );
    engine.tick(const Duration(milliseconds: 50));
    expect(engine.finishedStrokes, isEmpty);
    engine.dispose();
  });

  test('workers freeze on strokes and avoid them when walking', () {
    final engine = GameEngine()..setBounds(const Size(800, 600));
    final worker = engine.workers.first;
    final start = worker.position;

    // Risco atravessando o grupo.
    engine.pointerDown(9, start + const Offset(-40, 0));
    engine.pointerMove(9, start + const Offset(0, 0));
    engine.pointerMove(9, start + const Offset(40, 0));
    engine.pointerUp(9, start + const Offset(60, 0));

    for (var i = 0; i < 20; i++) {
      engine.tick(Duration(milliseconds: i * 50));
    }
    expect((worker.position - start).distance, lessThan(4));

    // Sem risco no caminho: consegue avançar.
    engine.finishedStrokes.clear();
    final before = worker.position;
    for (var i = 0; i < 30; i++) {
      engine.tick(Duration(milliseconds: 200 + i * 50));
    }
    expect((worker.position - before).distance, greaterThan(5));
    engine.dispose();
  });
}
