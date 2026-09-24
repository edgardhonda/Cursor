import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.engine);

  final GameEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    _paintKitchen(canvas, size);
    _paintSoup(canvas);
    _paintFlies(canvas);
    _paintBadFrogs(canvas);
    _paintGoodFrogs(canvas);
    _paintTongue(canvas);
    _paintPlayer(canvas);
    _paintBombs(canvas);
    _paintHud(canvas, size);
  }

  void _paintKitchen(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80), Color(0xFFA1887F)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.78, size.width, size.height * 0.22),
      Paint()..color = const Color(0xFF6D4C41),
    );
  }

  void _paintSoup(Canvas canvas) {
    final bowl = engine.soupBowl;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bowl.center.dx, bowl.bottom + 8),
        width: bowl.width + 28,
        height: 36,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bowl.inflate(14), const Radius.circular(40)),
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bowl, const Radius.circular(34)),
      Paint()..color = const Color(0xFFFFB74D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bowl.deflate(10),
        const Radius.circular(28),
      ),
      Paint()..color = const Color(0xFFFFA726).withValues(alpha: 0.55),
    );
  }

  void _paintFlies(Canvas canvas) {
    for (final fly in engine.flies) {
      if (fly.phase == FlyPhase.gone) continue;
      final p = fly.position;
      final wing = sin(engine.now * 28 + fly.id) * 5;
      canvas.drawOval(
        Rect.fromCenter(center: p + Offset(-8, -4 + wing), width: 12, height: 8),
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
      canvas.drawOval(
        Rect.fromCenter(center: p + Offset(8, -4 - wing), width: 12, height: 8),
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
      canvas.drawCircle(p, FlyModel.radius * 0.55, Paint()..color = Colors.black);
      canvas.drawCircle(
        p + const Offset(-3, -2),
        2,
        Paint()..color = const Color(0xFF76FF03),
      );
    }
  }

  void _paintPlayer(Canvas canvas) {
    final p = engine.player.position;
    if (engine.player.phase == PlayerPhase.exploding) {
      final t = ((engine.now - engine.player.explodeStartedAt) /
              playerExplodeSeconds)
          .clamp(0.0, 1.0);
      _paintBurst(canvas, p, engine.player.radius * (1.2 + t * 1.6));
      return;
    }
    _drawFrog(
      canvas,
      p,
      radius: engine.player.radius,
      body: const Color(0xFF66BB6A),
      belly: const Color(0xFFC8E6C9),
      happy: !engine.playerSurprised,
      surprised: engine.playerSurprised,
    );
  }

  void _paintTongue(Canvas canvas) {
    final player = engine.player;
    if (player.tonguePhase == TonguePhase.idle) return;
    final tip = engine.tongueTip;
    canvas.drawLine(
      player.position + const Offset(0, -8),
      tip,
      Paint()
        ..color = const Color(0xFFEC407A)
        ..strokeWidth = 6 + player.sizeScale * 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(tip, 7, Paint()..color = const Color(0xFFD81B60));
  }

  void _paintBadFrogs(Canvas canvas) {
    for (final frog in engine.badFrogs) {
      if (frog.phase == BadFrogPhase.gone) continue;
      if (frog.phase == BadFrogPhase.exploding) {
        _paintBurst(canvas, frog.position, 26);
        continue;
      }
      _drawFrog(
        canvas,
        frog.position,
        radius: BadFrogModel.radius,
        body: const Color(0xFF7B1FA2),
        belly: const Color(0xFFCE93D8),
        angry: true,
      );
    }
  }

  void _paintGoodFrogs(Canvas canvas) {
    for (final frog in engine.goodFrogs) {
      if (frog.phase == GoodFrogPhase.gone) continue;
      _drawFrog(
        canvas,
        frog.position,
        radius: GoodFrogModel.radius,
        body: const Color(0xFF29B6F6),
        belly: const Color(0xFFB3E5FC),
        happy: true,
      );
    }
  }

  void _paintBombs(Canvas canvas) {
    for (final bomb in engine.bombs) {
      if (bomb.phase == BombPhase.gone) continue;
      if (bomb.phase == BombPhase.exploding) {
        _paintBurst(canvas, bomb.position, 22);
        continue;
      }
      canvas.drawCircle(bomb.position, 9, Paint()..color = const Color(0xFF212121));
      canvas.drawCircle(
        bomb.position + const Offset(-2, -3),
        3,
        Paint()..color = const Color(0xFF757575),
      );
      canvas.drawLine(
        bomb.position + const Offset(0, -9),
        bomb.position + const Offset(4, -16),
        Paint()
          ..color = const Color(0xFFFFA000)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawFrog(
    Canvas canvas,
    Offset p, {
    required double radius,
    required Color body,
    required Color belly,
    bool angry = false,
    bool happy = false,
    bool surprised = false,
  }) {
    canvas.drawCircle(p + const Offset(0, 4), radius, Paint()..color = body);
    canvas.drawOval(
      Rect.fromCenter(
        center: p + Offset(0, radius * 0.25),
        width: radius * 1.1,
        height: radius * 0.9,
      ),
      Paint()..color = belly,
    );
    final eyeY = -radius * 0.55;
    canvas.drawCircle(p + Offset(-radius * 0.38, eyeY), radius * 0.28, Paint()..color = Colors.white);
    canvas.drawCircle(p + Offset(radius * 0.38, eyeY), radius * 0.28, Paint()..color = Colors.white);
    canvas.drawCircle(
      p + Offset(-radius * 0.38, eyeY),
      radius * (surprised ? 0.16 : 0.14),
      Paint()..color = angry ? const Color(0xFFB71C1C) : Colors.black,
    );
    canvas.drawCircle(
      p + Offset(radius * 0.38, eyeY),
      radius * (surprised ? 0.16 : 0.14),
      Paint()..color = angry ? const Color(0xFFB71C1C) : Colors.black,
    );
    if (surprised) {
      final brow = Paint()
        ..color = Colors.black87
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(
          center: p + Offset(-radius * 0.38, eyeY - radius * 0.22),
          width: radius * 0.34,
          height: radius * 0.2,
        ),
        0.1,
        pi - 0.2,
        false,
        brow,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: p + Offset(radius * 0.38, eyeY - radius * 0.22),
          width: radius * 0.34,
          height: radius * 0.2,
        ),
        0.1,
        pi - 0.2,
        false,
        brow,
      );
    }
    final mouth = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    if (surprised) {
      final mouthRect = Rect.fromCenter(
        center: p + Offset(0, radius * 0.28),
        width: radius * 0.52,
        height: radius * 0.4,
      );
      canvas.drawOval(mouthRect, Paint()..color = const Color(0xFF1B5E20));
      canvas.drawOval(mouthRect, mouth..strokeWidth = 2.6);
    } else if (angry) {
      canvas.drawArc(
        Rect.fromCenter(
          center: p + Offset(0, radius * 0.2),
          width: radius * 0.7,
          height: radius * 0.4,
        ),
        pi + 0.2,
        pi - 0.4,
        false,
        mouth,
      );
    } else if (happy) {
      canvas.drawArc(
        Rect.fromCenter(
          center: p + Offset(0, radius * 0.15),
          width: radius * 0.7,
          height: radius * 0.45,
        ),
        0.2,
        pi - 0.4,
        false,
        mouth,
      );
    }
  }

  void _paintBurst(Canvas canvas, Offset p, double r) {
    canvas.drawCircle(p, r, Paint()..color = const Color(0xFFFFEE58));
    canvas.drawCircle(p, r * 0.55, Paint()..color = const Color(0xFFFF6F00));
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(
        p,
        p + Offset(cos(a), sin(a)) * (r * 1.35),
        Paint()
          ..color = const Color(0xFFFFAB40)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
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
          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(16, tablet ? 18 : 12));

    final hint = TextPainter(
      text: const TextSpan(
        text: 'Toque na mosca para comer · toque no sapo mau para a bomba · riscar o sapo estoura',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          shadows: [Shadow(blurRadius: 3, color: Colors.black45)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 32);
    hint.paint(canvas, Offset(16, size.height * 0.84));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
