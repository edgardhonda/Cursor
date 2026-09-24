import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';

typedef SoundCallback = void Function(String sound);

class _PointerTrack {
  _PointerTrack(this.startPos, this.startTime, this.stroke)
      : lastPos = startPos,
        lastTime = startTime;

  final Offset startPos;
  final DateTime startTime;
  Offset lastPos;
  DateTime lastTime;
  double maxDist = 0;
  final Stroke stroke;
}

class GameEngine {
  GameEngine({this.onSound});

  final SoundCallback? onSound;
  Size _bounds = Size.zero;
  CastleGeometry? castle;

  final List<Soldier> soldiers = [];
  final List<Ball> balls = [];
  final List<Fire> fires = [];
  final List<Stroke> strokes = [];

  final Map<int, _PointerTrack> _pointers = {};

  final ValueNotifier<int> repaintTick = ValueNotifier<int>(0);
  int paintTimeMs = 0;

  bool running = true;
  bool castleDestroyed = false;

  int _soldierIdSeq = 0;
  double soldierSize = 42;
  double ballRadius = 9;

  DateTime _startedAt = DateTime.now();
  DateTime? _lastTick;
  final Random _rng = Random();

  static const _cBlue = Color(0xFF1E88E5);
  static const _cGreen = Color(0xFF43A047);
  static const _cYellow = Color(0xFFFDD835);
  static const _cOrange = Color(0xFFFB8C00);
  static const _cRed = Color(0xFFE53935);

  Size get bounds => _bounds;

  int get arrivedCount => soldiers.where((s) => s.arrived).length;

  void setBounds(Size size) {
    if (size.isEmpty) return;
    _bounds = size;
    castle = CastleGeometry(size);
    soldierSize = (min(size.width, size.height) * 0.10).clamp(30.0, 76.0);
    ballRadius = (min(size.width, size.height) * 0.014).clamp(7.0, 16.0);
  }

  void reset() {
    soldiers.clear();
    balls.clear();
    fires.clear();
    strokes.clear();
    _pointers.clear();
    castleDestroyed = false;
    _soldierIdSeq = 0;
    _startedAt = DateTime.now();
    _lastTick = null;
    running = true;
    _requestRepaint();
  }

  // ---------------------------------------------------------------- game loop

  void tick() {
    if (_bounds.isEmpty || castle == null) return;
    final now = DateTime.now();
    var dt = 0.0;
    if (_lastTick != null) {
      dt = now.difference(_lastTick!).inMicroseconds / 1000000.0;
      if (dt > 0.05) dt = 0.05;
    }
    _lastTick = now;
    paintTimeMs = now.difference(_startedAt).inMilliseconds;

    if (!castleDestroyed) {
      _updateSoldiers(dt);
      _updateBalls(dt);
      _checkCastle();
    }
    _pruneFires(now);
    _pruneStrokes(now);
    _requestRepaint();
  }

  void _updateSoldiers(double dt) {
    final c = castle!;
    for (final s in soldiers) {
      if (s.arrived) {
        s.orbitAngle += s.orbitDir * (kSoldierSpeed / c.orbitRadius) * dt;
        s.position = c.center +
            Offset(cos(s.orbitAngle), sin(s.orbitAngle)) * c.orbitRadius;
        s.heading = s.orbitAngle + s.orbitDir * pi / 2;
        s.walkPhase += dt * 7;
      } else {
        final toCenter = c.center - s.position;
        final dist = toCenter.distance;
        if (dist <= c.arriveRadius) {
          s.arrived = true;
          s.orbitAngle =
              atan2(s.position.dy - c.center.dy, s.position.dx - c.center.dx);
        } else {
          final dir = toCenter / dist;
          s.position += dir * kSoldierSpeed * dt;
          s.heading = atan2(dir.dy, dir.dx);
          s.walkPhase += dt * (kSoldierSpeed / 9);
        }
      }
    }
  }

  void _updateBalls(double dt) {
    final toRemove = <Ball>[];
    for (final b in balls) {
      if (b.targetId != null) {
        final target = _soldierById(b.targetId!);
        if (target != null) {
          final desired = target.position - b.position;
          final dd = desired.distance;
          if (dd > 0.001) {
            final desiredVel = desired / dd * kBallSpeed;
            final tt = (kBallHomingRate * dt).clamp(0.0, 1.0);
            b.velocity = Offset(
              b.velocity.dx + (desiredVel.dx - b.velocity.dx) * tt,
              b.velocity.dy + (desiredVel.dy - b.velocity.dy) * tt,
            );
          }
        } else {
          b.targetId = null;
        }
      }

      b.position += b.velocity * dt;
      b.trail.add(b.position);
      while (b.trail.length > kBallTrailMax) {
        b.trail.removeAt(0);
      }

      Soldier? hit;
      for (final s in soldiers) {
        if ((s.position - b.position).distance <= s.radius + b.radius) {
          hit = s;
          break;
        }
      }
      if (hit != null) {
        _destroySoldier(hit);
        toRemove.add(b);
        continue;
      }

      const m = 48.0;
      if (b.position.dx < -m ||
          b.position.dx > _bounds.width + m ||
          b.position.dy < -m ||
          b.position.dy > _bounds.height + m) {
        toRemove.add(b);
      }
    }
    for (final b in toRemove) {
      balls.remove(b);
    }
  }

  void _checkCastle() {
    if (arrivedCount >= kSoldiersToDestroy) {
      _destroyCastle();
    }
  }

  void _destroyCastle() {
    castleDestroyed = true;
    onSound?.call('blast');
    fires.add(Fire(
      position: Offset(castle!.center.dx, castle!.center.dy + castle!.unit * 0.2),
      startedAt: DateTime.now(),
      durationMs: kCastleFireMs,
      maxRadius: castle!.unit * 1.4,
    ));
  }

  void _destroySoldier(Soldier s) {
    soldiers.remove(s);
    onSound?.call('hit');
    fires.add(Fire(
      position: s.position,
      startedAt: DateTime.now(),
      durationMs: kSoldierFireMs,
      maxRadius: s.size * 0.8,
    ));
  }

  void _fireBall() {
    final c = castle;
    if (c == null) return;
    final origin = c.towerTop;
    Soldier? nearest;
    var best = double.infinity;
    for (final s in soldiers) {
      final d = (s.position - origin).distance;
      if (d < best) {
        best = d;
        nearest = s;
      }
    }

    Offset vel;
    int? targetId;
    if (nearest != null) {
      final dir = nearest.position - origin;
      final dd = dir.distance;
      vel = dd > 0.001 ? dir / dd * kBallSpeed : const Offset(kBallSpeed, 0);
      targetId = nearest.id;
    } else {
      final angle = -pi / 4 + _rng.nextDouble() * (pi / 2);
      vel = Offset(cos(angle), sin(angle)) * kBallSpeed;
    }

    balls.add(Ball(
      position: origin,
      velocity: vel,
      color: _randomBallColor(),
      radius: ballRadius,
      targetId: targetId,
    ));
    onSound?.call('shoot');
  }

  void _spawnSoldier(double y) {
    if (castleDestroyed) return;
    final yy = y.clamp(soldierSize, _bounds.height - soldierSize);
    soldiers.add(Soldier(
      id: _soldierIdSeq++,
      position: Offset(_bounds.width - kSpawnStripWidth * 0.5, yy),
      size: soldierSize,
      orbitDir: _rng.nextBool() ? 1 : -1,
      walkPhase: _rng.nextDouble() * pi * 2,
    ));
    onSound?.call('spawn');
  }

  Color _randomBallColor() {
    return HSVColor.fromAHSV(1, _rng.nextDouble() * 360, 0.78, 0.95).toColor();
  }

  Soldier? _soldierById(int id) {
    for (final s in soldiers) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ------------------------------------------------------------------- input

  void pointerDown(int id, Offset pos) {
    final stroke = Stroke()
      ..add(StrokePoint(pos, _cBlue, DateTime.now()));
    strokes.add(stroke);
    _pointers[id] = _PointerTrack(pos, DateTime.now(), stroke);
    _requestRepaint();
  }

  void pointerMove(int id, Offset pos) {
    final t = _pointers[id];
    if (t == null) return;
    final now = DateTime.now();
    final dtMs = now.difference(t.lastTime).inMicroseconds / 1000.0;
    final dist = (pos - t.lastPos).distance;
    final pxPerSec = dtMs > 0 ? dist / (dtMs / 1000.0) : 0.0;
    t.maxDist = max(t.maxDist, (pos - t.startPos).distance);
    t.stroke.add(StrokePoint(pos, _strokeColorForSpeed(pxPerSec), now));
    if (dist > 4) onSound?.call('swipe');
    _destroySoldiersAlongSegment(t.lastPos, pos);
    t.lastPos = pos;
    t.lastTime = now;
    _requestRepaint();
  }

  void _destroySoldiersAlongSegment(Offset a, Offset b) {
    if (soldiers.isEmpty) return;
    final hits = <Soldier>[];
    for (final s in soldiers) {
      final d = _distancePointToSegment(s.position, a, b);
      if (d <= s.radius + ballRadius) hits.add(s);
    }
    for (final s in hits) {
      _destroySoldier(s);
    }
  }

  double _distancePointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 0.0001) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }

  void pointerUp(int id, Offset pos) {
    final t = _pointers.remove(id);
    if (t == null) return;
    final durMs = DateTime.now().difference(t.startTime).inMilliseconds;
    final isTap = t.maxDist < 14 && durMs < 450;
    if (isTap) {
      strokes.remove(t.stroke);
      _handleTap(pos);
    }
    _requestRepaint();
  }

  void _handleTap(Offset pos) {
    Soldier? hit;
    var best = double.infinity;
    for (final s in soldiers) {
      final d = (s.position - pos).distance;
      if (d <= s.radius + 12 && d < best) {
        best = d;
        hit = s;
      }
    }
    if (hit != null) {
      _destroySoldier(hit);
      return;
    }

    final c = castle;
    if (!castleDestroyed &&
        c != null &&
        (pos - c.center).distance <= c.hitRadius) {
      _fireBall();
      return;
    }

    if (pos.dx >= _bounds.width - kSpawnStripWidth) {
      _spawnSoldier(pos.dy);
    }
  }

  Color _strokeColorForSpeed(double pxPerSec) {
    if (pxPerSec < 250) return _cBlue;
    if (pxPerSec < 600) return _cGreen;
    if (pxPerSec < 1000) return _cYellow;
    if (pxPerSec < 1600) return _cOrange;
    return _cRed;
  }

  // ------------------------------------------------------------------ pruning

  void _pruneFires(DateTime now) {
    fires.removeWhere((f) => f.isDone(now));
  }

  void _pruneStrokes(DateTime now) {
    final limitMs = (kStrokeFadeSeconds * 1000).round();
    for (final s in strokes) {
      s.points.removeWhere(
          (p) => now.difference(p.createdAt).inMilliseconds > limitMs);
    }
    final active = _pointers.values.map((e) => e.stroke).toSet();
    strokes.removeWhere((s) => s.isEmpty && !active.contains(s));
  }

  void _requestRepaint() {
    repaintTick.value++;
  }
}
