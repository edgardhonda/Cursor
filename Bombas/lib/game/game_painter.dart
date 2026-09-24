import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.engine) : super(repaint: engine);

  final GameEngine engine;

  Paint _stroke(Color color, [double width = 3]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    for (final ash in engine.ashes) {
      _drawAshes(canvas, ash.position);
    }
    for (final tree in engine.trees) {
      _drawTree(canvas, tree);
    }
    for (final house in engine.houses) {
      _drawHouse(canvas, house);
    }
    for (final group in engine.workers) {
      _drawWorkerGroup(canvas, group);
    }
    for (final bomb in engine.bombs) {
      _drawBomb(canvas, bomb);
    }
    _drawStrokes(canvas);
  }

  void _drawStrokes(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final now = DateTime.now();

    void drawPoints(List<StrokePoint> points) {
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1];
        final b = points[i];
        final ageSec = now.difference(b.createdAt).inMilliseconds / 1000.0;
        final opacity = (1 - ageSec / strokeFadeSeconds).clamp(0.0, 1.0);
        if (opacity <= 0) continue;
        paint
          ..color = b.color.withValues(alpha: opacity)
          ..strokeWidth = b.width;
        canvas.drawLine(a.position, b.position, paint);
      }
    }

    for (final stroke in engine.activeStrokes.values) {
      drawPoints(stroke.points);
    }
    drawPoints(engine.finishedStrokes);
  }

  void _drawTree(Canvas canvas, TreeModel tree) {
    final color = tree.phase == WorldObjectPhase.charred
        ? const Color(0xff343434)
        : const Color(0xff148a38);
    final p = _stroke(color, 3.2);
    final x = tree.position.dx;
    final y = tree.position.dy;
    canvas.drawLine(Offset(x - 7, y + 30), Offset(x - 5, y - 2), p);
    canvas.drawLine(Offset(x + 7, y + 30), Offset(x + 5, y - 2), p);
    canvas.drawLine(Offset(x - 7, y + 30), Offset(x + 7, y + 30), p);
    final crown = Path()
      ..moveTo(x - 5, y + 2)
      ..cubicTo(x - 40, y + 1, x - 37, y - 27, x - 18, y - 28)
      ..cubicTo(x - 12, y - 48, x + 18, y - 48, x + 21, y - 26)
      ..cubicTo(x + 43, y - 20, x + 36, y + 7, x + 5, y + 3);
    canvas.drawPath(crown, p);
    canvas.drawLine(Offset(x, y - 2), Offset(x - 16, y - 17), p);
    canvas.drawLine(Offset(x, y - 4), Offset(x + 17, y - 19), p);
    if (tree.phase == WorldObjectPhase.burning) {
      _drawFire(canvas, Offset(x, y - 3));
    }
  }

  void _drawHouse(Canvas canvas, HouseModel house) {
    final color = house.phase == WorldObjectPhase.charred
        ? const Color(0xff343434)
        : house.color;
    final p = _stroke(color, 3.4);
    final x = house.position.dx;
    final y = house.position.dy;
    final body = Rect.fromCenter(
      center: Offset(x, y + 4),
      width: 62,
      height: 48,
    );
    canvas.drawRect(body, p);
    final roof = Path()
      ..moveTo(x - 38, y - 20)
      ..lineTo(x, y - 52)
      ..lineTo(x + 38, y - 20);
    canvas.drawPath(roof, p);
    canvas.drawRect(Rect.fromLTWH(x - 9, y + 5, 18, 23), p);
    canvas.drawRect(Rect.fromLTWH(x + 14, y - 9, 11, 12), p);
    if (house.phase == WorldObjectPhase.burning) {
      _drawFire(canvas, Offset(x, y - 5));
    }
  }

  void _drawAshes(Canvas canvas, Offset center) {
    final p = _stroke(const Color(0xff555555), 3);
    final path = Path()
      ..moveTo(center.dx - 34, center.dy + 23)
      ..quadraticBezierTo(
        center.dx - 19,
        center.dy + 5,
        center.dx - 5,
        center.dy + 19,
      )
      ..quadraticBezierTo(
        center.dx + 8,
        center.dy - 1,
        center.dx + 18,
        center.dy + 18,
      )
      ..quadraticBezierTo(
        center.dx + 28,
        center.dy + 9,
        center.dx + 36,
        center.dy + 24,
      )
      ..close();
    canvas.drawPath(path, p);
    canvas.drawArc(
      Rect.fromCenter(
        center: center + const Offset(-5, 20),
        width: 54,
        height: 8,
      ),
      0,
      pi,
      false,
      p,
    );
  }

  void _drawWorkerGroup(Canvas canvas, WorkerGroupModel group) {
    if (group.phase == WorkerPhase.done) return;
    var center = group.position;
    var opacity = 1.0;
    if (group.phase == WorkerPhase.entering) {
      final t = ((engine.now - group.phaseStartedAt) / 1.2).clamp(0.0, 1.0);
      final from = group.enteringFrom ?? center;
      final to = group.enteringTo ?? center;
      center = Offset.lerp(from, to, t)!;
      opacity = 1 - t;
    }
    final stride = sin(engine.now * 9 + group.id) * 3;
    for (var i = 0; i < 3; i++) {
      _drawStickMan(
        canvas,
        center + Offset((i - 1) * 18.0, (i.isOdd ? -5 : 4)),
        stride * (i.isEven ? 1 : -1),
        group.phase == WorkerPhase.working,
        opacity,
      );
    }
  }

  void _drawStickMan(
    Canvas canvas,
    Offset center,
    double stride,
    bool working,
    double opacity,
  ) {
    final color = const Color(0xff7b28a8).withValues(alpha: opacity);
    final p = _stroke(color, 2.3);
    final bob = working ? sin(engine.now * 12) * 3 : 0.0;
    final c = center + Offset(0, bob);
    canvas.drawCircle(c + const Offset(0, -21), 5, p);
    canvas.drawLine(c + const Offset(0, -16), c + const Offset(0, 2), p);
    canvas.drawLine(c + const Offset(0, 2), c + Offset(-7 + stride, 15), p);
    canvas.drawLine(c + const Offset(0, 2), c + Offset(7 - stride, 15), p);

    // Braços elevados: a picareta fica sempre acima das mãos.
    final swing = working ? sin(engine.now * 12) * 7 : 0.0;
    final leftHand = c + Offset(-9, -12 + swing * 0.35);
    final rightHand = c + Offset(8, -14 + swing);
    canvas.drawLine(c + const Offset(0, -11), leftHand, p);
    canvas.drawLine(c + const Offset(0, -11), rightHand, p);
    _drawPickaxe(canvas, rightHand, p, swing);
  }

  /// Picareta com cabo para cima e lâmina pontuda (não um arco tipo garfo).
  void _drawPickaxe(Canvas canvas, Offset hand, Paint paint, double swing) {
    final tip = hand + Offset(2.5 - swing * 0.15, -17 - swing.abs() * 0.2);
    canvas.drawLine(hand, tip, paint);

    // Lâmina em forma de "V" invertido / foice de picareta.
    final leftPoint = tip + const Offset(-9, 4);
    final rightPoint = tip + const Offset(9, 4);
    final blade = Path()
      ..moveTo(leftPoint.dx, leftPoint.dy)
      ..lineTo(tip.dx, tip.dy - 3)
      ..lineTo(rightPoint.dx, rightPoint.dy);
    canvas.drawPath(blade, paint);

    // Ponta inferior da lâmina (perfil clássico de picareta).
    canvas.drawLine(
      tip + const Offset(-1, -1),
      tip + const Offset(0, 5),
      paint,
    );
  }

  void _drawBomb(Canvas canvas, BombModel bomb) {
    if (bomb.phase == BombPhase.spent) return;
    if (bomb.phase == BombPhase.hole) {
      final p = _stroke(const Color(0xff442e25), 4);
      canvas.drawOval(
        Rect.fromCenter(center: bomb.position, width: 50, height: 22),
        p,
      );
      canvas.drawArc(
        Rect.fromCenter(center: bomb.position, width: 34, height: 12),
        0,
        pi,
        false,
        p,
      );
      return;
    }
    if (bomb.phase == BombPhase.exploding) {
      _drawExplosion(canvas, bomb);
      return;
    }

    final x = bomb.position.dx;
    final y = bomb.position.dy;
    final p = _stroke(const Color(0xffe32636), 3.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y + 3), width: 25, height: 31),
        const Radius.circular(6),
      ),
      p,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y - 12), width: 25, height: 8),
      p,
    );
    final fuse = Path()
      ..moveTo(x, y - 17)
      ..quadraticBezierTo(x + 2, y - 27, x + 11, y - 28);
    final fuseProgress = bomb.phase == BombPhase.fuse
        ? ((engine.now - bomb.phaseStartedAt) / 3).clamp(0.0, 1.0)
        : 0.0;
    canvas.drawPath(fuse, _stroke(const Color(0xff333333), 3));
    if (bomb.phase == BombPhase.fuse) {
      final spark = Offset(
        x + 11 * (1 - fuseProgress),
        y - 28 + 11 * fuseProgress,
      );
      final sparkPaint = _stroke(const Color(0xffff8c00), 2);
      for (var i = 0; i < 6; i++) {
        final angle = i * pi / 3 + engine.now * 7;
        canvas.drawLine(
          spark,
          spark + Offset(cos(angle), sin(angle)) * 7,
          sparkPaint,
        );
      }
    }
  }

  void _drawExplosion(Canvas canvas, BombModel bomb) {
    final t = ((engine.now - bomb.phaseStartedAt) / 0.75).clamp(0.0, 1.0);
    final radius = 18 + sin(t * pi) * 48;
    final colors = [
      const Color(0xffffc107),
      const Color(0xffff5722),
      const Color(0xffe32636),
    ];
    for (var ring = 0; ring < colors.length; ring++) {
      final p = _stroke(colors[ring], 4 - ring * .6);
      final path = Path();
      for (var i = 0; i < 16; i++) {
        final angle = i * pi / 8;
        final r = radius * (i.isEven ? 1 : 0.48) - ring * 7;
        final point = bomb.position + Offset(cos(angle), sin(angle)) * r;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, p);
    }
  }

  void _drawFire(Canvas canvas, Offset center) {
    final flicker = sin(engine.now * 14) * 4;
    final outer = Path()
      ..moveTo(center.dx - 20, center.dy + 28)
      ..cubicTo(
        center.dx - 33,
        center.dy + 4,
        center.dx - 8,
        center.dy - 4 + flicker,
        center.dx - 7,
        center.dy - 27,
      )
      ..cubicTo(
        center.dx + 4,
        center.dy - 15,
        center.dx + 4,
        center.dy - 7,
        center.dx + 13,
        center.dy - 16 - flicker,
      )
      ..cubicTo(
        center.dx + 33,
        center.dy + 4,
        center.dx + 27,
        center.dy + 22,
        center.dx + 17,
        center.dy + 28,
      )
      ..close();
    canvas.drawPath(outer, _stroke(const Color(0xffff5722), 4));
    final inner = Path()
      ..moveTo(center.dx - 7, center.dy + 25)
      ..quadraticBezierTo(
        center.dx - 10,
        center.dy + 6,
        center.dx + 2,
        center.dy - 5 + flicker,
      )
      ..quadraticBezierTo(
        center.dx + 15,
        center.dy + 11,
        center.dx + 8,
        center.dy + 25,
      );
    canvas.drawPath(inner, _stroke(const Color(0xffffc107), 3));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => false;
}
