import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.engine);

  final GameEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    final track = engine.track;
    if (track != null) {
      _paintTrack(canvas, track);
    }
    for (final ash in engine.ashes) {
      _paintAsh(canvas, ash.position);
    }
    for (final m in engine.martians) {
      _paintMartian(canvas, m);
    }
    for (final laser in engine.lasers) {
      _paintLaser(canvas, laser);
    }
    for (final scratch in engine.scratches) {
      _paintScratch(canvas, scratch);
    }
    final car = engine.car;
    if (car != null) {
      _paintCar(canvas, car);
    }
    if (engine.showTrophy && track != null) {
      _paintTrophy(canvas, track.finish);
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A237E), Color(0xFF4A148C), Color(0xFF880E4F)],
      ).createShader(rect);
    canvas.drawRect(rect, sky);

    // Solo marciano.
    final ground = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.35);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
      ground,
    );
  }

  void _paintTrack(Canvas canvas, TrackPath track) {
    if (track.points.length < 2) return;
    final path = Path()..moveTo(track.points.first.dx, track.points.first.dy);
    for (var i = 1; i < track.points.length; i++) {
      path.lineTo(track.points[i].dx, track.points[i].dy);
    }

    final shoulder = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, shoulder);

    final asphalt = Paint()
      ..color = const Color(0xFF616161)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, asphalt);

    final dash = Paint()
      ..color = const Color(0xFFFFF59D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    _drawDashedPath(canvas, path, dash, 10, 8);

    _paintStartFinish(canvas, track);
  }

  void _paintStartFinish(Canvas canvas, TrackPath track) {
    final startDir = track.tangentAt(0);
    final endDir = track.tangentAt(1);
    _paintCheckeredBand(canvas, track.start, startDir, isStart: true);
    _paintCheckeredBand(canvas, track.finish, endDir, isStart: false);
  }

  void _paintCheckeredBand(
    Canvas canvas,
    Offset center,
    Offset tangent, {
    required bool isStart,
  }) {
    final normal = Offset(-tangent.dy, tangent.dx);
    final half = 16.0;
    final cells = 6;
    for (var i = 0; i < cells; i++) {
      final t0 = -half + (2 * half) * (i / cells);
      final t1 = -half + (2 * half) * ((i + 1) / cells);
      final a = center + normal * t0 - tangent * 5;
      final b = center + normal * t1 - tangent * 5;
      final c = center + normal * t1 + tangent * 5;
      final d = center + normal * t0 + tangent * 5;
      final dark = (i % 2 == 0) ^ !isStart;
      final paint = Paint()
        ..color = dark ? Colors.black : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..lineTo(d.dx, d.dy)
          ..close(),
        paint,
      );
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dash,
    double gap,
  ) {
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  void _paintMartian(Canvas canvas, MartianModel m) {
    final r = m.radius;
    final attacking = m.phase == MartianPhase.attacking;
    final skin = attacking ? _lighten(m.color, 0.12) : m.color;
    final outline = const Color(0xFF1A1A1A);
    final highlight = _lighten(skin, 0.28);
    final center = m.position;

    switch (m.size) {
      case MartianSize.large:
        _paintMartianUfo(
          canvas,
          center,
          r,
          skin,
          highlight,
          outline,
          attacking: attacking,
        );
      case MartianSize.medium:
        _paintMartianSuit(
          canvas,
          center,
          r,
          skin,
          highlight,
          outline,
          attacking: attacking,
        );
      case MartianSize.small:
        if (attacking) {
          _paintMartianRunning(canvas, center, r, skin, highlight, outline);
        } else {
          _paintMartianStanding(canvas, center, r, skin, highlight, outline);
        }
    }

    final maxHits = m.size.maxHits;
    final lifeY = center.dy + r * 1.15;
    for (var i = 0; i < maxHits; i++) {
      final filled = i < m.hitsLeft;
      canvas.drawCircle(
        Offset(center.dx + (i - (maxHits - 1) / 2) * 7, lifeY),
        3.2,
        Paint()
          ..color = filled ? const Color(0xFFFF5252) : const Color(0xFF455A64),
      );
    }
  }

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _paintKawaiiHead(
    Canvas canvas,
    Offset head,
    double headW,
    double headH,
    Color skin,
    Color highlight,
    Color outline, {
    required _MouthStyle mouth,
  }) {
    final headRect = Rect.fromCenter(center: head, width: headW, height: headH);
    canvas.drawOval(headRect, _fill(skin));
    // Brilho no topo-esquerdo da cabeça.
    canvas.drawOval(
      Rect.fromCenter(
        center: head + Offset(-headW * 0.18, -headH * 0.22),
        width: headW * 0.42,
        height: headH * 0.32,
      ),
      _fill(highlight.withValues(alpha: 0.55)),
    );
    canvas.drawOval(headRect, _stroke(outline, max(1.6, headW * 0.045)));

    // Olhos pretos amendoados com reflexos brancos.
    final eyeW = headW * 0.28;
    final eyeH = headH * 0.38;
    final eyeY = -headH * 0.02;
    final eyeGap = headW * 0.18;
    for (final side in [-1.0, 1.0]) {
      final eye = head + Offset(side * eyeGap, eyeY);
      final eyePath = Path()
        ..addOval(Rect.fromCenter(center: eye, width: eyeW, height: eyeH));
      canvas.drawPath(eyePath, _fill(Colors.black));
      canvas.drawCircle(
        eye + Offset(-eyeW * 0.18, -eyeH * 0.22),
        eyeW * 0.16,
        _fill(Colors.white),
      );
      canvas.drawCircle(
        eye + Offset(eyeW * 0.2, eyeH * 0.08),
        eyeW * 0.08,
        _fill(Colors.white.withValues(alpha: 0.9)),
      );
    }

    final mouthCenter = head + Offset(0, headH * 0.32);
    switch (mouth) {
      case _MouthStyle.toothyGrin:
        final mouthRect = Rect.fromCenter(
          center: mouthCenter,
          width: headW * 0.42,
          height: headH * 0.22,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(mouthRect, Radius.circular(headH * 0.08)),
          _fill(Colors.white),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(mouthRect, Radius.circular(headH * 0.08)),
          _stroke(outline, max(1.2, headW * 0.035)),
        );
        // Dentes.
        final teeth = Paint()
          ..color = outline
          ..strokeWidth = max(1.0, headW * 0.03);
        for (var i = 1; i <= 3; i++) {
          final x = mouthRect.left + mouthRect.width * (i / 4);
          canvas.drawLine(
            Offset(x, mouthRect.top + 1),
            Offset(x, mouthRect.bottom - 1),
            teeth,
          );
        }
      case _MouthStyle.softSmile:
        canvas.drawArc(
          Rect.fromCenter(
            center: mouthCenter + Offset(0, -headH * 0.02),
            width: headW * 0.28,
            height: headH * 0.18,
          ),
          0.2,
          pi - 0.4,
          false,
          _stroke(outline, max(1.4, headW * 0.04)),
        );
      case _MouthStyle.openCheer:
        final mouthRect = Rect.fromCenter(
          center: mouthCenter,
          width: headW * 0.28,
          height: headH * 0.26,
        );
        canvas.drawOval(mouthRect, _fill(const Color(0xFF3E2723)));
        canvas.drawOval(mouthRect, _stroke(outline, max(1.2, headW * 0.035)));
        canvas.drawOval(
          Rect.fromCenter(
            center: mouthCenter + Offset(0, headH * 0.04),
            width: headW * 0.14,
            height: headH * 0.1,
          ),
          _fill(const Color(0xFFE57373)),
        );
    }
  }

  void _paintPeaceHand(Canvas canvas, Offset tip, double s, Color skin, Color outline) {
    final finger = Paint()
      ..color = skin
      ..strokeWidth = max(2.0, s * 0.55)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(tip, tip + Offset(-s * 0.15, -s * 1.1), finger);
    canvas.drawLine(tip, tip + Offset(s * 0.35, -s * 1.0), finger);
    canvas.drawCircle(tip, s * 0.45, _fill(skin));
    canvas.drawCircle(tip, s * 0.45, _stroke(outline, max(1.0, s * 0.18)));
  }

  void _paintMartianStanding(
    Canvas canvas,
    Offset center,
    double r,
    Color skin,
    Color highlight,
    Color outline,
  ) {
    final head = center + Offset(0, -r * 0.28);
    final headW = r * 1.15;
    final headH = r * 1.05;
    final bodyTop = center + Offset(0, r * 0.28);

    // Braços erguidos com V.
    final arm = Paint()
      ..color = skin
      ..strokeWidth = max(3.0, r * 0.16)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final leftHand = bodyTop + Offset(-r * 0.85, -r * 0.15);
    final rightHand = bodyTop + Offset(r * 0.85, -r * 0.15);
    canvas.drawLine(bodyTop + Offset(-r * 0.18, r * 0.05), leftHand, arm);
    canvas.drawLine(bodyTop + Offset(r * 0.18, r * 0.05), rightHand, arm);
    _paintPeaceHand(canvas, leftHand, r * 0.18, skin, outline);
    _paintPeaceHand(canvas, rightHand, r * 0.18, skin, outline);

    // Corpo pequenino.
    final bodyRect = Rect.fromCenter(
      center: bodyTop + Offset(0, r * 0.22),
      width: r * 0.55,
      height: r * 0.55,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(r * 0.18)),
      _fill(skin),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(r * 0.18)),
      _stroke(outline, max(1.4, r * 0.04)),
    );

    // Pernas.
    final leg = Paint()
      ..color = skin
      ..strokeWidth = max(3.0, r * 0.14)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      bodyTop + Offset(-r * 0.12, r * 0.45),
      bodyTop + Offset(-r * 0.18, r * 0.78),
      leg,
    );
    canvas.drawLine(
      bodyTop + Offset(r * 0.12, r * 0.45),
      bodyTop + Offset(r * 0.18, r * 0.78),
      leg,
    );

    _paintKawaiiHead(
      canvas,
      head,
      headW,
      headH,
      skin,
      highlight,
      outline,
      mouth: _MouthStyle.toothyGrin,
    );
  }

  void _paintMartianRunning(
    Canvas canvas,
    Offset center,
    double r,
    Color skin,
    Color highlight,
    Color outline,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.18);

    final head = Offset(r * 0.08, -r * 0.32);
    final body = Offset(0, r * 0.28);
    final arm = Paint()
      ..color = skin
      ..strokeWidth = max(3.0, r * 0.15)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final leg = Paint()
      ..color = skin
      ..strokeWidth = max(3.0, r * 0.15)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Braço da frente (erguido) e de trás.
    canvas.drawLine(body + Offset(-r * 0.1, 0), Offset(-r * 0.55, -r * 0.35), arm);
    canvas.drawLine(body + Offset(r * 0.1, 0), Offset(r * 0.7, r * 0.05), arm);
    canvas.drawCircle(Offset(-r * 0.55, -r * 0.35), r * 0.12, _fill(skin));
    canvas.drawCircle(Offset(r * 0.7, r * 0.05), r * 0.12, _fill(skin));

    final bodyRect = Rect.fromCenter(
      center: body + Offset(0, r * 0.12),
      width: r * 0.5,
      height: r * 0.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(r * 0.16)),
      _fill(skin),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(r * 0.16)),
      _stroke(outline, max(1.4, r * 0.04)),
    );

    // Pernas em corrida.
    canvas.drawLine(body + Offset(-r * 0.08, r * 0.3), Offset(-r * 0.55, r * 0.55), leg);
    canvas.drawLine(body + Offset(r * 0.08, r * 0.3), Offset(r * 0.45, r * 0.75), leg);

    _paintKawaiiHead(
      canvas,
      head,
      r * 1.1,
      r * 1.0,
      skin,
      highlight,
      outline,
      mouth: _MouthStyle.openCheer,
    );
    canvas.restore();
  }

  void _paintMartianSuit(
    Canvas canvas,
    Offset center,
    double r,
    Color skin,
    Color highlight,
    Color outline, {
    required bool attacking,
  }) {
    const suit = Color(0xFF81D4FA);
    const suitDark = Color(0xFF4FC3F7);
    const accent = Color(0xFF7E57C2);
    final bodyCenter = center + Offset(0, r * 0.22);
    final head = center + Offset(0, -r * 0.22);

    // Traje.
    final suitRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: bodyCenter, width: r * 0.95, height: r * 1.05),
      Radius.circular(r * 0.28),
    );
    canvas.drawRRect(suitRect, _fill(suit));
    canvas.drawRRect(suitRect, _stroke(outline, max(1.5, r * 0.04)));
    // Cinto roxo.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: bodyCenter + Offset(0, r * 0.12),
          width: r * 0.95,
          height: r * 0.16,
        ),
        Radius.circular(r * 0.04),
      ),
      _fill(accent),
    );
    canvas.drawCircle(bodyCenter + Offset(0, r * 0.12), r * 0.1, _fill(suitDark));

    // Braços / luvas.
    final arm = Paint()
      ..color = suit
      ..strokeWidth = max(4.0, r * 0.2)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      bodyCenter + Offset(-r * 0.35, -r * 0.1),
      bodyCenter + Offset(-r * 0.85, r * 0.15),
      arm,
    );
    canvas.drawLine(
      bodyCenter + Offset(r * 0.35, -r * 0.05),
      bodyCenter + Offset(r * 0.9, r * 0.05),
      arm,
    );
    canvas.drawCircle(
      bodyCenter + Offset(-r * 0.85, r * 0.15),
      r * 0.16,
      _fill(accent),
    );
    final gunHand = bodyCenter + Offset(r * 0.9, r * 0.05);
    canvas.drawCircle(gunHand, r * 0.16, _fill(accent));

    // Ray gun.
    final gunBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(gunHand.dx + r * 0.05, gunHand.dy - r * 0.12, r * 0.55, r * 0.22),
      Radius.circular(r * 0.06),
    );
    canvas.drawRRect(gunBody, _fill(const Color(0xFFFFEE58)));
    canvas.drawRRect(gunBody, _stroke(outline, 1.2));
    canvas.drawCircle(
      Offset(gunHand.dx + r * 0.25, gunHand.dy),
      r * 0.1,
      _fill(const Color(0xFFE53935)),
    );
    canvas.drawCircle(
      Offset(gunHand.dx + r * 0.55, gunHand.dy),
      r * 0.08,
      _fill(const Color(0xFFE53935)),
    );

    // Botas.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: bodyCenter + Offset(-r * 0.22, r * 0.58),
          width: r * 0.28,
          height: r * 0.22,
        ),
        Radius.circular(r * 0.08),
      ),
      _fill(accent),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: bodyCenter + Offset(r * 0.22, r * 0.58),
          width: r * 0.28,
          height: r * 0.22,
        ),
        Radius.circular(r * 0.08),
      ),
      _fill(accent),
    );

    // Capacete bolha.
    final helmetR = r * 0.62;
    canvas.drawCircle(
      head,
      helmetR,
      _fill(const Color(0xFFB3E5FC).withValues(alpha: 0.35)),
    );
    canvas.drawCircle(head, helmetR, _stroke(const Color(0xFF81D4FA), max(2.0, r * 0.05)));
    canvas.drawArc(
      Rect.fromCircle(center: head + Offset(-helmetR * 0.15, -helmetR * 0.2), radius: helmetR * 0.55),
      -2.2,
      1.4,
      false,
      _stroke(Colors.white.withValues(alpha: 0.55), max(2.0, r * 0.04)),
    );

    _paintKawaiiHead(
      canvas,
      head,
      r * 0.95,
      r * 0.88,
      skin,
      highlight,
      outline,
      mouth: attacking ? _MouthStyle.openCheer : _MouthStyle.softSmile,
    );
  }

  void _paintMartianUfo(
    Canvas canvas,
    Offset center,
    double r,
    Color skin,
    Color highlight,
    Color outline, {
    required bool attacking,
  }) {
    const saucer = Color(0xFF7E57C2);
    const saucerDark = Color(0xFF5E35B1);
    const dome = Color(0xFF81D4FA);

    final saucerCenter = center + Offset(0, r * 0.35);
    final domeCenter = center + Offset(0, -r * 0.05);

    // Disco voador.
    final saucerRect = Rect.fromCenter(
      center: saucerCenter,
      width: r * 2.1,
      height: r * 0.55,
    );
    canvas.drawOval(saucerRect, _fill(saucer));
    canvas.drawOval(saucerRect, _stroke(outline, max(1.6, r * 0.04)));
    canvas.drawOval(
      Rect.fromCenter(
        center: saucerCenter + Offset(0, -r * 0.05),
        width: r * 1.55,
        height: r * 0.28,
      ),
      _fill(saucerDark),
    );

    // Luzes no aro.
    for (var i = 0; i < 7; i++) {
      final t = (i / 6) * 2 - 1;
      canvas.drawCircle(
        saucerCenter + Offset(t * r * 0.85, r * 0.02),
        r * 0.06,
        _fill(Colors.white),
      );
    }

    // Cúpula de vidro.
    final domeRect = Rect.fromCenter(
      center: domeCenter,
      width: r * 1.25,
      height: r * 1.15,
    );
    canvas.drawOval(domeRect, _fill(dome.withValues(alpha: 0.28)));
    canvas.drawArc(
      domeRect,
      pi,
      pi,
      false,
      _stroke(dome, max(2.0, r * 0.05)),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: domeCenter + Offset(-r * 0.2, -r * 0.25),
        width: r * 0.55,
        height: r * 0.4,
      ),
      -2.4,
      1.2,
      false,
      _stroke(Colors.white.withValues(alpha: 0.5), max(1.8, r * 0.035)),
    );

    _paintKawaiiHead(
      canvas,
      domeCenter + Offset(0, r * 0.05),
      r * 0.95,
      r * 0.85,
      skin,
      highlight,
      outline,
      mouth: attacking ? _MouthStyle.openCheer : _MouthStyle.softSmile,
    );
  }

  Color _lighten(Color c, double amount) {
    return Color.lerp(c, Colors.white, amount) ?? c;
  }

  void _paintScratch(Canvas canvas, ScratchSegment scratch) {
    final age = engine.now - scratch.createdAt;
    final life = (1.0 - age / scratchFadeSeconds).clamp(0.0, 1.0);
    if (life <= 0) return;
    final paint = Paint()
      ..color = scratch.color.withValues(alpha: 0.35 + 0.65 * life)
      ..strokeWidth = scratch.strokeWidth * (0.7 + 0.3 * life)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(scratch.from, scratch.to, paint);
    // Brilho no centro do risco.
    canvas.drawLine(
      scratch.from,
      scratch.to,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35 * life)
        ..strokeWidth = scratch.strokeWidth * 0.35
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintLaser(Canvas canvas, LaserBeam laser) {
    final tip = laser.position;
    final tail = tip - laser.direction * 28;
    final paint = Paint()
      ..color = laserColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, tip, paint);
    canvas.drawCircle(tip, 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      tip,
      7,
      Paint()
        ..color = laserColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _paintCar(Canvas canvas, CarModel car) {
    switch (car.phase) {
      case CarPhase.exploding:
        _paintBurst(canvas, car.position, 22);
        return;
      case CarPhase.burning:
        _paintFire(canvas, car.position);
        return;
      case CarPhase.ashes:
        _paintAsh(canvas, car.position);
        return;
      case CarPhase.finished:
      case CarPhase.racing:
        break;
    }

    final angle = atan2(car.direction.dy, car.direction.dx);
    canvas.save();
    canvas.translate(car.position.dx, car.position.dy);
    canvas.rotate(angle);

    // Rodas.
    final wheel = Paint()..color = const Color(0xFF212121);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-16, -14, 10, 6),
        const Radius.circular(2),
      ),
      wheel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, -14, 10, 6),
        const Radius.circular(2),
      ),
      wheel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-16, 8, 10, 6),
        const Radius.circular(2),
      ),
      wheel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 8, 10, 6),
        const Radius.circular(2),
      ),
      wheel,
    );

    // Corpo buggy.
    final body = Paint()..color = car.color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -10, 36, 20),
        const Radius.circular(5),
      ),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -16, 18, 10),
        const Radius.circular(3),
      ),
      Paint()..color = car.color.withValues(alpha: 0.85),
    );

    // Capô / grade.
    canvas.drawRect(
      const Rect.fromLTWH(10, -6, 8, 12),
      Paint()..color = const Color(0xFF37474F),
    );

    // Canhão laser no teto.
    final cannon = Paint()..color = const Color(0xFF78909C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, -26, 8, 12),
        const Radius.circular(2),
      ),
      cannon,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, -24, 14, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFFEE58),
    );

    canvas.restore();
  }

  void _paintBurst(Canvas canvas, Offset p, double r) {
    canvas.drawCircle(
      p,
      r,
      Paint()..color = const Color(0xFFFFEE58).withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      p,
      r * 0.55,
      Paint()..color = const Color(0xFFFF6F00),
    );
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(
        p,
        p + Offset(cos(a), sin(a)) * (r * 1.4),
        Paint()
          ..color = const Color(0xFFFFAB40)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintFire(Canvas canvas, Offset p) {
    final flames = [
      (const Offset(0, -18), 14.0, const Color(0xFFFFEB3B)),
      (const Offset(-8, -10), 11.0, const Color(0xFFFF9800)),
      (const Offset(8, -10), 11.0, const Color(0xFFFF5722)),
      (const Offset(0, -4), 8.0, const Color(0xFFFFCC80)),
    ];
    for (final f in flames) {
      canvas.drawOval(
        Rect.fromCenter(center: p + f.$1, width: f.$2, height: f.$2 * 1.4),
        Paint()..color = f.$3,
      );
    }
  }

  void _paintAsh(Canvas canvas, Offset p) {
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 28, height: 12),
      Paint()..color = const Color(0xFF9E9E9E),
    );
    canvas.drawOval(
      Rect.fromCenter(center: p + const Offset(4, 2), width: 18, height: 8),
      Paint()..color = const Color(0xFF757575),
    );
  }

  void _paintTrophy(Canvas canvas, Offset finish) {
    final p = finish + const Offset(0, -42);
    final cup = Paint()..color = const Color(0xFFFFD600);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: p, width: 22, height: 16),
        const Radius.circular(4),
      ),
      cup,
    );
    canvas.drawCircle(p + const Offset(0, -10), 12, cup);
    canvas.drawRect(
      Rect.fromCenter(center: p + const Offset(0, 12), width: 6, height: 10),
      Paint()..color = const Color(0xFFFFB300),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: p + const Offset(0, 20), width: 18, height: 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFF8F00),
    );
    // Alças.
    canvas.drawArc(
      Rect.fromCenter(center: p + const Offset(-14, -6), width: 12, height: 14),
      -pi / 2,
      pi,
      false,
      Paint()
        ..color = const Color(0xFFFFD600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawArc(
      Rect.fromCenter(center: p + const Offset(14, -6), width: 12, height: 14),
      pi / 2,
      pi,
      false,
      Paint()
        ..color = const Color(0xFFFFD600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}

enum _MouthStyle { toothyGrin, softSmile, openCheer }
