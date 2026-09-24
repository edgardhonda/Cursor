enum Team { left, right }

enum UnitKind { cachorro, soldado, cavaleiro, gigante, arqueiro, canhao }

enum AttackType { melee, ranged }

enum UnitAnim { idle, walk, attack, dead, celebrate }

enum BattlePhase { setup, fighting, leftWins, rightWins, draw }

enum GameSoundCue { cachorro, soldado, cavaleiro, gigante, arqueiro, canhao, vitoria }

/// Current (fast) speed is 1.0. Default medium is 30% slower; slow is 50% slower.
enum GameSpeed {
  slow(0.5, 'Lenta'),
  medium(0.7, 'Média'),
  fast(1.0, 'Rápida');

  const GameSpeed(this.factor, this.label);
  final double factor;
  final String label;
}

class UnitType {
  const UnitType({
    required this.kind,
    required this.name,
    required this.cost,
    required this.size,
    required this.attack,
    required this.defense,
    required this.speed,
    required this.attackRadius,
    required this.attackFreq,
    required this.vision,
    required this.attackType,
  });

  final UnitKind kind;
  final String name;
  final int cost;
  final int size;
  final int attack;
  final int defense;
  final int speed;
  final int attackRadius;
  final int attackFreq;
  final int vision;
  final AttackType attackType;

  bool get isRanged => attackType == AttackType.ranged;

  /// Seconds between attacks: [attackFreq] hits every 2 seconds.
  double get attackCooldown => 2.0 / attackFreq;
}

/// Costs keep any 15-point army from being a hard lock.
/// Dogs swarm but die in one knight/cannon/giant hit.
/// Knights are capped at 3 so they cannot farm 15 dogs.
/// Giant DPS was halved, so cost 5 (max 3) still loses to soldiers if they connect.
/// Archer fire rate dropped, so cost 3 (max 5) remains fragile to knights.
/// Cannon fire rate dropped, so cost 7 allows two pieces but only 1 leftover.
const Map<UnitKind, UnitType> unitCatalog = {
  UnitKind.cachorro: UnitType(
    kind: UnitKind.cachorro,
    name: 'Cachorro',
    cost: 1,
    size: 1,
    attack: 1,
    defense: 5,
    speed: 7,
    attackRadius: 0,
    attackFreq: 7,
    vision: 10,
    attackType: AttackType.melee,
  ),
  UnitKind.soldado: UnitType(
    kind: UnitKind.soldado,
    name: 'Soldado',
    cost: 2,
    size: 2,
    attack: 3,
    defense: 10,
    speed: 5,
    attackRadius: 0,
    attackFreq: 5,
    vision: 10,
    attackType: AttackType.melee,
  ),
  UnitKind.cavaleiro: UnitType(
    kind: UnitKind.cavaleiro,
    name: 'Cavaleiro',
    cost: 4,
    size: 2,
    attack: 5,
    defense: 10,
    speed: 4,
    attackRadius: 0,
    attackFreq: 5,
    vision: 7,
    attackType: AttackType.melee,
  ),
  UnitKind.gigante: UnitType(
    kind: UnitKind.gigante,
    name: 'Gigante',
    cost: 5,
    size: 4,
    attack: 10,
    defense: 20,
    speed: 2,
    attackRadius: 0,
    attackFreq: 1,
    vision: 5,
    attackType: AttackType.melee,
  ),
  UnitKind.arqueiro: UnitType(
    kind: UnitKind.arqueiro,
    name: 'Arqueiro',
    cost: 3,
    size: 2,
    attack: 2,
    defense: 5,
    speed: 3,
    attackRadius: 10,
    attackFreq: 3,
    vision: 20,
    attackType: AttackType.ranged,
  ),
  UnitKind.canhao: UnitType(
    kind: UnitKind.canhao,
    name: 'Canhão',
    cost: 7,
    size: 4,
    attack: 5,
    defense: 10,
    speed: 3,
    attackRadius: 10,
    attackFreq: 1,
    vision: 20,
    attackType: AttackType.ranged,
  ),
};

const List<UnitKind> paletteOrder = [
  UnitKind.cachorro,
  UnitKind.soldado,
  UnitKind.cavaleiro,
  UnitKind.gigante,
  UnitKind.arqueiro,
  UnitKind.canhao,
];

class BattleUnit {
  BattleUnit({
    required this.id,
    required this.type,
    required this.team,
    required this.x,
    required this.y,
    required this.col,
    required this.row,
  }) : hp = type.defense;

  final int id;
  final UnitType type;
  final Team team;
  double x;
  double y;
  int col;
  int row;
  int hp;
  int? targetId;
  double cooldown = 0;
  double animTime = 0;
  UnitAnim anim = UnitAnim.idle;
  bool get alive => hp > 0;
}

class Projectile {
  Projectile({
    required this.x,
    required this.y,
    required this.tx,
    required this.ty,
    required this.damage,
    required this.targetId,
    required this.fromCannon,
    required this.angle,
  });

  double x;
  double y;
  double tx;
  double ty;
  double angle;
  final int damage;
  final int targetId;
  final bool fromCannon;
  double age = 0;
  bool spent = false;
}
