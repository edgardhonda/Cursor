import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.engine);

  final GameEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    for (final hole in engine.holes) {
      _paintHole(canvas, hole);
    }
    for (final hole in engine.holes) {
      if (hole.clawPhase != ClawPhase.idle) {
        _paintClaw(canvas, hole);
      }
    }
    for (final plane in engine.planes) {
      if (plane.phase != PlanePhase.gone) {
        _paintPlane(canvas, plane);
      }
    }
    _paintHud(canvas, size);
  }

  void _paintSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF81D4FA), Color(0xFF4FC3F7), Color(0xFF29B6F6)],
        ).createShader(rect),
    );
    // Nuvens leves.
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height * 0.15),
        width: size.width * 0.28,
        height: 36,
      ),
      cloud,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.7, size.height * 0.22),
        width: size.width * 0.34,
        height: 42,
      ),
      cloud,
    );
    // Solo.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.78, size.width, size.height * 0.22),
      Paint()..color = const Color(0xFF66BB6A),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.86, size.width, size.height * 0.14),
      Paint()..color = const Color(0xFF8D6E63),
    );
  }

  void _paintHole(Canvas canvas, HoleModel hole) {
    final r = hole.radius;
    // Sombra / borda do buraco.
    canvas.drawOval(
      Rect.fromCenter(
        center: hole.center + const Offset(0, 3),
        width: r * 2.2,
        height: r * 1.15,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawOval(
      Rect.fromCenter(center: hole.center, width: r * 2.1, height: r * 1.05),
      Paint()..color = const Color(0xFF3E2723),
    );
    canvas.drawOval(
      Rect.fromCenter(center: hole.center, width: r * 1.7, height: r * 0.8),
      Paint()..color = Colors.black,
    );
    // Anel colorido da garra/buraco.
    canvas.drawOval(
      Rect.fromCenter(center: hole.center, width: r * 2.15, height: r * 1.1),
      Paint()
        ..color = hole.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    // Garra em repouso (pequena).
    if (hole.clawPhase == ClawPhase.idle) {
      final tip = hole.center + Offset(0, -r * 0.35);
      _drawClawHead(canvas, tip, hole.color, r * 0.55, open: true);
    }
  }

  void _paintClaw(Canvas canvas, HoleModel hole) {
    final tip = engine.clawTipFor(hole);
    final cable = Paint()
      ..color = hole.color.withValues(alpha: 0.9)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hole.center, tip, cable);
    canvas.drawLine(
      hole.center,
      tip,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    final open = hole.clawPhase == ClawPhase.extending ||
        (hole.clawPhase == ClawPhase.grabbing && hole.caughtPlaneId == null);
    _drawClawHead(canvas, tip, hole.color, hole.radius * 0.7, open: open);
  }

  void _drawClawHead(
    Canvas canvas,
    Offset tip,
    Color color,
    double s, {
    required bool open,
  }) {
    final base = Paint()..color = color;
    canvas.drawCircle(tip, s * 0.35, base);
    canvas.drawCircle(
      tip,
      s * 0.35,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final spread = open ? 0.75 : 0.28;
    final left = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        tip.dx - s * 0.7,
        tip.dy - s * spread,
        tip.dx - s * 0.15,
        tip.dy - s * 1.15,
      );
    final right = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        tip.dx + s * 0.7,
        tip.dy - s * spread,
        tip.dx + s * 0.15,
        tip.dy - s * 1.15,
      );
    final clawPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(3.0, s * 0.28)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(left, clawPaint);
    canvas.drawPath(right, clawPaint);
  }

  void _paintPlane(Canvas canvas, PlaneModel plane) {
    final p = plane.position;
    final s = plane.size;
    final facingRight = plane.velocity.dx >= 0 ||
        plane.phase == PlanePhase.caught ||
        plane.phase == PlanePhase.falling;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    if (!facingRight && plane.phase == PlanePhase.flying) {
      canvas.scale(-1, 1);
    }
    if (plane.phase == PlanePhase.falling) {
      canvas.rotate(0.4 + (engine.now - plane.phaseStartedAt) * 4);
    }

    final body = Paint()..color = plane.color;
    final wingColor = Color.lerp(plane.color, Colors.white, 0.22)!;
    final wingDark = Color.lerp(plane.color, Colors.black, 0.12)!;
    final wingFill = Paint()..color = wingColor;
    final wingEdge = Paint()..color = wingDark;
    final outline = Paint()
      ..color = Colors.black.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.1, s * 0.05)
      ..strokeJoin = StrokeJoin.round;

    // Vista de cima: fuselagem no eixo X, asas largas no eixo Y.
    final mainWings = Path()
      ..moveTo(-s * 0.28, -s * 1.18)
      ..lineTo(s * 0.62, -s * 1.28)
      ..lineTo(s * 0.72, -s * 0.24)
      ..lineTo(s * 0.72, s * 0.24)
      ..lineTo(s * 0.62, s * 1.28)
      ..lineTo(-s * 0.28, s * 1.18)
      ..lineTo(-s * 0.42, s * 0.22)
      ..lineTo(-s * 0.42, -s * 0.22)
      ..close();
    canvas.drawPath(mainWings, wingFill);
    canvas.drawPath(mainWings, outline);

    // Estabilizadores horizontais (cauda).
    for (final side in [-1.0, 1.0]) {
      final tail = Path()
        ..moveTo(-s * 0.78, side * s * 0.12)
        ..lineTo(-s * 1.02, side * s * 0.68)
        ..lineTo(-s * 0.88, side * s * 0.72)
        ..lineTo(-s * 0.62, side * s * 0.18)
        ..close();
      canvas.drawPath(tail, wingEdge);
      canvas.drawPath(tail, outline);
    }

    // Estabilizador vertical (visto de cima: triângulo na cauda).
    final fin = Path()
      ..moveTo(-s * 0.92, 0)
      ..lineTo(-s * 1.12, -s * 0.34)
      ..lineTo(-s * 0.68, 0)
      ..close();
    canvas.drawPath(fin, wingEdge);
    canvas.drawPath(fin, outline);

    // Fuselagem estreita sobre as asas.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(s * 0.06, 0), width: s * 1.95, height: s * 0.36),
        Radius.circular(s * 0.18),
      ),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(s * 0.06, 0), width: s * 1.95, height: s * 0.36),
        Radius.circular(s * 0.18),
      ),
      outline,
    );

    // Nariz e cockpit.
    canvas.drawCircle(Offset(s * 0.98, 0), s * 0.09, Paint()..color = wingDark);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.48, 0), width: s * 0.3, height: s * 0.2),
      Paint()..color = const Color(0xFFBBDEFB),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.48, 0), width: s * 0.3, height: s * 0.2),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.9, s * 0.04),
    );

    canvas.restore();
  }

  void _paintHud(Canvas canvas, Size size) {
    final tablet = size.shortestSide >= 600;
    final tp = TextPainter(
      text: TextSpan(
        text: 'Pontos ${engine.score}',
        style: TextStyle(
          color: Colors.white,
          fontSize: tablet ? 22 : 18,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(blurRadius: 4, color: Colors.black54),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(16, tablet ? 18 : 12));

    if (engine.combo > 1) {
      final combo = TextPainter(
        text: TextSpan(
          text: 'Combo x${engine.combo}',
          style: TextStyle(
            color: const Color(0xFFFFF176),
            fontSize: tablet ? 18 : 15,
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      combo.paint(canvas, Offset(16, tablet ? 46 : 36));
    }

    final hint = TextPainter(
      text: const TextSpan(
        text: 'Toque no buraco da mesma cor do avião',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13,
          shadows: [Shadow(blurRadius: 3, color: Colors.black45)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 32);
    hint.paint(canvas, Offset(16, size.height * 0.72));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
