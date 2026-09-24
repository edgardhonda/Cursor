import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/game_audio_controller.dart';
import '../models/game_models.dart';

class GameEngine extends ChangeNotifier {
  GameEngine({this.onSound});

  final void Function(GameSoundCue cue)? onSound;
  final Random _random = Random();

  final List<TreeModel> trees = [];
  final List<HouseModel> houses = [];
  final List<AshPileModel> ashes = [];
  final List<WorkerGroupModel> workers = [];
  final List<BombModel> bombs = [];
  final Map<int, ActiveStroke> activeStrokes = {};
  final List<StrokePoint> finishedStrokes = [];

  Size _bounds = Size.zero;
  double now = 0;
  double _lastTick = 0;
  int _nextId = 1;
  bool _initialized = false;
  bool _paused = false;

  Size get bounds => _bounds;

  void setBounds(Size size) {
    if (size.width <= 0 || size.height <= 0 || size == _bounds) return;
    if (!_initialized) {
      _bounds = size;
      reset();
      return;
    }
    final sx = size.width / _bounds.width;
    final sy = size.height / _bounds.height;
    Offset scale(Offset p) => Offset(p.dx * sx, p.dy * sy);
    for (final tree in trees) {
      tree.position = scale(tree.position);
    }
    for (final house in houses) {
      house.position = scale(house.position);
    }
    for (final worker in workers) {
      worker.position = scale(worker.position);
      if (worker.enteringFrom case final from?) {
        worker.enteringFrom = scale(from);
      }
      if (worker.enteringTo case final to?) {
        worker.enteringTo = scale(to);
      }
    }
    _bounds = size;
    notifyListeners();
  }

  void reset() {
    if (_bounds.isEmpty) return;
    trees.clear();
    houses.clear();
    ashes.clear();
    workers.clear();
    bombs.clear();
    activeStrokes.clear();
    finishedStrokes.clear();
    now = 0;
    _lastTick = 0;
    _nextId = 1;
    _paused = false;

    for (var i = 0; i < 5; i++) {
      _spawnTree();
    }
    for (var i = 0; i < 3; i++) {
      final start = Offset(
        _bounds.width * (0.18 + i * 0.32),
        _bounds.height - 45 - (i.isOdd ? 16 : 0),
      );
      workers.add(
        WorkerGroupModel(
          id: _nextId++,
          position: start,
          targetTreeId: trees[i].id,
        ),
      );
    }
    _initialized = true;
    notifyListeners();
  }

  void tick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final dt = _lastTick == 0 ? 0.0 : min(seconds - _lastTick, 0.05);
    _lastTick = seconds;
    if (_paused || dt <= 0) {
      _pruneStrokes();
      notifyListeners();
      return;
    }
    now += dt;
    _updateWorkers(dt);
    _updateBombs();
    _updateWorldObjects();
    _pruneStrokes();
    notifyListeners();
  }

  void setPaused(bool value) {
    _paused = value;
    notifyListeners();
  }

  void pointerDown(int pointer, Offset position) {
    if (_paused) return;
    final p = _clamp(position);
    activeStrokes[pointer] = ActiveStroke(
      pointer: pointer,
      points: [
        StrokePoint(
          position: p,
          color: strokeColorForSpeed(0),
          width: strokeWidthForSpeed(0),
          createdAt: DateTime.now(),
        ),
      ],
    );
    notifyListeners();
  }

  void pointerMove(int pointer, Offset position) {
    if (_paused) return;
    final stroke = activeStrokes[pointer];
    if (stroke == null || stroke.points.isEmpty) return;

    final p = _clamp(position);
    final prev = stroke.points.last;
    final stamp = DateTime.now();
    final dtMs = max(1, stamp.difference(prev.createdAt).inMilliseconds);
    final distance = (p - prev.position).distance;
    if (distance < 0.8) return;

    final speed = distance / dtMs * 1000;
    stroke.points.add(
      StrokePoint(
        position: p,
        color: strokeColorForSpeed(speed),
        width: strokeWidthForSpeed(speed),
        createdAt: stamp,
      ),
    );
    notifyListeners();
  }

  void pointerUp(int pointer, Offset position) {
    final stroke = activeStrokes.remove(pointer);
    if (stroke == null || stroke.points.isEmpty) {
      notifyListeners();
      return;
    }

    final p = _clamp(position);
    final totalMove = (p - stroke.points.first.position).distance;
    final isTap = stroke.points.length <= 2 && totalMove < tapMoveThreshold;

    if (isTap) {
      _handleTap(p);
    } else {
      if ((p - stroke.points.last.position).distance > 1) {
        final prev = stroke.points.last;
        final stamp = DateTime.now();
        final dtMs = max(1, stamp.difference(prev.createdAt).inMilliseconds);
        final distance = (p - prev.position).distance;
        final speed = distance / dtMs * 1000;
        stroke.points.add(
          StrokePoint(
            position: p,
            color: strokeColorForSpeed(speed),
            width: strokeWidthForSpeed(speed),
            createdAt: stamp,
          ),
        );
      }
      finishedStrokes.addAll(stroke.points);
    }
    notifyListeners();
  }

  void _handleTap(Offset p) {
    BombModel? tapped;
    var bestDistance = double.infinity;
    for (final bomb in bombs) {
      if (bomb.phase != BombPhase.idle) continue;
      final distance = (bomb.position - p).distance;
      if (distance <= 34 && distance < bestDistance) {
        tapped = bomb;
        bestDistance = distance;
      }
    }
    if (tapped != null) {
      tapped.phase = BombPhase.fuse;
      tapped.phaseStartedAt = now;
    } else {
      bombs.add(BombModel(id: _nextId++, position: p));
    }
  }

  void _pruneStrokes() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 10));
    finishedStrokes.removeWhere((point) => point.createdAt.isBefore(cutoff));
  }

  void _updateWorkers(double dt) {
    for (final group in workers) {
      if (group.phase == WorkerPhase.done) continue;

      // Linha sobre o grupo: fica parado até o risco sumir.
      if (_pointNearAnyStroke(group.position, workerStrokeHitRadius)) {
        if (group.phase == WorkerPhase.working ||
            group.phase == WorkerPhase.entering) {
          group.phaseStartedAt += dt;
        }
        continue;
      }

      var target = _treeById(group.targetTreeId);
      if (target == null || target.phase != WorldObjectPhase.normal) {
        target = _pickAvailableTree();
        if (target == null) {
          group.phase = WorkerPhase.done;
          continue;
        }
        group.targetTreeId = target.id;
        group.phase = WorkerPhase.walking;
      }

      switch (group.phase) {
        case WorkerPhase.walking:
          final delta = target.position - group.position;
          if (delta.distance <= 48) {
            group.phase = WorkerPhase.working;
            group.phaseStartedAt = now;
            onSound?.call(GameSoundCue.construction);
          } else {
            _moveWorkerAvoidingStrokes(group, delta, dt);
          }
          break;
        case WorkerPhase.working:
          if (now - group.phaseStartedAt >= 5) {
            _buildHouse(target, group);
          }
          break;
        case WorkerPhase.entering:
          if (now - group.phaseStartedAt >= 1.2) {
            group.phase = WorkerPhase.done;
          }
          break;
        case WorkerPhase.done:
          break;
      }
    }
  }

  void _moveWorkerAvoidingStrokes(
    WorkerGroupModel group,
    Offset delta,
    double dt,
  ) {
    final step = min(delta.distance, 62 * dt);
    if (step <= 0.001) return;
    final dir = delta / delta.distance;

    Offset? bestDir;
    var bestScore = -2.0;
    const angles = <double>[
      0,
      0.45,
      -0.45,
      0.9,
      -0.9,
      1.35,
      -1.35,
      1.8,
      -1.8,
      pi,
    ];
    for (final angle in angles) {
      final cosA = cos(angle);
      final sinA = sin(angle);
      final candidate = Offset(
        dir.dx * cosA - dir.dy * sinA,
        dir.dx * sinA + dir.dy * cosA,
      );
      final next = group.position + candidate * step;
      if (_pointNearAnyStroke(next, workerStrokeAvoidRadius)) continue;
      final score = candidate.dx * dir.dx + candidate.dy * dir.dy;
      if (score > bestScore) {
        bestScore = score;
        bestDir = candidate;
      }
    }

    if (bestDir != null) {
      group.position += bestDir * step;
    }
    // Sem caminho livre: permanece parado até a linha sumir ou abrir espaço.
  }

  bool _pointNearAnyStroke(Offset point, double radius) {
    for (final stroke in activeStrokes.values) {
      if (_pointNearStrokePoints(point, radius, stroke.points)) return true;
    }
    return _pointNearStrokePoints(point, radius, finishedStrokes);
  }

  bool _pointNearStrokePoints(
    Offset point,
    double radius,
    List<StrokePoint> points,
  ) {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final hitRadius = radius + b.width * 0.5;
      if (_distanceToSegment(point, a.position, b.position) <= hitRadius) {
        return true;
      }
    }
    return false;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length2 < 0.0001) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length2).clamp(
      0.0,
      1.0,
    );
    final projection = a + ab * t;
    return (p - projection).distance;
  }

  void _buildHouse(TreeModel tree, WorkerGroupModel group) {
    if (!trees.remove(tree)) return;
    const colors = [Colors.blue, Colors.red, Colors.amber, Colors.green];
    houses.add(
      HouseModel(
        id: _nextId++,
        position: tree.position,
        color: colors[houses.length % colors.length],
      ),
    );
    _spawnTree();
    group.enteringFrom = group.position;
    group.enteringTo = tree.position;
    group.phase = WorkerPhase.entering;
    group.phaseStartedAt = now;
  }

  void _updateBombs() {
    for (final bomb in bombs) {
      switch (bomb.phase) {
        case BombPhase.idle:
          break;
        case BombPhase.fuse:
          if (now - bomb.phaseStartedAt >= 3) {
            bomb.phase = BombPhase.exploding;
            bomb.phaseStartedAt = now;
            bomb.hitWorldObject = _explodeAt(bomb.position);
            onSound?.call(GameSoundCue.explosion);
            if (bomb.hitWorldObject) {
              onSound?.call(GameSoundCue.fire);
            }
          }
          break;
        case BombPhase.exploding:
          _igniteBombsTouchedByExplosion(bomb);
          if (now - bomb.phaseStartedAt >= 0.75) {
            bomb.phase = bomb.hitWorldObject ? BombPhase.spent : BombPhase.hole;
            bomb.phaseStartedAt = now;
          }
          break;
        case BombPhase.hole:
        case BombPhase.spent:
          break;
      }
    }
  }

  void _igniteBombsTouchedByExplosion(BombModel exploding) {
    final radius = _explosionRadius(now - exploding.phaseStartedAt);
    const bombBodyRadius = 20.0;
    for (final other in bombs) {
      if (other.id == exploding.id || other.phase != BombPhase.idle) continue;
      if ((other.position - exploding.position).distance <= radius + bombBodyRadius) {
        other.phase = BombPhase.fuse;
        other.phaseStartedAt = now;
      }
    }
  }

  double _explosionRadius(double ageSeconds) {
    final t = (ageSeconds / 0.75).clamp(0.0, 1.0);
    return 18 + sin(t * pi) * 48;
  }

  bool _explodeAt(Offset point) {
    var hit = false;
    for (final tree in trees) {
      if (tree.phase == WorldObjectPhase.normal &&
          (tree.position - point).distance <= 58) {
        tree.phase = WorldObjectPhase.burning;
        tree.phaseStartedAt = now;
        hit = true;
      }
    }
    for (final house in houses) {
      if (house.phase == WorldObjectPhase.normal &&
          (house.position - point).distance <= 62) {
        house.phase = WorldObjectPhase.burning;
        house.phaseStartedAt = now;
        hit = true;
      }
    }
    return hit;
  }

  void _updateWorldObjects() {
    var collapsed = false;
    final treesToReplace = <TreeModel>[];
    for (final tree in trees) {
      if (_advanceObjectPhase(tree.phase, tree.phaseStartedAt)
          case final next?) {
        tree.phase = next;
        tree.phaseStartedAt = now;
        if (next == WorldObjectPhase.ashes) treesToReplace.add(tree);
      }
    }
    for (final tree in treesToReplace) {
      ashes.add(AshPileModel(position: tree.position, createdAt: now));
      trees.remove(tree);
      _spawnTree();
      collapsed = true;
    }

    final housesToRemove = <HouseModel>[];
    for (final house in houses) {
      if (_advanceObjectPhase(house.phase, house.phaseStartedAt)
          case final next?) {
        house.phase = next;
        house.phaseStartedAt = now;
        if (next == WorldObjectPhase.ashes) housesToRemove.add(house);
      }
    }
    for (final house in housesToRemove) {
      ashes.add(AshPileModel(position: house.position, createdAt: now));
      houses.remove(house);
      collapsed = true;
    }
    if (collapsed) {
      onSound?.call(GameSoundCue.collapse);
    }
  }

  WorldObjectPhase? _advanceObjectPhase(
    WorldObjectPhase phase,
    double started,
  ) {
    final age = now - started;
    return switch (phase) {
      WorldObjectPhase.burning when age >= 2.2 => WorldObjectPhase.charred,
      WorldObjectPhase.charred when age >= 2 => WorldObjectPhase.ashes,
      _ => null,
    };
  }

  TreeModel? _treeById(int id) {
    for (final tree in trees) {
      if (tree.id == id) return tree;
    }
    return null;
  }

  TreeModel? _pickAvailableTree() {
    final claimed = workers
        .where(
          (w) => w.phase != WorkerPhase.done && w.phase != WorkerPhase.entering,
        )
        .map((w) => w.targetTreeId)
        .toSet();
    for (final tree in trees) {
      if (tree.phase == WorldObjectPhase.normal && !claimed.contains(tree.id)) {
        return tree;
      }
    }
    for (final tree in trees) {
      if (tree.phase == WorldObjectPhase.normal) return tree;
    }
    return null;
  }

  void _spawnTree() {
    trees.add(TreeModel(id: _nextId++, position: _randomFreePoint()));
  }

  Offset _randomFreePoint() {
    final marginX = min(52.0, _bounds.width * 0.12);
    final top = min(58.0, _bounds.height * 0.14);
    final bottom = max(top + 1, _bounds.height - 105);
    for (var attempt = 0; attempt < 80; attempt++) {
      final point = Offset(
        marginX + _random.nextDouble() * max(1, _bounds.width - marginX * 2),
        top + _random.nextDouble() * max(1, bottom - top),
      );
      final occupied = [
        ...trees.map((e) => e.position),
        ...houses.map((e) => e.position),
        ...ashes.map((e) => e.position),
      ];
      if (occupied.every((other) => (other - point).distance > 88)) {
        return point;
      }
    }
    return Offset(
      marginX + _random.nextDouble() * max(1, _bounds.width - marginX * 2),
      top + _random.nextDouble() * max(1, bottom - top),
    );
  }

  Offset _clamp(Offset p) => Offset(
    p.dx.clamp(24, max(24, _bounds.width - 24)).toDouble(),
    p.dy.clamp(34, max(34, _bounds.height - 34)).toDouble(),
  );
}
