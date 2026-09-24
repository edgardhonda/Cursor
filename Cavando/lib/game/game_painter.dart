import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_engine.dart';
import 'mountain_layout.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.engine);

  final GameEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    if (!engine.hasLayout) return;
    final m = engine.layout;
    _drawSky(canvas, size);
    _drawClouds(canvas, size);
    _drawHills(canvas, size, m);
    _drawMountain(canvas, size, m);
    _drawTunnels(canvas);
    _drawSnow(canvas, m);
    _drawCraterAndSmoke(canvas, m);
    _drawMountainStroke(canvas, m);
    _drawGrass(canvas, size, m);
    _drawItems(canvas);
    _drawDiamond(canvas);
    _drawExplosion(canvas);
    if (engine.state != FerretState.exploding) {
      _drawFerret(canvas);
    }
    _drawStars(canvas);
    _drawWin(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB9E4F5), Color(0xFF7EC8E3), Color(0xFF9FDBF0)],
        ).createShader(rect),
    );
  }

  void _drawClouds(Canvas canvas, Size size) {
    final t = engine.time;
    _cloud(canvas, Offset(size.width * 0.12, size.height * 0.09), size.width * 0.11, t);
    _cloud(canvas, Offset(size.width * 0.38, size.height * 0.055), size.width * 0.08, t + 1.2);
    _cloud(canvas, Offset(size.width * 0.70, size.height * 0.07), size.width * 0.10, t + 2.1);
    _cloud(canvas, Offset(size.width * 0.90, size.height * 0.10), size.width * 0.09, t + 0.4);
  }

  void _cloud(Canvas canvas, Offset c, double s, double phase) {
    final o = Offset(math.sin(phase * 0.15) * 6, 0);
    final p = Paint()..color = const Color(0xFFF7FCFF);
    canvas.drawOval(Rect.fromCenter(center: c + o, width: s * 2.2, height: s * 0.85), p);
    canvas.drawCircle(c + o + Offset(-s * 0.55, -s * 0.12), s * 0.42, p);
    canvas.drawCircle(c + o + Offset(s * 0.45, -s * 0.18), s * 0.38, p);
    canvas.drawCircle(c + o + Offset(0, -s * 0.28), s * 0.36, p);
  }

  void _drawHills(Canvas canvas, Size size, MountainLayout m) {
    final paint = Paint()..color = const Color(0xFF7FBF55);
    final left = Path()
      ..moveTo(0, m.baseY)
      ..quadraticBezierTo(size.width * 0.12, m.baseY - size.height * 0.08, size.width * 0.28, m.baseY)
      ..lineTo(0, m.baseY)
      ..close();
    final right = Path()
      ..moveTo(size.width * 0.72, m.baseY)
      ..quadraticBezierTo(size.width * 0.88, m.baseY - size.height * 0.07, size.width, m.baseY)
      ..lineTo(size.width * 0.72, m.baseY)
      ..close();
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);
  }

  void _drawMountain(Canvas canvas, Size size, MountainLayout m) {
    canvas.drawPath(m.bodyPath, Paint()..color = const Color(0xFFA05A32));
    canvas.save();
    canvas.clipPath(m.bodyPath);
    canvas.drawPath(m.shadePath, Paint()..color = const Color(0xFF6E3A1C));
    canvas.restore();
  }

  void _drawTunnels(Canvas canvas) {
    if (engine.tunnels.isEmpty) return;
    canvas.save();
    canvas.clipPath(engine.layout.bodyPath);
    canvas.drawPath(
      engine.tunnelPath,
      Paint()..color = const Color(0xFF3A1E10),
    );
    canvas.drawPath(
      engine.tunnelPath,
      Paint()
        ..color = const Color(0xFF241208)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.restore();
  }

  void _drawSnow(Canvas canvas, MountainLayout m) {
    canvas.save();
    canvas.clipPath(m.bodyPath);
    canvas.drawPath(m.snowPath, Paint()..color = const Color(0xFFF4F7FA));
    // Soft shade on the right of the snow.
    canvas.drawPath(
      m.snowPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0x00FFFFFF),
            const Color(0x332A1A10),
          ],
        ).createShader(m.snowPath.getBounds()),
    );
    canvas.restore();
  }

  void _drawCraterAndSmoke(Canvas canvas, MountainLayout m) {
    canvas.drawPath(m.craterPath, Paint()..color = const Color(0xFF4A2A18));
    canvas.drawPath(
      m.craterPath,
      Paint()
        ..color = const Color(0xFF1E1008)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final t = engine.time;
    final c = Offset(m.peakX, m.peakY - engine.size.height * 0.01);
    final smoke = Paint()..color = const Color(0x996E7A86);
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(math.sin(t * 0.7) * 4, -engine.size.height * 0.045),
        width: engine.size.width * 0.07,
        height: engine.size.height * 0.04,
      ),
      smoke,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(math.cos(t * 0.55) * 8, -engine.size.height * 0.08),
        width: engine.size.width * 0.085,
        height: engine.size.height * 0.05,
      ),
      smoke,
    );
  }

  void _drawMountainStroke(Canvas canvas, MountainLayout m) {
    canvas.drawPath(
      m.bodyPath,
      Paint()
        ..color = const Color(0xFF24160E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawGrass(Canvas canvas, Size size, MountainLayout m) {
    final grass = Path()
      ..moveTo(0, m.baseY)
      ..lineTo(size.width, m.baseY)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      grass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF7EC85A), Color(0xFF4F9A3A)],
        ).createShader(Rect.fromLTWH(0, m.baseY, size.width, size.height - m.baseY)),
    );
    // A few simple pines so the base feels alive without covering the volcano.
    _pine(canvas, Offset(size.width * 0.08, m.baseY + 6), size.shortestSide * 0.07);
    _pine(canvas, Offset(size.width * 0.16, m.baseY + 10), size.shortestSide * 0.055);
    _pine(canvas, Offset(size.width * 0.86, m.baseY + 8), size.shortestSide * 0.06);
    _pine(canvas, Offset(size.width * 0.94, m.baseY + 4), size.shortestSide * 0.075);
  }

  void _pine(Canvas canvas, Offset foot, double h) {
    final trunk = Paint()..color = const Color(0xFF5A3A22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: foot + Offset(0, -h * 0.08), width: h * 0.12, height: h * 0.22),
        const Radius.circular(2),
      ),
      trunk,
    );
    final leaf = Paint()..color = const Color(0xFF2F7A38);
    for (var i = 0; i < 3; i++) {
      final top = foot + Offset(0, -h * (0.35 + i * 0.28));
      final w = h * (0.55 - i * 0.1);
      final path = Path()
        ..moveTo(top.dx, top.dy - h * 0.18)
        ..lineTo(top.dx - w, top.dy + h * 0.16)
        ..lineTo(top.dx + w, top.dy + h * 0.16)
        ..close();
      canvas.drawPath(path, leaf);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF1E3F1C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawItems(Canvas canvas) {
    for (final o in engine.obstacles) {
      switch (o.kind) {
        case ObstacleKind.rock:
          _rock(canvas, o);
        case ObstacleKind.poop:
          _poop(canvas, o);
        case ObstacleKind.bone:
          _bone(canvas, o);
      }
    }
    for (final f in engine.fruits) {
      if (f.eaten && f.eatProgress >= 1) continue;
      canvas.save();
      canvas.translate(f.position.dx, f.position.dy);
      final s = f.eaten ? (1 - f.eatProgress) : (0.2 + 0.8 * f.appearProgress);
      canvas.scale(s);
      _fruit(canvas, f.kind, f.radius);
      canvas.restore();
    }
  }

  void _drawDiamond(Canvas canvas) {
    if (engine.diamondCollected && engine.diamondCollect >= 1) return;
    final bob = engine.diamondCollected
        ? 0.0
        : math.sin(engine.time * 3.2) * engine.diamondRadius * 0.18;
    final collected = engine.diamondCollected;
    final pop = collected ? (1 + engine.diamondCollect * 0.8) : 1.0;
    final fade = collected ? (1 - engine.diamondCollect) : 1.0;
    canvas.save();
    canvas.translate(engine.diamondPos.dx, engine.diamondPos.dy + bob);
    canvas.scale(pop * fade);
    final r = engine.diamondRadius;
    final gem = Path()
      ..moveTo(0, -r)
      ..lineTo(r * 0.72, -r * 0.12)
      ..lineTo(0, r)
      ..lineTo(-r * 0.72, -r * 0.12)
      ..close();
    canvas.drawPath(gem, Paint()..color = const Color(0xFF5AD0FF));
    final facet = Path()
      ..moveTo(0, -r)
      ..lineTo(r * 0.72, -r * 0.12)
      ..lineTo(0, -r * 0.18)
      ..close();
    canvas.drawPath(facet, Paint()..color = const Color(0xFFE8FBFF));
    final facet2 = Path()
      ..moveTo(0, -r)
      ..lineTo(-r * 0.72, -r * 0.12)
      ..lineTo(0, -r * 0.18)
      ..close();
    canvas.drawPath(facet2, Paint()..color = const Color(0xFF9BE8FF));
    canvas.drawPath(
      gem,
      Paint()
        ..color = const Color(0xFF1A5A88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    if (!collected) {
      for (var i = 0; i < 6; i++) {
        final a = engine.time * 2.4 + i * math.pi / 3;
        final p = Offset(math.cos(a), math.sin(a)) * (r * 1.45);
        canvas.drawCircle(
          p,
          r * 0.08,
          Paint()..color = const Color(0xCCFFF7A0),
        );
      }
    }
    canvas.restore();
  }

  void _drawExplosion(Canvas canvas) {
    if (engine.state != FerretState.exploding) return;
    final t = (engine.explodeTime / GameEngine.explodeDuration).clamp(0.0, 1.0);
    final origin = engine.explodePos;
    final maxR = engine.explodeRadius;
    final fade = (1 - t).clamp(0.0, 1.0);
    canvas.drawCircle(
      origin,
      maxR * (0.35 + t * 0.85),
      Paint()..color = Color.fromARGB((150 * fade).round(), 255, 140, 40),
    );
    canvas.drawCircle(
      origin,
      maxR * (0.18 + t * 0.55),
      Paint()..color = Color.fromARGB((200 * fade).round(), 255, 220, 80),
    );
    canvas.drawCircle(
      origin,
      maxR * (0.08 + t * 0.22),
      Paint()..color = Color.fromARGB((220 * fade).round(), 255, 255, 230),
    );
    for (var i = 0; i < 8; i++) {
      final a = t * 4 + i * math.pi / 4;
      final p = origin + Offset(math.cos(a), math.sin(a)) * (maxR * (0.4 + t * 0.5));
      canvas.drawCircle(
        p,
        maxR * 0.12 * fade,
        Paint()..color = Color.fromARGB((180 * fade).round(), 90, 50, 30),
      );
    }
  }

  void _drawWin(Canvas canvas, Size size) {
    if (engine.state != FerretState.won) return;
    final t = engine.winTime.clamp(0.0, 1.0);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.fromARGB((120 * t).round(), 20, 40, 70),
    );
    final banner = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.22),
        width: size.width * 0.78,
        height: size.shortestSide * 0.16,
      ),
      const Radius.circular(22),
    );
    canvas.drawRRect(banner, Paint()..color = const Color(0xF5F4E2C0));
    canvas.drawRRect(
      banner,
      Paint()
        ..color = const Color(0xFF5A3A22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final titleSize = size.shortestSide * 0.075;
    final tp = TextPainter(
      text: TextSpan(
        text: 'Você ganhou!',
        style: TextStyle(
          fontSize: titleSize,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF5A3A22),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.7);
    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height * 0.22 - tp.height / 2),
    );
  }

  void _rock(Canvas canvas, Obstacle o) {
    final r = o.radius;
    final path = Path()
      ..moveTo(o.position.dx - r, o.position.dy + r * 0.35)
      ..quadraticBezierTo(o.position.dx - r * 0.7, o.position.dy - r, o.position.dx, o.position.dy - r * 0.85)
      ..quadraticBezierTo(o.position.dx + r * 0.8, o.position.dy - r * 0.9, o.position.dx + r, o.position.dy + r * 0.2)
      ..quadraticBezierTo(o.position.dx + r * 0.2, o.position.dy + r * 0.9, o.position.dx - r, o.position.dy + r * 0.35)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF8A8F96));
    canvas.drawPath(path, Paint()..color = const Color(0xFF5C6168)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawOval(
      Rect.fromCenter(center: o.position + Offset(-r * 0.25, -r * 0.15), width: r * 0.45, height: r * 0.25),
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  void _poop(Canvas canvas, Obstacle o) {
    final p = o.position;
    final r = o.radius;
    final fill = Paint()..color = const Color(0xFF6B3A18);
    final stroke = Paint()
      ..color = const Color(0xFF3A1E0C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawOval(Rect.fromCenter(center: p + Offset(0, r * 0.35), width: r * 1.7, height: r * 0.9), fill);
    canvas.drawOval(Rect.fromCenter(center: p + Offset(0, r * 0.35), width: r * 1.7, height: r * 0.9), stroke);
    canvas.drawCircle(p + Offset(-r * 0.05, -r * 0.05), r * 0.55, fill);
    canvas.drawCircle(p + Offset(-r * 0.05, -r * 0.05), r * 0.55, stroke);
    canvas.drawCircle(p + Offset(r * 0.08, -r * 0.55), r * 0.32, fill);
    canvas.drawCircle(p + Offset(r * 0.08, -r * 0.55), r * 0.32, stroke);
  }

  void _bone(Canvas canvas, Obstacle o) {
    final p = o.position;
    final r = o.radius;
    final fill = Paint()..color = const Color(0xFFF2E6C9);
    final stroke = Paint()
      ..color = const Color(0xFF5A4A32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(-0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 0.42),
        const Radius.circular(8),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 0.42),
        const Radius.circular(8),
      ),
      stroke,
    );
    for (final x in [-r * 0.85, r * 0.85]) {
      canvas.drawCircle(Offset(x, -r * 0.28), r * 0.28, fill);
      canvas.drawCircle(Offset(x, r * 0.28), r * 0.28, fill);
      canvas.drawCircle(Offset(x, -r * 0.28), r * 0.28, stroke);
      canvas.drawCircle(Offset(x, r * 0.28), r * 0.28, stroke);
    }
    canvas.restore();
  }

  void _fruit(Canvas canvas, FruitKind kind, double r) {
    switch (kind) {
      case FruitKind.apple:
        canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFE23B3B));
        canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF7A1C1C)..style = PaintingStyle.stroke..strokeWidth = 1.6);
        canvas.drawCircle(Offset(-r * 0.3, -r * 0.25), r * 0.22, Paint()..color = const Color(0x66FFFFFF));
        _stem(canvas, r);
      case FruitKind.orange:
        canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFF08A24));
        canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF9A4A10)..style = PaintingStyle.stroke..strokeWidth = 1.6);
        _stem(canvas, r);
      case FruitKind.pear:
        canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.15), width: r * 1.6, height: r * 1.5), Paint()..color = const Color(0xFFC6D94A));
        canvas.drawCircle(Offset(0, -r * 0.45), r * 0.55, Paint()..color = const Color(0xFFC6D94A));
        _stem(canvas, r);
      case FruitKind.berry:
        canvas.drawCircle(Offset(-r * 0.28, 0), r * 0.55, Paint()..color = const Color(0xFF7B2CBF));
        canvas.drawCircle(Offset(r * 0.28, 0.1 * r), r * 0.55, Paint()..color = const Color(0xFF9B4DCA));
        canvas.drawCircle(Offset(0, -r * 0.28), r * 0.5, Paint()..color = const Color(0xFF6A1B9A));
        _stem(canvas, r * 0.8);
    }
  }

  void _stem(Canvas canvas, double r) {
    canvas.drawLine(
      Offset(0, -r * 0.7),
      Offset(0, -r * 1.15),
      Paint()
        ..color = const Color(0xFF4A2A12)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final leaf = Path()
      ..moveTo(0, -r * 1.0)
      ..quadraticBezierTo(r * 0.55, -r * 1.25, r * 0.15, -r * 0.7)
      ..quadraticBezierTo(r * 0.05, -r * 0.95, 0, -r * 1.0);
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF3FA34D));
  }

  void _drawFerret(Canvas canvas) {
    final pos = engine.ferretPos;
    final r = engine.ferretRadius;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    if (engine.state == FerretState.rolling) {
      canvas.rotate(engine.ferretAngle);
    }
    if (!engine.facingRight) {
      canvas.scale(-1, 1);
    }
    final walk = engine.state == FerretState.walking || engine.state == FerretState.digging
        ? engine.walkPhase
        : 0.0;
    final bob = math.sin(walk * 2) * r * 0.06;
    canvas.translate(0, bob);

    if (engine.state == FerretState.bumping) {
      canvas.translate(math.sin(engine.bumpTime * 42) * r * 0.18, 0);
    }

    _ferretBody(canvas, r, walk);
    canvas.restore();
  }

  void _ferretBody(Canvas canvas, double r, double walk) {
    final outline = Paint()
      ..color = const Color(0xFF2A1A10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, r * 0.08)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final brown = Paint()..color = const Color(0xFF8D5A32);
    final cream = Paint()..color = const Color(0xFFE8D5B0);
    final dark = Paint()..color = const Color(0xFF3D2A1C);
    final pink = Paint()..color = const Color(0xFFE8A090);

    // Tail
    final wag = math.sin(walk * 1.4) * r * 0.18;
    final tail = Path()
      ..moveTo(-r * 1.05, r * 0.05)
      ..quadraticBezierTo(-r * 1.7, r * 0.15 + wag, -r * 2.05, r * 0.55 + wag)
      ..quadraticBezierTo(-r * 1.55, r * 0.55 + wag * 0.4, -r * 1.0, r * 0.25)
      ..close();
    canvas.drawPath(tail, brown);
    canvas.drawPath(tail, outline);

    // Legs
    final lift = engine.state == FerretState.rolling ? 0.0 : 1.0;
    _leg(canvas, Offset(r * 0.62, r * 0.42), r, math.sin(walk) * r * 0.22 * lift, brown, outline);
    _leg(canvas, Offset(r * 0.22, r * 0.48), r, math.sin(walk + math.pi) * r * 0.22 * lift, brown, outline);
    _leg(canvas, Offset(-r * 0.28, r * 0.48), r, math.sin(walk + math.pi) * r * 0.2 * lift, brown, outline);
    _leg(canvas, Offset(-r * 0.68, r * 0.42), r, math.sin(walk) * r * 0.2 * lift, brown, outline);

    // Body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(r * 0.05, 0), width: r * 2.25, height: r * 1.15),
      Radius.circular(r * 0.7),
    );
    canvas.drawRRect(body, brown);
    canvas.drawRRect(body, outline);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r * 0.22, r * 0.18), width: r * 1.55, height: r * 0.7),
      cream,
    );

    // Head
    var chew = 0.0;
    var nod = 0.0;
    if (engine.state == FerretState.eating) {
      chew = math.sin(engine.eatTime * 22) * 0.08;
      nod = 0.35;
    }
    canvas.save();
    canvas.translate(r * 1.05, -r * 0.28);
    canvas.rotate(nod);
    canvas.scale(1, 1 + chew);

    canvas.drawCircle(Offset.zero, r * 0.72, brown);
    canvas.drawCircle(Offset.zero, r * 0.72, outline);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r * 0.12, r * 0.12), width: r * 0.85, height: r * 0.7),
      cream,
    );

    // Ears
    canvas.drawOval(Rect.fromCenter(center: Offset(-r * 0.38, -r * 0.58), width: r * 0.38, height: r * 0.42), brown);
    canvas.drawOval(Rect.fromCenter(center: Offset(-r * 0.38, -r * 0.58), width: r * 0.38, height: r * 0.42), outline);
    canvas.drawOval(Rect.fromCenter(center: Offset(-r * 0.38, -r * 0.55), width: r * 0.2, height: r * 0.22), pink);
    canvas.drawOval(Rect.fromCenter(center: Offset(r * 0.18, -r * 0.62), width: r * 0.34, height: r * 0.38), brown);
    canvas.drawOval(Rect.fromCenter(center: Offset(r * 0.18, -r * 0.62), width: r * 0.34, height: r * 0.38), outline);
    canvas.drawOval(Rect.fromCenter(center: Offset(r * 0.18, -r * 0.58), width: r * 0.16, height: r * 0.18), pink);

    // Mask
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r * 0.02, -r * 0.12), width: r * 1.05, height: r * 0.55),
      dark,
    );

    // Eyes
    canvas.drawCircle(Offset(-r * 0.12, -r * 0.16), r * 0.16, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(r * 0.28, -r * 0.18), r * 0.16, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(-r * 0.08, -r * 0.16), r * 0.09, Paint()..color = const Color(0xFF1A120C));
    canvas.drawCircle(Offset(r * 0.32, -r * 0.18), r * 0.09, Paint()..color = const Color(0xFF1A120C));
    canvas.drawCircle(Offset(-r * 0.12, -r * 0.20), r * 0.035, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(r * 0.28, -r * 0.22), r * 0.035, Paint()..color = Colors.white);

    // Nose + mouth
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r * 0.42, r * 0.06), width: r * 0.22, height: r * 0.16),
      pink,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r * 0.42, r * 0.06), width: r * 0.22, height: r * 0.16),
      outline,
    );
    canvas.drawLine(
      Offset(r * 0.42, r * 0.14),
      Offset(r * 0.42, r * 0.28),
      outline,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(r * 0.34, r * 0.28), width: r * 0.22, height: r * 0.16),
      0.2,
      math.pi * 0.7,
      false,
      outline,
    );

    // Whiskers
    final wPaint = Paint()
      ..color = const Color(0xFF2A1A10)
      ..strokeWidth = 1.1;
    canvas.drawLine(Offset(r * 0.3, r * 0.12), Offset(r * 0.85, r * 0.02), wPaint);
    canvas.drawLine(Offset(r * 0.3, r * 0.18), Offset(r * 0.82, r * 0.22), wPaint);
    canvas.drawLine(Offset(r * 0.28, r * 0.24), Offset(r * 0.78, r * 0.38), wPaint);

    canvas.restore();
  }

  void _leg(Canvas canvas, Offset origin, double r, double lift, Paint fill, Paint outline) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy + lift);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, r * 0.28), width: r * 0.28, height: r * 0.62),
      Radius.circular(r * 0.14),
    );
    canvas.drawRRect(rect, fill);
    canvas.drawRRect(rect, outline);
    canvas.restore();
  }

  void _drawStars(Canvas canvas) {
    for (final s in engine.stars) {
      final alpha = (s.life.clamp(0.0, 1.0) * 255).round();
      canvas.save();
      canvas.translate(s.position.dx, s.position.dy);
      canvas.rotate(s.spin);
      final path = _starPath(engine.ferretRadius * 0.28);
      canvas.drawPath(
        path,
        Paint()..color = Color.fromARGB(alpha, 255, 214, 64),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.fromARGB(alpha, 180, 120, 20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.restore();
    }
  }

  Path _starPath(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rad = i.isEven ? r : r * 0.42;
      final p = Offset(math.cos(a) * rad, math.sin(a) * rad);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
