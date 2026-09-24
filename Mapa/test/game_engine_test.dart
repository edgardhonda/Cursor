import 'package:flutter_test/flutter_test.dart';
import 'package:mapa/game/game_engine.dart';
import 'package:mapa/models/game_models.dart';

void main() {
  test('reset builds a 5x5 map with pirate, treasure and a clear path', () {
    final engine = GameEngine()..reset();
    expect(engine.pirate, const GridPos(pirateStartRow, pirateStartCol));
    expect(engine.treasure.row, 0);
    expect(engine.treasure.inBounds, isTrue);
    expect(engine.cells.length, gridSize);
    expect(engine.cells.first.length, gridSize);
    expect(engine.cellAt(engine.pirate), CellKind.empty);
    expect(engine.cellAt(engine.treasure), CellKind.empty);

    final empty = engine.cells.expand((r) => r).where((c) => !c.isObstacle);
    expect(empty.length, greaterThan(5));
    engine.dispose();
  });

  test('commands are stored and start walks with one-second steps', () {
    final engine = GameEngine()..reset();
    _clearMap(engine);
    engine.treasure = const GridPos(0, 2);
    engine.pirate = const GridPos(4, 2);

    engine.addCommand(MoveCommand.up);
    engine.addCommand(MoveCommand.up);
    expect(engine.program.length, 2);

    engine.start();
    expect(engine.phase, GamePhase.running);

    final clock = _TestClock();
    // Atraso inicial + prévia do comando, ainda sem andar.
    clock.pump(engine, 0.25);
    expect(engine.pirate.row, 4);
    expect(engine.previewCommand, MoveCommand.up);
    expect(engine.runStepPhase, RunStepPhase.previewing);

    // Termina a prévia e executa o primeiro passo.
    clock.pump(engine, commandPreviewSeconds + 0.05);
    expect(engine.pirate.row, 3);
    expect(engine.pirate.col, 2);
    expect(engine.pathMarks, isNotEmpty);
    expect(engine.pathMarks.first.cell, const GridPos(4, 2));
    expect(engine.pathMarks.first.command, MoveCommand.up);

    // Prévia + segundo passo.
    clock.pump(engine, stepSeconds + commandPreviewSeconds + 0.1);
    expect(engine.pirate.row, 2);
    expect(engine.pirate.col, 2);
    engine.dispose();
  });

  test('hitting an obstacle moves onto it then faints', () {
    final engine = GameEngine()..reset();
    _clearMap(engine);
    engine.pirate = const GridPos(4, 2);
    engine.cells[3][2] = CellKind.obstacleBarrel;
    engine.addCommand(MoveCommand.up);
    engine.start();
    _TestClock().pump(engine, 0.2 + commandPreviewSeconds + 0.1);
    expect(engine.phase, GamePhase.lost);
    expect(engine.piratePhase, PiratePhase.fainted);
    expect(engine.crashKind, CrashKind.obstacle);
    expect(engine.pirate, const GridPos(3, 2));
    engine.dispose();
  });

  test('reaching treasure wins and celebrates', () {
    final engine = GameEngine()..reset();
    _clearMap(engine);
    engine.treasure = const GridPos(3, 2);
    engine.pirate = const GridPos(4, 2);
    engine.addCommand(MoveCommand.up);
    engine.start();
    _TestClock().pump(engine, 0.2 + commandPreviewSeconds + 0.1);
    expect(engine.phase, GamePhase.won);
    expect(engine.piratePhase, PiratePhase.celebrating);
    expect(engine.pirate, engine.treasure);
    engine.dispose();
  });

  test('hitting map edge smashes face toward the wall', () {
    final engine = GameEngine()..reset();
    _clearMap(engine);
    engine.pirate = const GridPos(4, 2);
    engine.addCommand(MoveCommand.down);
    engine.start();
    _TestClock().pump(engine, 0.2 + commandPreviewSeconds + 0.1);
    expect(engine.phase, GamePhase.lost);
    expect(engine.piratePhase, PiratePhase.smashed);
    expect(engine.crashKind, CrashKind.wall);
    expect(engine.crashDirection, MoveCommand.down);
    expect(engine.pirate, const GridPos(4, 2));
    engine.dispose();
  });

  test('restart clears program and restores pirate', () {
    final engine = GameEngine()..reset();
    engine.addCommand(MoveCommand.left);
    engine.pirate = const GridPos(2, 2);
    engine.reset();
    expect(engine.program, isEmpty);
    expect(engine.pirate, const GridPos(pirateStartRow, pirateStartCol));
    expect(engine.phase, GamePhase.programming);
    engine.dispose();
  });

  test('Ir! continues from current position after a safe run', () {
    final engine = GameEngine()..reset();
    _clearMap(engine);
    engine.treasure = const GridPos(0, 0);
    engine.pirate = const GridPos(4, 2);
    engine.addCommand(MoveCommand.up);
    engine.start();
    final clock = _TestClock();
    clock.pump(engine, 0.2 + commandPreviewSeconds + 0.1);
    expect(engine.pirate, const GridPos(3, 2));
    // Após o passo, espera o intervalo e o fim da sequência.
    clock.pump(engine, stepSeconds + 0.1);
    expect(engine.phase, GamePhase.programming);
    expect(engine.program, isEmpty);

    engine.addCommand(MoveCommand.left);
    engine.start();
    expect(engine.pirate, const GridPos(3, 2)); // não volta ao início
    clock.pump(engine, 0.2 + commandPreviewSeconds + 0.1);
    expect(engine.pirate, const GridPos(3, 1));
    expect(engine.pathMarks.length, greaterThanOrEqualTo(2));
    engine.dispose();
  });
}

void _clearMap(GameEngine engine) {
  for (var r = 0; r < gridSize; r++) {
    for (var c = 0; c < gridSize; c++) {
      engine.cells[r][c] = CellKind.empty;
    }
  }
}

/// Avança o motor em passos de 16ms (respeita o clamp de dt do tick).
class _TestClock {
  int elapsedMs = 0;

  void pump(GameEngine engine, double seconds) {
    if (elapsedMs == 0) {
      engine.tick(Duration(milliseconds: elapsedMs += 16));
    }
    final frames = (seconds / 0.016).ceil().clamp(1, 10000);
    for (var i = 0; i < frames; i++) {
      engine.tick(Duration(milliseconds: elapsedMs += 16));
    }
  }
}
