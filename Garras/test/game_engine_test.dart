import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garras/game/game_engine.dart';
import 'package:garras/models/game_models.dart';

void main() {
  test('builds colored holes and initial planes', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    expect(engine.holes.length, gameColors.length);
    expect(engine.planes, isNotEmpty);
    expect(engine.holes.map((h) => h.colorId).toSet().length, gameColors.length);
    engine.dispose();
  });

  test('tapping a hole launches a claw', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    final hole = engine.holes.first;
    expect(hole.clawPhase, ClawPhase.idle);
    engine.tapAt(hole.center);
    expect(hole.clawPhase, ClawPhase.extending);
    engine.dispose();
  });

  test('matching plane above hole can be caught and scored', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    engine.planes.clear();
    final hole = engine.holes.first;
    engine.planes.add(
      PlaneModel(
        id: 99,
        colorId: hole.colorId,
        position: Offset(hole.center.dx, hole.center.dy - 160),
        velocity: const Offset(40, 0),
        size: 28,
      ),
    );
    engine.tapAt(hole.center);
    for (var i = 0; i < 120; i++) {
      engine.tick(Duration(milliseconds: 20 + i * 16));
    }
    expect(engine.score, greaterThan(0));
    engine.dispose();
  });

  test('wrong-color plane is not caught', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    engine.planes.clear();
    final hole = engine.holes.first;
    final otherColor = (hole.colorId + 1) % gameColors.length;
    engine.planes.add(
      PlaneModel(
        id: 42,
        colorId: otherColor,
        position: Offset(hole.center.dx, hole.center.dy - 140),
        velocity: const Offset(30, 0),
        size: 28,
      ),
    );
    engine.tapAt(hole.center);
    for (var i = 0; i < 80; i++) {
      engine.tick(Duration(milliseconds: 20 + i * 16));
    }
    expect(engine.score, 0);
    expect(
      engine.planes.any((p) => p.id == 42 && p.phase == PlanePhase.flying),
      isTrue,
    );
    engine.dispose();
  });

  test('restart clears score', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.score = 9;
    engine.reset();
    expect(engine.score, 0);
    expect(engine.holes, isNotEmpty);
    engine.dispose();
  });
}
