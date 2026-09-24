import 'dart:math';
import 'dart:ui';

/// Quantos soldados ao redor do castelo bastam para destruí-lo.
const int kSoldiersToDestroy = 5;

/// Largura da faixa de spawn (toque cria soldado) na borda direita.
const double kSpawnStripWidth = 72;

/// Velocidade do soldado (px/s).
const double kSoldierSpeed = 78;

/// Velocidade da bola (px/s).
const double kBallSpeed = 360;

/// Quão rápido a bola corrige a direção rumo ao alvo (homing).
const double kBallHomingRate = 3.5;

/// Duração da animação de fogo ao destruir um soldado.
const int kSoldierFireMs = 1000;

/// Duração da fogueira ao destruir o castelo.
const int kCastleFireMs = 5000;

/// Tempo (s) para um risco desaparecer.
const double kStrokeFadeSeconds = 3.0;

/// Tamanho do rastro da bola (em quantidade de posições amostradas).
const int kBallTrailMax = 16;

/// Geometria do castelo derivada do tamanho da área de jogo.
class CastleGeometry {
  CastleGeometry(this.bounds) {
    unit = min(bounds.width * 0.17, bounds.height * 0.42).clamp(90.0, 360.0);
    center = Offset(bounds.width * 0.05 + unit * 0.85, bounds.height * 0.52);
    hitRadius = unit * 1.0;
    arriveRadius = unit * 1.2;
    orbitRadius = unit * 1.1;
  }

  final Size bounds;
  late final double unit;
  late final Offset center;
  late final double hitRadius;
  late final double arriveRadius;
  late final double orbitRadius;

  Offset get towerTop => Offset(center.dx, center.dy - unit * 0.95);
}

class Soldier {
  Soldier({
    required this.id,
    required this.position,
    required this.size,
    required this.orbitDir,
    required this.walkPhase,
  });

  final int id;
  Offset position;
  final double size;
  final int orbitDir;
  double walkPhase;
  double heading = pi;
  bool arrived = false;
  double orbitAngle = 0;

  double get radius => size * 0.45;
}

class Ball {
  Ball({
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
    this.targetId,
  });

  Offset position;
  Offset velocity;
  final Color color;
  final double radius;
  int? targetId;
  final List<Offset> trail = [];
}

class Fire {
  Fire({
    required this.position,
    required this.startedAt,
    required this.durationMs,
    required this.maxRadius,
  });

  final Offset position;
  final DateTime startedAt;
  final int durationMs;
  final double maxRadius;

  double progress(DateTime now) =>
      (now.difference(startedAt).inMilliseconds / durationMs).clamp(0.0, 1.0);

  bool isDone(DateTime now) =>
      now.difference(startedAt).inMilliseconds >= durationMs;
}

class StrokePoint {
  StrokePoint(this.position, this.color, this.createdAt);

  final Offset position;
  final Color color;
  final DateTime createdAt;
}

class Stroke {
  final List<StrokePoint> points = [];

  void add(StrokePoint p) => points.add(p);

  bool get isEmpty => points.isEmpty;
}
