import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marcianos/game/game_engine.dart';
import 'package:marcianos/models/game_models.dart';

void main() {
  test('builds a non-self-crossing left-to-right track', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    final track = engine.track!;
    expect(track.points.length, greaterThan(10));
    expect(track.start.dx, lessThan(track.finish.dx));
    for (var i = 1; i < track.points.length; i++) {
      expect(track.points[i].dx, greaterThanOrEqualTo(track.points[i - 1].dx));
    }
    expect(engine.car, isNotNull);
    expect(engine.martians, isNotEmpty);
    engine.dispose();
  });

  test('car progresses along the track until finish shows trophy', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    for (var i = 0; i < 2000; i++) {
      engine.martians.clear();
      engine.tick(Duration(milliseconds: 16 * (i + 1)));
      if (engine.showTrophy) break;
    }
    expect(engine.showTrophy, isTrue);
    expect(engine.wins, greaterThanOrEqualTo(1));
    engine.dispose();
  });

  test('tapping a martian fires a yellow laser that can defeat it', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    final target = MartianModel(
      id: 9999,
      position: engine.car!.position + const Offset(120, -40),
      size: MartianSize.small,
      color: martianColors.first,
    );
    engine.martians
      ..clear()
      ..add(target);
    engine.pointerDown(1, target.position);
    engine.pointerUp(1, target.position);
    expect(engine.lasers, isNotEmpty);

    for (var i = 0; i < 80; i++) {
      engine.tick(Duration(milliseconds: 32 + i * 16));
    }
    expect(engine.martians.any((m) => m.id == target.id), isFalse);
    engine.dispose();
  });

  test('large martians need three hits', () {
    expect(MartianSize.large.maxHits, 3);
    expect(MartianSize.medium.maxHits, 2);
    expect(MartianSize.small.maxHits, 1);
  });

  test('martians chase the car and speed up when closer', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    final car = engine.car!;
    car.invulnerableUntil = 9999;
    final hunter = MartianModel(
      id: 4242,
      position: car.position + const Offset(280, 0),
      size: MartianSize.medium,
      color: martianColors[1],
    );
    engine.martians
      ..clear()
      ..add(hunter);

    final farDist = (hunter.position - car.position).distance;
    for (var i = 0; i < 20; i++) {
      engine.tick(Duration(milliseconds: 32 + i * 16));
    }
    final midDist = (hunter.position - car.position).distance;
    expect(midDist, lessThan(farDist));

    // Coloca bem perto: deve avançar mais em poucos frames (aceleração).
    hunter.position = car.position + const Offset(90, 0);
    final nearStart = (hunter.position - car.position).distance;
    final nearPos = hunter.position;
    for (var i = 0; i < 8; i++) {
      engine.tick(Duration(milliseconds: 400 + i * 16));
    }
    final nearMoved = (hunter.position - nearPos).distance;
    final nearEnd = (hunter.position - car.position).distance;

    hunter.position = car.position + const Offset(320, 0);
    final farPos = hunter.position;
    for (var i = 0; i < 8; i++) {
      engine.tick(Duration(milliseconds: 600 + i * 16));
    }
    final farMoved = (hunter.position - farPos).distance;

    expect(nearMoved, greaterThan(farMoved));
    expect(nearEnd, lessThan(nearStart));

    hunter.position = car.position + const Offset(80, 0);
    engine.tick(const Duration(milliseconds: 900));
    expect(hunter.phase, MartianPhase.attacking);
    engine.dispose();
  });

  test('martian reaching the car destroys it then respawns another', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    final car = engine.car!;
    car.invulnerableUntil = 0;
    final attacker = engine.martians.first;
    attacker.position = car.position;

    engine.tick(const Duration(milliseconds: 50));
    engine.tick(const Duration(milliseconds: 100));
    expect(car.phase, CarPhase.exploding);

    // Afasta o atacante para o novo buggy não ser destruído na hora.
    attacker.position = const Offset(10, 10);

    for (var i = 0; i < 500; i++) {
      engine.tick(Duration(milliseconds: 150 + i * 20));
      if (engine.car != null &&
          engine.car!.phase == CarPhase.racing &&
          !identical(engine.car, car)) {
        break;
      }
    }
    expect(engine.car, isNotNull);
    expect(engine.car!.phase, CarPhase.racing);
    expect(identical(engine.car, car), isFalse);
    expect(engine.car!.progress, lessThan(0.1));
    expect(buggyColors.contains(engine.car!.color), isTrue);
    engine.dispose();
  });

  test('restart restores a fresh race', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    for (var i = 0; i < 100; i++) {
      engine.tick(Duration(milliseconds: 16 * (i + 1)));
    }
    engine.reset();
    expect(engine.car!.progress, 0);
    expect(engine.showTrophy, isFalse);
    expect(engine.wins, 0);
    expect(engine.lasers, isEmpty);
    engine.dispose();
  });

  test('track changes on each restart', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    final first = List<Offset>.from(engine.track!.points);
    var different = false;
    for (var i = 0; i < 10; i++) {
      engine.reset();
      final next = engine.track!.points;
      for (var j = 0; j < next.length; j++) {
        if ((next[j] - first[j]).distance > 2) {
          different = true;
          break;
        }
      }
      if (different) break;
    }
    expect(different, isTrue);
    engine.dispose();
  });

  test('scratching across a martian destroys it instantly', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    final target = MartianModel(
      id: 7777,
      position: const Offset(400, 240),
      size: MartianSize.large,
      color: martianColors.first,
    );
    engine.martians
      ..clear()
      ..add(target);

    engine.pointerDown(2, const Offset(280, 240));
    engine.pointerMove(2, const Offset(320, 240));
    engine.pointerMove(2, const Offset(400, 240));
    engine.pointerMove(2, const Offset(480, 240));
    engine.pointerUp(2, const Offset(520, 240));

    expect(target.phase, MartianPhase.dead);
    expect(engine.scratches, isNotEmpty);
    expect(
      engine.scratches.every(
        (s) => ScratchSpeedLevel.values.contains(s.level),
      ),
      isTrue,
    );
    engine.dispose();
  });

  test('scratch speed maps to five color levels', () {
    expect(ScratchSpeedLevelX.fromSpeed(100), ScratchSpeedLevel.blue);
    expect(ScratchSpeedLevelX.fromSpeed(500), ScratchSpeedLevel.green);
    expect(ScratchSpeedLevelX.fromSpeed(1000), ScratchSpeedLevel.yellow);
    expect(ScratchSpeedLevelX.fromSpeed(1600), ScratchSpeedLevel.orange);
    expect(ScratchSpeedLevelX.fromSpeed(3000), ScratchSpeedLevel.red);
  });
}
