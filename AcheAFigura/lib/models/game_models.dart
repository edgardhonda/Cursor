import 'dart:ui';

import 'package:flutter/material.dart';

class EmojiTile {
  EmojiTile({
    required this.id,
    required this.emoji,
    required this.bounds,
    required this.rotation,
    required this.color,
  });

  final int id;
  final String emoji;
  Rect bounds;
  final double rotation;
  final Color color;
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

/// Paleta variada com 12 cores; o índice sobe com a velocidade do risco.
const List<Color> strokeSpeedColors = [
  Color(0xFF1565C0), // azul
  Color(0xFF00838F), // teal
  Color(0xFF2E7D32), // verde
  Color(0xFF7CB342), // verde-claro
  Color(0xFFC0CA33), // lima
  Color(0xFFF9A825), // amarelo
  Color(0xFFFF8F00), // âmbar
  Color(0xFFEF6C00), // laranja
  Color(0xFFE65100), // laranja-escuro
  Color(0xFFD84315), // vermelho-alaranjado
  Color(0xFFC62828), // vermelho
  Color(0xFFAD1457), // magenta
];

/// Velocidade máxima de referência (dobro da escala anterior).
const double strokeTopSpeedPxPerSec = 1440;

/// Velocidade do risco (px/s) → cor entre [strokeSpeedColors].
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
