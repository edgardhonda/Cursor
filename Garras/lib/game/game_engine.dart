import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_audio.dart';

class GameEngine {
  GameEngine({this.audio});

  final GameAudio? audio;
  final Random _random = Random();

  Size bounds = Size.zero;
  double now = 0;
  double _lastTickSeconds = 0;
  bool paused = false;
  int _nextId = 1;
  int score = 0;
  int combo = 0;
  double _nextSpawnAt = 0;

  final List<PlaneModel> planes = [];
  final List<HoleModel> holes = [];

  void setBounds(Size size) {
    if (size == bounds || size.isEmpty) return;
    bounds = size;
    reset();
  }

  void setPaused(bool value) => paused = value;

  void reset() {
    if (bounds.isEmpty) return;
    now = 0;
    _lastTickSeconds = 0;
    _nextId = 1;
    score = 0;
    combo = 0;
    planes.clear();
    holes.clear();
    _buildHoles();
    _nextSpawnAt = 0.4;
    for (var i = 0; i < 4; i++) {
      _spawnPlane(force: true);
    }
  }

  void tick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / 1e6;
    if (_lastTickSeconds == 0) {
      _lastTickSeconds = seconds;
      return;
    }
    var dt = seconds - _lastTickSeconds;
    _lastTickSeconds = seconds;
    if (paused || bounds.isEmpty) return;
    dt = dt.clamp(0.0, 0.05);
    now += dt;

    _updatePlanes(dt);
    _updateClaws(dt);
    _spawnIfNeeded();
    planes.removeWhere((p) => p.phase == PlanePhase.gone);
  }

  void tapAt(Offset position) {
    if (paused || bounds.isEmpty) return;
    HoleModel? hit;
    var best = double.infinity;
    for (final hole in holes) {
      if (hole.clawPhase != ClawPhase.idle) continue;
      final d = (hole.center - position).distance;
      if (d <= hole.radius * 1.35 && d < best) {
        best = d;
        hit = hole;
      }
    }
    if (hit != null) _launchClaw(hit);
  }

  void dispose() {}

  void _buildHoles() {
    final count = gameColors.length;
    final tablet = bounds.shortestSide >= 600;
    final radius = tablet ? 34.0 : 26.0;
    final y = bounds.height - (tablet ? 72.0 : 58.0);
    final margin = bounds.width * 0.06;
    final usable = bounds.width - margin * 2;
    for (var i = 0; i < count; i++) {
      final t = count == 1 ? 0.5 : i / (count - 1);
      holes.add(
        HoleModel(
          index: i,
          colorId: gameColors[i].id,
          center: Offset(margin + usable * t, y),
          radius: radius,
        ),
      );
    }
  }

  void _spawnIfNeeded() {
    if (now < _nextSpawnAt) return;
    if (planes.where((p) => p.phase == PlanePhase.flying).length >=
        maxPlanesOnScreen) {
      _nextSpawnAt = now + 0.4;
      return;
    }
    _spawnPlane();
    _nextSpawnAt = now + planeSpawnInterval * (0.7 + _random.nextDouble() * 0.7);
  }

  void _spawnPlane({bool force = false}) {
    if (!force &&
        planes.where((p) => p.phase == PlanePhase.flying).length >=
            maxPlanesOnScreen) {
      return;
    }
    final colorId = gameColors[_random.nextInt(gameColors.length)].id;
    final fromLeft = _random.nextBool();
    final tablet = bounds.shortestSide >= 600;
    final size = tablet
        ? 28.0 + _random.nextDouble() * 14
        : 22.0 + _random.nextDouble() * 12;
    final minY = bounds.height * 0.12;
    final maxY = bounds.height * 0.58;
    final y = minY + _random.nextDouble() * (maxY - minY);
    final speed = (tablet ? 110.0 : 90.0) + _random.nextDouble() * 70;
    final x = fromLeft ? -size * 1.5 : bounds.width + size * 1.5;
    final vx = fromLeft ? speed : -speed;
    planes.add(
      PlaneModel(
        id: _nextId++,
        colorId: colorId,
        position: Offset(x, y),
        velocity: Offset(vx, _random.nextDouble() * 12 - 6),
        size: size,
      ),
    );
    audio?.playWhoosh(wallTime: _wallTime());
  }

  void _updatePlanes(double dt) {
    for (final plane in planes) {
      switch (plane.phase) {
        case PlanePhase.flying:
          plane.position += plane.velocity * dt;
          plane.position = Offset(
            plane.position.dx,
            plane.position.dy + sin(now * 3 + plane.id) * 8 * dt,
          );
          final off = plane.position.dx < -80 ||
              plane.position.dx > bounds.width + 80;
          if (off) plane.phase = PlanePhase.gone;
        case PlanePhase.caught:
          break;
        case PlanePhase.falling:
          final holeIndex = plane.caughtByHole;
          if (holeIndex == null ||
              holeIndex < 0 ||
              holeIndex >= holes.length) {
            plane.phase = PlanePhase.gone;
            break;
          }
          final hole = holes[holeIndex];
          final t =
              ((now - plane.phaseStartedAt) / planeFallSeconds).clamp(0.0, 1.0);
          final ease = t * t;
          final startPos = Offset(plane.velocity.dx, plane.velocity.dy);
          plane.position = Offset.lerp(startPos, hole.center, ease)!;
          if (t >= 1) {
            plane.phase = PlanePhase.gone;
            score += 1 + combo;
            combo++;
            audio?.playFall();
            audio?.playChirp();
          }
        case PlanePhase.gone:
          break;
      }
    }
  }

  void _launchClaw(HoleModel hole) {
    PlaneModel? target;
    var best = double.infinity;
    final range = hole.radius * clawGrabRangeFactor;
    for (final plane in planes) {
      if (plane.phase != PlanePhase.flying) continue;
      if (plane.colorId != hole.colorId) continue;
      final dx = (plane.position.dx - hole.center.dx).abs();
      if (dx > range + plane.size) continue;
      if (plane.position.dy > hole.center.dy - hole.radius) continue;
      final d = dx + (hole.center.dy - plane.position.dy) * 0.15;
      if (d < best) {
        best = d;
        target = plane;
      }
    }

    hole.clawPhase = ClawPhase.extending;
    hole.clawStartedAt = now;
    hole.clawProgress = 0;
    hole.caughtPlaneId = null;
    if (target != null) {
      hole.clawTarget = target.position;
      hole.caughtPlaneId = target.id;
    } else {
      // Sobe até altura máxima vazia.
      hole.clawTarget = Offset(hole.center.dx, bounds.height * 0.22);
    }
    audio?.playTap(hole.colorId);
  }

  void _updateClaws(double dt) {
    for (final hole in holes) {
      switch (hole.clawPhase) {
        case ClawPhase.idle:
          hole.clawProgress = 0;
        case ClawPhase.extending:
          final t = ((now - hole.clawStartedAt) / clawExtendSeconds)
              .clamp(0.0, 1.0);
          hole.clawProgress = Curves.easeOut.transform(t);
          // Atualiza alvo se o avião ainda voa.
          final pid = hole.caughtPlaneId;
          if (pid != null) {
            final plane = planes.cast<PlaneModel?>().firstWhere(
                  (p) => p?.id == pid,
                  orElse: () => null,
                );
            if (plane != null && plane.phase == PlanePhase.flying) {
              hole.clawTarget = plane.position;
            }
          }
          if (t >= 1) {
            hole.clawPhase = ClawPhase.grabbing;
            hole.clawStartedAt = now;
            _tryGrab(hole);
          }
        case ClawPhase.grabbing:
          if (now - hole.clawStartedAt >= clawGrabHoldSeconds) {
            hole.clawPhase = ClawPhase.retracting;
            hole.clawStartedAt = now;
          }
        case ClawPhase.retracting:
          final t = ((now - hole.clawStartedAt) / clawRetractSeconds)
              .clamp(0.0, 1.0);
          hole.clawProgress = 1.0 - Curves.easeIn.transform(t);
          final pid = hole.caughtPlaneId;
          if (pid != null) {
            final plane = planes.cast<PlaneModel?>().firstWhere(
                  (p) => p?.id == pid && p?.phase == PlanePhase.caught,
                  orElse: () => null,
                );
            if (plane != null && hole.clawTarget != null) {
              final tip = _clawTip(hole);
              plane.position = tip;
            }
          }
          if (t >= 1) {
            final pidDone = hole.caughtPlaneId;
            if (pidDone != null) {
              final plane = planes.cast<PlaneModel?>().firstWhere(
                    (p) => p?.id == pidDone && p?.phase == PlanePhase.caught,
                    orElse: () => null,
                  );
              if (plane != null) {
                plane.phase = PlanePhase.falling;
                plane.phaseStartedAt = now;
                plane.caughtByHole = hole.index;
                // Guarda posição inicial da queda em velocity.
                plane.velocity = Offset(plane.position.dx, plane.position.dy);
              }
            } else {
              combo = 0;
              audio?.playMiss();
            }
            hole.clawPhase = ClawPhase.idle;
            hole.clawProgress = 0;
            hole.clawTarget = null;
            hole.caughtPlaneId = null;
          }
      }
    }
  }

  void _tryGrab(HoleModel hole) {
    final pid = hole.caughtPlaneId;
    if (pid == null) return;
    final plane = planes.cast<PlaneModel?>().firstWhere(
          (p) => p?.id == pid,
          orElse: () => null,
        );
    if (plane == null || plane.phase != PlanePhase.flying) {
      hole.caughtPlaneId = null;
      return;
    }
    final tip = _clawTip(hole);
    final reach = plane.size * 0.9 + hole.radius * 0.5;
    if ((plane.position - tip).distance <= reach ||
        (plane.position.dx - hole.center.dx).abs() <=
            hole.radius * clawGrabRangeFactor) {
      plane.phase = PlanePhase.caught;
      plane.phaseStartedAt = now;
      plane.caughtByHole = hole.index;
    } else {
      hole.caughtPlaneId = null;
    }
  }

  Offset clawTipFor(HoleModel hole) => _clawTip(hole);

  Offset _clawTip(HoleModel hole) {
    final target = hole.clawTarget ??
        Offset(hole.center.dx, bounds.height * 0.22);
    return Offset.lerp(hole.center, target, hole.clawProgress)!;
  }

  double _wallTime() => DateTime.now().microsecondsSinceEpoch / 1e6;
}
