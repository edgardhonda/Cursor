import 'dart:math' as math;

import '../models/game_models.dart';

class BattleEvent {
  const BattleEvent(this.sound);
  final GameSoundCue sound;
}

class BattleEngine {
  BattleEngine({this.budget = 15, this.gridCols = 4, this.gridRows = 4});

  static const int maxSpeed = 7;
  static const double dogSpeedPx = 92;

  final int budget;
  final int gridCols;
  final int gridRows;

  BattlePhase phase = BattlePhase.setup;
  GameSpeed speed = GameSpeed.medium;
  final List<BattleUnit> units = [];
  final List<Projectile> projectiles = [];
  int _nextId = 1;
  double fieldW = 800;
  double fieldH = 480;
  double cell = 28;
  double leftOriginX = 24;
  double leftOriginY = 280;
  double rightOriginX = 700;
  double rightOriginY = 40;

  int spent(Team team) => units
      .where((u) => u.team == team)
      .fold(0, (sum, u) => sum + u.type.cost);

  int remaining(Team team) => budget - spent(team);

  bool get canFight =>
      units.any((u) => u.team == Team.left) &&
      units.any((u) => u.team == Team.right);

  void layoutField(double width, double height) {
    fieldW = width;
    fieldH = height;
    cell = math.min(width, height) / 18;
    final pad = cell * 0.4;
    final rail = 96.0;
    leftOriginX = rail + pad;
    leftOriginY = height - pad - gridRows * cell;
    rightOriginX = width - rail - pad - gridCols * cell;
    rightOriginY = pad;
  }

  double bodyPx(BattleUnit unit) => unit.type.size * cell * 0.5;

  double _ownStartX(Team team) =>
      team == Team.left ? leftOriginX : rightOriginX + gridCols * cell;

  double _oppositeX(Team team) =>
      team == Team.left ? rightOriginX + gridCols * cell : leftOriginX;

  double fieldDiagonal() => math.sqrt(fieldW * fieldW + fieldH * fieldH);

  /// 1× at spawn, 2× at midfield, full battlefield on the opposite side.
  double visionMultiplier(BattleUnit unit) {
    final startX = _ownStartX(unit.team);
    final midX = fieldW / 2;
    final endX = _oppositeX(unit.team);
    final full = _fullVisionMultiplier(unit);
    if (unit.team == Team.left) {
      if (unit.x <= midX) {
        final span = (midX - startX).abs();
        if (span < 1) return 1;
        final t = ((unit.x - startX) / span).clamp(0.0, 1.0);
        return 1 + t;
      }
      final span = (endX - midX).abs();
      if (span < 1) return full;
      final t = ((unit.x - midX) / span).clamp(0.0, 1.0);
      return 2 + t * (full - 2);
    }
    if (unit.x >= midX) {
      final span = (startX - midX).abs();
      if (span < 1) return 1;
      final t = ((startX - unit.x) / span).clamp(0.0, 1.0);
      return 1 + t;
    }
    final span = (midX - endX).abs();
    if (span < 1) return full;
    final t = ((midX - unit.x) / span).clamp(0.0, 1.0);
    return 2 + t * (full - 2);
  }

  double _fullVisionMultiplier(BattleUnit unit) {
    final base = unit.type.vision * bodyPx(unit);
    if (base < 1) return 8;
    return math.max(2.0, fieldDiagonal() / base);
  }

  double visionPx(BattleUnit unit) =>
      unit.type.vision * bodyPx(unit) * visionMultiplier(unit);

  double attackPx(BattleUnit unit) {
    if (!unit.type.isRanged || unit.type.attackRadius <= 0) {
      return bodyPx(unit) * 0.85;
    }
    return unit.type.attackRadius * bodyPx(unit);
  }

  double contactPx(BattleUnit a, BattleUnit b) =>
      (bodyPx(a) + bodyPx(b)) * 0.8;

  bool inStrikeRange(BattleUnit attacker, BattleUnit target) {
    final dist = _dist(attacker, target);
    if (attacker.type.isRanged) {
      return dist <= attackPx(attacker);
    }
    return dist <= contactPx(attacker, target);
  }

  (int, int)? nextFreeSlot(Team team, int size) {
    final occupied = <String>{};
    for (final u in units.where((u) => u.team == team)) {
      final w = _widthCells(u.type.size);
      final h = _heightCells(u.type.size);
      for (var c = u.col; c < u.col + w; c++) {
        for (var r = u.row; r < u.row + h; r++) {
          occupied.add('$c,$r');
        }
      }
    }
    final w = _widthCells(size);
    final h = _heightCells(size);
    for (var r = 0; r <= gridRows - h; r++) {
      for (var c = 0; c <= gridCols - w; c++) {
        var free = true;
        for (var dc = 0; dc < w && free; dc++) {
          for (var dr = 0; dr < h && free; dr++) {
            if (occupied.contains('${c + dc},${r + dr}')) free = false;
          }
        }
        if (free) return (c, r);
      }
    }
    return null;
  }

  int _widthCells(int size) => size >= 2 ? 2 : 1;

  int _heightCells(int size) => size >= 4 ? 2 : 1;

  bool tryPlace(Team team, UnitKind kind) {
    if (phase != BattlePhase.setup) return false;
    final type = unitCatalog[kind]!;
    if (remaining(team) < type.cost) return false;
    final slot = nextFreeSlot(team, type.size);
    if (slot == null) return false;
    final (col, row) = slot;
    final pos = _cellCenter(team, col, row, type.size);
    units.add(
      BattleUnit(
        id: _nextId++,
        type: type,
        team: team,
        x: pos.$1,
        y: pos.$2,
        col: col,
        row: row,
      ),
    );
    return true;
  }

  bool removeAt(double x, double y) {
    if (phase != BattlePhase.setup) return false;
    BattleUnit? hit;
    var best = double.infinity;
    for (final u in units) {
      final d = math.sqrt(math.pow(u.x - x, 2) + math.pow(u.y - y, 2));
      if (d < bodyPx(u) * 1.35 && d < best) {
        best = d;
        hit = u;
      }
    }
    if (hit == null) return false;
    units.remove(hit);
    return true;
  }

  (double, double) _cellCenter(Team team, int col, int row, int size) {
    final w = _widthCells(size);
    final h = _heightCells(size);
    if (team == Team.left) {
      return (
        leftOriginX + (col + w / 2) * cell,
        leftOriginY + (row + h / 2) * cell,
      );
    }
    return (
      rightOriginX + (gridCols - col - w / 2) * cell,
      rightOriginY + (row + h / 2) * cell,
    );
  }

  void restart() {
    units.clear();
    projectiles.clear();
    phase = BattlePhase.setup;
    _nextId = 1;
  }

  void pulseAnims(double dt) {
    for (final u in units) {
      u.animTime += dt;
    }
  }

  bool startFight() {
    if (!canFight || phase != BattlePhase.setup) return false;
    phase = BattlePhase.fighting;
    for (final u in units) {
      u.anim = UnitAnim.walk;
      u.cooldown = 0;
      u.targetId = null;
    }
    return true;
  }

  List<BattleEvent> tick(double dt) {
    final events = <BattleEvent>[];
    if (phase != BattlePhase.fighting) return events;

    pulseAnims(dt);
    for (final u in units.where((u) => u.alive)) {
      u.cooldown = math.max(0, u.cooldown - dt);
    }
    _retargetAll();
    final snapshot = {for (final u in units) u.id: (u.x, u.y)};
    for (final u in units.where((u) => u.alive)) {
      final target = _byId(u.targetId);
      _move(u, target, dt, targetPos: target == null ? null : snapshot[target.id]);
      if (u.anim == UnitAnim.attack && u.animTime > 0.28) {
        u.anim = UnitAnim.walk;
      }
    }

    final meleeHits = <BattleUnit, int>{};
    for (final u in units.where((u) => u.alive)) {
      final target = _byId(u.targetId);
      if (target == null || !target.alive) {
        if (u.anim != UnitAnim.attack) u.anim = UnitAnim.walk;
        continue;
      }
      if (inStrikeRange(u, target) && u.cooldown <= 0) {
        events.addAll(_declareAttack(u, target, meleeHits));
      } else if (u.anim != UnitAnim.attack) {
        u.anim = UnitAnim.walk;
      }
    }
    _resolveHits(meleeHits);

    _tickProjectiles(dt);
    if (_checkWinner()) {
      events.add(const BattleEvent(GameSoundCue.vitoria));
    }
    return events;
  }

  void _retargetAll() {
    final left = _aliveOn(Team.left);
    final right = _aliveOn(Team.right);
    for (final u in units) {
      u.targetId = null;
    }
    final n = math.min(left.length, right.length);
    for (var i = 0; i < n; i++) {
      if (_canSee(left[i], right[i]) || _canSee(right[i], left[i])) {
        left[i].targetId = right[i].id;
        right[i].targetId = left[i].id;
      }
    }
    if (left.length > n) {
      for (var i = n; i < left.length; i++) {
        left[i].targetId = _nearestVisible(left[i], right)?.id;
      }
    } else if (right.length > n) {
      for (var i = n; i < right.length; i++) {
        right[i].targetId = _nearestVisible(right[i], left)?.id;
      }
    }
  }

  bool _canSee(BattleUnit from, BattleUnit to) =>
      _dist(from, to) <= visionPx(from);

  List<BattleUnit> _aliveOn(Team team) {
    final list = units.where((u) => u.team == team && u.alive).toList();
    list.sort((a, b) {
      final byKind = a.type.kind.index.compareTo(b.type.kind.index);
      if (byKind != 0) return byKind;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  BattleUnit? _nearestVisible(BattleUnit u, List<BattleUnit> enemies) {
    BattleUnit? best;
    var bestD = visionPx(u);
    for (final other in enemies) {
      final d = _dist(u, other);
      if (d <= bestD) {
        bestD = d;
        best = other;
      }
    }
    return best;
  }

  void _move(
    BattleUnit u,
    BattleUnit? target,
    double dt, {
    (double, double)? targetPos,
  }) {
    var dx = u.team == Team.left ? 1.0 : -1.0;
    var dy = 0.0;
    if (target != null && target.alive) {
      dx = (targetPos?.$1 ?? target.x) - u.x;
      dy = (targetPos?.$2 ?? target.y) - u.y;
    }
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.5) return;
    if (target != null && _dist(u, target) <= contactPx(u, target)) {
      return;
    }
    final speed = (u.type.speed / maxSpeed) * dogSpeedPx;
    u.x += (dx / len) * speed * dt;
    u.y += (dy / len) * speed * dt;
    u.x = u.x.clamp(bodyPx(u), fieldW - bodyPx(u));
    u.y = u.y.clamp(bodyPx(u), fieldH - bodyPx(u));
  }

  List<BattleEvent> _declareAttack(
    BattleUnit attacker,
    BattleUnit target,
    Map<BattleUnit, int> meleeHits,
  ) {
    attacker.cooldown = attacker.type.attackCooldown;
    attacker.anim = UnitAnim.attack;
    attacker.animTime = 0;
    if (attacker.type.isRanged) {
      final dx = target.x - attacker.x;
      final dy = target.y - attacker.y;
      final len = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final muzzle = bodyPx(attacker) * 0.9;
      projectiles.add(
        Projectile(
          x: attacker.x + dx / len * muzzle,
          y: attacker.y + dy / len * muzzle,
          tx: target.x,
          ty: target.y,
          damage: attacker.type.attack,
          targetId: target.id,
          fromCannon: attacker.type.kind == UnitKind.canhao,
          angle: math.atan2(dy, dx),
        ),
      );
    } else {
      meleeHits[target] = (meleeHits[target] ?? 0) + attacker.type.attack;
    }
    return [BattleEvent(_soundFor(attacker.type.kind))];
  }

  void _tickProjectiles(double dt) {
    final hits = <BattleUnit, int>{};
    for (final p in projectiles) {
      p.age += dt;
      final target = _byId(p.targetId);
      if (target != null && target.alive) {
        p.tx = target.x;
        p.ty = target.y;
      }
      final remainX = p.tx - p.x;
      final remainY = p.ty - p.y;
      final d = math.sqrt(remainX * remainX + remainY * remainY);
      final speed = p.fromCannon ? 380.0 : 560.0;
      final step = speed * dt;
      final hitRadius = target != null ? math.max(16.0, bodyPx(target) * 0.45) : 16.0;
      if (d <= step || d <= hitRadius || p.age > 8) {
        if (target != null) {
          hits[target] = (hits[target] ?? 0) + p.damage;
        }
        p.spent = true;
        continue;
      }
      p.x += remainX / d * step;
      p.y += remainY / d * step;
      p.angle = math.atan2(remainY, remainX);
    }
    projectiles.removeWhere((p) => p.spent);
    _resolveHits(hits);
  }

  void _resolveHits(Map<BattleUnit, int> hits) {
    for (final entry in hits.entries) {
      final target = entry.key;
      if (target.hp <= 0) continue;
      target.hp -= entry.value;
      if (target.hp <= 0) {
        target.hp = 0;
        target.anim = UnitAnim.dead;
        target.targetId = null;
      }
    }
  }

  bool _checkWinner() {
    final leftAlive = units.any((u) => u.team == Team.left && u.alive);
    final rightAlive = units.any((u) => u.team == Team.right && u.alive);
    if (!leftAlive && rightAlive) {
      phase = BattlePhase.rightWins;
      _startCelebrate(Team.right);
      return true;
    }
    if (leftAlive && !rightAlive) {
      phase = BattlePhase.leftWins;
      _startCelebrate(Team.left);
      return true;
    }
    if (!leftAlive && !rightAlive) {
      phase = BattlePhase.draw;
    }
    return false;
  }

  void _startCelebrate(Team team) {
    var i = 0;
    for (final u in units) {
      if (u.team != team || !u.alive) continue;
      u.anim = UnitAnim.celebrate;
      u.animTime = -i * 0.12;
      i++;
    }
  }

  BattleUnit? _byId(int? id) {
    if (id == null) return null;
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }

  double _dist(BattleUnit a, BattleUnit b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  GameSoundCue _soundFor(UnitKind kind) {
    switch (kind) {
      case UnitKind.cachorro:
        return GameSoundCue.cachorro;
      case UnitKind.soldado:
        return GameSoundCue.soldado;
      case UnitKind.cavaleiro:
        return GameSoundCue.cavaleiro;
      case UnitKind.gigante:
        return GameSoundCue.gigante;
      case UnitKind.arqueiro:
        return GameSoundCue.arqueiro;
      case UnitKind.canhao:
        return GameSoundCue.canhao;
    }
  }
}
