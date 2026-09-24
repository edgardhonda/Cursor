import 'dart:ui';

enum MartianSize { small, medium, large }

enum MartianPhase { idle, attacking, dead }

enum CarPhase { racing, exploding, burning, ashes, finished }

enum LaserPhase { flying, gone }

extension MartianSizeX on MartianSize {
  double get radius => switch (this) {
        MartianSize.small => 56,
        MartianSize.medium => 88,
        MartianSize.large => 128,
      };

  int get maxHits => switch (this) {
        MartianSize.small => 1,
        MartianSize.medium => 2,
        MartianSize.large => 3,
      };

  double get speed => switch (this) {
        MartianSize.small => 22,
        MartianSize.medium => 17,
        MartianSize.large => 13,
      };
}

class TrackPath {
  TrackPath({required this.points});

  final List<Offset> points;
  late final List<double> _cumLen;
  late final double length;

  factory TrackPath.fromPoints(List<Offset> points) {
    final track = TrackPath(points: List<Offset>.from(points));
    track._buildLengths();
    return track;
  }

  void _buildLengths() {
    _cumLen = List<double>.filled(points.length, 0);
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
      _cumLen[i] = total;
    }
    length = total;
  }

  /// Progress 0..1 along the track.
  Offset positionAt(double t) {
    if (points.isEmpty) return Offset.zero;
    if (points.length == 1 || length <= 0) return points.first;
    final target = (t.clamp(0.0, 1.0)) * length;
    var i = 1;
    while (i < _cumLen.length && _cumLen[i] < target) {
      i++;
    }
    if (i >= points.length) return points.last;
    final prev = _cumLen[i - 1];
    final seg = _cumLen[i] - prev;
    final local = seg <= 0 ? 0.0 : (target - prev) / seg;
    return Offset.lerp(points[i - 1], points[i], local)!;
  }

  Offset tangentAt(double t) {
    final a = positionAt((t - 0.002).clamp(0.0, 1.0));
    final b = positionAt((t + 0.002).clamp(0.0, 1.0));
    final d = b - a;
    if (d.distance < 0.001) return const Offset(1, 0);
    return d / d.distance;
  }

  Offset get start => points.first;
  Offset get finish => points.last;
}

class CarModel {
  CarModel({required this.color});

  Color color;
  double progress = 0;
  CarPhase phase = CarPhase.racing;
  double phaseStartedAt = 0;
  double invulnerableUntil = 0;
  Offset position = Offset.zero;
  Offset direction = const Offset(1, 0);
}

class MartianModel {
  MartianModel({
    required this.id,
    required this.position,
    required this.size,
    required this.color,
    this.nextChirpAt = 0,
  }) : hitsLeft = size.maxHits;

  final int id;
  Offset position;
  final MartianSize size;
  final Color color;
  int hitsLeft;
  MartianPhase phase = MartianPhase.idle;
  double phaseStartedAt = 0;
  /// Próximo bip cartoon ("pi pó…").
  double nextChirpAt;

  double get radius => size.radius;
}

class LaserBeam {
  LaserBeam({
    required this.id,
    required this.position,
    required this.direction,
    required this.targetId,
  });

  final int id;
  Offset position;
  Offset direction;
  final int targetId;
  LaserPhase phase = LaserPhase.flying;
}

class AshPileModel {
  AshPileModel({required this.position, required this.createdAt});

  final Offset position;
  final double createdAt;
}

/// Nível de velocidade do risco na tela (lento → rápido).
enum ScratchSpeedLevel { blue, green, yellow, orange, red }

extension ScratchSpeedLevelX on ScratchSpeedLevel {
  Color get color => switch (this) {
        ScratchSpeedLevel.blue => const Color(0xFF2196F3),
        ScratchSpeedLevel.green => const Color(0xFF4CAF50),
        ScratchSpeedLevel.yellow => const Color(0xFFFFEB3B),
        ScratchSpeedLevel.orange => const Color(0xFFFF9800),
        ScratchSpeedLevel.red => const Color(0xFFF44336),
      };

  double get strokeWidth => switch (this) {
        ScratchSpeedLevel.blue => 4.5,
        ScratchSpeedLevel.green => 5.5,
        ScratchSpeedLevel.yellow => 6.5,
        ScratchSpeedLevel.orange => 7.5,
        ScratchSpeedLevel.red => 9.0,
      };

  static ScratchSpeedLevel fromSpeed(double pixelsPerSecond) {
    if (pixelsPerSecond < 350) return ScratchSpeedLevel.blue;
    if (pixelsPerSecond < 750) return ScratchSpeedLevel.green;
    if (pixelsPerSecond < 1300) return ScratchSpeedLevel.yellow;
    if (pixelsPerSecond < 2100) return ScratchSpeedLevel.orange;
    return ScratchSpeedLevel.red;
  }
}

class ScratchSegment {
  ScratchSegment({
    required this.from,
    required this.to,
    required this.level,
    required this.createdAt,
  });

  final Offset from;
  final Offset to;
  final ScratchSpeedLevel level;
  final double createdAt;

  Color get color => level.color;
  double get strokeWidth => level.strokeWidth;
}

const List<Color> buggyColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
  Color(0xFFFDD835),
  Color(0xFF6D4C41),
];

const List<Color> martianColors = [
  Color(0xFF8BCF2E),
  Color(0xFF9AD83A),
  Color(0xFF7AC41F),
  Color(0xFFA8E046),
  Color(0xFF6FB81A),
  Color(0xFFB4EC5A),
];

const Color laserColor = Color(0xFFFFEB3B);
const double carSpeed = 0.055; // progress units per second
const double laserSpeed = 420;
/// Distância em que o marciano entra em modo de ataque (sprint).
const double martianAggroRange = 200;
/// Alcance da curva de aceleração em direção ao buggy.
const double martianChaseRange = 560;
const double carHitRadius = 22;
/// Tempo até o risco sumir da tela.
const double scratchFadeSeconds = 1.15;
/// Movimento mínimo para considerar risco (em vez de toque).
const double scratchDragThreshold = 10;
/// Intervalo mínimo entre bips de marcianos (evita sobrepor vários).
const double martianChirpGap = 0.85;
