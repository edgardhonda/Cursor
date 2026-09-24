import 'package:flutter_test/flutter_test.dart';
import 'package:obstaculos/game/game_engine.dart';
import 'package:obstaculos/models/game_models.dart';

void main() {
  test('reset builds a segment with 2 to 4 obstacles', () {
    final engine = GameEngine(random: null)..reset();
    expect(engine.obstacles.length, inInclusiveRange(2, 4));
    expect(engine.phase, ExplorerPhase.walking);
    expect(engine.explorerX, lessThan(0.2));
  });

  test('catalog covers every obstacle kind', () {
    expect(obstacleCatalog.length, ObstacleKind.values.length);
    for (final kind in ObstacleKind.values) {
      final spec = obstacleCatalog[kind]!;
      expect(spec.validResources, isNotEmpty);
      expect(spec.label, isNotEmpty);
    }
  });

  test('reaching an obstacle opens choices with one correct option', () {
    final engine = GameEngine(random: null)..reset();
    engine.obstacles = [
      PlacedObstacle(kind: ObstacleKind.hole, x: 0.3),
    ];
    engine.explorerX = 0.2;
    _pump(engine, 1.0);
    expect(engine.phase, ExplorerPhase.choosing);
    expect(engine.choices.length, 3);
    expect(engine.choices.where((c) => c.correct).length, 1);
    final correct = engine.choices.indexWhere((c) => c.correct);
    final valid = obstacleCatalog[ObstacleKind.hole]!.validResources;
    expect(valid.contains(engine.choices[correct].resource), isTrue);
  });

  test('wrong choice goes sad then returns to choosing', () {
    final engine = GameEngine(random: null)..reset();
    engine.obstacles = [
      PlacedObstacle(kind: ObstacleKind.campfire, x: 0.25),
    ];
    engine.explorerX = 0.2;
    _pump(engine, 0.8);
    expect(engine.phase, ExplorerPhase.choosing);
    final wrong = engine.choices.indexWhere((c) => !c.correct);
    engine.selectChoice(wrong);
    expect(engine.phase, ExplorerPhase.sad);
    _pump(engine, sadSeconds + 0.1);
    expect(engine.phase, ExplorerPhase.choosing);
  });

  test('correct choice clears obstacle and resumes walking', () {
    final engine = GameEngine(random: null)..reset();
    engine.obstacles = [
      PlacedObstacle(kind: ObstacleKind.rock, x: 0.25),
    ];
    engine.explorerX = 0.2;
    _pump(engine, 0.8);
    final correct = engine.choices.indexWhere((c) => c.correct);
    engine.selectChoice(correct);
    expect(engine.phase, ExplorerPhase.showcasing);
    _pump(engine, showcaseSeconds + 0.05);
    expect(engine.phase, ExplorerPhase.resolving);
    _pump(engine, resolveSeconds + 0.1);
    expect(engine.obstacles.first.cleared, isTrue);
    expect(engine.phase, ExplorerPhase.walking);
  });

  test('board crossOver leaves plank resource on obstacle', () {
    final engine = GameEngine(random: null)..reset();
    engine.obstacles = [
      PlacedObstacle(kind: ObstacleKind.hole, x: 0.25),
    ];
    engine.explorerX = 0.2;
    _pump(engine, 0.8);
    var boardChoice = engine.choices.indexWhere(
      (c) => c.correct && c.resource == ResourceKind.board,
    );
    if (boardChoice < 0) {
      engine.choices = [
        const ChoiceOption(resource: ResourceKind.board, correct: true),
        const ChoiceOption(resource: ResourceKind.fire, correct: false),
        const ChoiceOption(resource: ResourceKind.axe, correct: false),
      ];
      boardChoice = 0;
    }
    engine.selectChoice(boardChoice);
    _pump(engine, showcaseSeconds + resolveSeconds + 0.15);
    final o = engine.obstacles.first;
    expect(o.cleared, isTrue);
    expect(o.resolveResource, ResourceKind.board);
    expect(engine.phase, ExplorerPhase.walking);
  });

  test('crossOver obstacles stay cleared but not fleeing', () {
    final engine = GameEngine(random: null)..reset();
    engine.obstacles = [
      PlacedObstacle(kind: ObstacleKind.hole, x: 0.25),
    ];
    engine.explorerX = 0.2;
    _pump(engine, 0.8);
    engine.selectChoice(engine.choices.indexWhere((c) => c.correct));
    _pump(engine, showcaseSeconds + resolveSeconds + 0.15);
    final o = engine.obstacles.first;
    expect(o.cleared, isTrue);
    expect(o.fleeing, isFalse);
    expect(o.fleeT, 0);
  });

  test('scare obstacles flee toward the end of the screen', () {
    final engine = GameEngine(random: null)..reset();
    engine.obstacles = [
      PlacedObstacle(kind: ObstacleKind.monster, x: 0.25),
    ];
    engine.explorerX = 0.2;
    _pump(engine, 0.8);
    engine.selectChoice(engine.choices.indexWhere((c) => c.correct));
    _pump(engine, showcaseSeconds + resolveSeconds + 0.05);
    final o = engine.obstacles.first;
    expect(o.cleared, isTrue);
    expect(o.fleeing || o.fleeT > 0, isTrue);
    _pump(engine, fleeSeconds + 0.2);
    expect(o.fleeT, 1);
    expect(o.fleeing, isFalse);
  });

  test('climb obstacles stay cleared but visible (not fleeing)', () {
    final engine = GameEngine(random: null)..reset();
    engine.obstacles = [
      PlacedObstacle(kind: ObstacleKind.wall, x: 0.25),
    ];
    engine.explorerX = 0.2;
    _pump(engine, 0.8);
    engine.selectChoice(engine.choices.indexWhere((c) => c.correct));
    _pump(engine, showcaseSeconds + resolveSeconds + 0.15);
    final o = engine.obstacles.first;
    expect(o.cleared, isTrue);
    expect(o.fleeing, isFalse);
    expect(obstacleCatalog[o.kind]!.action, ResolveAction.climb);
  });
}

void _pump(GameEngine engine, double seconds) {
  var elapsedMs = 0;
  engine.tick(Duration(milliseconds: elapsedMs += 16));
  final frames = (seconds / 0.016).ceil().clamp(1, 20000);
  for (var i = 0; i < frames; i++) {
    engine.tick(Duration(milliseconds: elapsedMs += 16));
  }
}
