import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapos/game/game_engine.dart';
import 'package:sapos/models/game_models.dart';

void main() {
  test('builds soup, player frog and initial flies', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    expect(engine.soupBowl.width, greaterThan(100));
    expect(engine.player.position.dy, greaterThan(engine.soupBowl.center.dy));
    expect(engine.flies, isNotEmpty);
    engine.dispose();
  });

  test('tapping a fly launches the tongue and can eat it', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    engine.flies
      ..clear()
      ..add(
        FlyModel(
          id: 7,
          position: engine.player.position + const Offset(0, -80),
          velocity: Offset.zero,
        ),
      );
    engine.pointerDown(1, engine.flies.first.position);
    engine.pointerUp(1, engine.flies.first.position);
    expect(engine.player.tonguePhase, TonguePhase.extending);

    for (var i = 0; i < 40; i++) {
      engine.tick(Duration(milliseconds: 20 + i * 16));
    }
    expect(engine.fliesEaten, 1);
    expect(engine.score, greaterThan(0));
    expect(engine.player.sizeScale, closeTo(playerGrowFactor, 0.0001));
    engine.dispose();
  });

  test('tapping a bad frog throws a bomb that blasts it', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    engine.badFrogs
      ..clear()
      ..add(
        BadFrogModel(
          id: 11,
          position: engine.player.position + const Offset(40, -90),
        ),
      );
    engine.pointerDown(1, engine.badFrogs.first.position);
    engine.pointerUp(1, engine.badFrogs.first.position);
    expect(engine.bombs, isNotEmpty);

    for (var i = 0; i < 50; i++) {
      engine.tick(Duration(milliseconds: 20 + i * 16));
    }
    expect(engine.badFrogsBlasted, 1);
    expect(engine.score, greaterThanOrEqualTo(5));
    engine.dispose();
  });

  test('good frog expels a hunting bad frog', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    engine.badFrogs
      ..clear()
      ..add(BadFrogModel(id: 21, position: const Offset(400, 200)));
    engine.goodFrogs
      ..clear()
      ..add(GoodFrogModel(id: 22, position: const Offset(400, 200)));

    engine.tick(const Duration(milliseconds: 32));
    engine.tick(const Duration(milliseconds: 48));
    expect(engine.badFrogs.first.phase, BadFrogPhase.fleeing);
    engine.dispose();
  });

  test('restart clears score', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.score = 12;
    engine.reset();
    expect(engine.score, 0);
    expect(engine.flies, isNotEmpty);
    engine.dispose();
  });

  test('player keeps growing after 10 flies without auto explode', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    var tickMs = 32;
    for (var eat = 0; eat < fliesToSurprise + 2; eat++) {
      engine.flies
        ..clear()
        ..add(
          FlyModel(
            id: 100 + eat,
            position: engine.player.position + const Offset(0, -80),
            velocity: Offset.zero,
          ),
        );
      engine.player.tonguePhase = TonguePhase.idle;
      engine.pointerDown(1, engine.flies.first.position);
      engine.pointerUp(1, engine.flies.first.position);
      for (var i = 0; i < 40; i++) {
        engine.tick(Duration(milliseconds: tickMs));
        tickMs += 16;
      }
      expect(engine.player.phase, PlayerPhase.idle);
    }
    expect(engine.fliesEaten, fliesToSurprise + 2);
    expect(engine.playerSurprised, isTrue);
    expect(engine.player.sizeScale, greaterThan(1));
    engine.dispose();
  });

  test('slashing player frog explodes and restarts', () {
    final engine = GameEngine()..setBounds(const Size(800, 480));
    engine.tick(const Duration(milliseconds: 16));
    final center = engine.player.position;
    engine.pointerDown(1, center + const Offset(-30, 0));
    engine.pointerMove(1, center + const Offset(30, 0));
    engine.pointerUp(1, center + const Offset(30, 0));
    expect(engine.player.phase, PlayerPhase.exploding);

    var tickMs = 32;
    for (var i = 0; i < 50; i++) {
      engine.tick(Duration(milliseconds: tickMs));
      tickMs += 16;
      if (engine.player.phase == PlayerPhase.idle && engine.fliesEaten == 0) {
        break;
      }
    }
    expect(engine.player.phase, PlayerPhase.idle);
    expect(engine.fliesEaten, 0);
    expect(engine.player.sizeScale, 1);
    expect(engine.score, 0);
    engine.dispose();
  });
}
