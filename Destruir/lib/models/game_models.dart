import 'dart:math';
import 'dart:ui';

enum CreatureKind { ant, cockroach, trex, bat, robot }

const double creatureMinSpeed = 15.0;
const double creatureMaxSpeedMultiplier = 4.0;
const double creatureBaseSize = 56.0;
const int creatureSizeLevels = 4;

class Creature {
  Creature({
    required this.id,
    required this.kind,
    required this.position,
    required this.heading,
    required this.speed,
    required this.turnRate,
    required this.size,
    required this.wobblePhase,
  });

  final int id;
  final CreatureKind kind;
  Offset position;
  double heading;
  final double speed;
  double turnRate;
  final double size;
  final double wobblePhase;

  static final _random = Random();
  static int _nextId = 0;

  factory Creature.random(Offset position, Size bounds) {
    final kinds = CreatureKind.values;
    final kind = kinds[_random.nextInt(kinds.length)];
    final heading = _random.nextDouble() * 2 * pi;
    final speed = creatureMinSpeed +
        _random.nextDouble() * creatureMinSpeed * (creatureMaxSpeedMultiplier - 1);
    final curved = _random.nextDouble() < 0.45;
    final turnRate = curved
        ? (_random.nextBool() ? 1 : -1) * (0.06 + _random.nextDouble() * 0.10)
        : 0.0;

    final sizeLevel = _random.nextInt(creatureSizeLevels);
    final sizeMultiplier =
        1.0 + sizeLevel / (creatureSizeLevels - 1); // 1.0, 1.33, 1.67, 2.0
    final size = creatureBaseSize * sizeMultiplier;

    return Creature(
      id: _nextId++,
      kind: kind,
      position: position,
      heading: heading,
      speed: speed,
      turnRate: turnRate,
      size: size,
      wobblePhase: _random.nextDouble() * pi * 2,
    );
  }
}

class StrokePoint {
  StrokePoint({
    required this.position,
    required this.color,
    required this.width,
    required this.createdAt,
  });

  final Offset position;
  final Color color;
  final double width;
  final DateTime createdAt;
}

class ActiveStroke {
  ActiveStroke({required this.pointer, required this.points});

  final int pointer;
  final List<StrokePoint> points;
}

class Explosion {
  Explosion({
    required this.position,
    required this.startedAt,
  });

  final Offset position;
  final DateTime startedAt;

  static const durationMs = 450;
}

/// Velocidade do risco (px/s) → cor.
Color strokeColorForSpeed(double speedPxPerSec) {
  if (speedPxPerSec < 180) return const Color(0xFF1565C0);
  if (speedPxPerSec < 360) return const Color(0xFF2E7D32);
  if (speedPxPerSec < 540) return const Color(0xFFF9A825);
  if (speedPxPerSec < 720) return const Color(0xFFEF6C00);
  return const Color(0xFFC62828);
}

const double strokeFadeMs = 3000;
const double minSpawnIntervalMs = 500;
const double initialSpawnIntervalMs = 2000;
const int maxCreatures = 20;
const double tapMoveThreshold = 12;
const double doubleTapMaxMs = 350;
const double doubleTapMaxDistance = 40;
