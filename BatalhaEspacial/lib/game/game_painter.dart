import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.engine);

  final GameEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    final horizonY = size.height * 0.36;
    final vanish = Offset(size.width * 0.5, horizonY);
    final bottomY = size.height * 0.92;

    _paintSky(canvas, size, horizonY);
    _paintStars(canvas, size, horizonY);
    _paintTerrain(canvas, size, vanish, bottomY);
    final showPlayerShip = engine.phase != GamePhase.playerExploding;
    if (showPlayerShip) {
      _paintShip(canvas, size, bottomY);
    }
    if (engine.enemy case final enemy?) {
      if (engine.phase != GamePhase.playerExploding) {
        _paintEnemy(canvas, size, vanish, horizonY, bottomY, enemy);
      }
    }
    if (engine.phase == GamePhase.playerScared) {
      _paintScaredFace(canvas, size, bottomY, 1.0);
    }
    if (engine.phase == GamePhase.firingLaser && engine.enemy != null) {
      _paintLaser(canvas, size, bottomY, horizonY, engine.enemy!);
    }
    if (engine.phase == GamePhase.enemyDestroyed && engine.enemy != null) {
      _paintBurst(canvas, size, vanish, horizonY, bottomY, engine.enemy!);
    }
    if (engine.phase == GamePhase.playerExploding) {
      _paintPlayerExplosion(canvas, size, bottomY);
    }
  }

  double _enemyY(
    Size size,
    double horizonY,
    double bottomY,
    double approach,
  ) {
    final far = horizonY + 18;
    final playerY = bottomY - size.height * 0.11;
    return ui.lerpDouble(far, playerY, approach.clamp(0.0, 1.0))!;
  }

  void _paintSky(Canvas canvas, Size size, double horizonY) {
    final rect = Rect.fromLTWH(0, 0, size.width, horizonY + 8);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, max(horizonY, 1)),
        const [Color(0xFF020818), Color(0xFF0B1D4A), Color(0xFF1A3D7A)],
        [0.0, 0.55, 1.0],
      );
    canvas.drawRect(rect, paint);
  }

  void _paintStars(Canvas canvas, Size size, double horizonY) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final rng = Random(42);
    for (var i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * horizonY * 0.95;
      final r = rng.nextDouble() * 1.4 + 0.4;
      final twinkle = 0.55 + 0.45 * sin(engine.now * 3 + i);
      paint.color = Colors.white.withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _paintTerrain(Canvas canvas, Size size, Offset vanish, double bottomY) {
    const rows = 28;
    final scroll = engine.terrainScroll;

    for (var row = 0; row <= rows; row++) {
      final depth = (row + scroll) / rows;
      final t = pow(depth, 1.65).toDouble();
      final y = ui.lerpDouble(bottomY, vanish.dy, t)!;
      final halfWidth = ui.lerpDouble(size.width * 0.62, 1, t)!;
      final shade = (40 + t * 90).round().clamp(0, 255);
      final paint = Paint()
        ..color = Color.fromARGB(255, shade ~/ 3, shade, shade ~/ 2)
        ..strokeWidth = max(1.0, 3.5 - t * 2.5);
      canvas.drawLine(
        Offset(vanish.dx - halfWidth, y),
        Offset(vanish.dx + halfWidth, y),
        paint,
      );
    }

    for (var lane = -6; lane <= 6; lane++) {
      final xNear = vanish.dx + lane * size.width * 0.09;
      final paint = Paint()
        ..color = const Color(0xFF1F6B3A).withValues(alpha: 0.55)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(xNear, bottomY), vanish, paint);
    }

    final ground = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, vanish.dy),
        Offset(0, bottomY),
        const [Color(0xFF0D3B22), Color(0xFF145A32), Color(0xFF1E7A3F)],
        const [0.0, 0.5, 1.0],
      );
    final path = Path()
      ..moveTo(0, bottomY)
      ..lineTo(size.width, bottomY)
      ..lineTo(vanish.dx + 2, vanish.dy)
      ..lineTo(vanish.dx - 2, vanish.dy)
      ..close();
    canvas.drawPath(path, ground);
  }

  void _paintShip(Canvas canvas, Size size, double bottomY) {
    final cx = size.width * 0.5;
    final cy = bottomY - size.height * 0.11;
    final w = size.width * 0.11;
    final h = size.height * 0.09;
    final bob = sin(engine.now * 6) * 3;

    final body = Path()
      ..moveTo(cx, cy - h + bob)
      ..lineTo(cx - w * 0.55, cy + h * 0.55 + bob)
      ..lineTo(cx, cy + h * 0.2 + bob)
      ..lineTo(cx + w * 0.55, cy + h * 0.55 + bob)
      ..close();

    canvas.drawPath(body, Paint()..color = const Color(0xFF90CAF9));
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF1565C0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final flame = Paint()..color = const Color(0xFFFF7043);
    final flameH = h * (0.35 + 0.12 * (sin(engine.now * 18) * 0.5 + 0.5));
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * 0.18, cy + h * 0.45 + bob)
        ..lineTo(cx, cy + h * 0.45 + flameH + bob)
        ..lineTo(cx + w * 0.18, cy + h * 0.45 + bob)
        ..close(),
      flame,
    );
  }

  void _paintEnemy(
    Canvas canvas,
    Size size,
    Offset vanish,
    double horizonY,
    double bottomY,
    EnemyModel enemy,
  ) {
    final y = _enemyY(size, horizonY, bottomY, enemy.approach);
    final cx = size.width * 0.5;
    final scale = 0.55 + enemy.strength / 20.0;
    final w = size.width * 0.08 * scale;
    final h = size.height * 0.07 * scale;

    switch (enemy.kind) {
      case EnemyKind.fighter:
        _paintFighter(canvas, cx, y, w, h);
      case EnemyKind.cruiser:
        _paintCruiser(canvas, cx, y, w, h);
      case EnemyKind.drone:
        _paintDrone(canvas, cx, y, w, h);
      case EnemyKind.mothership:
        _paintMothership(canvas, cx, y, w, h);
      case EnemyKind.interceptor:
        _paintInterceptor(canvas, cx, y, w, h);
      case EnemyKind.saucer:
        _paintSaucer(canvas, cx, y, w, h);
    }

    _paintStrengthRays(canvas, cx, y - h - 6, enemy.strength, min(w, h) * 0.55);
  }

  void _paintStrengthRays(
    Canvas canvas,
    double cx,
    double baseY,
    int strength,
    double raySize,
  ) {
    final rows = strength > 6 ? 2 : 1;
    final perRow = (strength + rows - 1) ~/ rows;
    final rayW = raySize * 0.48;
    final rayH = raySize * 1.0;
    final gap = raySize * 0.12;
    final rowGap = raySize * 0.22;

    var remaining = strength;
    for (var row = 0; row < rows; row++) {
      final count = min(perRow, remaining);
      remaining -= count;
      final rowWidth = count * rayW + max(0, count - 1) * gap;
      final startX = cx - rowWidth / 2 + rayW / 2;
      final rowY = baseY - (rows - 1 - row) * (rayH + rowGap);

      for (var i = 0; i < count; i++) {
        final flicker = 0.75 + 0.25 * sin(engine.now * 9 + i * 0.7 + row);
        _paintStrengthRay(
          canvas,
          Offset(startX + i * (rayW + gap), rowY),
          rayW,
          rayH,
          flicker,
        );
      }
    }
  }

  void _paintStrengthRay(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    double alpha,
  ) {
    final bolt = Path()
      ..moveTo(center.dx, center.dy - h * 0.52)
      ..lineTo(center.dx + w * 0.34, center.dy - h * 0.06)
      ..lineTo(center.dx + w * 0.1, center.dy - h * 0.06)
      ..lineTo(center.dx + w * 0.4, center.dy + h * 0.52)
      ..lineTo(center.dx - w * 0.02, center.dy + h * 0.04)
      ..lineTo(center.dx + w * 0.14, center.dy - h * 0.24)
      ..lineTo(center.dx - w * 0.36, center.dy - h * 0.04)
      ..close();

    canvas.drawPath(
      bolt,
      Paint()
        ..color = const Color(0xFFFFC107).withValues(alpha: alpha * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawPath(
      bolt,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx, center.dy - h * 0.5),
          Offset(center.dx, center.dy + h * 0.5),
          [
            const Color(0xFFFFF59D).withValues(alpha: alpha),
            const Color(0xFFFFEB3B).withValues(alpha: alpha),
            const Color(0xFFFFA000).withValues(alpha: alpha),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    canvas.drawPath(
      bolt,
      Paint()
        ..color = const Color(0xFFE65100).withValues(alpha: alpha * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, w * 0.14)
        ..strokeJoin = StrokeJoin.round,
    );

    final highlight = Path()
      ..moveTo(center.dx - w * 0.04, center.dy - h * 0.38)
      ..lineTo(center.dx + w * 0.18, center.dy - h * 0.08)
      ..lineTo(center.dx + w * 0.06, center.dy - h * 0.08)
      ..lineTo(center.dx + w * 0.22, center.dy + h * 0.28);
    canvas.drawPath(
      highlight,
      Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, w * 0.1)
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintLaser(
    Canvas canvas,
    Size size,
    double bottomY,
    double horizonY,
    EnemyModel enemy,
  ) {
    final progress =
        (engine.phaseElapsed / laserDurationSeconds).clamp(0.0, 1.0);
    final cx = size.width * 0.5;
    final shipY = bottomY - size.height * 0.11 - size.height * 0.09 * 0.5;
    final enemyY =
        _enemyY(size, horizonY, bottomY, enemy.approach);
    final tipY = ui.lerpDouble(shipY, enemyY, progress)!;
    final start = Offset(cx, shipY);
    final end = Offset(cx, tipY);

    final glow = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, glow);

    final beam = Paint()
      ..shader = ui.Gradient.linear(
        start,
        end,
        [
          const Color(0xFFE1F5FE),
          const Color(0xFF00E5FF),
          const Color(0xFF18FFFF),
        ],
        [0.0, 0.55, 1.0],
      )
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, beam);

    final core = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, core);

    if (progress > 0.82) {
      final flash = (progress - 0.82) / 0.18;
      canvas.drawCircle(
        Offset(cx, enemyY),
        10 + flash * 28,
        Paint()
          ..color = const Color(0xFF80DEEA).withValues(alpha: 1 - flash)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      canvas.drawCircle(
        Offset(cx, enemyY),
        6 + flash * 12,
        Paint()..color = Colors.white.withValues(alpha: 1 - flash * 0.5),
      );
    }
  }

  void _paintScaredFace(Canvas canvas, Size size, double bottomY, double alpha) {
    final cx = size.width * 0.5;
    final cy = bottomY - size.height * 0.11;
    final r = size.shortestSide * 0.07;

    canvas.drawCircle(
      Offset(cx, cy - r * 0.15),
      r,
      Paint()..color = const Color(0xFFFFE0B2).withValues(alpha: alpha),
    );
    canvas.drawCircle(
      Offset(cx, cy - r * 0.15),
      r,
      Paint()
        ..color = const Color(0xFF5D4037).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final eyePaint = Paint()..color = Colors.white.withValues(alpha: alpha);
    final pupilPaint = Paint()..color = const Color(0xFF212121).withValues(alpha: alpha);
    for (final dx in [-r * 0.38, r * 0.38]) {
      final eye = Offset(cx + dx, cy - r * 0.28);
      canvas.drawCircle(eye, r * 0.22, eyePaint);
      canvas.drawCircle(eye + Offset(dx * 0.15, r * 0.04), r * 0.1, pupilPaint);
    }

    final browPaint = Paint()
      ..color = const Color(0xFF4E342E).withValues(alpha: alpha)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - r * 0.62, cy - r * 0.52),
      Offset(cx - r * 0.2, cy - r * 0.42),
      browPaint,
    );
    canvas.drawLine(
      Offset(cx + r * 0.62, cy - r * 0.52),
      Offset(cx + r * 0.2, cy - r * 0.42),
      browPaint,
    );

    final mouth = Path()
      ..moveTo(cx - r * 0.28, cy + r * 0.08)
      ..quadraticBezierTo(cx, cy + r * 0.55, cx + r * 0.28, cy + r * 0.08)
      ..quadraticBezierTo(cx, cy + r * 0.18, cx - r * 0.28, cy + r * 0.08);
    canvas.drawPath(
      mouth,
      Paint()..color = const Color(0xFF3E2723).withValues(alpha: alpha),
    );
  }

  void _paintFighter(Canvas canvas, double cx, double y, double w, double h) {
    final ship = Path()
      ..moveTo(cx, y + h * 0.5)
      ..lineTo(cx - w, y - h * 0.35)
      ..lineTo(cx - w * 0.35, y - h * 0.55)
      ..lineTo(cx, y - h * 0.75)
      ..lineTo(cx + w * 0.35, y - h * 0.55)
      ..lineTo(cx + w, y - h * 0.35)
      ..close();
    _fillStroke(canvas, ship, const Color(0xFFE53935), const Color(0xFFB71C1C));
  }

  void _paintCruiser(Canvas canvas, double cx, double y, double w, double h) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, y), width: w * 2.1, height: h * 1.1),
      Radius.circular(h * 0.15),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFF7043));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFFE64A19)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, y - h * 0.15), width: w * 0.5, height: h * 0.35),
      Paint()..color = const Color(0xFFFFCCBC),
    );
  }

  void _paintDrone(Canvas canvas, double cx, double y, double w, double h) {
    final core = Paint()..color = const Color(0xFFAB47BC);
    canvas.drawCircle(Offset(cx, y), min(w, h) * 0.55, core);
    for (var i = 0; i < 4; i++) {
      final angle = i * pi / 2 + engine.now * 2;
      final orb = Offset(cx + cos(angle) * w * 0.75, y + sin(angle) * h * 0.55);
      canvas.drawCircle(orb, min(w, h) * 0.18, Paint()..color = const Color(0xFFCE93D8));
    }
  }

  void _paintMothership(Canvas canvas, double cx, double y, double w, double h) {
    final ship = Path()
      ..moveTo(cx, y - h * 0.85)
      ..lineTo(cx - w * 1.1, y + h * 0.35)
      ..lineTo(cx, y + h * 0.55)
      ..lineTo(cx + w * 1.1, y + h * 0.35)
      ..close();
    _fillStroke(canvas, ship, const Color(0xFF8E24AA), const Color(0xFF4A148C));
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, y), width: w * 0.35, height: h * 0.55),
      Paint()..color = const Color(0xFFE1BEE7),
    );
  }

  void _paintInterceptor(Canvas canvas, double cx, double y, double w, double h) {
    final ship = Path()
      ..moveTo(cx, y - h * 0.8)
      ..lineTo(cx - w * 0.25, y + h * 0.45)
      ..lineTo(cx - w * 0.9, y + h * 0.2)
      ..lineTo(cx, y + h * 0.05)
      ..lineTo(cx + w * 0.9, y + h * 0.2)
      ..lineTo(cx + w * 0.25, y + h * 0.45)
      ..close();
    _fillStroke(canvas, ship, const Color(0xFF66BB6A), const Color(0xFF2E7D32));
  }

  void _paintSaucer(Canvas canvas, double cx, double y, double w, double h) {
    final hover = sin(engine.now * 5) * 2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, y + hover), width: w * 2, height: h * 0.7),
      Paint()..color = const Color(0xFF26C6DA),
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, y - h * 0.2 + hover), width: w * 1.1, height: h * 0.9),
      pi,
      pi,
      true,
      Paint()..color = const Color(0xFF80DEEA),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, y - h * 0.05 + hover), width: w * 0.45, height: h * 0.35),
      Paint()..color = const Color(0xFFE0F7FA),
    );
  }

  void _fillStroke(Canvas canvas, Path path, Color fill, Color stroke) {
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintBurst(
    Canvas canvas,
    Size size,
    Offset vanish,
    double horizonY,
    double bottomY,
    EnemyModel enemy,
  ) {
    final cx = size.width * 0.5;
    final cy = _enemyY(size, horizonY, bottomY, enemy.approach);
    final t = (engine.phaseElapsed / enemyDestroyedPauseSeconds).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 1 - t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (var i = 0; i < 10; i++) {
      final angle = i * pi / 5;
      final r = 20 + t * 80;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(angle) * r, cy + sin(angle) * r),
        paint,
      );
    }
  }

  void _paintPlayerExplosion(Canvas canvas, Size size, double bottomY) {
    final cx = size.width * 0.5;
    final cy = bottomY - size.height * 0.11;
    final t =
        (engine.phaseElapsed / playerExplosionDurationSeconds).clamp(0.0, 1.0);
    final core = Paint()..color = const Color(0xFFFF5722).withValues(alpha: 1 - t * 0.4);
    canvas.drawCircle(Offset(cx, cy), 18 + t * 52, core);
    canvas.drawCircle(
      Offset(cx, cy),
      28 + t * 70,
      Paint()
        ..color = const Color(0xFFFFEB3B).withValues(alpha: (1 - t) * 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    final burst = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 1 - t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (var i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      final r = 24 + t * 90;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(angle) * r, cy + sin(angle) * r),
        burst,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
