import 'dart:ui';

enum PlanePhase { flying, caught, falling, gone }

enum ClawPhase { idle, extending, grabbing, retracting }

class GameColor {
  const GameColor({required this.id, required this.color, required this.label});

  final int id;
  final Color color;
  final String label;
}

const List<GameColor> gameColors = [
  GameColor(id: 0, color: Color(0xFFE53935), label: 'Vermelho'),
  GameColor(id: 1, color: Color(0xFF1E88E5), label: 'Azul'),
  GameColor(id: 2, color: Color(0xFF43A047), label: 'Verde'),
  GameColor(id: 3, color: Color(0xFFFDD835), label: 'Amarelo'),
  GameColor(id: 4, color: Color(0xFFFF9800), label: 'Laranja'),
  GameColor(id: 5, color: Color(0xFF8E24AA), label: 'Roxo'),
  GameColor(id: 6, color: Color(0xFF00ACC1), label: 'Ciano'),
  GameColor(id: 7, color: Color(0xFFEC407A), label: 'Rosa'),
];

class PlaneModel {
  PlaneModel({
    required this.id,
    required this.colorId,
    required this.position,
    required this.velocity,
    required this.size,
  });

  final int id;
  final int colorId;
  Offset position;
  Offset velocity;
  final double size;
  PlanePhase phase = PlanePhase.flying;
  double phaseStartedAt = 0;
  int? caughtByHole;

  Color get color => gameColors[colorId].color;
}

class HoleModel {
  HoleModel({
    required this.index,
    required this.colorId,
    required this.center,
    required this.radius,
  });

  final int index;
  final int colorId;
  Offset center;
  final double radius;
  ClawPhase clawPhase = ClawPhase.idle;
  double clawProgress = 0; // 0 = no buraco, 1 = altura máxima / alvo
  double clawStartedAt = 0;
  Offset? clawTarget;
  int? caughtPlaneId;

  Color get color => gameColors[colorId].color;
}

/// Alcance horizontal (em múltiplos do raio do buraco) para agarrar.
const double clawGrabRangeFactor = 2.8;
const double clawExtendSeconds = 0.28;
const double clawGrabHoldSeconds = 0.12;
const double clawRetractSeconds = 0.36;
const double planeFallSeconds = 0.55;
const int maxPlanesOnScreen = 10;
const double planeSpawnInterval = 1.1;
