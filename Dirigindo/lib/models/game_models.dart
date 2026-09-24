import 'dart:ui';

/// Largura da faixa de chegada (lado direito).
const double kFinishStripWidth = 80;

/// Margem esquerda onde o carro aparece.
const double kSpawnMargin = 56;

/// Duração da animação de explosão (ms).
const int kExplosionMs = 900;

/// Tempo exibindo medalha antes de novo carro (ms).
const int kVictoryHoldMs = 1400;

enum CarType { monsterTruck, stockCar, fusca, truck }

enum ObstacleType { rock, house, tree, bush, hole }

enum CarState { idle, following, exploding, celebrating }

/// Cores disponíveis para pintar o carro ao spawnar.
const List<Color> kCarColors = [
  Color(0xFFE53935), // vermelho
  Color(0xFF1E88E5), // azul
  Color(0xFFFDD835), // amarelo
  Color(0xFF43A047), // verde
  Color(0xFFEC407A), // rosa
  Color(0xFFAB47BC), // roxo
  Color(0xFFFB8C00), // laranja
];

class Car {
  Car({
    required this.type,
    required this.position,
    required this.size,
    required this.heading,
    required this.color,
  });

  final CarType type;
  Offset position;
  final double size;
  double heading;
  final Color color;
  CarState state = CarState.idle;
  double speed = 0;
  final List<Offset> path = [];
  int pathIndex = 0;
  int? linkedPointer;
  bool showMedal = false;

  double get radius => size * 0.42;
}

class Obstacle {
  Obstacle({
    required this.type,
    required this.position,
    required this.size,
  });

  final ObstacleType type;
  final Offset position;
  final double size;

  double get radius => size * 0.5;
}

class Explosion {
  Explosion({
    required this.position,
    required this.startedAt,
    required this.maxRadius,
  });

  final Offset position;
  final DateTime startedAt;
  final double maxRadius;

  double progress(DateTime now) =>
      (now.difference(startedAt).inMilliseconds / kExplosionMs).clamp(0.0, 1.0);

  bool isDone(DateTime now) =>
      now.difference(startedAt).inMilliseconds >= kExplosionMs;
}

class StrokePoint {
  StrokePoint(this.position, this.color, this.createdAt, this.speed);

  final Offset position;
  final Color color;
  final DateTime createdAt;
  final double speed;
}

class Stroke {
  final List<StrokePoint> points = [];

  void add(StrokePoint p) => points.add(p);

  bool get isEmpty => points.isEmpty;
}
