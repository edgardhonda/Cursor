import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_audio.dart';

class _PointerTrack {
  _PointerTrack(this.start) : last = start;

  final Offset start;
  Offset last;
  double maxDist = 0;
}

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
  int fliesEaten = 0;
  int badFrogsBlasted = 0;

  Rect soup = Rect.zero;
  final PlayerFrog player = PlayerFrog();
  final List<FlyModel> flies = [];
  final List<BadFrogModel> badFrogs = [];
  final List<GoodFrogModel> goodFrogs = [];
  final List<BombModel> bombs = [];
  final Map<int, _PointerTrack> _pointers = {};

  double _nextFlyAt = 0;
  double _nextBadAt = 0;
  double _nextGoodAt = 0;

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
    fliesEaten = 0;
    badFrogsBlasted = 0;
    flies.clear();
    badFrogs.clear();
    goodFrogs.clear();
    bombs.clear();
    _pointers.clear();
    player.tonguePhase = TonguePhase.idle;
    player.phase = PlayerPhase.idle;
    player.tongueProgress = 0;
    player.tongueTarget = null;
    player.tongueFlyId = null;
    player.sizeScale = 1;
    player.explodeStartedAt = 0;
    _layoutSoup();
    _nextFlyAt = 0.2;
    _nextBadAt = 3.2;
    _nextGoodAt = 6.5;
    for (var i = 0; i < 4; i++) {
      _spawnFly(force: true);
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

    if (player.phase == PlayerPhase.exploding) {
      if (now - player.explodeStartedAt >= playerExplodeSeconds) {
        reset();
      }
      return;
    }

    _spawnIfNeeded();
    _updateFlies(dt);
    _updateBadFrogs(dt);
    _updateGoodFrogs(dt);
    _updateTongue();
    _updateBombs(dt);
    _cleanup();
  }

  void tapAt(Offset position) {
    if (paused || bounds.isEmpty) return;
    if (player.phase == PlayerPhase.exploding) return;

    BadFrogModel? badHit;
    var bestBad = double.infinity;
    for (final frog in badFrogs) {
      if (frog.phase != BadFrogPhase.hunting) continue;
      final d = (frog.position - position).distance;
      if (d <= BadFrogModel.radius + 16 && d < bestBad) {
        bestBad = d;
        badHit = frog;
      }
    }
    if (badHit != null) {
      _throwBomb(badHit);
      return;
    }

    if (player.tonguePhase != TonguePhase.idle) return;

    FlyModel? flyHit;
    var bestFly = double.infinity;
    for (final fly in flies) {
      if (fly.phase != FlyPhase.buzzing) continue;
      final d = (fly.position - position).distance;
      if (d <= FlyModel.radius + 18 && d < bestFly) {
        bestFly = d;
        flyHit = fly;
      }
    }
    if (flyHit != null) _launchTongue(flyHit);
  }

  void pointerDown(int id, Offset position) {
    _pointers[id] = _PointerTrack(position);
  }

  void pointerMove(int id, Offset position) {
    final track = _pointers[id];
    if (track == null) return;
    _slashPlayerAlongSegment(track.last, position);
    track.maxDist = max(track.maxDist, (position - track.start).distance);
    track.last = position;
  }

  void pointerUp(int id, Offset position) {
    final track = _pointers.remove(id);
    if (track == null) return;
    if (track.maxDist < 14) {
      tapAt(track.start);
    }
  }

  bool get playerSurprised => fliesEaten >= fliesToSurprise;

  double _maxPlayerScale() {
    if (bounds.isEmpty || soup.isEmpty) return 1;
    final availW = soup.width * 0.92;
    final availH = (player.position.dy - soup.top).clamp(40.0, bounds.height);
    final maxDiameter = min(availW, availH * 1.85);
    return max(1.0, maxDiameter / (PlayerFrog.baseRadius * 2));
  }

  void _slashPlayerAlongSegment(Offset a, Offset b) {
    if (player.phase == PlayerPhase.exploding) return;
    final hitDist = _distancePointToSegment(player.position, a, b);
    if (hitDist <= player.radius + 10) {
      _explodePlayer();
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

  void dispose() {}

  Rect get soupBowl => soup;

  void _layoutSoup() {
    final tablet = bounds.shortestSide >= 600;
    final marginX = tablet ? bounds.width * 0.1 : bounds.width * 0.06;
    final top = bounds.height * (tablet ? 0.16 : 0.18);
    final bottom = bounds.height * 0.82;
    soup = Rect.fromLTRB(marginX, top, bounds.width - marginX, bottom);
    player.position = Offset(soup.center.dx, soup.bottom - 18);
  }

  void _spawnIfNeeded() {
    if (now >= _nextFlyAt) {
      _spawnFly();
      _nextFlyAt = now + flySpawnInterval * (0.7 + _random.nextDouble() * 0.8);
    }
    if (now >= _nextBadAt) {
      _spawnBadFrog();
      _nextBadAt = now + badSpawnInterval * (0.8 + _random.nextDouble() * 0.6);
    }
    if (now >= _nextGoodAt) {
      _spawnGoodFrog();
      _nextGoodAt = now + goodSpawnInterval * (0.85 + _random.nextDouble() * 0.5);
    }
  }

  void _spawnFly({bool force = false}) {
    final buzzing = flies.where((f) => f.phase == FlyPhase.buzzing).length;
    if (!force && buzzing >= maxFlies) return;
    final pos = Offset(
      soup.left + 24 + _random.nextDouble() * (soup.width - 48),
      soup.top + 30 + _random.nextDouble() * (soup.height - 80),
    );
    final angle = _random.nextDouble() * pi * 2;
    flies.add(
      FlyModel(
        id: _nextId++,
        position: pos,
        velocity: Offset(cos(angle), sin(angle)) * flySpeed,
      ),
    );
    audio?.playBuzz(wallTime: _wallTime());
  }

  void _spawnBadFrog() {
    if (badFrogs.where((f) => f.phase == BadFrogPhase.hunting).length >=
        maxBadFrogs) {
      return;
    }
    final fromLeft = _random.nextBool();
    final y = soup.top + 40 + _random.nextDouble() * (soup.height * 0.5);
    final x = fromLeft ? soup.left - 36 : soup.right + 36;
    badFrogs.add(
      BadFrogModel(id: _nextId++, position: Offset(x, y)),
    );
    audio?.playRibbit(wallTime: _wallTime());
  }

  void _spawnGoodFrog() {
    if (goodFrogs.where((f) => f.phase == GoodFrogPhase.hunting).length >=
        maxGoodFrogs) {
      return;
    }
    if (badFrogs.where((f) => f.phase == BadFrogPhase.hunting).isEmpty) {
      _nextGoodAt = now + 1.5;
      return;
    }
    final y = soup.bottom - 50;
    final x = _random.nextBool() ? soup.left + 40 : soup.right - 40;
    goodFrogs.add(GoodFrogModel(id: _nextId++, position: Offset(x, y)));
    audio?.playCheer();
  }

  void _updateFlies(double dt) {
    for (final fly in flies) {
      if (fly.phase != FlyPhase.buzzing) continue;
      fly.position += fly.velocity * dt;
      fly.velocity += Offset(
        (_random.nextDouble() - 0.5) * 80 * dt,
        (_random.nextDouble() - 0.5) * 80 * dt,
      );
      final speed = fly.velocity.distance;
      if (speed > flySpeed * 1.4) {
        fly.velocity = fly.velocity / speed * flySpeed * 1.4;
      }
      if (fly.position.dx < soup.left + 16 || fly.position.dx > soup.right - 16) {
        fly.velocity = Offset(-fly.velocity.dx, fly.velocity.dy);
      }
      if (fly.position.dy < soup.top + 20 || fly.position.dy > soup.bottom - 50) {
        fly.velocity = Offset(fly.velocity.dx, -fly.velocity.dy);
      }
      fly.position = Offset(
        fly.position.dx.clamp(soup.left + 16, soup.right - 16),
        fly.position.dy.clamp(soup.top + 20, soup.bottom - 50),
      );
    }
  }

  void _updateBadFrogs(double dt) {
    for (final frog in badFrogs) {
      switch (frog.phase) {
        case BadFrogPhase.hunting:
          final target = _nearestBuzzingFly(frog.position);
          if (target == null) {
            frog.velocity = Offset.zero;
            break;
          }
          frog.targetFlyId = target.id;
          final to = target.position - frog.position;
          final dist = to.distance;
          if (dist < 0.001) break;
          frog.velocity = to / dist * badFrogSpeed;
          frog.position += frog.velocity * dt;
          if (dist <= BadFrogModel.radius + FlyModel.radius) {
            target.phase = FlyPhase.stolen;
            target.phaseStartedAt = now;
            frog.targetFlyId = null;
          }
        case BadFrogPhase.fleeing:
          frog.position += frog.velocity * dt;
          if (frog.position.dx < soup.left - 80 ||
              frog.position.dx > soup.right + 80 ||
              frog.position.dy < soup.top - 80) {
            frog.phase = BadFrogPhase.gone;
          }
        case BadFrogPhase.exploding:
          if (now - frog.phaseStartedAt > 0.35) {
            frog.phase = BadFrogPhase.gone;
          }
        case BadFrogPhase.gone:
          break;
      }
    }
  }

  void _updateGoodFrogs(double dt) {
    for (final frog in goodFrogs) {
      switch (frog.phase) {
        case GoodFrogPhase.hunting:
          final target = _nearestHuntingBad(frog.position);
          if (target == null) {
            frog.phase = GoodFrogPhase.celebrating;
            frog.phaseStartedAt = now;
            break;
          }
          frog.targetBadId = target.id;
          final to = target.position - frog.position;
          final dist = to.distance;
          if (dist < 0.001) break;
          frog.velocity = to / dist * goodFrogSpeed;
          frog.position += frog.velocity * dt;
          if (dist <= GoodFrogModel.radius + BadFrogModel.radius * 0.7) {
            _expelBadFrog(target, from: frog.position);
            frog.phase = GoodFrogPhase.celebrating;
            frog.phaseStartedAt = now;
            audio?.playCheer();
          }
        case GoodFrogPhase.celebrating:
          if (now - frog.phaseStartedAt > 0.9) {
            frog.phase = GoodFrogPhase.gone;
          }
        case GoodFrogPhase.gone:
          break;
      }
    }
  }

  void _expelBadFrog(BadFrogModel frog, {required Offset from}) {
    if (frog.phase != BadFrogPhase.hunting) return;
    frog.phase = BadFrogPhase.fleeing;
    frog.phaseStartedAt = now;
    final away = frog.position - from;
    final dir = away.distance < 0.001
        ? Offset(frog.position.dx < soup.center.dx ? -1 : 1, -0.4)
        : away / away.distance;
    frog.velocity = (dir + const Offset(0, -0.35)) / (dir + const Offset(0, -0.35)).distance * 220;
    frog.targetFlyId = null;
    score += 2;
  }

  void _launchTongue(FlyModel fly) {
    player.tonguePhase = TonguePhase.extending;
    player.tongueStartedAt = now;
    player.tongueProgress = 0;
    player.tongueTarget = fly.position;
    player.tongueFlyId = fly.id;
    audio?.playTongue();
  }

  void _updateTongue() {
    switch (player.tonguePhase) {
      case TonguePhase.idle:
        player.tongueProgress = 0;
      case TonguePhase.extending:
        final t =
            ((now - player.tongueStartedAt) / tongueExtendSeconds).clamp(0.0, 1.0);
        player.tongueProgress = Curves.easeOut.transform(t);
        final flyId = player.tongueFlyId;
        if (flyId != null) {
          final fly = _flyById(flyId);
          if (fly != null && fly.phase == FlyPhase.buzzing) {
            player.tongueTarget = fly.position;
          }
        }
        if (t >= 1) {
          _tryEat();
          player.tonguePhase = TonguePhase.retracting;
          player.tongueStartedAt = now;
        }
      case TonguePhase.retracting:
        final t =
            ((now - player.tongueStartedAt) / tongueRetractSeconds).clamp(0.0, 1.0);
        player.tongueProgress = 1.0 - Curves.easeIn.transform(t);
        if (t >= 1) {
          player.tonguePhase = TonguePhase.idle;
          player.tongueProgress = 0;
          player.tongueTarget = null;
          player.tongueFlyId = null;
        }
    }
  }

  void _tryEat() {
    final flyId = player.tongueFlyId;
    if (flyId == null) return;
    final fly = _flyById(flyId);
    if (fly == null || fly.phase != FlyPhase.buzzing) return;
    final tip = tongueTip;
    if ((fly.position - tip).distance <= FlyModel.radius + 22) {
      fly.phase = FlyPhase.eaten;
      fly.phaseStartedAt = now;
      fliesEaten++;
      score += 1;
      player.sizeScale = min(
        player.sizeScale * playerGrowFactor,
        _maxPlayerScale(),
      );
      audio?.playGulp();
    }
  }

  void _explodePlayer() {
    player.phase = PlayerPhase.exploding;
    player.explodeStartedAt = now;
    player.tonguePhase = TonguePhase.idle;
    player.tongueProgress = 0;
    player.tongueTarget = null;
    player.tongueFlyId = null;
    audio?.playBoom();
  }

  Offset get tongueTip {
    final target = player.tongueTarget ?? player.position;
    return Offset.lerp(player.position, target, player.tongueProgress)!;
  }

  void _throwBomb(BadFrogModel frog) {
    if (bombs.any((b) => b.targetId == frog.id && b.phase == BombPhase.flying)) {
      return;
    }
    final dir = frog.position - player.position;
    if (dir.distance < 0.001) return;
    bombs.add(
      BombModel(
        id: _nextId++,
        position: player.position,
        targetId: frog.id,
        direction: dir / dir.distance,
      ),
    );
  }

  void _updateBombs(double dt) {
    for (final bomb in bombs) {
      switch (bomb.phase) {
        case BombPhase.flying:
          bomb.position += bomb.direction * bombSpeed * dt;
          final target = _badById(bomb.targetId);
          if (target == null || target.phase != BadFrogPhase.hunting) {
            bomb.phase = BombPhase.gone;
            break;
          }
          bomb.direction = (target.position - bomb.position);
          final d = bomb.direction.distance;
          if (d > 0.001) bomb.direction = bomb.direction / d;
          if (d <= BadFrogModel.radius + 10) {
            bomb.phase = BombPhase.exploding;
            bomb.phaseStartedAt = now;
            target.phase = BadFrogPhase.exploding;
            target.phaseStartedAt = now;
            badFrogsBlasted++;
            score += 5;
            audio?.playBoom();
          } else if (bomb.position.dx < -40 ||
              bomb.position.dy < -40 ||
              bomb.position.dx > bounds.width + 40 ||
              bomb.position.dy > bounds.height + 40) {
            bomb.phase = BombPhase.gone;
          }
        case BombPhase.exploding:
          if (now - bomb.phaseStartedAt > 0.3) bomb.phase = BombPhase.gone;
        case BombPhase.gone:
          break;
      }
    }
  }

  void _cleanup() {
    flies.removeWhere((f) {
      if (f.phase == FlyPhase.gone) return true;
      if (f.phase == FlyPhase.eaten || f.phase == FlyPhase.stolen) {
        return now - f.phaseStartedAt > 0.2;
      }
      return false;
    });
    badFrogs.removeWhere((f) => f.phase == BadFrogPhase.gone);
    goodFrogs.removeWhere((f) => f.phase == GoodFrogPhase.gone);
    bombs.removeWhere((b) => b.phase == BombPhase.gone);
  }

  FlyModel? _nearestBuzzingFly(Offset from) {
    FlyModel? best;
    var bestD = double.infinity;
    for (final fly in flies) {
      if (fly.phase != FlyPhase.buzzing) continue;
      final d = (fly.position - from).distance;
      if (d < bestD) {
        bestD = d;
        best = fly;
      }
    }
    return best;
  }

  BadFrogModel? _nearestHuntingBad(Offset from) {
    BadFrogModel? best;
    var bestD = double.infinity;
    for (final frog in badFrogs) {
      if (frog.phase != BadFrogPhase.hunting) continue;
      final d = (frog.position - from).distance;
      if (d < bestD) {
        bestD = d;
        best = frog;
      }
    }
    return best;
  }

  FlyModel? _flyById(int id) {
    for (final fly in flies) {
      if (fly.id == id) return fly;
    }
    return null;
  }

  BadFrogModel? _badById(int id) {
    for (final frog in badFrogs) {
      if (frog.id == id) return frog;
    }
    return null;
  }

  double _wallTime() => DateTime.now().microsecondsSinceEpoch / 1e6;
}
