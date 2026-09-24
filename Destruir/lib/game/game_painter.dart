import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../models/game_models.dart';

class GamePainter extends CustomPainter {
  GamePainter({required this.engine}) : super(repaint: engine.repaintTick);

  final GameEngine engine;

  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  static final Paint _creaturePaint = Paint()
    ..color = const Color(0xFF000000)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  static final Paint _dotPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static final Paint _explosionPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final nowMs = engine.paintTimeMs;
    _paintStrokes(canvas, nowMs);
    for (final c in engine.creatures) {
      _paintCreature(canvas, c, nowMs);
    }
    for (final e in engine.explosions) {
      _paintExplosion(canvas, e, nowMs);
    }
  }

  void _paintStrokes(Canvas canvas, int nowMs) {
    _paintPointList(canvas, engine.finishedPoints, nowMs);
    for (final stroke in engine.activeStrokes.values) {
      _paintPointList(canvas, stroke.points, nowMs);
    }
  }

  void _paintPointList(Canvas canvas, List<StrokePoint> points, int nowMs) {
    if (points.isEmpty) return;

    if (points.length < 2) {
      for (final p in points) {
        final opacity = _strokeOpacity(p.createdAt.millisecondsSinceEpoch, nowMs);
        if (opacity <= 0) continue;
        _dotPaint.color = p.color.withValues(alpha: opacity);
        canvas.drawCircle(p.position, p.width / 2, _dotPaint);
      }
      return;
    }

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (b.createdAt.difference(a.createdAt).inMilliseconds > 400) continue;

      final opacity = _strokeOpacity(b.createdAt.millisecondsSinceEpoch, nowMs);
      if (opacity <= 0) continue;

      _strokePaint
        ..color = b.color.withValues(alpha: opacity)
        ..strokeWidth = b.width;
      canvas.drawLine(a.position, b.position, _strokePaint);
    }
  }

  double _strokeOpacity(int createdMs, int nowMs) {
    return (1 - (nowMs - createdMs) / strokeFadeMs).clamp(0.0, 1.0);
  }

  Paint _childPaint(Creature c) {
    _creaturePaint.strokeWidth = 2.6 + (c.id % 3) * 0.4;
    return _creaturePaint;
  }

  double _phase(Creature c, int nowMs) {
    return nowMs / 1000.0 * c.speed * 0.11 + c.wobblePhase;
  }

  double _legAngle(Creature c, int index, int nowMs, {double spread = 0.55}) {
    return pi / 2 + sin(_phase(c, nowMs) + index * pi) * spread;
  }

  double _armAngle(Creature c, int index, int nowMs, {double spread = 0.7}) {
    return pi / 2 + sin(_phase(c, nowMs) + index * pi + pi / 4) * spread;
  }

  double _wingAngle(Creature c, int nowMs, {bool left = true}) {
    final flap = sin(_phase(c, nowMs) * 1.6);
    return (left ? -1 : 1) * (0.35 + flap * 0.45);
  }

  void _paintCreature(Canvas canvas, Creature c, int nowMs) {
    final paint = _childPaint(c);
    final bob = sin(_phase(c, nowMs) * 0.8) * 1.2;

    canvas.save();
    canvas.translate(c.position.dx, c.position.dy + bob);
    canvas.rotate(c.heading);

    switch (c.kind) {
      case CreatureKind.ant:
        _drawAnt(canvas, paint, c, nowMs);
      case CreatureKind.cockroach:
        _drawCockroach(canvas, paint, c, nowMs);
      case CreatureKind.trex:
        _drawTrex(canvas, paint, c, nowMs);
      case CreatureKind.bat:
        _drawBat(canvas, paint, c, nowMs);
      case CreatureKind.robot:
        _drawRobot(canvas, paint, c, nowMs);
    }
    canvas.restore();
  }

  void _drawAnt(Canvas canvas, Paint paint, Creature c, int nowMs) {
    final s = c.size;
    final seed = c.id.toDouble();
    final phase = _phase(c, nowMs);

    const segments = [
      Offset(-0.12, 0.0),
      Offset(0.08, 0.0),
      Offset(0.30, 0.0),
    ];
    const radii = [0.16, 0.18, 0.14];

    // Pernas atrás do corpo — lado esquerdo (y negativo).
    for (var i = 0; i < 3; i++) {
      final center = Offset(segments[i].dx * s, segments[i].dy * s);
      final hip = center + Offset(0, -radii[i] * s);
      final swing = sin(phase + i * pi) * 0.5;
      _drawLimb(canvas, paint, hip, s * 0.24, -pi / 2 + swing);
    }

    _wobblyCircle(canvas, paint, Offset(-s * 0.12, 0), s * 0.16, seed);
    _wobblyCircle(canvas, paint, Offset(s * 0.08, 0), s * 0.18, seed + 1);
    _wobblyCircle(canvas, paint, Offset(s * 0.3, 0), s * 0.14, seed + 2);

    // Pernas à frente do corpo — lado direito (y positivo), fase oposta.
    for (var i = 0; i < 3; i++) {
      final center = Offset(segments[i].dx * s, segments[i].dy * s);
      final hip = center + Offset(0, radii[i] * s);
      final swing = sin(phase + i * pi + pi) * 0.5;
      _drawLimb(canvas, paint, hip, s * 0.24, pi / 2 + swing);
    }

    _wobblyLine(canvas, paint, Offset(s * 0.38, -s * 0.04), Offset(s * 0.52, -s * 0.18),
        wobble: s * 0.03, seed: seed);
    _wobblyLine(canvas, paint, Offset(s * 0.38, s * 0.04), Offset(s * 0.52, s * 0.18),
        wobble: s * 0.03, seed: seed + 0.5);
  }

  void _drawCockroach(Canvas canvas, Paint paint, Creature c, int nowMs) {
    final s = c.size;
    final seed = c.id.toDouble();
    final phase = _phase(c, nowMs);

    const legX = [-0.20, 0.0, 0.20];
    const sideY = 0.20;

    // Pernas esquerda (atrás do corpo).
    for (var i = 0; i < 3; i++) {
      final hip = Offset(legX[i] * s, -sideY * s);
      final swing = sin(phase + i * pi) * 0.5;
      _drawLimb(canvas, paint, hip, s * 0.26, -pi / 2 + swing);
    }

    _wobblyOval(canvas, paint, Offset.zero, s * 0.72, s * 0.42, seed);

    // Cabeça separada do resto do corpo.
    _wobblyLine(canvas, paint, Offset(s * 0.24, -s * 0.16), Offset(s * 0.24, s * 0.16),
        wobble: s * 0.02, seed: seed + 2);

    // Linha central marcando as duas asas.
    _wobblyLine(canvas, paint, Offset(-s * 0.32, 0), Offset(s * 0.20, 0),
        wobble: s * 0.02, seed: seed + 3);

    // Pernas direita (à frente do corpo), fase oposta.
    for (var i = 0; i < 3; i++) {
      final hip = Offset(legX[i] * s, sideY * s);
      final swing = sin(phase + i * pi + pi) * 0.5;
      _drawLimb(canvas, paint, hip, s * 0.26, pi / 2 + swing);
    }

    _wobblyLine(canvas, paint, Offset(s * 0.28, -s * 0.10), Offset(s * 0.44, -s * 0.32),
        wobble: s * 0.05, seed: seed);
    _wobblyLine(canvas, paint, Offset(s * 0.28, s * 0.10), Offset(s * 0.44, s * 0.32),
        wobble: s * 0.05, seed: seed + 1);
  }

  void _drawTrex(Canvas canvas, Paint paint, Creature c, int nowMs) {
    final s = c.size;
    final seed = c.id.toDouble();
    final phase = _phase(c, nowMs);
    final jawOpen = s * (0.07 + sin(phase * 0.5) * 0.03);
    final tailWag = sin(phase * 0.65) * s * 0.04;

    // Rabo — forma destacada (contorno fechado), com leve balanço.
    _wobblyPath(canvas, paint, [
      Offset(-s * 0.06, s * 0.10),
      Offset(-s * 0.26, s * 0.05 + tailWag * 0.4),
      Offset(-s * 0.46, -s * 0.02 + tailWag),
      Offset(-s * 0.66, -s * 0.10 + tailWag * 0.6),
      Offset(-s * 0.72, s * 0.02 + tailWag * 0.3),
      Offset(-s * 0.50, s * 0.14 + tailWag * 0.5),
      Offset(-s * 0.24, s * 0.22 + tailWag * 0.2),
      Offset(-s * 0.06, s * 0.18),
    ], seed + 20, close: true);

    _drawLimb(canvas, paint, Offset(-s * 0.14, s * 0.22), s * 0.32,
        _legAngle(c, 0, nowMs, spread: 0.45) + 0.2);
    _drawLimb(canvas, paint, Offset(s * 0.04, s * 0.24), s * 0.34,
        _legAngle(c, 1, nowMs, spread: 0.45) - 0.1);

    // Corpo separado da cabeça.
    _wobblyOval(canvas, paint, Offset(-s * 0.04, s * 0.14), s * 0.36, s * 0.28, seed);

    _drawLimb(canvas, paint, Offset(s * 0.08, s * 0.02), s * 0.15,
        _armAngle(c, 0, nowMs, spread: 0.9) - 0.85);
    _drawLimb(canvas, paint, Offset(s * 0.16, s * 0.04), s * 0.13,
        _armAngle(c, 1, nowMs, spread: 0.9) - 0.55);

    // Pescoço — liga corpo e cabeça.
    _wobblyLine(canvas, paint, Offset(s * 0.10, s * 0.04), Offset(s * 0.20, -s * 0.02),
        wobble: s * 0.03, seed: seed + 6);
    _wobblyLine(canvas, paint, Offset(s * 0.10, s * 0.10), Offset(s * 0.18, s * 0.06),
        wobble: s * 0.03, seed: seed + 7);

    // Cabeça grande e destacada.
    _wobblyOval(canvas, paint, Offset(s * 0.36, -s * 0.05), s * 0.44, s * 0.38, seed + 1);

    _wobblyCircle(canvas, paint, Offset(s * 0.28, -s * 0.14), s * 0.055, seed + 2);

    // Boca aberta — mandíbula superior e inferior.
    _wobblyLine(canvas, paint, Offset(s * 0.22, s * 0.02), Offset(s * 0.58, -s * 0.06),
        wobble: s * 0.025, seed: seed + 3);
    _wobblyLine(canvas, paint, Offset(s * 0.22, s * 0.10), Offset(s * 0.54, s * 0.16 + jawOpen),
        wobble: s * 0.025, seed: seed + 4);
    _wobblyLine(canvas, paint, Offset(s * 0.22, s * 0.02), Offset(s * 0.22, s * 0.10),
        wobble: s * 0.02, seed: seed + 5);

    // Dentes simplistas.
    for (var i = 0; i < 3; i++) {
      final tx = s * (0.34 + i * 0.08);
      _wobblyLine(canvas, paint, Offset(tx, s * 0.02), Offset(tx + s * 0.02, s * 0.07),
          wobble: s * 0.01, seed: seed + 8 + i);
    }
  }

  void _drawBat(Canvas canvas, Paint paint, Creature c, int nowMs) {
    final s = c.size;
    final seed = c.id.toDouble();

    _wobblyCircle(canvas, paint, Offset.zero, s * 0.13, seed);
    _wobblyCircle(canvas, paint, Offset(-s * 0.05, -s * 0.02), s * 0.025, seed + 1);
    _wobblyCircle(canvas, paint, Offset(s * 0.05, -s * 0.02), s * 0.025, seed + 2);

    _drawWing(canvas, paint, c, nowMs, left: true, s: s, seed: seed);
    _drawWing(canvas, paint, c, nowMs, left: false, s: s, seed: seed + 10);

    _drawLimb(canvas, paint, Offset(-s * 0.04, s * 0.1), s * 0.1,
        _legAngle(c, 0, nowMs, spread: 0.25) + 0.4);
    _drawLimb(canvas, paint, Offset(s * 0.04, s * 0.1), s * 0.1,
        _legAngle(c, 1, nowMs, spread: 0.25) - 0.4);
  }

  void _drawWing(
    Canvas canvas,
    Paint paint,
    Creature c,
    int nowMs, {
    required bool left,
    required double s,
    required double seed,
  }) {
    final side = left ? -1.0 : 1.0;
    final angle = _wingAngle(c, nowMs, left: left);
    canvas.save();
    canvas.rotate(angle * side);
    _wobblyPath(canvas, paint, [
      Offset.zero,
      Offset(side * s * 0.22, -s * 0.38),
      Offset(side * s * 0.55, -s * 0.22),
      Offset(side * s * 0.72, s * 0.04),
      Offset(side * s * 0.4, s * 0.12),
    ], seed, close: true);
    canvas.restore();
  }

  void _drawRobot(Canvas canvas, Paint paint, Creature c, int nowMs) {
    final s = c.size;
    final seed = c.id.toDouble();

    _wobblyRect(canvas, paint, Rect.fromCenter(center: Offset.zero, width: s * 0.48, height: s * 0.52), seed);
    _wobblyRect(canvas, paint,
        Rect.fromCenter(center: Offset(0, -s * 0.36), width: s * 0.34, height: s * 0.18), seed + 1);

    _wobblyLine(canvas, paint, Offset(-s * 0.1, -s * 0.44), Offset(-s * 0.1, -s * 0.58),
        wobble: s * 0.02, seed: seed + 2);
    _wobblyLine(canvas, paint, Offset(s * 0.1, -s * 0.44), Offset(s * 0.1, -s * 0.58),
        wobble: s * 0.02, seed: seed + 3);
    _wobblyCircle(canvas, paint, Offset(-s * 0.09, -s * 0.34), s * 0.045, seed + 4);
    _wobblyCircle(canvas, paint, Offset(s * 0.09, -s * 0.34), s * 0.045, seed + 5);

    _drawLimb(canvas, paint, Offset(-s * 0.24, -s * 0.02), s * 0.22,
        _armAngle(c, 0, nowMs, spread: 0.55) - 0.3);
    _drawLimb(canvas, paint, Offset(s * 0.24, -s * 0.02), s * 0.22,
        _armAngle(c, 1, nowMs, spread: 0.55) + 0.3);
    _drawLimb(canvas, paint, Offset(-s * 0.14, s * 0.26), s * 0.24, _legAngle(c, 0, nowMs, spread: 0.35));
    _drawLimb(canvas, paint, Offset(s * 0.14, s * 0.26), s * 0.24, _legAngle(c, 1, nowMs, spread: 0.35));
  }

  void _drawLimb(Canvas canvas, Paint paint, Offset origin, double length, double angle) {
    final end = origin + Offset(cos(angle), sin(angle)) * length;
    _wobblyLine(canvas, paint, origin, end, wobble: length * 0.1, seed: length);
  }

  void _wobblyLine(
    Canvas canvas,
    Paint paint,
    Offset a,
    Offset b, {
    required double wobble,
    required double seed,
  }) {
    final mid = (a + b) / 2;
    final dir = b - a;
    final len = dir.distance;
    if (len < 0.001) return;

    final perp = Offset(-dir.dy / len, dir.dx / len);
    final ctrl = mid + perp * sin(seed * 2.1) * wobble;
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
    canvas.drawPath(path, paint);
  }

  void _wobblyCircle(Canvas canvas, Paint paint, Offset center, double radius, double seed) {
    final path = Path();
    const segments = 6;
    for (var i = 0; i <= segments; i++) {
      final angle = i * 2 * pi / segments;
      final r = radius + sin(angle * 2.5 + seed) * radius * 0.1;
      final p = center + Offset(cos(angle) * r, sin(angle) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _wobblyOval(
    Canvas canvas,
    Paint paint,
    Offset center,
    double width,
    double height,
    double seed,
  ) {
    final path = Path();
    const segments = 7;
    for (var i = 0; i <= segments; i++) {
      final angle = i * 2 * pi / segments;
      final wobble = sin(angle * 3 + seed) * width * 0.05;
      final p = center +
          Offset(
            cos(angle) * (width * 0.5 + wobble),
            sin(angle) * (height * 0.5 + wobble * 0.6),
          );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _wobblyRect(Canvas canvas, Paint paint, Rect rect, double seed) {
    _wobblyPath(canvas, paint, [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ], seed, close: true);
  }

  void _wobblyPath(
    Canvas canvas,
    Paint paint,
    List<Offset> points,
    double seed, {
    required bool close,
  }) {
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mid = (a + b) / 2;
      final wobble = sin(seed + i * 1.7) * (a - b).distance * 0.08;
      final dir = b - a;
      final len = dir.distance;
      final perp = len > 0.001 ? Offset(-dir.dy / len, dir.dx / len) : Offset.zero;
      final ctrl = mid + perp * wobble;
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
    }
    if (close) path.close();
    canvas.drawPath(path, paint);
  }

  void _paintExplosion(Canvas canvas, Explosion e, int nowMs) {
    final t = (nowMs - e.startedAt.millisecondsSinceEpoch) / Explosion.durationMs;
    if (t >= 1) return;

    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4 + t * 0.4;
      final len = 8 + t * 28;
      final end = e.position + Offset(cos(angle) * len, sin(angle) * len);
      _explosionPaint.color = Color.fromRGBO(0, 0, 0, (1 - t).clamp(0.0, 1.0));
      canvas.drawLine(e.position, end, _explosionPaint);
    }
    _explosionPaint
      ..color = Color.fromRGBO(0, 0, 0, (1 - t).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(e.position, 6 + t * 18, _explosionPaint);
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => false;
}
