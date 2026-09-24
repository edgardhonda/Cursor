import 'dart:ui';

enum FlyPhase { buzzing, eaten, stolen, gone }

enum TonguePhase { idle, extending, retracting }

enum BadFrogPhase { hunting, fleeing, exploding, gone }

enum GoodFrogPhase { hunting, celebrating, gone }

enum BombPhase { flying, exploding, gone }

class FlyModel {
  FlyModel({
    required this.id,
    required this.position,
    required this.velocity,
  });

  final int id;
  Offset position;
  Offset velocity;
  FlyPhase phase = FlyPhase.buzzing;
  double phaseStartedAt = 0;

  static const double radius = 14;
}

class BadFrogModel {
  BadFrogModel({
    required this.id,
    required this.position,
  });

  final int id;
  Offset position;
  Offset velocity = Offset.zero;
  BadFrogPhase phase = BadFrogPhase.hunting;
  double phaseStartedAt = 0;
  int? targetFlyId;

  static const double radius = 28;
}

class GoodFrogModel {
  GoodFrogModel({
    required this.id,
    required this.position,
  });

  final int id;
  Offset position;
  Offset velocity = Offset.zero;
  GoodFrogPhase phase = GoodFrogPhase.hunting;
  double phaseStartedAt = 0;
  int? targetBadId;

  static const double radius = 30;
}

class BombModel {
  BombModel({
    required this.id,
    required this.position,
    required this.targetId,
    required this.direction,
  });

  final int id;
  Offset position;
  Offset direction;
  final int targetId;
  BombPhase phase = BombPhase.flying;
  double phaseStartedAt = 0;
}

enum PlayerPhase { idle, exploding }

class PlayerFrog {
  Offset position = Offset.zero;
  TonguePhase tonguePhase = TonguePhase.idle;
  PlayerPhase phase = PlayerPhase.idle;
  double tongueProgress = 0;
  Offset? tongueTarget;
  int? tongueFlyId;
  double tongueStartedAt = 0;
  double explodeStartedAt = 0;
  double sizeScale = 1;

  static const double baseRadius = 36;

  double get radius => baseRadius * sizeScale;
}

const double tongueExtendSeconds = 0.16;
const double tongueRetractSeconds = 0.18;
const double bombSpeed = 520;
const double badFrogSpeed = 78;
const double goodFrogSpeed = 96;
const double flySpeed = 62;
const int maxFlies = 8;
const int maxBadFrogs = 3;
const int maxGoodFrogs = 2;
const double flySpawnInterval = 0.85;
const double badSpawnInterval = 4.2;
const double goodSpawnInterval = 7.5;
const double playerGrowFactor = 1.10;
/// Após esta quantidade de moscas, o sapo fica com boca aberta (surpresa).
const int fliesToSurprise = 10;
const double playerExplodeSeconds = 0.55;
