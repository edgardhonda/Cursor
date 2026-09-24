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
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final t = engine.paintTimeMs / 1000.0;
    final now = DateTime.now();

    _drawSpawnStrip(canvas, size);

    if (engine.castle != null) {
      if (!engine.castleDestroyed) {
        _drawCastle(canvas, t);
      } else {
        _drawRubble(canvas);
      }
    }

    for (final s in engine.soldiers) {
      _drawSoldier(canvas, s);
    }
    for (final b in engine.balls) {
      _drawBall(canvas, b);
    }

    _drawStrokes(canvas, now);

    for (final f in engine.fires) {
      _drawFire(canvas, f, now);
    }
  }

  // ----------------------------------------------------------- spawn strip

  void _drawSpawnStrip(Canvas canvas, Size size) {
    final stripLeft = size.width - kSpawnStripWidth;
    canvas.drawRect(
      Rect.fromLTWH(stripLeft, 0, kSpawnStripWidth, size.height),
      Paint()..color = const Color(0x143949AB),
    );
    final border = Paint()
      ..color = const Color(0x553949AB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(stripLeft, 0), Offset(stripLeft, size.height), border);

    final arrow = Paint()
      ..color = const Color(0x553949AB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final cx = stripLeft + kSpawnStripWidth * 0.5;
    for (double y = 46; y < size.height; y += 84) {
      canvas.drawPath(
        Path()
          ..moveTo(cx + 9, y - 9)
          ..lineTo(cx - 9, y)
          ..lineTo(cx + 9, y + 9),
        arrow,
      );
    }
  }

  // ----------------------------------------------------------------- castle

  void _drawCastle(Canvas canvas, double t) {
    final c = engine.castle!;
    final cx = c.center.dx;
    final cy = c.center.dy;
    final u = c.unit;

    final wallLeft = cx - u * 0.78;
    final wallRight = cx + u * 0.78;
    final wallTop = cy - u * 0.05;
    final wallBottom = cy + u * 0.6;
    canvas.drawRect(
        Rect.fromLTRB(wallLeft, wallTop, wallRight, wallBottom), _outline);

    _battlement(canvas, wallLeft + u * 0.05, wallTop, u * 0.3, u * 0.26);
    _battlement(
        canvas, wallRight - u * 0.05 - u * 0.3, wallTop, u * 0.3, u * 0.26);

    final towLeft = cx - u * 0.3;
    final towRight = cx + u * 0.3;
    final towTop = cy - u * 0.62;
    canvas.drawRect(
        Rect.fromLTRB(towLeft, towTop, towRight, wallBottom), _outline);

    final roof = Path()
      ..moveTo(towLeft - u * 0.07, towTop)
      ..lineTo(cx, towTop - u * 0.42)
      ..lineTo(towRight + u * 0.07, towTop)
      ..close();
    canvas.drawPath(roof, _outline);

    final win = Rect.fromCenter(
      center: Offset(cx, cy - u * 0.26),
      width: u * 0.36,
      height: u * 0.44,
    );
    canvas.drawRect(win, _outline);

    _drawKing(canvas, win, t);
  }

  void _battlement(
      Canvas canvas, double left, double baseTop, double w, double h) {
    final bodyTop = baseTop - h * 0.5;
    canvas.drawRect(Rect.fromLTRB(left, bodyTop, left + w, baseTop), _outline);
    final tw = w / 5;
    for (var i = 0; i < 3; i++) {
      final x = left + i * 2 * tw;
      canvas.drawRect(Rect.fromLTRB(x, baseTop - h, x + tw, bodyTop), _outline);
    }
  }

  void _drawKing(Canvas canvas, Rect win, double t) {
    final h = win.height * 0.72;
    final baseX = win.center.dx;
    final footY = win.bottom - win.height * 0.06;
    final hip = Offset(baseX, footY - h * 0.42);
    final neck = Offset(hip.dx, hip.dy - h * 0.5);
    final headR = h * 0.16;
    final headC = Offset(hip.dx, neck.dy - headR);
    final phase = sin(t * 3);

    canvas.drawCircle(headC, headR, _outline);
    canvas.drawLine(neck, hip, _outline);

    final crownY = headC.dy - headR;
    final cw = headR * 1.5;
    final crown = Path()
      ..moveTo(headC.dx - cw / 2, crownY)
      ..lineTo(headC.dx - cw / 2, crownY - headR * 0.55)
      ..lineTo(headC.dx - cw * 0.22, crownY - headR * 0.12)
      ..lineTo(headC.dx, crownY - headR * 0.8)
      ..lineTo(headC.dx + cw * 0.22, crownY - headR * 0.12)
      ..lineTo(headC.dx + cw / 2, crownY - headR * 0.55)
      ..lineTo(headC.dx + cw / 2, crownY);
    canvas.drawPath(crown, _outline);

    final legLen = h * 0.4;
    final lAmp = h * 0.1;
    canvas.drawLine(
        hip, Offset(hip.dx + lAmp * phase, hip.dy + legLen), _outline);
    canvas.drawLine(
        hip, Offset(hip.dx - lAmp * phase, hip.dy + legLen), _outline);

    final shoulder = Offset(neck.dx, neck.dy + h * 0.06);
    final armLen = h * 0.3;
    canvas.drawLine(
      shoulder,
      Offset(shoulder.dx - armLen * 0.85, shoulder.dy - armLen * 0.45 * phase),
      _outline,
    );
    canvas.drawLine(
      shoulder,
      Offset(shoulder.dx + armLen * 0.85, shoulder.dy + armLen * 0.45 * phase),
      _outline,
    );
  }

  void _drawRubble(Canvas canvas) {
    final c = engine.castle!;
    final cx = c.center.dx;
    final cy = c.center.dy;
    final u = c.unit;
    final p = _outline;

    final broken = Path()
      ..moveTo(cx - u * 0.78, cy + u * 0.6)
      ..lineTo(cx - u * 0.5, cy + u * 0.6)
      ..lineTo(cx - u * 0.38, cy + u * 0.3)
      ..lineTo(cx - u * 0.2, cy + u * 0.55)
      ..lineTo(cx - u * 0.02, cy + u * 0.22)
      ..lineTo(cx + u * 0.18, cy + u * 0.5)
      ..lineTo(cx + u * 0.34, cy + u * 0.28)
      ..lineTo(cx + u * 0.5, cy + u * 0.6)
      ..lineTo(cx + u * 0.78, cy + u * 0.6);
    canvas.drawPath(broken, p);

    for (var i = 0; i < 4; i++) {
      final rx = cx - u * 0.55 + i * u * 0.32;
      canvas.drawRect(
        Rect.fromLTWH(rx, cy + u * 0.46, u * 0.13, u * 0.11),
        p,
      );
    }
  }

  // ---------------------------------------------------------------- soldier

  void _drawSoldier(Canvas canvas, Soldier s) {
    final h = s.size;
    final hip = Offset(s.position.dx, s.position.dy + h * 0.1);
    final neck = Offset(hip.dx, hip.dy - h * 0.5);
    final headR = h * 0.16;
    final headC = Offset(hip.dx, neck.dy - headR);
    final legPhase = sin(s.walkPhase);
    final armPhase = sin(s.walkPhase + pi);

    canvas.drawCircle(headC, headR, _outline);
    canvas.drawLine(neck, hip, _outline);

    final legLen = h * 0.42;
    final lAmp = h * 0.16;
    canvas.drawLine(
        hip, Offset(hip.dx + lAmp * legPhase, hip.dy + legLen), _outline);
    canvas.drawLine(
        hip, Offset(hip.dx - lAmp * legPhase, hip.dy + legLen), _outline);

    final shoulder = Offset(neck.dx, neck.dy + h * 0.05);
    final armLen = h * 0.3;
    final aAmp = h * 0.16;
    canvas.drawLine(
      shoulder,
      Offset(shoulder.dx + aAmp * armPhase, shoulder.dy + armLen),
      _outline,
    );

    // Braço com espada apontando para o castelo (esquerda).
    final swHand = Offset(shoulder.dx - armLen * 0.8, shoulder.dy - h * 0.02);
    canvas.drawLine(shoulder, swHand, _outline);
    final tip = Offset(swHand.dx - h * 0.52, swHand.dy - h * 0.14);
    canvas.drawLine(swHand, tip, _outline);
    final bd = tip - swHand;
    final bl = bd.distance;
    final bn = bl > 0 ? bd / bl : const Offset(-1, 0);
    final gp = Offset(-bn.dy, bn.dx) * (h * 0.1);
    canvas.drawLine(swHand - gp, swHand + gp, _outline);
  }

  // ------------------------------------------------------------------- ball

  void _drawBall(Canvas canvas, Ball b) {
    final n = b.trail.length;
    for (var i = 0; i < n; i++) {
      final f = (i + 1) / n;
      final r = b.radius * (0.25 + 0.7 * f);
      canvas.drawCircle(
        b.trail[i],
        r,
        Paint()..color = b.color.withAlpha(((0.05 + 0.4 * f) * 255).round()),
      );
    }
    canvas.drawCircle(b.position, b.radius, Paint()..color = b.color);
    canvas.drawCircle(b.position, b.radius, _outline);
  }

  // ---------------------------------------------------------------- strokes

  void _drawStrokes(Canvas canvas, DateTime now) {
    final fadeMs = kStrokeFadeSeconds * 1000;
    _strokePaint.strokeWidth = engine.ballRadius * 2;
    for (final s in engine.strokes) {
      final pts = s.points;
      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1];
        final b = pts[i];
        final age = now.difference(b.createdAt).inMilliseconds / fadeMs;
        final alpha = (1.0 - age).clamp(0.0, 1.0);
        if (alpha <= 0) continue;
        _strokePaint.color = b.color.withAlpha((alpha * 255).round());
        canvas.drawLine(a.position, b.position, _strokePaint);
      }
    }
  }

  // ------------------------------------------------------------------- fire

  Path _flame(Offset base, double w, double hgt) {
    return Path()
      ..moveTo(base.dx - w / 2, base.dy)
      ..quadraticBezierTo(
          base.dx - w / 2, base.dy - hgt * 0.6, base.dx, base.dy - hgt)
      ..quadraticBezierTo(
          base.dx + w / 2, base.dy - hgt * 0.6, base.dx + w / 2, base.dy)
      ..close();
  }

  void _drawFire(Canvas canvas, Fire f, DateTime now) {
    final p = f.progress(now);
    final intensity = sin(p * pi).clamp(0.0, 1.0);
    if (intensity <= 0) return;

    final isBonfire = f.durationMs >= kCastleFireMs;
    final flick =
        0.85 + 0.15 * sin(now.millisecondsSinceEpoch / 50.0 + f.position.dx);
    final scale = f.maxRadius * flick * (0.55 + 0.6 * p);
    final base = Offset(f.position.dx, f.position.dy + f.maxRadius * 0.35);

    if (isBonfire) {
      final logs = Paint()
        ..color = Colors.black
        ..strokeWidth = scale * 0.12
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(base + Offset(-scale * 0.6, 6),
          base + Offset(scale * 0.6, -2), logs);
      canvas.drawLine(base + Offset(-scale * 0.6, -2),
          base + Offset(scale * 0.6, 6), logs);
    }

    void tongue(Offset b, double s, Color col) {
      canvas.drawPath(
        _flame(b, s * 1.1, s * 2.0),
        Paint()..color = col.withAlpha((220 * intensity).round()),
      );
    }

    if (isBonfire) {
      tongue(base + Offset(-scale * 0.45, 0), scale * 0.6, _cRedFire);
      tongue(base + Offset(scale * 0.45, 0), scale * 0.6, _cRedFire);
    }
    tongue(base, scale, _cRedFire);
    tongue(base, scale * 0.66, _cOrangeFire);
    tongue(base, scale * 0.36, _cYellowFire);
  }

  static const _cRedFire = Color(0xFFE53935);
  static const _cOrangeFire = Color(0xFFFB8C00);
  static const _cYellowFire = Color(0xFFFDD835);

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => false;
}
