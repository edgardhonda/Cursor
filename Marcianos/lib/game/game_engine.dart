import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_audio.dart';

class GameEngine {
  GameEngine({this.onCarDestroyed, this.onCarFinished, this.audio});

  final VoidCallback? onCarDestroyed;
  final VoidCallback? onCarFinished;
  final GameAudio? audio;

  final Random _random = Random();
  Size bounds = Size.zero;
  double now = 0;
  double _lastTickSeconds = 0;
  bool paused = false;
  int _nextId = 1;
  int wins = 0;

  TrackPath? track;
  CarModel? car;
  final List<MartianModel> martians = [];
  final List<LaserBeam> lasers = [];
  final List<AshPileModel> ashes = [];
  final List<ScratchSegment> scratches = [];
  final Map<int, _ScratchPointer> _pointers = {};
  double _lastChirpAt = -999;
  bool showTrophy = false;

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
    wins = 0;
    showTrophy = false;
    lasers.clear();
    ashes.clear();
    scratches.clear();
    _pointers.clear();
    _lastChirpAt = -999;
    martians.clear();
    track = _buildTrack(bounds);
    _spawnMartians();
    _spawnCar();
  }

  void tick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / 1e6;
    if (_lastTickSeconds == 0) {
      _lastTickSeconds = seconds;
      return;
    }
    var dt = seconds - _lastTickSeconds;
    _lastTickSeconds = seconds;
    if (paused || bounds.isEmpty || track == null) return;
    dt = dt.clamp(0.0, 0.05);
    now += dt;

    ashes.removeWhere((a) => now - a.createdAt > 8);
    scratches.removeWhere((s) => now - s.createdAt > scratchFadeSeconds);
    _updateCar(dt);
    _updateMartians(dt);
    _updateLasers(dt);
    _cleanupAndRespawnMartians();
  }

  void pointerDown(int pointer, Offset position) {
    if (paused) return;
    _pointers[pointer] = _ScratchPointer(
      start: position,
      last: position,
      lastWallTime: _wallTime(),
      dragged: false,
    );
  }

  void pointerMove(int pointer, Offset position) {
    if (paused) return;
    final p = _pointers[pointer];
    if (p == null) return;

    final wall = _wallTime();
    final dist = (position - p.last).distance;
    if (dist < 0.5) return;

    if (!p.dragged && (position - p.start).distance >= scratchDragThreshold) {
      p.dragged = true;
    }
    if (!p.dragged) {
      p.last = position;
      p.lastWallTime = wall;
      return;
    }

    final dt = (wall - p.lastWallTime).clamp(0.001, 0.08);
    final speed = dist / dt;
    final level = ScratchSpeedLevelX.fromSpeed(speed);
    final from = p.last;
    final to = position;
    scratches.add(
      ScratchSegment(from: from, to: to, level: level, createdAt: now),
    );
    audio?.playSaber(wallTime: wall);
    _slashMartians(from, to);

    p.last = position;
    p.lastWallTime = wall;
  }

  void pointerUp(int pointer, Offset position) {
    final p = _pointers.remove(pointer);
    if (p == null || paused) return;
    if (p.dragged) {
      // Último segmento curto até o ponto de soltura.
      final dist = (position - p.last).distance;
      if (dist >= 0.5) {
        final wall = _wallTime();
        final dt = (wall - p.lastWallTime).clamp(0.001, 0.08);
        final level = ScratchSpeedLevelX.fromSpeed(dist / dt);
        scratches.add(
          ScratchSegment(
            from: p.last,
            to: position,
            level: level,
            createdAt: now,
          ),
        );
        audio?.playSaber(wallTime: wall);
        _slashMartians(p.last, position);
      }
      return;
    }
    // Toque curto: mantém o laser no alvo.
    if (car == null || car!.phase != CarPhase.racing) return;
    MartianModel? hit;
    var best = double.infinity;
    for (final m in martians) {
      if (m.phase == MartianPhase.dead) continue;
      final d = (m.position - p.start).distance;
      if (d <= m.radius + 16 && d < best) {
        best = d;
        hit = m;
      }
    }
    if (hit != null) _fireLaser(hit);
  }

  double _wallTime() => DateTime.now().microsecondsSinceEpoch / 1e6;

  void _slashMartians(Offset from, Offset to) {
    for (final m in martians) {
      if (m.phase == MartianPhase.dead) continue;
      if (_distanceToSegment(m.position, from, to) <= m.radius) {
        m.hitsLeft = 0;
        m.phase = MartianPhase.dead;
        m.phaseStartedAt = now;
      }
    }
  }

  void dispose() {
    _pointers.clear();
  }

  TrackPath _buildTrack(Size size) {
    final w = size.width;
    final h = size.height;
    final marginX = w * 0.06;
    final midY = h * (0.45 + _random.nextDouble() * 0.1);
    final amp = h * (0.22 + _random.nextDouble() * 0.12);
    final yMin = h * (0.10 + _random.nextDouble() * 0.05);
    final yMax = h * (0.85 + _random.nextDouble() * 0.05);

    final f1 = 1.9 + _random.nextDouble() * 1.1;
    final f2 = 3.6 + _random.nextDouble() * 1.8;
    final f3 = 6.2 + _random.nextDouble() * 2.6;
    final p1 = _random.nextDouble() * pi * 2;
    final p2 = _random.nextDouble() * pi * 2;
    final p3 = _random.nextDouble() * pi * 2;
    final a1 = 0.42 + _random.nextDouble() * 0.22;
    final a2 = 0.18 + _random.nextDouble() * 0.18;
    final a3 = 0.08 + _random.nextDouble() * 0.14;

    final points = <Offset>[];
    const samples = 72;
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final x = marginX + t * (w - marginX * 2);
      // Harmônicos sinuosos com X monotônico → pista sem auto-cruzamento.
      final y = midY +
          amp * a1 * sin(t * pi * f1 + p1) +
          amp * a2 * sin(t * pi * f2 + p2) +
          amp * a3 * sin(t * pi * f3 + p3);
      points.add(Offset(x, y.clamp(yMin, yMax)));
    }
    return TrackPath.fromPoints(points);
  }

  void _spawnMartians() {
    martians.clear();
    const count = 6;
    for (var i = 0; i < count; i++) {
      final size = MartianSize.values[_random.nextInt(3)];
      Offset pos;
      var attempts = 0;
      do {
        pos = Offset(
          _random.nextDouble() * bounds.width,
          _random.nextDouble() * bounds.height,
        );
        attempts++;
      } while (attempts < 40 && _tooCloseToTrack(pos, size.radius + 36));
      // Empurra para fora da pista se ainda estiver perto.
      if (_tooCloseToTrack(pos, size.radius + 28)) {
        final nearest = _nearestOnTrack(pos);
        final away = pos - nearest;
        final n = away.distance < 1
            ? Offset(0, pos.dy < bounds.height / 2 ? -1 : 1)
            : away / away.distance;
        pos = nearest + n * (size.radius + 48);
        pos = Offset(
          pos.dx.clamp(size.radius + 4, bounds.width - size.radius - 4),
          pos.dy.clamp(size.radius + 4, bounds.height - size.radius - 4),
        );
      }
      martians.add(_createMartian(pos, size));
    }
  }

  MartianModel _createMartian(Offset pos, MartianSize size) {
    return MartianModel(
      id: _nextId++,
      position: pos,
      size: size,
      color: martianColors[_random.nextInt(martianColors.length)],
      nextChirpAt: now + 0.6 + _random.nextDouble() * 3.5,
    );
  }

  bool _tooCloseToTrack(Offset p, double minDist) {
    final tr = track!;
    for (var i = 0; i < tr.points.length; i += 2) {
      if ((tr.points[i] - p).distance < minDist) return true;
    }
    return false;
  }

  Offset _nearestOnTrack(Offset p) {
    final tr = track!;
    var best = tr.points.first;
    var bestD = double.infinity;
    for (final pt in tr.points) {
      final d = (pt - p).distance;
      if (d < bestD) {
        bestD = d;
        best = pt;
      }
    }
    return best;
  }

  void _spawnCar() {
    final tr = track!;
    final color = buggyColors[_random.nextInt(buggyColors.length)];
    final c = CarModel(color: color)
      ..progress = 0
      ..phase = CarPhase.racing
      ..phaseStartedAt = now
      ..invulnerableUntil = now + 1.6
      ..position = tr.start
      ..direction = tr.tangentAt(0);
    car = c;
    showTrophy = false;
  }

  void _updateCar(double dt) {
    final c = car;
    final tr = track;
    if (c == null || tr == null) return;

    switch (c.phase) {
      case CarPhase.racing:
        c.progress = (c.progress + carSpeed * dt).clamp(0.0, 1.0);
        c.position = tr.positionAt(c.progress);
        c.direction = tr.tangentAt(c.progress);
        if (c.progress >= 1.0) {
          c.phase = CarPhase.finished;
          c.phaseStartedAt = now;
          showTrophy = true;
          wins++;
          onCarFinished?.call();
        }
        break;
      case CarPhase.exploding:
        if (now - c.phaseStartedAt >= 0.45) {
          c.phase = CarPhase.burning;
          c.phaseStartedAt = now;
        }
        break;
      case CarPhase.burning:
        if (now - c.phaseStartedAt >= 0.9) {
          c.phase = CarPhase.ashes;
          c.phaseStartedAt = now;
          ashes.add(AshPileModel(position: c.position, createdAt: now));
        }
        break;
      case CarPhase.ashes:
        if (now - c.phaseStartedAt >= 5.0) {
          _spawnCar();
        }
        break;
      case CarPhase.finished:
        // Troféu permanece; novo buggy após breve pausa.
        if (now - c.phaseStartedAt >= 2.2) {
          _spawnCar();
        }
        break;
    }
  }

  void _updateMartians(double dt) {
    final c = car;
    if (c == null || c.phase != CarPhase.racing) {
      for (final m in martians) {
        if (m.phase == MartianPhase.attacking) m.phase = MartianPhase.idle;
      }
      return;
    }

    for (final m in martians) {
      if (m.phase == MartianPhase.dead) continue;

      _maybeChirp(m);

      final toCar = c.position - m.position;
      final dist = toCar.distance;
      if (dist < 0.001) continue;

      // Sempre caminham em direção ao buggy; aceleram conforme ele se aproxima.
      final closeness =
          (1.0 - (dist / martianChaseRange).clamp(0.0, 1.0));
      // Longe ~0.4x; no aggro sobe rápido até ~3x da velocidade base.
      final accel = 0.4 + closeness * closeness * 2.6;
      final step = m.size.speed * accel * dt;
      final dir = toCar / dist;
      m.position += dir * min(step, dist);

      m.phase =
          dist <= martianAggroRange ? MartianPhase.attacking : MartianPhase.idle;

      // Mantém na tela.
      m.position = Offset(
        m.position.dx.clamp(m.radius, bounds.width - m.radius),
        m.position.dy.clamp(m.radius, bounds.height - m.radius),
      );

      if ((m.position - c.position).distance <= m.radius + carHitRadius) {
        if (now >= c.invulnerableUntil) {
          _destroyCar();
          m.phase = MartianPhase.idle;
          break;
        }
      }
    }
  }

  void _maybeChirp(MartianModel m) {
    if (now < m.nextChirpAt) return;
    // Reagenda mesmo se o gap global bloquear o som (evita fila de bips).
    m.nextChirpAt = now + 2.2 + _random.nextDouble() * 5.5;
    if (now - _lastChirpAt < martianChirpGap) return;
    _lastChirpAt = now;
    audio?.playChirp();
  }

  void _destroyCar() {
    final c = car;
    if (c == null || c.phase != CarPhase.racing) return;
    c.phase = CarPhase.exploding;
    c.phaseStartedAt = now;
    lasers.clear();
    audio?.playExplosion();
    onCarDestroyed?.call();
  }

  void _fireLaser(MartianModel target) {
    final c = car;
    if (c == null || c.phase != CarPhase.racing) return;
    final tip = _cannonTip(c);
    final dir = target.position - tip;
    if (dir.distance < 0.001) return;
    lasers.add(
      LaserBeam(
        id: _nextId++,
        position: tip,
        direction: dir / dir.distance,
        targetId: target.id,
      ),
    );
    audio?.playLaser();
  }

  Offset _cannonTip(CarModel c) {
    final forward = c.direction;
    final up = Offset(-forward.dy, forward.dx);
    // Canhão no teto do buggy.
    return c.position + up * -16 + forward * 4;
  }

  void _updateLasers(double dt) {
    final remaining = <LaserBeam>[];
    for (final laser in lasers) {
      if (laser.phase != LaserPhase.flying) continue;
      final previous = laser.position;
      laser.position += laser.direction * laserSpeed * dt;

      final off = laser.position.dx < -40 ||
          laser.position.dy < -40 ||
          laser.position.dx > bounds.width + 40 ||
          laser.position.dy > bounds.height + 40;
      if (off) continue;

      var hit = false;
      for (final m in martians) {
        if (m.phase == MartianPhase.dead) continue;
        final hitRadius = m.radius + 8;
        final dist = _distanceToSegment(m.position, previous, laser.position);
        if (dist <= hitRadius) {
          m.hitsLeft -= 1;
          if (m.hitsLeft <= 0) {
            m.phase = MartianPhase.dead;
            m.phaseStartedAt = now;
          }
          hit = true;
          break;
        }
      }
      if (!hit) remaining.add(laser);
    }
    lasers
      ..clear()
      ..addAll(remaining);
  }

  void _cleanupAndRespawnMartians() {
    // Remove marcianos mortos após um instante.
    martians.removeWhere(
      (m) => m.phase == MartianPhase.dead && now - m.phaseStartedAt > 0.15,
    );

    // Repõe marcianos se o campo esvaziar demais (só durante a corrida).
    if (car?.phase == CarPhase.racing && martians.length < 6 && track != null) {
      final need = 6 - martians.length;
      for (var i = 0; i < need; i++) {
        final size = MartianSize.values[_random.nextInt(3)];
        final side = _random.nextBool();
        final pos = Offset(
          _random.nextDouble() * bounds.width,
          side
              ? _random.nextDouble() * bounds.height * 0.22
              : bounds.height * (0.78 + _random.nextDouble() * 0.18),
        );
        martians.add(_createMartian(pos, size));
      }
    }
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
}

class _ScratchPointer {
  _ScratchPointer({
    required this.start,
    required this.last,
    required this.lastWallTime,
    required this.dragged,
  });

  final Offset start;
  Offset last;
  double lastWallTime;
  bool dragged;
}
