import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_models.dart';

class _PointerTrack {
  _PointerTrack(this.startPos, this.startTime, this.stroke)
      : lastPos = startPos,
        lastTime = startTime;

  final Offset startPos;
  final DateTime startTime;
  Offset lastPos;
  DateTime lastTime;
  final Stroke stroke;
}

class GameEngine {
  static const _soundChannel = MethodChannel('com.dirigindo.dirigindo/sound');

  Size _bounds = Size.zero;
  final Random _rng = Random();

  Car? car;
  /// Carros que já chegaram — ficam na faixa com medalha.
  final List<Car> finishedCars = [];
  final List<Obstacle> obstacles = [];
  final List<Explosion> explosions = [];
  final List<Stroke> strokes = [];
  final Map<int, _PointerTrack> _pointers = {};

  final ValueNotifier<int> repaintTick = ValueNotifier<int>(0);
  int paintTimeMs = 0;

  DateTime _startedAt = DateTime.now();
  DateTime? _lastTick;
  DateTime? _victoryAt;

  double carSize = 52;
  double strokeWidth = 14;
  double _playLeft = 0;
  double _playRight = 0;
  double _playTop = 0;
  double _playBottom = 0;

  static const _cBlue = Color(0xFF1E88E5);
  static const _cGreen = Color(0xFF43A047);
  static const _cYellow = Color(0xFFFDD835);
  static const _cOrange = Color(0xFFFB8C00);
  static const _cRed = Color(0xFFE53935);

  static const _minFollowSpeed = 55.0;
  static const _maxFollowSpeed = 520.0;
  static const _speedFactor = 0.85;

  void setBounds(Size size) {
    if (size.isEmpty) return;
    _bounds = size;
    carSize = (min(size.width, size.height) * 0.11).clamp(36.0, 80.0);
    strokeWidth = carSize * 0.28;
    _playLeft = kSpawnMargin + carSize;
    _playRight = size.width - kFinishStripWidth - carSize * 0.5;
    _playTop = carSize;
    _playBottom = size.height - carSize;
    if (car == null) {
      _spawnCar();
      _generateObstacles();
    }
  }

  void reset() {
    strokes.clear();
    explosions.clear();
    finishedCars.clear();
    _pointers.clear();
    _victoryAt = null;
    _startedAt = DateTime.now();
    _lastTick = null;
    _generateObstacles();
    _spawnCar();
    _requestRepaint();
  }

  // ---------------------------------------------------------------- game loop

  void tick() {
    if (_bounds.isEmpty) return;
    final now = DateTime.now();
    var dt = 0.0;
    if (_lastTick != null) {
      dt = now.difference(_lastTick!).inMicroseconds / 1000000.0;
      if (dt > 0.05) dt = 0.05;
    }
    _lastTick = now;
    paintTimeMs = now.difference(_startedAt).inMilliseconds;

    explosions.removeWhere((e) => e.isDone(now));
    final c = car;
    if (c != null) {
      if (c.state == CarState.following) {
        _moveCarAlongPath(c, dt);
        _checkObstacleHit(c);
        _checkFinish(c);
      } else if (c.state == CarState.exploding && explosions.isEmpty) {
        _spawnCar();
      } else if (c.state == CarState.celebrating && _victoryAt != null) {
        if (now.difference(_victoryAt!).inMilliseconds >= kVictoryHoldMs) {
          // Mantém o carro vencedor + medalha e cria outro na lateral.
          finishedCars.add(c);
          _spawnCar();
        }
      }
    }

    _requestRepaint();
  }

  void _moveCarAlongPath(Car c, double dt) {
    if (c.path.isEmpty) {
      c.state = CarState.idle;
      c.speed = 0;
      return;
    }

    var remaining = c.speed * dt;
    while (remaining > 0 && c.pathIndex < c.path.length) {
      final target = c.path[c.pathIndex];
      final delta = target - c.position;
      final dist = delta.distance;
      if (dist < 0.5) {
        c.pathIndex++;
        continue;
      }
      if (dist <= remaining) {
        c.position = target;
        c.heading = atan2(delta.dy, delta.dx);
        remaining -= dist;
        c.pathIndex++;
      } else {
        final dir = delta / dist;
        c.position += dir * remaining;
        c.heading = atan2(dir.dy, dir.dx);
        remaining = 0;
      }
    }

    if (c.pathIndex >= c.path.length) {
      c.state = CarState.idle;
      c.speed = 0;
      c.linkedPointer = null;
    }
  }

  void _checkObstacleHit(Car c) {
    for (final o in obstacles) {
      final hitDist = c.radius + o.radius * 0.85;
      if ((c.position - o.position).distance <= hitDist) {
        _crashCar(c);
        return;
      }
    }
  }

  void _checkFinish(Car c) {
    if (c.position.dx >= _bounds.width - kFinishStripWidth - c.radius * 0.3) {
      c.state = CarState.celebrating;
      c.showMedal = true;
      c.speed = 0;
      c.linkedPointer = null;
      _victoryAt = DateTime.now();
      _playVictorySound();
    }
  }

  void _crashCar(Car c) {
    c.state = CarState.exploding;
    c.speed = 0;
    c.linkedPointer = null;
    c.showMedal = false;
    explosions.add(Explosion(
      position: c.position,
      startedAt: DateTime.now(),
      maxRadius: c.size * 0.9,
    ));
    _playExplosionSound();
  }

  void _spawnCar() {
    _victoryAt = null;
    final types = CarType.values;
    final y = _playTop + _rng.nextDouble() * (_playBottom - _playTop);
    car = Car(
      type: types[_rng.nextInt(types.length)],
      position: Offset(kSpawnMargin, y),
      size: carSize,
      heading: 0,
      color: kCarColors[_rng.nextInt(kCarColors.length)],
    );
  }

  void _generateObstacles() {
    obstacles.clear();
    if (_bounds.isEmpty) return;
    final count = (12 + _rng.nextInt(6)).clamp(10, 18);
    final types = ObstacleType.values;
    final playW = _playRight - _playLeft;
    final playH = _playBottom - _playTop;
    var attempts = 0;
    while (obstacles.length < count && attempts < count * 30) {
      attempts++;
      final type = types[_rng.nextInt(types.length)];
      final size = _obstacleSize(type);
      final x = _playLeft + _rng.nextDouble() * playW;
      final y = _playTop + _rng.nextDouble() * playH;
      final pos = Offset(x, y);
      if (_overlapsSpawn(pos, size) || _overlapsFinish(pos, size)) continue;
      if (_overlapsObstacle(pos, size)) continue;
      obstacles.add(Obstacle(type: type, position: pos, size: size));
    }
  }

  double _obstacleSize(ObstacleType type) {
    return switch (type) {
      ObstacleType.rock => carSize * (0.5 + _rng.nextDouble() * 0.25),
      ObstacleType.house => carSize * (1.1 + _rng.nextDouble() * 0.35),
      ObstacleType.tree => carSize * (0.9 + _rng.nextDouble() * 0.4),
      ObstacleType.bush => carSize * (0.45 + _rng.nextDouble() * 0.2),
      ObstacleType.hole => carSize * (0.55 + _rng.nextDouble() * 0.25),
    };
  }

  bool _overlapsSpawn(Offset pos, double size) {
    final spawn = Offset(kSpawnMargin, _bounds.height / 2);
    return (pos - spawn).distance < size + carSize * 1.2;
  }

  bool _overlapsFinish(Offset pos, double size) {
    return pos.dx + size > _bounds.width - kFinishStripWidth - 20;
  }

  bool _overlapsObstacle(Offset pos, double size) {
    for (final o in obstacles) {
      if ((pos - o.position).distance < (size + o.size) * 0.55) return true;
    }
    return false;
  }

  // ------------------------------------------------------------------- input

  void pointerDown(int id, Offset pos) {
    final stroke = Stroke()
      ..add(StrokePoint(pos, _cBlue, DateTime.now(), 0));
    strokes.add(stroke);
    _pointers[id] = _PointerTrack(pos, DateTime.now(), stroke);
    _tryAttachCarToStroke(id, pos, pos, 0);
    _requestRepaint();
  }

  void pointerMove(int id, Offset pos) {
    final t = _pointers[id];
    if (t == null) return;
    final now = DateTime.now();
    final dtMs = now.difference(t.lastTime).inMicroseconds / 1000.0;
    final dist = (pos - t.lastPos).distance;
    final pxPerSec = dtMs > 0 ? dist / (dtMs / 1000.0) : 0.0;
    final speed = pxPerSec.clamp(_minFollowSpeed, _maxFollowSpeed);
    t.stroke.add(StrokePoint(pos, _strokeColorForSpeed(pxPerSec), now, speed));
    _tryAttachCarToStroke(id, t.lastPos, pos, speed);
    _extendCarPath(id, pos, speed);
    t.lastPos = pos;
    t.lastTime = now;
    _requestRepaint();
  }

  void pointerUp(int id, Offset pos) {
    _pointers.remove(id);
    final c = car;
    if (c != null && c.linkedPointer == id) {
      c.linkedPointer = null;
    }
    _requestRepaint();
  }

  void _tryAttachCarToStroke(int pointerId, Offset a, Offset b, double speed) {
    final c = car;
    if (c == null || c.state != CarState.idle) return;
    final d = _distancePointToSegment(c.position, a, b);
    if (d > c.radius + strokeWidth * 0.5) return;

    final attach = _nearestPointOnSegment(c.position, a, b);
    c.path
      ..clear()
      ..add(attach)
      ..add(b);
    c.pathIndex = 0;
    c.state = CarState.following;
    c.speed = (speed * _speedFactor).clamp(_minFollowSpeed, _maxFollowSpeed);
    c.linkedPointer = pointerId;
    c.heading = atan2(b.dy - a.dy, b.dx - a.dx);
  }

  void _extendCarPath(int pointerId, Offset pos, double speed) {
    final c = car;
    if (c == null || c.state != CarState.following) return;
    if (c.linkedPointer != pointerId) return;
    if (c.path.isEmpty || (c.path.last - pos).distance > 2) {
      c.path.add(pos);
    }
    c.speed = (speed * _speedFactor).clamp(_minFollowSpeed, _maxFollowSpeed);
  }

  Color _strokeColorForSpeed(double pxPerSec) {
    if (pxPerSec < 250) return _cBlue;
    if (pxPerSec < 600) return _cGreen;
    if (pxPerSec < 1000) return _cYellow;
    if (pxPerSec < 1600) return _cOrange;
    return _cRed;
  }

  // ----------------------------------------------------------- geometry helpers

  double _distancePointToSegment(Offset p, Offset a, Offset b) {
    final proj = _nearestPointOnSegment(p, a, b);
    return (p - proj).distance;
  }

  Offset _nearestPointOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 0.0001) return a;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    return Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  }

  // ------------------------------------------------------------------- sounds

  Future<void> _playExplosionSound() async {
    try {
      await _soundChannel.invokeMethod('playExplosion');
    } catch (_) {}
  }

  Future<void> _playVictorySound() async {
    try {
      await _soundChannel.invokeMethod('playVictory');
    } catch (_) {}
  }

  void _requestRepaint() {
    repaintTick.value++;
  }
}
