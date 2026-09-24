import 'dart:ui';

enum FerretState { idle, walking, digging, onPeak, rolling, eating, bumping, exploding, won }

enum GameSoundCue { dig, eat, bump, success }

enum ObstacleKind { rock, poop, bone }

enum FruitKind { apple, orange, pear, berry }

class TunnelStamp {
  const TunnelStamp(this.center, this.radius);

  final Offset center;
  final double radius;
}

class Fruit {
  Fruit({
    required this.position,
    required this.kind,
    required this.radius,
  });

  final Offset position;
  final FruitKind kind;
  final double radius;
  bool eaten = false;
  double eatProgress = 0;
  double appearProgress = 1;
}

class Obstacle {
  const Obstacle({
    required this.position,
    required this.kind,
    required this.radius,
  });

  final Offset position;
  final ObstacleKind kind;
  final double radius;
}

class StarParticle {
  StarParticle({
    required this.position,
    required this.velocity,
    required this.spin,
  });

  Offset position;
  Offset velocity;
  double spin;
  double life = 1;
}
