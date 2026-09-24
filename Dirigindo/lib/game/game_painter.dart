import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  GamePainter({required this.engine}) : super(repaint: engine.repaintTick);

  final GameEngine engine;

  static final Paint _outline = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    _drawFinishStrip(canvas, size);
    for (final o in engine.obstacles) {
      _drawObstacle(canvas, o);
    }
    _drawStrokes(canvas);
    for (final finished in engine.finishedCars) {
      _drawCar(canvas, finished);
      _drawMedal(canvas, finished.position, finished.size);
    }
    final c = engine.car;
    if (c != null && c.state != CarState.exploding) {
      _drawCar(canvas, c);
      if (c.showMedal) _drawMedal(canvas, c.position, c.size);
    }
    for (final e in engine.explosions) {
      _drawExplosion(canvas, e);
    }
  }

  // ----------------------------------------------------------- finish strip

  void _drawFinishStrip(Canvas canvas, Size size) {
    final left = size.width - kFinishStripWidth;
    const rows = 8;
    const cols = 4;
    final cellW = kFinishStripWidth / cols;
    final cellH = size.height / rows;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final dark = (r + c).isEven;
        canvas.drawRect(
          Rect.fromLTWH(left + c * cellW, r * cellH, cellW, cellH),
          Paint()..color = dark ? const Color(0xFF212121) : const Color(0xFFFAFAFA),
        );
      }
    }
    canvas.drawLine(
      Offset(left, 0),
      Offset(left, size.height),
      Paint()
        ..color = Colors.black
        ..strokeWidth = 3,
    );
    final flag = TextPainter(
      text: const TextSpan(
        text: '🏁',
        style: TextStyle(fontSize: 28),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    flag.paint(canvas, Offset(left + 8, 8));
  }

  // --------------------------------------------------------------- strokes

  void _drawStrokes(Canvas canvas) {
    final w = engine.strokeWidth;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in engine.strokes) {
      final pts = s.points;
      for (var i = 1; i < pts.length; i++) {
        paint.color = pts[i].color;
        canvas.drawLine(pts[i - 1].position, pts[i].position, paint);
      }
    }
  }

  // ------------------------------------------------------------------ car

  void _drawCar(Canvas canvas, Car c) {
    canvas.save();
    canvas.translate(c.position.dx, c.position.dy);
    canvas.rotate(c.heading);
    switch (c.type) {
      case CarType.monsterTruck:
        _drawMonsterTruck(canvas, c.size, c.color);
      case CarType.stockCar:
        _drawStockCar(canvas, c.size, c.color);
      case CarType.fusca:
        _drawFusca(canvas, c.size, c.color);
      case CarType.truck:
        _drawTruck(canvas, c.size, c.color);
    }
    canvas.restore();
  }

  void _drawMonsterTruck(Canvas canvas, double s, Color color) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 1.1, height: s * 0.55),
      const Radius.circular(4),
    );
    canvas.drawRRect(body, _fill(color));
    canvas.drawRRect(body, _outline);
    _wheel(canvas, Offset(-s * 0.38, s * 0.32), s * 0.22);
    _wheel(canvas, Offset(s * 0.38, s * 0.32), s * 0.22);
    _wheel(canvas, Offset(-s * 0.38, -s * 0.32), s * 0.22);
    _wheel(canvas, Offset(s * 0.38, -s * 0.32), s * 0.22);
    canvas.drawLine(Offset(-s * 0.2, -s * 0.1), Offset(s * 0.35, -s * 0.1), _outline);
  }

  void _drawStockCar(Canvas canvas, double s, Color color) {
    final body = Rect.fromCenter(center: Offset.zero, width: s * 1.05, height: s * 0.5);
    canvas.drawOval(body, _fill(color));
    canvas.drawOval(body, _outline);
    canvas.drawLine(Offset(-s * 0.15, -s * 0.08), Offset(s * 0.2, -s * 0.08), _outline);
    _wheel(canvas, Offset(-s * 0.32, s * 0.28), s * 0.14);
    _wheel(canvas, Offset(s * 0.32, s * 0.28), s * 0.14);
    canvas.drawRect(
      Rect.fromLTWH(s * 0.42, -s * 0.06, s * 0.08, s * 0.12),
      _outline,
    );
  }

  void _drawFusca(Canvas canvas, double s, Color color) {
    final path = Path()
      ..moveTo(-s * 0.5, s * 0.05)
      ..quadraticBezierTo(-s * 0.45, -s * 0.35, 0, -s * 0.38)
      ..quadraticBezierTo(s * 0.45, -s * 0.35, s * 0.5, s * 0.05)
      ..lineTo(s * 0.45, s * 0.22)
      ..lineTo(-s * 0.45, s * 0.22)
      ..close();
    canvas.drawPath(path, _fill(color));
    canvas.drawPath(path, _outline);
    _wheel(canvas, Offset(-s * 0.28, s * 0.28), s * 0.13);
    _wheel(canvas, Offset(s * 0.28, s * 0.28), s * 0.13);
  }

  void _drawTruck(Canvas canvas, double s, Color color) {
    final cargo = Rect.fromCenter(
      center: Offset(-s * 0.12, 0),
      width: s * 0.75,
      height: s * 0.48,
    );
    final cab = Rect.fromCenter(
      center: Offset(s * 0.38, s * 0.04),
      width: s * 0.35,
      height: s * 0.38,
    );
    canvas.drawRect(cargo, _fill(color));
    canvas.drawRect(cargo, _outline);
    canvas.drawRect(cab, _fill(color));
    canvas.drawRect(cab, _outline);
    _wheel(canvas, Offset(-s * 0.28, s * 0.3), s * 0.13);
    _wheel(canvas, Offset(s * 0.1, s * 0.3), s * 0.13);
    _wheel(canvas, Offset(s * 0.38, s * 0.3), s * 0.13);
  }

  void _wheel(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, _outline);
    canvas.drawCircle(c, r * 0.35, _outline);
  }

  // ----------------------------------------------------------- obstacles

  void _drawObstacle(Canvas canvas, Obstacle o) {
    switch (o.type) {
      case ObstacleType.rock:
        _drawRock(canvas, o);
      case ObstacleType.house:
        _drawHouse(canvas, o);
      case ObstacleType.tree:
        _drawTree(canvas, o);
      case ObstacleType.bush:
        _drawBush(canvas, o);
      case ObstacleType.hole:
        _drawHole(canvas, o);
    }
  }

  void _drawRock(Canvas canvas, Obstacle o) {
    final s = o.size;
    final p = Path()
      ..moveTo(o.position.dx - s * 0.4, o.position.dy + s * 0.2)
      ..lineTo(o.position.dx - s * 0.2, o.position.dy - s * 0.35)
      ..lineTo(o.position.dx + s * 0.25, o.position.dy - s * 0.3)
      ..lineTo(o.position.dx + s * 0.42, o.position.dy + s * 0.15)
      ..close();
    canvas.drawPath(p, _outline);
  }

  void _drawHouse(Canvas canvas, Obstacle o) {
    final s = o.size;
    final cx = o.position.dx;
    final cy = o.position.dy;
    canvas.drawRect(
      Rect.fromCenter(center: o.position, width: s, height: s * 0.7),
      _outline,
    );
    final roof = Path()
      ..moveTo(cx - s * 0.55, cy - s * 0.35)
      ..lineTo(cx, cy - s * 0.75)
      ..lineTo(cx + s * 0.55, cy - s * 0.35);
    canvas.drawPath(roof, _outline);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, cy + s * 0.12),
        width: s * 0.22,
        height: s * 0.28,
      ),
      _outline,
    );
  }

  void _drawTree(Canvas canvas, Obstacle o) {
    final s = o.size;
    final cx = o.position.dx;
    final cy = o.position.dy;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + s * 0.22), width: s * 0.15, height: s * 0.35),
      _outline,
    );
    canvas.drawCircle(Offset(cx, cy - s * 0.08), s * 0.38, _outline);
  }

  void _drawBush(Canvas canvas, Obstacle o) {
    final s = o.size;
    final cx = o.position.dx;
    final cy = o.position.dy;
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(Offset(cx + i * s * 0.28, cy), s * 0.32, _outline);
    }
  }

  void _drawHole(Canvas canvas, Obstacle o) {
    final s = o.size;
    canvas.drawOval(
      Rect.fromCenter(center: o.position, width: s * 1.1, height: s * 0.65),
      _outline,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: o.position + Offset(0, s * 0.06),
        width: s * 0.75,
        height: s * 0.4,
      ),
      Paint()
        ..color = const Color(0xFF424242)
        ..style = PaintingStyle.fill,
    );
  }

  // ------------------------------------------------------------- explosion

  void _drawExplosion(Canvas canvas, Explosion e) {
    final p = e.progress(DateTime.now());
    final intensity = sin(p * pi).clamp(0.0, 1.0);
    if (intensity <= 0) return;
    final scale = e.maxRadius * (0.5 + 0.6 * p);
    final base = e.position;

    void tongue(double ox, double sy, Color col) {
      final path = Path()
        ..moveTo(base.dx + ox - sy * 0.4, base.dy)
        ..quadraticBezierTo(
            base.dx + ox - sy * 0.4, base.dy - sy, base.dx + ox, base.dy - sy * 1.3)
        ..quadraticBezierTo(
            base.dx + ox + sy * 0.4, base.dy - sy, base.dx + ox + sy * 0.4, base.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = col.withAlpha((220 * intensity).round()),
      );
    }

    tongue(0, scale, const Color(0xFFE53935));
    tongue(-scale * 0.35, scale * 0.65, const Color(0xFFFB8C00));
    tongue(scale * 0.35, scale * 0.65, const Color(0xFFFDD835));
  }

  // ----------------------------------------------------------------- medal

  void _drawMedal(Canvas canvas, Offset pos, double carS) {
    final cx = pos.dx;
    final cy = pos.dy - carS * 0.75;
    canvas.drawCircle(
      Offset(cx, cy),
      carS * 0.22,
      Paint()..color = const Color(0xFFFFD700),
    );
    canvas.drawCircle(Offset(cx, cy), carS * 0.22, _outline);
    final ribbon = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx - 8, cy + carS * 0.18), Offset(cx - 14, cy + carS * 0.42), ribbon);
    canvas.drawLine(Offset(cx + 8, cy + carS * 0.18), Offset(cx + 14, cy + carS * 0.42), ribbon);
    final star = TextPainter(
      text: const TextSpan(text: '★', style: TextStyle(fontSize: 14, color: Colors.black)),
      textDirection: TextDirection.ltr,
    )..layout();
    star.paint(canvas, Offset(cx - 7, cy - 9));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => false;
}
