import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_audio.dart';

class GameEngine {
  GameEngine({this.audio});

  final GameAudio? audio;
  final Random _random = Random();

  final List<List<CellKind>> cells = List.generate(
    gridSize,
    (_) => List.filled(gridSize, CellKind.empty),
  );

  GridPos pirate = const GridPos(pirateStartRow, pirateStartCol);
  GridPos treasure = const GridPos(0, 2);
  final List<MoveCommand> program = [];
  final List<PathMark> pathMarks = [];

  GamePhase phase = GamePhase.programming;
  PiratePhase piratePhase = PiratePhase.ready;
  CrashKind crashKind = CrashKind.none;
  MoveCommand? crashDirection;
  RunStepPhase runStepPhase = RunStepPhase.waiting;
  MoveCommand? previewCommand;
  int runIndex = 0;
  double nextStepAt = 0;
  double now = 0;
  double _lastTickSeconds = 0;
  double bumpFlashUntil = 0;
  bool paused = false;

  /// Cores do pirata (sorteadas a cada novo mapa).
  Color pirateFaceColor = const Color(0xFFFFCC80);
  Color pirateBandanaColor = const Color(0xFF42A5F5);

  void setPaused(bool value) => paused = value;

  void reset() {
    now = 0;
    _lastTickSeconds = 0;
    program.clear();
    pathMarks.clear();
    phase = GamePhase.programming;
    piratePhase = PiratePhase.ready;
    crashKind = CrashKind.none;
    crashDirection = null;
    runStepPhase = RunStepPhase.waiting;
    previewCommand = null;
    runIndex = 0;
    nextStepAt = 0;
    bumpFlashUntil = 0;
    pirate = const GridPos(pirateStartRow, pirateStartCol);
    _rollPirateColors();
    _generateMap();
  }

  void _rollPirateColors() {
    const faces = [
      Color(0xFFFFCC80), // pele clara
      Color(0xFFFFAB91),
      Color(0xFFD7CCC8),
      Color(0xFFFFE082),
      Color(0xFFBCAAA4),
      Color(0xFFFFCCBC),
      Color(0xFFE0B090),
      Color(0xFFCFA07A),
    ];
    const bandanas = [
      Color(0xFFEF5350),
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFFFCA28),
      Color(0xFFAB47BC),
      Color(0xFF26C6DA),
      Color(0xFFFF7043),
      Color(0xFF5C6BC0),
      Color(0xFFEC407A),
      Color(0xFF26A69A),
    ];
    pirateFaceColor = faces[_random.nextInt(faces.length)];
    pirateBandanaColor = bandanas[_random.nextInt(bandanas.length)];
  }

  void addCommand(MoveCommand cmd) {
    if (phase != GamePhase.programming) return;
    if (program.length >= 24) return;
    program.add(cmd);
    audio?.playTick();
  }

  void removeLastCommand() {
    if (phase != GamePhase.programming) return;
    if (program.isEmpty) return;
    program.removeLast();
  }

  void start() {
    if (phase != GamePhase.programming) return;
    if (program.isEmpty) return;
    // Continua da posição atual (não volta ao início).
    piratePhase = PiratePhase.walking;
    phase = GamePhase.running;
    crashKind = CrashKind.none;
    crashDirection = null;
    runStepPhase = RunStepPhase.waiting;
    previewCommand = null;
    runIndex = 0;
    nextStepAt = now + 0.15;
    bumpFlashUntil = 0;
  }

  void tick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / 1e6;
    if (_lastTickSeconds == 0) {
      _lastTickSeconds = seconds;
      return;
    }
    var dt = seconds - _lastTickSeconds;
    _lastTickSeconds = seconds;
    if (paused) return;
    dt = dt.clamp(0.0, 0.05);
    now += dt;

    if (phase != GamePhase.running) return;
    if (now < nextStepAt) return;

    if (runStepPhase == RunStepPhase.waiting) {
      if (runIndex >= program.length) {
        // Sequência concluída sem batida: pode programar de novo daqui.
        phase = GamePhase.programming;
        piratePhase = PiratePhase.ready;
        previewCommand = null;
        program.clear();
        return;
      }
      // Destaca o comando sobre o pirata antes de andar.
      previewCommand = program[runIndex];
      runStepPhase = RunStepPhase.previewing;
      nextStepAt = now + commandPreviewSeconds;
      audio?.playTick();
      return;
    }

    // Fim da prévia: marca a célula e executa o movimento.
    final cmd = program[runIndex];
    final origin = pirate;
    pathMarks.add(PathMark(cell: origin, command: cmd));
    runIndex++;
    previewCommand = null;
    runStepPhase = RunStepPhase.waiting;

    final next = pirate.moved(cmd);

    if (!next.inBounds) {
      phase = GamePhase.lost;
      piratePhase = PiratePhase.smashed;
      crashKind = CrashKind.wall;
      crashDirection = cmd;
      bumpFlashUntil = now + 0.7;
      audio?.playBump();
      return;
    }

    if (cells[next.row][next.col].isObstacle) {
      pirate = next;
      phase = GamePhase.lost;
      piratePhase = PiratePhase.fainted;
      crashKind = CrashKind.obstacle;
      crashDirection = cmd;
      bumpFlashUntil = now + 0.7;
      audio?.playBump();
      return;
    }

    pirate = next;
    audio?.playStep();
    nextStepAt = now + stepSeconds;

    if (pirate == treasure) {
      phase = GamePhase.won;
      piratePhase = PiratePhase.celebrating;
      audio?.playVictory();
    }
  }

  CellKind cellAt(GridPos p) => cells[p.row][p.col];

  void dispose() {}

  void _generateMap() {
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        cells[r][c] = CellKind.empty;
      }
    }

    final start = const GridPos(pirateStartRow, pirateStartCol);
    pirate = start;

    // Tesouro em uma célula da linha superior (exceto colisão com caminho mínimo óbvio).
    final treasureCols = List<int>.generate(gridSize, (i) => i)..shuffle(_random);
    treasure = GridPos(0, treasureCols.first);

    final obstacleKinds = [
      CellKind.obstacleBarrel,
      CellKind.obstacleSword,
      CellKind.obstacleOctopus,
      CellKind.obstacleSkull,
      CellKind.obstaclePalm,
    ];

    final candidates = <GridPos>[];
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final p = GridPos(r, c);
        if (p == start || p == treasure) continue;
        candidates.add(p);
      }
    }
    candidates.shuffle(_random);

    final count =
        minObstacles + _random.nextInt(maxObstacles - minObstacles + 1);

    for (var attempt = 0; attempt < 40; attempt++) {
      for (var r = 0; r < gridSize; r++) {
        for (var c = 0; c < gridSize; c++) {
          cells[r][c] = CellKind.empty;
        }
      }
      candidates.shuffle(_random);
      for (var i = 0; i < count && i < candidates.length; i++) {
        final p = candidates[i];
        cells[p.row][p.col] =
            obstacleKinds[_random.nextInt(obstacleKinds.length)];
      }
      if (_hasPath(start, treasure)) return;
    }

    // Fallback: mapa limpo se não achar layout válido.
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        cells[r][c] = CellKind.empty;
      }
    }
  }

  bool _hasPath(GridPos start, GridPos goal) {
    final seen = <GridPos>{};
    final queue = Queue<GridPos>()..add(start);
    seen.add(start);
    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      if (cur == goal) return true;
      for (final cmd in MoveCommand.values) {
        final n = cur.moved(cmd);
        if (!n.inBounds || seen.contains(n)) continue;
        if (cells[n.row][n.col].isObstacle) continue;
        seen.add(n);
        queue.add(n);
      }
    }
    return false;
  }
}
