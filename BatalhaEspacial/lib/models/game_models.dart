enum GamePhase {
  waiting,
  cruising,
  combat,
  firingLaser,
  enemyDestroyed,
  playerScared,
  enemyCharging,
  playerExploding,
  playerDestroyed,
}

enum EnemyKind {
  fighter,
  cruiser,
  drone,
  mothership,
  interceptor,
  saucer,
}

class EnemyModel {
  EnemyModel({
    required this.kind,
    required this.strength,
    required this.spawnedAt,
  });

  final EnemyKind kind;
  final int strength;
  final double spawnedAt;
  double approach = 0;
}

const double combatDurationSeconds = 5;
const double enemyDestroyedPauseSeconds = 1.2;
const double minCruiseSeconds = 1.8;
const double maxCruiseSeconds = 3.5;
const int minEnemyStrength = 2;
const int maxEnemyStrength = 10;
const double laserDurationSeconds = 0.38;
const double scaredFaceDurationSeconds = 0.85;
const double enemyChargeBaseSeconds = 1.35;
const double playerExplosionDurationSeconds = 1.0;
const double combatMaxApproach = 0.82;
const double collisionApproach = 1.0;
