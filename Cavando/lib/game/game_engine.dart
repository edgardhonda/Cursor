import 'dart:math' as math;
import 'dart:ui';

import '../models/game_models.dart';
import 'mountain_layout.dart';

class GameEngine {
  GameEngine({this.seed = 11, this.onSound});

  final int seed;
  final void Function(GameSoundCue cue)? onSound;

  Size size = Size.zero;
  MountainLayout? mountain;
  Offset ferretPos = Offset.zero;
  double ferretAngle = 0;
  double ferretScale = 1;
  bool facingRight = true;
  FerretState state = FerretState.idle;
  double walkPhase = 0;
  double time = 0;
  double eatTime = 0;
  double bumpTime = 0;
  double rollT = 0;
  bool rollLeft = true;
  double rollSpin = 0;

  final List<TunnelStamp> tunnels = [];
  final Path tunnelPath = Path();
  final List<Fruit> fruits = [];
  final List<Obstacle> obstacles = [];
  final List<StarParticle> stars = [];
  Offset diamondPos = Offset.zero;
  double diamondRadius = 16;
  bool diamondCollected = false;
  double diamondCollect = 0;
  double winTime = 0;
  Offset explodePos = Offset.zero;
  double explodeTime = 0;
  double explodeRadius = 40;

  Offset? _dragTarget;
  bool _dragging = false;
  Duration? _lastElapsed;
  math.Random? _rng;
  int _round = 0;
  double _fruitSpawnTimer = 0;
  int fruitsEaten = 0;
  double _lastFerretTapAt = -99;
  Offset? _pressOrigin;
  bool _pressMoved = false;
  bool _pressOnFerret = false;
  double _lastDigSoundAt = -99;

  static const growFactor = 1.10;
  static const maxTunnels = 1800;
  static const fruitRespawnDelay = 8.0;
  static const maxLiveFruits = 8;
  static const doubleTapWindow = 0.4;
  static const explodeDuration = 0.55;

  bool get isDragging => _dragging;
  bool get hasLayout => mountain != null;
  MountainLayout get layout => mountain!;

  double get ferretRadius => size.shortestSide * 0.048 * ferretScale;

  double get standY => size.height - ferretRadius * 1.25;

  int get liveFruitCount => fruits.where((f) => !f.eaten).length;

  void setSize(Size next) {
    if (next.width < 8 || next.height < 8) return;
    final same = (size.width - next.width).abs() < 0.5 &&
        (size.height - next.height).abs() < 0.5;
    if (same && mountain != null) return;

    final first = mountain == null;
    final old = size;
    size = next;
    mountain = MountainLayout(next);
    if (first) {
      ferretPos = Offset(next.width * 0.5, standY);
      _spawnItems();
      _placeDiamond();
    } else if (old.width > 0 && old.height > 0) {
      final sx = next.width / old.width;
      final sy = next.height / old.height;
      ferretPos = Offset(ferretPos.dx * sx, ferretPos.dy * sy);
      _remapItems(sx, sy);
    }
  }

  void tick(Duration elapsed) {
    if (mountain == null) return;
    final last = _lastElapsed ?? elapsed;
    _lastElapsed = elapsed;
    var dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;
    time += dt;
    _updateStars(dt);
    if (state == FerretState.won) {
      winTime += dt;
      diamondCollect = math.min(1, diamondCollect + dt / 0.45);
      return;
    }
    _updateFruits(dt);
    switch (state) {
      case FerretState.eating:
        _updateEating(dt);
      case FerretState.bumping:
        _updateBumping(dt);
      case FerretState.rolling:
        _updateRolling(dt);
      case FerretState.exploding:
        _updateExploding(dt);
      case FerretState.idle:
      case FerretState.walking:
      case FerretState.digging:
      case FerretState.onPeak:
        _updateMove(dt);
        _tryCollectDiamond();
      case FerretState.won:
        break;
    }
  }

  void pointerDown(Offset p) {
    if (state == FerretState.exploding || state == FerretState.won) {
      return;
    }
    final onFerret = (p - ferretPos).distance <= ferretRadius * 1.85;
    if (onFerret &&
        time - _lastFerretTapAt <= doubleTapWindow &&
        !_pressMoved) {
      _explode();
      return;
    }
    _pressOnFerret = onFerret;
    _pressOrigin = p;
    _pressMoved = false;
    if (state == FerretState.rolling ||
        state == FerretState.eating ||
        state == FerretState.bumping) {
      return;
    }
    if (onFerret) {
      _dragging = true;
      _dragTarget = p;
    }
  }

  void pointerMove(Offset p) {
    final origin = _pressOrigin;
    if (origin != null && (p - origin).distance > 14) {
      _pressMoved = true;
      _lastFerretTapAt = -99;
    }
    if (!_dragging) return;
    _dragTarget = p;
  }

  void pointerUp() {
    if (_pressOnFerret && !_pressMoved && state != FerretState.exploding) {
      _lastFerretTapAt = time;
    }
    _dragging = false;
    _dragTarget = null;
    _pressOnFerret = false;
    _pressOrigin = null;
    if (state == FerretState.walking) {
      state = FerretState.idle;
    }
  }

  void restart() {
    if (mountain == null) return;
    _round++;
    ferretScale = 1;
    ferretPos = Offset(size.width * 0.5, standY);
    ferretAngle = 0;
    facingRight = true;
    state = FerretState.idle;
    walkPhase = 0;
    eatTime = 0;
    bumpTime = 0;
    rollT = 0;
    rollSpin = 0;
    fruitsEaten = 0;
    _fruitSpawnTimer = 0;
    _dragging = false;
    _dragTarget = null;
    _lastFerretTapAt = -99;
    _pressOnFerret = false;
    _pressOrigin = null;
    _pressMoved = false;
    explodeTime = 0;
    _lastDigSoundAt = -99;
    tunnels.clear();
    tunnelPath.reset();
    stars.clear();
    diamondCollected = false;
    diamondCollect = 0;
    winTime = 0;
    _spawnItems();
    _placeDiamond();
  }

  /// Test helper: place the ferret without going through drag.
  void debugTeleport(Offset p) {
    ferretPos = p;
    if (mountain != null && layout.contains(p)) {
      state = FerretState.digging;
      _carve(p);
      _tryEat();
    }
    _tryCollectDiamond();
  }

  void _spawnItems() {
    _rng = math.Random(seed + _round * 97);
    fruits.clear();
    obstacles.clear();
    final rng = _rng!;
    const obstacleKinds = ObstacleKind.values;

    for (var i = 0; i < maxLiveFruits; i++) {
      _spawnOneFruit(animate: false);
    }
    for (var i = 0; i < 7; i++) {
      final p = _randomInside(rng, extraMargin: 0.10);
      if (p == null) continue;
      obstacles.add(
        Obstacle(
          position: p,
          kind: obstacleKinds[rng.nextInt(obstacleKinds.length)],
          radius: size.shortestSide * (0.032 + rng.nextDouble() * 0.01),
        ),
      );
    }
  }

  Offset? _randomInside(math.Random rng, {required double extraMargin}) {
    final m = layout;
    for (var n = 0; n < 80; n++) {
      final p = Offset(
        rng.nextDouble() * size.width,
        m.peakY + extraMargin * size.height +
            rng.nextDouble() * (m.baseY - m.peakY - extraMargin * size.height * 2),
      );
      if (!m.contains(p)) continue;
      if (m.inSnow(p) && rng.nextDouble() < 0.55) continue;
      if ((p - ferretPos).distance < ferretRadius * 5) continue;
      var far = true;
      for (final f in fruits) {
        if (f.eaten) continue;
        if ((f.position - p).distance < size.shortestSide * 0.08) {
          far = false;
          break;
        }
      }
      for (final o in obstacles) {
        if ((o.position - p).distance < size.shortestSide * 0.08) {
          far = false;
          break;
        }
      }
      if (far) return p;
    }
    return null;
  }

  void _remapItems(double sx, double sy) {
    for (var i = 0; i < fruits.length; i++) {
      final f = fruits[i];
      fruits[i] = Fruit(
        position: Offset(f.position.dx * sx, f.position.dy * sy),
        kind: f.kind,
        radius: f.radius * (sx + sy) / 2,
      )..eaten = f.eaten
        ..eatProgress = f.eatProgress
        ..appearProgress = f.appearProgress;
    }
    final mapped = <Obstacle>[];
    for (final o in obstacles) {
      mapped.add(
        Obstacle(
          position: Offset(o.position.dx * sx, o.position.dy * sy),
          kind: o.kind,
          radius: o.radius * (sx + sy) / 2,
        ),
      );
    }
    obstacles
      ..clear()
      ..addAll(mapped);
    final oldTunnels = List<TunnelStamp>.from(tunnels);
    tunnels.clear();
    tunnelPath.reset();
    for (final t in oldTunnels) {
      _addTunnel(
        Offset(t.center.dx * sx, t.center.dy * sy),
        t.radius * (sx + sy) / 2,
        silent: true,
      );
    }
    diamondPos = Offset(diamondPos.dx * sx, diamondPos.dy * sy);
    diamondRadius *= (sx + sy) / 2;
  }

  void _placeDiamond() {
    diamondCollected = false;
    diamondCollect = 0;
    diamondRadius = size.shortestSide * 0.038;
    diamondPos = Offset(
      layout.peakX,
      layout.ridgeYAt(layout.peakX) - diamondRadius * 0.85,
    );
  }

  void _updateMove(double dt) {
    final target = _dragTarget;
    if (target == null) {
      if (state == FerretState.walking) state = FerretState.idle;
      return;
    }

    final to = target - ferretPos;
    final dist = to.distance;
    if (dist < 2) {
      if (state == FerretState.walking) state = FerretState.idle;
      return;
    }

    facingRight = to.dx >= 0;
    final speed = size.shortestSide * 0.55;
    final step = math.min(dist, speed * dt);
    final next = ferretPos + to / dist * step;

    if (_blocked(next)) {
      _startBump(next);
      return;
    }

    _advanceTo(next, dt);
  }

  void _advanceTo(Offset next, double dt) {
    final m = layout;
    final wasInside = m.contains(ferretPos);
    final willInside = m.contains(next);
    final traveled = (next - ferretPos).distance;

    if (state == FerretState.onPeak) {
      if (willInside) {
        state = FerretState.digging;
        ferretPos = next;
        _carve(next);
        walkPhase += traveled * 0.08;
        _tryEat();
        return;
      }
      final x = next.dx;
      final pushingOff = (ferretPos.dx <= m.ridgeLeft + 1.5 && x < ferretPos.dx) ||
          (ferretPos.dx >= m.ridgeRight - 1.5 && x > ferretPos.dx);
      if (x < m.ridgeLeft - 2 || x > m.ridgeRight + 2 || pushingOff) {
        _startRoll(x < m.peakX);
        return;
      }
      final clampedX = clampDouble(x, m.ridgeLeft, m.ridgeRight);
      ferretPos = Offset(clampedX, m.ridgeYAt(clampedX) - ferretRadius * 0.55);
      walkPhase += traveled * 0.08;
      return;
    }

    if (willInside) {
      state = FerretState.digging;
      ferretPos = next;
      _carve(next);
      walkPhase += traveled * 0.08;
      _tryEat();
      return;
    }

    if (wasInside && !willInside) {
      final dRidge = m.distanceToRidge(next);
      final dLeft = m.distanceToSlope(true, next);
      final dRight = m.distanceToSlope(false, next);
      if (dRidge < dLeft && dRidge < dRight && dRidge < ferretRadius * 3.2) {
        state = FerretState.onPeak;
        final x = clampDouble(next.dx, m.ridgeLeft, m.ridgeRight);
        ferretPos = Offset(x, m.ridgeYAt(x) - ferretRadius * 0.55);
        return;
      }
      _startRoll(next.dx < m.peakX);
      return;
    }

    final x = clampDouble(next.dx, ferretRadius, size.width - ferretRadius);
    var y = next.dy;
    if (y > standY) y = standY;
    ferretPos = Offset(x, y);
    walkPhase += traveled * 0.08;

    if (ferretPos.dy < m.baseY - 8 && !m.contains(ferretPos)) {
      _startRoll(ferretPos.dx < m.peakX);
      return;
    }

    state = traveled > 0.4 ? FerretState.walking : FerretState.idle;
  }

  bool _blocked(Offset next) {
    final reach = ferretRadius * 0.72;
    for (final o in obstacles) {
      if ((o.position - next).distance < o.radius + reach) return true;
    }
    return false;
  }

  void _carve(Offset p) {
    if (tunnels.length >= maxTunnels) return;
    final r = ferretRadius * 1.18;
    if (tunnels.isNotEmpty) {
      final last = tunnels.last;
      if ((last.center - p).distance < r * 0.32) return;
    }
    _addTunnel(p, r);
  }

  void _addTunnel(Offset p, double r, {bool silent = false}) {
    tunnels.add(TunnelStamp(p, r));
    tunnelPath.addOval(Rect.fromCircle(center: p, radius: r));
    if (silent) return;
    if (time - _lastDigSoundAt < 0.16) return;
    _lastDigSoundAt = time;
    onSound?.call(GameSoundCue.dig);
  }

  void _tryEat() {
    if (state == FerretState.eating) return;
    final reach = ferretRadius * 0.9;
    for (final f in fruits) {
      if (f.eaten) continue;
      if ((f.position - ferretPos).distance < f.radius + reach) {
        f.eaten = true;
        f.eatProgress = 0;
        state = FerretState.eating;
        eatTime = 0;
        _dragging = false;
        _dragTarget = null;
        onSound?.call(GameSoundCue.eat);
        return;
      }
    }
  }

  void _tryCollectDiamond() {
    if (diamondCollected || state == FerretState.won) return;
    final reach = ferretRadius * 0.95 + diamondRadius * 0.55;
    if ((ferretPos - diamondPos).distance > reach) return;
    diamondCollected = true;
    diamondCollect = 0;
    winTime = 0;
    state = FerretState.won;
    _dragging = false;
    _dragTarget = null;
    _burstWinStars();
    onSound?.call(GameSoundCue.success);
  }

  void _explode() {
    explodePos = ferretPos;
    explodeRadius = ferretRadius * 4.4 + size.shortestSide * 0.05;
    explodeTime = 0;
    state = FerretState.exploding;
    _dragging = false;
    _dragTarget = null;
    _pressOnFerret = false;
    _pressOrigin = null;
    _lastFerretTapAt = -99;
    obstacles.removeWhere(
      (o) => (o.position - explodePos).distance <= explodeRadius + o.radius,
    );
    final rng = _rng ?? math.Random(seed);
    stars.clear();
    for (var i = 0; i < 16; i++) {
      final a = i * (math.pi * 2 / 16) + (rng.nextDouble() - 0.5) * 0.4;
      stars.add(
        StarParticle(
          position: explodePos,
          velocity: Offset(math.cos(a), math.sin(a)) *
              (size.shortestSide * (0.2 + rng.nextDouble() * 0.28)),
          spin: (rng.nextDouble() - 0.5) * 14,
        ),
      );
    }
  }

  void _updateExploding(double dt) {
    explodeTime += dt;
    if (explodeTime < explodeDuration) return;
    ferretScale = 1;
    ferretAngle = 0;
    facingRight = true;
    walkPhase = 0;
    ferretPos = Offset(size.width * 0.5, standY);
    state = FerretState.idle;
  }

  void _burstWinStars() {
    final rng = _rng ?? math.Random(seed);
    stars.clear();
    for (var i = 0; i < 14; i++) {
      final a = -math.pi + i * (math.pi * 2 / 14) + (rng.nextDouble() - 0.5) * 0.4;
      stars.add(
        StarParticle(
          position: diamondPos,
          velocity: Offset(math.cos(a), math.sin(a)) *
              (size.shortestSide * (0.18 + rng.nextDouble() * 0.22)),
          spin: (rng.nextDouble() - 0.5) * 12,
        ),
      );
    }
  }

  void _updateEating(double dt) {
    eatTime += dt;
    for (final f in fruits) {
      if (f.eaten && f.eatProgress < 1) {
        f.eatProgress = (eatTime / 0.7).clamp(0.0, 1.0);
      }
    }
    if (eatTime >= 0.7) {
      ferretScale *= growFactor;
      fruitsEaten += 1;
      fruits.removeWhere((f) => f.eaten && f.eatProgress >= 1);
      state = FerretState.idle;
      if (layout.contains(ferretPos)) {
        state = FerretState.digging;
      }
    }
  }

  void _updateFruits(double dt) {
    for (final f in fruits) {
      if (f.eaten || f.appearProgress >= 1) continue;
      f.appearProgress = (f.appearProgress + dt / 0.45).clamp(0.0, 1.0);
    }
    if (liveFruitCount >= maxLiveFruits) {
      _fruitSpawnTimer = 0;
      return;
    }
    _fruitSpawnTimer += dt;
    if (_fruitSpawnTimer >= fruitRespawnDelay) {
      _fruitSpawnTimer = 0;
      _spawnOneFruit();
    }
  }

  void _spawnOneFruit({bool animate = true}) {
    if (mountain == null || liveFruitCount >= maxLiveFruits) return;
    final rng = _rng ?? math.Random(seed + _round);
    final p = _randomInside(rng, extraMargin: 0.12);
    if (p == null) return;
    fruits.add(
      Fruit(
        position: p,
        kind: FruitKind.values[rng.nextInt(FruitKind.values.length)],
        radius: size.shortestSide * 0.028,
      )..appearProgress = animate ? 0 : 1,
    );
  }

  void _startBump(Offset into) {
    state = FerretState.bumping;
    bumpTime = 0;
    final dir = (into - ferretPos);
    final n = dir.distance == 0 ? const Offset(0, -1) : dir / dir.distance;
    final rng = _rng ?? math.Random(seed);
    stars.clear();
    for (var i = 0; i < 7; i++) {
      final a = -math.pi * 0.9 + i * (math.pi * 1.8 / 6) + (rng.nextDouble() - 0.5) * 0.3;
      stars.add(
        StarParticle(
          position: ferretPos + n * ferretRadius * 0.2 + Offset(0, -ferretRadius * 0.85),
          velocity: Offset(math.cos(a), math.sin(a)) * (size.shortestSide * (0.22 + rng.nextDouble() * 0.12)),
          spin: (rng.nextDouble() - 0.5) * 10,
        ),
      );
    }
    onSound?.call(GameSoundCue.bump);
  }

  void _updateBumping(double dt) {
    bumpTime += dt;
    if (bumpTime >= 0.45) {
      state = layout.contains(ferretPos)
          ? FerretState.digging
          : (ferretPos.dy < layout.peakY + size.height * 0.2
              ? FerretState.onPeak
              : FerretState.idle);
    }
  }

  void _startRoll(bool left) {
    state = FerretState.rolling;
    rollLeft = left;
    rollT = layout.progressOnSlope(left, ferretPos);
    rollSpin = left ? -10.0 : 10.0;
    ferretAngle = 0;
    _dragging = false;
    _dragTarget = null;
  }

  void _updateRolling(double dt) {
    rollT += (0.55 + rollT * 1.4) * dt;
    ferretAngle += rollSpin * dt;
    if (rollT >= 1) {
      final foot = layout.pointOnSlope(rollLeft, 1);
      ferretPos = Offset(
        clampDouble(foot.dx, ferretRadius, size.width - ferretRadius),
        standY,
      );
      ferretAngle = 0;
      state = FerretState.idle;
      return;
    }
    final p = layout.pointOnSlope(rollLeft, rollT);
    ferretPos = Offset(p.dx, p.dy);
  }

  void _updateStars(double dt) {
    for (final s in stars) {
      s.life -= dt * 1.7;
      s.position += s.velocity * dt;
      s.velocity += const Offset(0, 180) * dt;
      s.spin += dt * 6;
    }
    stars.removeWhere((s) => s.life <= 0);
  }
}
