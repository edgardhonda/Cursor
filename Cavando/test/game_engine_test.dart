import 'package:cavando/game/game_engine.dart';
import 'package:cavando/models/game_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock {
  int ms = 0;

  void advance(GameEngine engine, int milliseconds, {void Function()? onTick}) {
    final end = ms + milliseconds;
    while (ms < end) {
      ms += 16;
      engine.tick(Duration(milliseconds: ms));
      onTick?.call();
    }
  }
}

GameEngine _engine() {
  return GameEngine(seed: 11)..setSize(const Size(400, 800));
}

void main() {
  test('mountain fills the screen width and height', () {
    final engine = _engine();
    final m = engine.layout;
    expect(m.baseY, greaterThan(800 * 0.85));
    expect(m.peakY, lessThan(800 * 0.1));
    expect(m.contains(const Offset(200, 400)), isTrue);
    expect(m.contains(const Offset(200, 790)), isFalse);
    expect(engine.ferretPos.dy, greaterThan(m.baseY));
  });

  test('dragging the ferret into the mountain carves a tunnel', () {
    final engine = _engine();
    engine.obstacles.clear();
    expect(engine.tunnels, isEmpty);
    engine.pointerDown(engine.ferretPos);
    engine.pointerMove(const Offset(200, 500));
    _Clock().advance(engine, 2500);
    expect(engine.tunnels, isNotEmpty);
    expect(engine.state, FerretState.digging);
    expect(engine.layout.contains(engine.ferretPos), isTrue);
  });

  test('eating a fruit grows the ferret by 10 percent', () {
    final engine = _engine();
    expect(engine.fruits, isNotEmpty);
    final fruit = engine.fruits.first;
    engine.debugTeleport(fruit.position);
    expect(engine.state, FerretState.eating);
    final before = engine.ferretScale;
    _Clock().advance(engine, 900);
    expect(engine.ferretScale, closeTo(before * GameEngine.growFactor, 0.0001));
    expect(engine.fruitsEaten, 1);
  });

  test('restart clears tunnels, size and puts the ferret back at the base', () {
    final engine = _engine();
    engine.obstacles.clear();
    final clock = _Clock();
    engine.pointerDown(engine.ferretPos);
    engine.pointerMove(const Offset(200, 500));
    clock.advance(engine, 2500);
    engine.debugTeleport(engine.fruits.first.position);
    clock.advance(engine, 900);
    expect(engine.tunnels, isNotEmpty);
    expect(engine.ferretScale, greaterThan(1));

    engine.restart();
    expect(engine.tunnels, isEmpty);
    expect(engine.ferretScale, 1);
    expect(engine.state, FerretState.idle);
    expect(engine.ferretPos.dx, closeTo(200, 1));
    expect(engine.ferretPos.dy, closeTo(engine.standY, 1));
    expect(engine.fruitsEaten, 0);
    expect(engine.liveFruitCount, GameEngine.maxLiveFruits);
    expect(engine.diamondCollected, isFalse);
  });

  test('a new fruit appears after the respawn delay', () {
    final engine = _engine();
    final clock = _Clock();
    final before = engine.liveFruitCount;
    engine.debugTeleport(engine.fruits.first.position);
    clock.advance(engine, 900);
    expect(engine.liveFruitCount, before - 1);

    clock.advance(engine, (GameEngine.fruitRespawnDelay * 1000).round() + 200);
    expect(engine.liveFruitCount, before);
  });

  test('obstacles block the ferret and spawn bump stars', () {
    final engine = _engine();
    final rock = engine.obstacles.first;
    final start = rock.position.translate(-rock.radius - engine.ferretRadius * 1.1, 0);
    engine.debugTeleport(start);
    engine.pointerDown(engine.ferretPos);
    engine.pointerMove(rock.position);
    _Clock().advance(engine, 400);
    expect(engine.state, FerretState.bumping);
    expect(engine.stars, isNotEmpty);
    expect((engine.ferretPos - rock.position).distance, greaterThan(rock.radius * 0.5));
  });

  test('leaving the mountain on a side rolls down to the base', () {
    final engine = _engine();
    engine.obstacles.clear();
    final m = engine.layout;
    final inside = m.leftOutline[3] + const Offset(18, 0);
    expect(m.contains(inside), isTrue);
    engine.debugTeleport(inside);
    engine.pointerDown(engine.ferretPos);
    engine.pointerMove(inside + const Offset(-90, 0));
    final clock = _Clock();
    var sawRolling = false;
    clock.advance(engine, 2500, onTick: () {
      if (engine.state == FerretState.rolling) sawRolling = true;
    });
    expect(sawRolling, isTrue);
    clock.advance(engine, 4000);
    expect(engine.state, FerretState.idle);
    expect(engine.ferretPos.dy, closeTo(engine.standY, 1));
    expect(engine.ferretPos.dx, lessThan(m.peakX));
  });

  test('walking to the peak edge rolls down to the base', () {
    final engine = _engine();
    engine.obstacles.clear();
    final m = engine.layout;
    final x = m.ridgeLeft + 18;
    engine.ferretPos = Offset(x, m.ridgeYAt(x) - engine.ferretRadius * 0.55);
    engine.state = FerretState.onPeak;
    engine.pointerDown(engine.ferretPos);
    engine.pointerMove(Offset(m.ridgeLeft - 80, engine.ferretPos.dy));
    final clock = _Clock();
    var sawRolling = false;
    clock.advance(engine, 2500, onTick: () {
      if (engine.state == FerretState.rolling) sawRolling = true;
    });
    expect(sawRolling, isTrue);
    clock.advance(engine, 4000);
    expect(engine.state, FerretState.idle);
    expect(engine.ferretPos.dy, closeTo(engine.standY, 1));
  });

  test('diamond sits on the peak', () {
    final engine = _engine();
    expect(engine.diamondPos.dx, closeTo(engine.layout.peakX, 1));
    expect(engine.diamondPos.dy, lessThan(engine.size.height * 0.2));
    expect(engine.diamondCollected, isFalse);
  });

  test('collecting the diamond wins the game', () {
    var won = false;
    final engine = GameEngine(
      seed: 11,
      onSound: (cue) {
        if (cue == GameSoundCue.success) won = true;
      },
    )..setSize(const Size(400, 800));
    engine.debugTeleport(engine.diamondPos);
    expect(engine.state, FerretState.won);
    expect(engine.diamondCollected, isTrue);
    expect(won, isTrue);

    engine.restart();
    expect(engine.state, FerretState.idle);
    expect(engine.diamondCollected, isFalse);
  });

  test('a single tap on the ferret does not explode', () {
    final engine = _engine();
    engine.pointerDown(engine.ferretPos);
    engine.pointerUp();
    expect(engine.state, isNot(FerretState.exploding));
  });

  test('double tap explodes nearby obstacles and respawns at the base', () {
    final engine = _engine();
    engine.obstacles.clear();
    engine.fruits.clear();
    final clock = _Clock();
    engine.pointerDown(engine.ferretPos);
    engine.pointerMove(const Offset(200, 500));
    clock.advance(engine, 1200);
    expect(engine.tunnels, isNotEmpty);
    final tunnelsBefore = engine.tunnels.length;
    engine.pointerUp();

    final near = Obstacle(
      position: engine.ferretPos,
      kind: ObstacleKind.rock,
      radius: 12,
    );
    final far = Obstacle(
      position: Offset(engine.layout.peakX, engine.layout.baseY - 40),
      kind: ObstacleKind.bone,
      radius: 12,
    );
    engine.obstacles.addAll([near, far]);
    engine.ferretScale = 1.21;

    engine.pointerDown(engine.ferretPos);
    engine.pointerUp();
    engine.pointerDown(engine.ferretPos);
    expect(engine.state, FerretState.exploding);
    expect(engine.obstacles, isNot(contains(near)));
    expect(engine.obstacles, contains(far));

    clock.advance(engine, 800);
    expect(engine.state, FerretState.idle);
    expect(engine.ferretScale, 1);
    expect(engine.ferretPos.dx, closeTo(200, 1));
    expect(engine.ferretPos.dy, closeTo(engine.standY, 1));
    expect(engine.tunnels, hasLength(tunnelsBefore));
  });

  test('dig, eat and bump fire sound cues', () {
    final cues = <GameSoundCue>[];
    final engine = GameEngine(seed: 11, onSound: cues.add)
      ..setSize(const Size(400, 800));
    final clock = _Clock();
    engine.obstacles.clear();
    engine.fruits.clear();
    engine.pointerDown(engine.ferretPos);
    engine.pointerMove(const Offset(200, 500));
    clock.advance(engine, 2500);
    expect(cues, contains(GameSoundCue.dig));

    cues.clear();
    engine.fruits.add(
      Fruit(
        position: engine.ferretPos,
        kind: FruitKind.apple,
        radius: 12,
      ),
    );
    engine.debugTeleport(engine.ferretPos);
    expect(cues, contains(GameSoundCue.eat));

    cues.clear();
    clock.advance(engine, 900);
    final rock = Obstacle(
      position: engine.ferretPos.translate(engine.ferretRadius * 1.5, 0),
      kind: ObstacleKind.rock,
      radius: 14,
    );
    engine.obstacles.add(rock);
    engine.pointerDown(engine.ferretPos);
    engine.pointerMove(rock.position);
    clock.advance(engine, 400);
    expect(cues, contains(GameSoundCue.bump));
  });
}
