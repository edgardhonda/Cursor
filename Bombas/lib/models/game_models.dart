import 'dart:ui';

enum WorldObjectPhase { normal, burning, charred, ashes }

enum WorkerPhase { walking, working, entering, done }

enum BombPhase { idle, fuse, exploding, hole, spent }

class TreeModel {
  TreeModel({required this.id, required this.position});

  final int id;
  Offset position;
  WorldObjectPhase phase = WorldObjectPhase.normal;
  double phaseStartedAt = 0;
}

class HouseModel {
  HouseModel({required this.id, required this.position, required this.color});

  final int id;
  Offset position;
  final Color color;
  WorldObjectPhase phase = WorldObjectPhase.normal;
  double phaseStartedAt = 0;
}

class AshPileModel {
  AshPileModel({required this.position, required this.createdAt});

  final Offset position;
  final double createdAt;
}

class WorkerGroupModel {
  WorkerGroupModel({
    required this.id,
    required this.position,
    required this.targetTreeId,
  });

  final int id;
  Offset position;
  int targetTreeId;
  WorkerPhase phase = WorkerPhase.walking;
  double phaseStartedAt = 0;
  Offset? enteringFrom;
  Offset? enteringTo;
}

const double workerStrokeHitRadius = 28;
const double workerStrokeAvoidRadius = 42;

class BombModel {
  BombModel({required this.id, required this.position});

  final int id;
  final Offset position;
  BombPhase phase = BombPhase.idle;
  double phaseStartedAt = 0;
  bool hitWorldObject = false;
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

/// 10 níveis de cor: lento (azul) → muito rápido (vermelho).
const List<Color> strokeSpeedColors = [
  Color(0xFF1565C0),
  Color(0xFF00838F),
  Color(0xFF2E7D32),
  Color(0xFF7CB342),
  Color(0xFFC0CA33),
  Color(0xFFF9A825),
  Color(0xFFFF8F00),
  Color(0xFFEF6C00),
  Color(0xFFD84315),
  Color(0xFFC62828),
];

const double strokeTopSpeedPxPerSec = 1440;
const double strokeFadeSeconds = 10;

Color strokeColorForSpeed(double speedPxPerSec) {
  final t = (speedPxPerSec / strokeTopSpeedPxPerSec).clamp(0.0, 1.0);
  final index = (t * (strokeSpeedColors.length - 1)).round().clamp(
    0,
    strokeSpeedColors.length - 1,
  );
  return strokeSpeedColors[index];
}

double strokeWidthForSpeed(double speedPxPerSec) {
  return 4 * (3.0 + (speedPxPerSec / 400).clamp(0.0, 4.0));
}

const double tapMoveThreshold = 12;
