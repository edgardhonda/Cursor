import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/game_models.dart';

typedef SoundCallback = void Function(String sound);

class GameEngine {
  GameEngine({this.onSound});

  final SoundCallback? onSound;

  final Random _random = Random();
  final List<Creature> creatures = [];
  final List<StrokePoint> finishedPoints = [];
  final Map<int, ActiveStroke> activeStrokes = {};
  final List<Explosion> explosions = [];

  bool running = false;
  bool started = false;
  double spawnIntervalMs = initialSpawnIntervalMs;
  DateTime? gameStart;
  DateTime? _lastSpawnAt;
  DateTime? _nextIntervalReduceAt;

  Size _bounds = Size.zero;
  DateTime? _lastMoveAt;
  DateTime? _pausedAt;
  bool _needsInitialSpawn = false;

  final ValueNotifier<int> repaintTick = ValueNotifier(0);
  int paintTimeMs = 0;

  DateTime? _lastTapAt;
  Offset? _lastTapPos;

  void setBounds(Size size) {
    if (_bounds == size) return;
    _bounds = size;
  }

  void _requestRepaint() {
    paintTimeMs = DateTime.now().millisecondsSinceEpoch;
    repaintTick.value++;
  }

  List<(_Segment, double)> _cachedStrokeSegments = [];
  bool _strokeSegmentsDirty = true;

  void _invalidateStrokeSegments() {
    _strokeSegmentsDirty = true;
  }

  void start() {
    started = true;
    running = true;
    final now = DateTime.now();
    gameStart = now;
    _nextIntervalReduceAt = now.add(const Duration(seconds: 10));
    spawnIntervalMs = initialSpawnIntervalMs;
    _lastSpawnAt = null;
    _lastMoveAt = null;
    _needsInitialSpawn = true;
  }

  void stop() {
    if (!running) return;
    running = false;
    _pausedAt = DateTime.now();
  }

  void resume() {
    if (!started || running) return;

    if (_pausedAt != null) {
      final pauseDuration = DateTime.now().difference(_pausedAt!);
      if (_lastSpawnAt != null) {
        _lastSpawnAt = _lastSpawnAt!.add(pauseDuration);
      }
      if (_nextIntervalReduceAt != null) {
        _nextIntervalReduceAt = _nextIntervalReduceAt!.add(pauseDuration);
      }
      _pausedAt = null;
    }

    _lastMoveAt = null;
    running = true;
  }

  void reset() {
    creatures.clear();
    finishedPoints.clear();
    activeStrokes.clear();
    explosions.clear();
    running = false;
    started = false;
    spawnIntervalMs = initialSpawnIntervalMs;
    gameStart = null;
    _lastSpawnAt = null;
    _nextIntervalReduceAt = null;
    _lastMoveAt = null;
    _pausedAt = null;
    _lastTapAt = null;
    _lastTapPos = null;
    _needsInitialSpawn = false;
    _invalidateStrokeSegments();
  }

  void tick() {
    if (!running || _bounds.isEmpty) return;

    final now = DateTime.now();
    var dt = 0.0;
    if (_lastMoveAt != null) {
      dt = now.difference(_lastMoveAt!).inMicroseconds / 1000000.0;
      if (dt > 0.1) dt = 0.1;
    }
    _lastMoveAt = now;

    if (_needsInitialSpawn) {
      _trySpawn();
      _needsInitialSpawn = false;
      _lastSpawnAt = now;
    } else if (_lastSpawnAt != null &&
        now.difference(_lastSpawnAt!).inMilliseconds >= spawnIntervalMs.round()) {
      _trySpawn();
      _lastSpawnAt = now;
    }

    if (_nextIntervalReduceAt != null && !now.isBefore(_nextIntervalReduceAt!)) {
      spawnIntervalMs = max(minSpawnIntervalMs, spawnIntervalMs * 0.9);
      _nextIntervalReduceAt = _nextIntervalReduceAt!.add(const Duration(seconds: 10));
    }

    final dtMs = (dt * 1000).clamp(0.0, 100.0);
    if (dtMs > 0) {
      _moveCreatures(dtMs / 1000.0);
    }
    _pruneExplosions(now);
    _pruneStrokes(now);
    _requestRepaint();
  }

  void _trySpawn() {
    if (creatures.length >= maxCreatures || _bounds.isEmpty) return;

    for (var attempt = 0; attempt < 24; attempt++) {
      final candidate = Creature.random(Offset.zero, _bounds);
      final margin = candidate.size * 0.55 + 20;
      final x = margin + _random.nextDouble() * (_bounds.width - margin * 2);
      final y = margin + _random.nextDouble() * (_bounds.height - margin * 2);
      candidate.position = Offset(x, y);
      if (_addCreatureIfPossible(candidate)) return;
    }
  }

  bool _spawnCreatureAt(Offset pos) {
    if (!running || creatures.length >= maxCreatures || _bounds.isEmpty) {
      return false;
    }

    final maxMargin = creatureBaseSize * 2.0 * 0.55 + 20;
    if (pos.dx < maxMargin ||
        pos.dy < maxMargin ||
        pos.dx > _bounds.width - maxMargin ||
        pos.dy > _bounds.height - maxMargin) {
      return false;
    }

    for (var attempt = 0; attempt < 16; attempt++) {
      final offset = attempt == 0
          ? Offset.zero
          : Offset(
              (_random.nextDouble() - 0.5) * 24,
              (_random.nextDouble() - 0.5) * 24,
            );
      final candidate = Creature.random(pos + offset, _bounds);
      candidate.position = pos + offset;
      if (_addCreatureIfPossible(candidate)) return true;
    }
    return false;
  }

  bool _addCreatureIfPossible(Creature candidate) {
    if (creatures.length >= maxCreatures) return false;
    if (_overlapsAnyCreature(candidate)) return false;
    creatures.add(candidate);
    _requestRepaint();
    return true;
  }

  double _creatureRadius(Creature c) => c.size * 0.35;

  bool _overlapsAnyCreature(Creature c, {int? ignoreId}) {
    for (final other in creatures) {
      if (other.id == c.id || other.id == ignoreId) continue;
      final minDist = _creatureRadius(c) + _creatureRadius(other);
      if ((other.position - c.position).distance < minDist) return true;
    }
    return false;
  }

  void _moveCreatures(double dt) {
    if (dt <= 0) return;

    final segments = _strokeSegments();

    for (final c in creatures) {
      c.heading += c.turnRate * dt;
      c.heading = _normalizeAngle(c.heading);

      final dir = Offset(cos(c.heading), sin(c.heading));
      var next = c.position + dir * c.speed * dt;
      final radius = _creatureRadius(c);

      next = _resolveBorderCollision(c, next, radius);
      next = _resolveStrokeCollision(c, c.position, next, segments, radius);
      next = _resolveCreatureCollision(c, c.position, next, radius);

      c.position = next;
    }

    for (var i = 0; i < 2; i++) {
      _resolveCreatureOverlaps();
    }
  }

  Offset _resolveCreatureCollision(
    Creature c,
    Offset from,
    Offset to,
    double radius,
  ) {
    var result = to;

    for (final other in creatures) {
      if (other.id == c.id) continue;

      final otherRadius = _creatureRadius(other);
      final minDist = radius + otherRadius;
      final delta = result - other.position;
      final dist = delta.distance;
      if (dist >= minDist || dist < 0.001) continue;

      final normal = Offset(delta.dx / dist, delta.dy / dist);
      final wasOutside = (from - other.position).distance >= minDist - 1;
      if (!wasOutside && dist >= minDist - 2) continue;

      final overlap = minDist - dist;
      result += Offset(normal.dx * (overlap + 1.5), normal.dy * (overlap + 1.5));
      _reflectCreature(c, normal);
    }

    return result;
  }

  void _resolveCreatureOverlaps() {
    for (var i = 0; i < creatures.length; i++) {
      for (var j = i + 1; j < creatures.length; j++) {
        final a = creatures[i];
        final b = creatures[j];
        final delta = b.position - a.position;
        final dist = delta.distance;
        final minDist = _creatureRadius(a) + _creatureRadius(b);

        if (dist >= minDist) continue;

        Offset normal;
        if (dist < 0.001) {
          final angle = _random.nextDouble() * 2 * pi;
          normal = Offset(cos(angle), sin(angle));
        } else {
          normal = Offset(delta.dx / dist, delta.dy / dist);
        }

        final overlap = minDist - max(dist, 0.001);
        final push = normal * (overlap / 2 + 0.5);
        a.position -= push;
        b.position += push;

        _reflectCreature(a, Offset(-normal.dx, -normal.dy));
        _reflectCreature(b, normal);
      }
    }
  }

  void _reflectCreature(Creature c, Offset outwardNormal) {
    final moveDir = Offset(cos(c.heading), sin(c.heading));
    final dot = moveDir.dx * outwardNormal.dx + moveDir.dy * outwardNormal.dy;
    if (dot >= 0) return;

    final reflected = Offset(
      moveDir.dx - 2 * dot * outwardNormal.dx,
      moveDir.dy - 2 * dot * outwardNormal.dy,
    );
    c.heading = atan2(reflected.dy, reflected.dx);
    _onDirectionChange(c);
    c.heading = _normalizeAngle(c.heading);
  }

  Offset _resolveBorderCollision(Creature c, Offset next, double radius) {
    var pos = next;

    if (pos.dx < radius) {
      pos = Offset(radius, pos.dy);
      c.heading = pi - c.heading;
      _onDirectionChange(c);
    } else if (pos.dx > _bounds.width - radius) {
      pos = Offset(_bounds.width - radius, pos.dy);
      c.heading = pi - c.heading;
      _onDirectionChange(c);
    }

    if (pos.dy < radius) {
      pos = Offset(pos.dx, radius);
      c.heading = -c.heading;
      _onDirectionChange(c);
    } else if (pos.dy > _bounds.height - radius) {
      pos = Offset(pos.dx, _bounds.height - radius);
      c.heading = -c.heading;
      _onDirectionChange(c);
    }

    c.heading = _normalizeAngle(c.heading);
    return pos;
  }

  Offset _resolveStrokeCollision(
    Creature c,
    Offset from,
    Offset to,
    List<(_Segment, double)> segments,
    double radius,
  ) {
    _Segment? hitSeg;
    var bestDist = double.infinity;
    var hitNormal = Offset.zero;

    for (final (seg, width) in segments) {
      final threshold = radius + width * 0.5 + 5;
      final dist = _pointToSegmentDistance(to, seg.a, seg.b);
      if (dist >= threshold || dist >= bestDist) continue;

      final segVec = seg.b - seg.a;
      final len = segVec.distance;
      if (len < 0.001) continue;

      final tangent = Offset(segVec.dx / len, segVec.dy / len);
      var normal = Offset(-tangent.dy, tangent.dx);
      final moveDir = Offset(cos(c.heading), sin(c.heading));
      final approach = moveDir.dx * normal.dx + moveDir.dy * normal.dy;
      if (approach > 0) normal = Offset(-normal.dx, -normal.dy);

      final wasOutside =
          _pointToSegmentDistance(from, seg.a, seg.b) >= threshold - 1;
      if (!wasOutside && dist >= threshold - 2) continue;

      bestDist = dist;
      hitSeg = seg;
      hitNormal = normal;
    }

    if (hitSeg == null) return to;

    final moveDir = Offset(cos(c.heading), sin(c.heading));
    final dot = moveDir.dx * hitNormal.dx + moveDir.dy * hitNormal.dy;
    final reflected = Offset(
      moveDir.dx - 2 * dot * hitNormal.dx,
      moveDir.dy - 2 * dot * hitNormal.dy,
    );
    c.heading = atan2(reflected.dy, reflected.dx);
    _onDirectionChange(c);

    final push = (radius + 6) - bestDist + 2;
    return to + Offset(hitNormal.dx * push, hitNormal.dy * push);
  }

  void _onDirectionChange(Creature c) {
    if (c.turnRate != 0) c.turnRate = -c.turnRate;
  }

  double _normalizeAngle(double angle) {
    while (angle > pi) {
      angle -= 2 * pi;
    }
    while (angle <= -pi) {
      angle += 2 * pi;
    }
    return angle;
  }

  List<(_Segment, double)> _strokeSegments() {
    if (!_strokeSegmentsDirty) return _cachedStrokeSegments;

    final out = <(_Segment, double)>[];
    _appendStrokeSegments(finishedPoints, out);
    for (final stroke in activeStrokes.values) {
      _appendStrokeSegments(stroke.points, out);
    }

    _cachedStrokeSegments = out;
    _strokeSegmentsDirty = false;
    return out;
  }

  void _appendStrokeSegments(List<StrokePoint> points, List<(_Segment, double)> out) {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (b.createdAt.difference(a.createdAt).inMilliseconds > 500) continue;
      out.add((_Segment(a.position, b.position), b.width));
    }
  }

  void pointerDown(int pointer, Offset pos) {
    if (!running) return;
    activeStrokes[pointer] = ActiveStroke(
      pointer: pointer,
      points: [
        StrokePoint(
          position: pos,
          color: const Color(0xFF1565C0),
          width: 4,
          createdAt: DateTime.now(),
        ),
      ],
    );
    _invalidateStrokeSegments();
    _requestRepaint();
  }

  void _handleTap(Offset pos) {
    final now = DateTime.now();
    if (_lastTapAt != null && _lastTapPos != null) {
      final elapsed = now.difference(_lastTapAt!).inMilliseconds;
      final distance = (pos - _lastTapPos!).distance;
      if (elapsed <= doubleTapMaxMs && distance <= doubleTapMaxDistance) {
        _lastTapAt = null;
        _lastTapPos = null;
        _spawnCreatureAt(pos);
        return;
      }
    }

    _lastTapAt = now;
    _lastTapPos = pos;
    _tryDestroyCreatureAt(pos);
  }

  void pointerMove(int pointer, Offset pos) {
    final stroke = activeStrokes[pointer];
    if (stroke == null || stroke.points.isEmpty) return;

    final prev = stroke.points.last;
    final now = DateTime.now();
    final dtMs = max(1, now.difference(prev.createdAt).inMilliseconds);
    final dist = (pos - prev.position).distance;
    final speed = dist / dtMs * 1000;
    final width = 3.0 + (speed / 400).clamp(0.0, 4.0);

    stroke.points.add(
      StrokePoint(
        position: pos,
        color: strokeColorForSpeed(speed),
        width: width,
        createdAt: now,
      ),
    );

    if (dist > 3) onSound?.call('drag');
    _destroyCreaturesHitByStroke(prev.position, pos, width);
    _invalidateStrokeSegments();
    _requestRepaint();
  }

  void pointerUp(int pointer, Offset pos) {
    final stroke = activeStrokes.remove(pointer);
    if (stroke == null || stroke.points.isEmpty) return;

    if (stroke.points.length == 1) {
      _handleTap(pos);
      return;
    }

    final last = stroke.points.last;
    if ((pos - last.position).distance > 1) {
      _destroyCreaturesHitByStroke(last.position, pos, last.width);
    }

    final totalMove = (pos - stroke.points.first.position).distance;
    if (totalMove < tapMoveThreshold) {
      _handleTap(pos);
      return;
    }

    finishedPoints.addAll(stroke.points);
    _invalidateStrokeSegments();
    _requestRepaint();
  }

  void _destroyCreaturesHitByStroke(Offset from, Offset to, double width) {
    if ((from - to).distance < 0.001) {
      _tryDestroyCreatureAt(from);
      return;
    }

    final hits = <Creature>[];
    for (final c in creatures) {
      final dist = _pointToSegmentDistance(c.position, from, to);
      final threshold = c.size * 0.55 + width * 0.5;
      if (dist < threshold) hits.add(c);
    }

    for (final c in hits) {
      if (creatures.remove(c)) {
        explosions.add(
          Explosion(position: c.position, startedAt: DateTime.now()),
        );
        onSound?.call('destroy');
      }
    }
    if (hits.isNotEmpty) _requestRepaint();
  }

  void _tryDestroyCreatureAt(Offset pos) {
    Creature? hit;
    var bestDist = double.infinity;
    for (final c in creatures) {
      final d = (c.position - pos).distance;
      if (d < c.size && d < bestDist) {
        bestDist = d;
        hit = c;
      }
    }
    if (hit != null) {
      creatures.remove(hit);
      explosions.add(Explosion(position: hit.position, startedAt: DateTime.now()));
      onSound?.call('destroy');
      _requestRepaint();
    }
  }

  void _pruneExplosions(DateTime now) {
    explosions.removeWhere(
      (e) => now.difference(e.startedAt).inMilliseconds > Explosion.durationMs,
    );
  }

  void _pruneStrokes(DateTime now) {
    final before = finishedPoints.length;
    finishedPoints.removeWhere(
      (p) => now.difference(p.createdAt).inMilliseconds > strokeFadeMs,
    );
    if (finishedPoints.length != before) {
      _invalidateStrokeSegments();
    }
  }
}

class _Segment {
  _Segment(this.a, this.b);
  final Offset a;
  final Offset b;
}

double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final ap = p - a;
  final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (abLen2 == 0) return (p - a).distance;
  var t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLen2;
  t = t.clamp(0.0, 1.0);
  final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  return (p - proj).distance;
}
