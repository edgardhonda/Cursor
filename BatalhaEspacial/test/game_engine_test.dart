import 'package:batalha_espacial/audio/game_audio_controller.dart';
import 'package:batalha_espacial/game/game_engine.dart';
import 'package:batalha_espacial/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void _advanceToCombat(GameEngine engine) {
  for (var ms = 0; ms <= 4000; ms += 50) {
    engine.tick(Duration(milliseconds: ms));
  }
}

void _completeLaser(GameEngine engine) {
  final base = (engine.now * 1000).round();
  for (var ms = base + 50; ms <= base + 500; ms += 50) {
    engine.tick(Duration(milliseconds: ms));
  }
}

void _completeFailureSequence(GameEngine engine) {
  var ms = (engine.now * 1000).round();
  while (engine.phase != GamePhase.playerDestroyed && ms < 25000) {
    ms += 50;
    engine.tick(Duration(milliseconds: ms));
  }
}

void main() {
  test('correct choice destroys enemy and adds score', () {
    final engine = GameEngine()..start();
    _advanceToCombat(engine);
    expect(engine.phase, GamePhase.combat);
    final strength = engine.enemy!.strength;
    engine.pickChoice(strength);
    expect(engine.phase, GamePhase.firingLaser);
    _completeLaser(engine);
    expect(engine.phase, GamePhase.enemyDestroyed);
    expect(engine.score, strength);
    engine.dispose();
  });

  test('wrong choice shows scared face then destroys player on contact', () {
    final engine = GameEngine()..start();
    _advanceToCombat(engine);
    final strength = engine.enemy!.strength;
    final wrong = engine.choices.firstWhere((n) => n != strength);
    engine.pickChoice(wrong);
    expect(engine.phase, GamePhase.playerScared);
    _completeFailureSequence(engine);
    expect(engine.phase, GamePhase.playerDestroyed);
    engine.dispose();
  });

  test('timeout destroys player after enemy reaches ship', () {
    final engine = GameEngine()..start();
    var ms = 0;
    while (engine.phase != GamePhase.playerDestroyed && ms <= 20000) {
      ms += 50;
      engine.tick(Duration(milliseconds: ms));
    }
    expect(engine.phase, GamePhase.playerDestroyed);
    engine.dispose();
  });

  test('choices always include the enemy strength', () {
    final engine = GameEngine()..start();
    _advanceToCombat(engine);
    expect(engine.choices, contains(engine.enemy!.strength));
    expect(engine.choices, hasLength(3));
    engine.dispose();
  });

  test('enemy spawns with a visual kind', () {
    final engine = GameEngine()..start();
    _advanceToCombat(engine);
    expect(EnemyKind.values, contains(engine.enemy!.kind));
    engine.dispose();
  });

  test('strength uses fixed range on spawn', () {
    final engine = GameEngine()..start();
    _advanceToCombat(engine);
    expect(engine.enemy!.strength, inInclusiveRange(minEnemyStrength, maxEnemyStrength));
    engine.dispose();
  });

  test('emits combat and outcome sounds', () {
    final cues = <GameSoundCue>[];
    final engine = GameEngine(onSound: cues.add)..start();
    _advanceToCombat(engine);
    expect(cues, contains(GameSoundCue.alert));

    final strength = engine.enemy!.strength;
    engine.pickChoice(strength);
    expect(cues, contains(GameSoundCue.laser));
    _completeLaser(engine);
    expect(cues, contains(GameSoundCue.destroy));
    engine.dispose();
  });

  test('wrong answer plays scared and blast sounds in sequence', () {
    final cues = <GameSoundCue>[];
    final engine = GameEngine(onSound: cues.add)..start();
    _advanceToCombat(engine);
    final wrong = engine.choices.firstWhere((n) => n != engine.enemy!.strength);
    engine.pickChoice(wrong);
    expect(cues, contains(GameSoundCue.wrong));
    _completeFailureSequence(engine);
    expect(cues, contains(GameSoundCue.blast));
    engine.dispose();
  });

  test('restart after defeat begins cruising immediately', () {
    final engine = GameEngine()..start();
    _advanceToCombat(engine);
    final wrong = engine.choices.firstWhere((n) => n != engine.enemy!.strength);
    engine.pickChoice(wrong);
    _completeFailureSequence(engine);
    expect(engine.phase, GamePhase.playerDestroyed);

    engine.start();
    expect(engine.phase, GamePhase.cruising);
    expect(engine.score, 0);
    engine.dispose();
  });
}