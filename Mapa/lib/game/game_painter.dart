import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.engine, {required this.boardRect});

  final GameEngine engine;
  final Rect boardRect;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintBoard(canvas);
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final cell = engine.cells[r][c];
        if (cell.isObstacle) {
          _paintObstacle(canvas, _cellRect(r, c), cell);
        }
      }
    }
    _paintTreasureMark(canvas, _cellRect(engine.treasure.row, engine.treasure.col));
    for (final mark in engine.pathMarks) {
      _paintCommandMark(canvas, _cellRect(mark.cell.row, mark.cell.col), mark.command);
    }
    if (engine.phase != GamePhase.won) {
      _paintPirate(canvas, _cellRect(engine.pirate.row, engine.pirate.col));
      if (engine.previewCommand != null) {
        _paintCommandPreview(
          canvas,
          _cellRect(engine.pirate.row, engine.pirate.col),
          engine.previewCommand!,
        );
      }
    } else {
      // Vitória: pirata pequeno ao lado e baú em destaque por cima.
      final cell = _cellRect(engine.treasure.row, engine.treasure.col);
      _paintPirate(
        canvas,
        Rect.fromLTWH(
          cell.left,
          cell.top + cell.height * 0.35,
          cell.width * 0.45,
          cell.height * 0.55,
        ),
      );
      _paintOpenChest(canvas, cell);
    }
    if (engine.phase == GamePhase.lost && engine.now < engine.bumpFlashUntil) {
      _paintBump(canvas, _cellRect(engine.pirate.row, engine.pirate.col));
    }
  }

  Rect _cellRect(int row, int col) {
    final cellW = boardRect.width / gridSize;
    final cellH = boardRect.height / gridSize;
    return Rect.fromLTWH(
      boardRect.left + col * cellW,
      boardRect.top + row * cellH,
      cellW,
      cellH,
    );
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF81D4FA), Color(0xFF4FC3F7), Color(0xFF0288D1)],
        ).createShader(Offset.zero & size),
    );
  }

  void _paintBoard(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.inflate(8), const Radius.circular(16)),
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(12)),
      Paint()..color = const Color(0xFFFFE082),
    );

    final cellW = boardRect.width / gridSize;
    final cellH = boardRect.height / gridSize;
    final line = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 2;
    for (var i = 1; i < gridSize; i++) {
      canvas.drawLine(
        Offset(boardRect.left + i * cellW, boardRect.top),
        Offset(boardRect.left + i * cellW, boardRect.bottom),
        line,
      );
      canvas.drawLine(
        Offset(boardRect.left, boardRect.top + i * cellH),
        Offset(boardRect.right, boardRect.top + i * cellH),
        line,
      );
    }
  }

  void _paintObstacle(Canvas canvas, Rect cell, CellKind kind) {
    final c = cell.center;
    final s = min(cell.width, cell.height) * 0.34;
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, s * 0.12)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = Colors.white;

    switch (kind) {
      case CellKind.obstacleBarrel:
        _paintBarrel(canvas, c, s, fill, stroke);
      case CellKind.obstacleSword:
        _paintSword(canvas, c, s, fill, stroke);
      case CellKind.obstacleOctopus:
        _paintOctopus(canvas, c, s, fill, stroke);
      case CellKind.obstacleSkull:
        _paintSkull(canvas, c, s, fill, stroke);
      case CellKind.obstaclePalm:
        _paintPalm(canvas, c, s, fill, stroke);
      case CellKind.empty:
        break;
    }
  }

  void _paintPalm(
    Canvas canvas,
    Offset c,
    double s,
    Paint fill,
    Paint stroke,
  ) {
    final trunk = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(3.0, s * 0.18)
      ..strokeCap = StrokeCap.round;
    // Tronco levemente torto.
    final trunkPath = Path()
      ..moveTo(c.dx, c.dy + s * 0.85)
      ..quadraticBezierTo(
        c.dx + s * 0.12,
        c.dy + s * 0.35,
        c.dx,
        c.dy - s * 0.15,
      );
    canvas.drawPath(trunkPath, trunk);

    final leaf = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.2, s * 0.12)
      ..strokeCap = StrokeCap.round;
    final tips = [
      Offset(-s * 0.95, -s * 0.35),
      Offset(-s * 0.7, -s * 0.85),
      Offset(-s * 0.15, -s * 1.05),
      Offset(s * 0.35, -s * 0.95),
      Offset(s * 0.85, -s * 0.55),
      Offset(s * 0.95, -s * 0.1),
    ];
    for (final tip in tips) {
      final path = Path()
        ..moveTo(c.dx, c.dy - s * 0.1)
        ..quadraticBezierTo(
          c.dx + tip.dx * 0.45,
          c.dy - s * 0.35 + tip.dy * 0.2,
          c.dx + tip.dx,
          c.dy + tip.dy,
        );
      canvas.drawPath(path, leaf);
    }

    // Coco.
    canvas.drawCircle(c + Offset(s * 0.14, -s * 0.02), s * 0.12, fill);
    canvas.drawCircle(c + Offset(s * 0.14, -s * 0.02), s * 0.12, stroke);
  }

  void _paintSword(
    Canvas canvas,
    Offset c,
    double s,
    Paint fill,
    Paint stroke,
  ) {
    // Coordenadas locais: pommel em (-1,-1), ponta em (+1,+1), diagonal.
    Offset p(double x, double y) => c + Offset(x * s, y * s);

    // Lâmina curva (alfange).
    final blade = Path()
      ..moveTo(p(-0.18, 0.05).dx, p(-0.18, 0.05).dy) // base esquerda (dorso)
      ..quadraticBezierTo(
        p(0.15, -0.55).dx,
        p(0.15, -0.55).dy,
        p(0.95, -0.95).dx,
        p(0.95, -0.95).dy, // ponta
      )
      ..quadraticBezierTo(
        p(0.55, -0.15).dx,
        p(0.55, -0.15).dy,
        p(0.05, 0.28).dx,
        p(0.05, 0.28).dy, // base direita (corte)
      )
      ..close();
    canvas.drawPath(blade, fill);
    canvas.drawPath(blade, stroke);

    // Entalhe interno da lâmina (dois traços curtos).
    final edgeDetail = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.6, s * 0.08)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p(0.12, -0.28), p(0.42, -0.52), edgeDetail);
    canvas.drawLine(p(0.18, -0.18), p(0.48, -0.42), edgeDetail);

    // Guarda (retângulo inclinado ~45°).
    canvas.save();
    canvas.translate(c.dx - s * 0.08, c.dy + s * 0.18);
    canvas.rotate(-pi / 4);
    final guard = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 0.55, height: s * 0.22),
      Radius.circular(s * 0.04),
    );
    canvas.drawRRect(guard, fill);
    canvas.drawRRect(guard, stroke);
    canvas.restore();

    // Empunhadura.
    canvas.save();
    canvas.translate(c.dx - s * 0.42, c.dy + s * 0.52);
    canvas.rotate(-pi / 4);
    final grip = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 0.42, height: s * 0.16),
      Radius.circular(s * 0.04),
    );
    canvas.drawRRect(grip, fill);
    canvas.drawRRect(grip, stroke);
    canvas.restore();

    // Pomo.
    final pommel = p(-0.72, 0.82);
    canvas.drawCircle(pommel, s * 0.14, fill);
    canvas.drawCircle(pommel, s * 0.14, stroke);
  }

  void _paintBarrel(
    Canvas canvas,
    Offset c,
    double s,
    Paint fill,
    Paint stroke,
  ) {
    final topY = c.dy - s * 0.9;
    final botY = c.dy + s * 0.9;
    final midY = c.dy;
    final endHalfW = s * 0.58;
    final midHalfW = s * 0.92;

    double halfAt(double y) {
      final t = ((y - topY) / (botY - topY)).clamp(0.0, 1.0);
      // Curva em barril: mais largo no meio.
      final bulge = 1 - (2 * t - 1).abs();
      return endHalfW + (midHalfW - endHalfW) * bulge;
    }

    final outline = Path()
      ..moveTo(c.dx - endHalfW, topY)
      ..lineTo(c.dx + endHalfW, topY)
      ..cubicTo(
        c.dx + midHalfW * 1.05,
        topY + (midY - topY) * 0.35,
        c.dx + midHalfW * 1.05,
        midY + (botY - midY) * 0.35,
        c.dx + endHalfW,
        botY,
      )
      ..lineTo(c.dx - endHalfW, botY)
      ..cubicTo(
        c.dx - midHalfW * 1.05,
        midY + (botY - midY) * 0.35,
        c.dx - midHalfW * 1.05,
        topY + (midY - topY) * 0.35,
        c.dx - endHalfW,
        topY,
      )
      ..close();
    canvas.drawPath(outline, fill);
    canvas.drawPath(outline, stroke);

    final line = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, s * 0.1)
      ..strokeCap = StrokeCap.round;

    void hoop(double y, {bool doubleBand = false}) {
      final halfW = halfAt(y) - s * 0.015;
      if (doubleBand) {
        canvas.drawLine(
          Offset(c.dx - halfW, y - s * 0.07),
          Offset(c.dx + halfW, y - s * 0.07),
          line,
        );
        canvas.drawLine(
          Offset(c.dx - halfW, y + s * 0.07),
          Offset(c.dx + halfW, y + s * 0.07),
          line,
        );
      } else {
        canvas.drawLine(
          Offset(c.dx - halfW, y),
          Offset(c.dx + halfW, y),
          line,
        );
      }
    }

    hoop(topY + s * 0.12);
    hoop(midY, doubleBand: true);
    hoop(botY - s * 0.12);

    final stave = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.8, s * 0.085)
      ..strokeCap = StrokeCap.round;

    const staveTs = [-0.78, -0.47, -0.16, 0.16, 0.47, 0.78];
    final gaps = [
      (topY + s * 0.06, topY + s * 0.12 - s * 0.04),
      (topY + s * 0.12 + s * 0.04, midY - s * 0.07 - s * 0.03),
      (midY + s * 0.07 + s * 0.03, botY - s * 0.12 - s * 0.04),
      (botY - s * 0.12 + s * 0.04, botY - s * 0.06),
    ];
    for (final tx in staveTs) {
      for (final gap in gaps) {
        final path = Path();
        const steps = 8;
        for (var i = 0; i <= steps; i++) {
          final y = gap.$1 + (gap.$2 - gap.$1) * (i / steps);
          if (gap.$2 <= gap.$1) break;
          final x = c.dx + tx * halfAt(y);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, stave);
      }
    }
  }

  void _paintOctopus(
    Canvas canvas,
    Offset c,
    double s,
    Paint fill,
    Paint stroke,
  ) {
    // Tentáculos.
    final tentacles = [
      [Offset(-s * 0.15, s * 0.15), Offset(-s * 0.95, -s * 0.15), Offset(-s * 1.05, -s * 0.55)],
      [Offset(-s * 0.05, s * 0.25), Offset(-s * 0.75, s * 0.45), Offset(-s * 0.85, s * 0.05)],
      [Offset(s * 0.05, s * 0.3), Offset(-s * 0.35, s * 0.85), Offset(-s * 0.55, s * 0.55)],
      [Offset(s * 0.15, s * 0.32), Offset(s * 0.05, s * 0.95), Offset(-s * 0.15, s * 0.7)],
      [Offset(s * 0.25, s * 0.28), Offset(s * 0.55, s * 0.9), Offset(s * 0.75, s * 0.55)],
      [Offset(s * 0.3, s * 0.2), Offset(s * 0.95, s * 0.45), Offset(s * 1.05, s * 0.05)],
      [Offset(s * 0.25, s * 0.1), Offset(s * 1.0, -s * 0.05), Offset(s * 0.85, -s * 0.4)],
      [Offset(s * 0.1, s * 0.05), Offset(s * 0.55, -s * 0.35), Offset(s * 0.35, -s * 0.15)],
    ];
    for (final t in tentacles) {
      final path = Path()
        ..moveTo(c.dx + t[0].dx, c.dy + t[0].dy)
        ..quadraticBezierTo(
          c.dx + t[1].dx,
          c.dy + t[1].dy,
          c.dx + t[2].dx,
          c.dy + t[2].dy,
        );
      canvas.drawPath(path, stroke);
    }
    // Cabeça.
    final head = Rect.fromCenter(
      center: c + Offset(0, -s * 0.15),
      width: s * 1.15,
      height: s * 1.35,
    );
    canvas.drawOval(head, fill);
    canvas.drawOval(head, stroke);
    // Brilho.
    canvas.drawArc(
      Rect.fromCenter(center: c + Offset(s * 0.22, -s * 0.45), width: s * 0.35, height: s * 0.28),
      -1.2,
      1.4,
      false,
      stroke,
    );
    // Olhos e sorriso.
    canvas.drawCircle(c + Offset(-s * 0.18, -s * 0.05), s * 0.07, Paint()..color = Colors.black);
    canvas.drawCircle(c + Offset(s * 0.18, -s * 0.05), s * 0.07, Paint()..color = Colors.black);
    canvas.drawArc(
      Rect.fromCenter(center: c + Offset(0, s * 0.08), width: s * 0.28, height: s * 0.18),
      0.15,
      pi - 0.3,
      false,
      stroke,
    );
  }

  void _paintSkull(
    Canvas canvas,
    Offset c,
    double s,
    Paint fill,
    Paint stroke,
  ) {
    // Ossos cruzados atrás.
    final bone = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.4, s * 0.14)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      c + Offset(-s * 0.7, s * 0.15),
      c + Offset(s * 0.7, s * 0.85),
      bone,
    );
    canvas.drawLine(
      c + Offset(s * 0.7, s * 0.15),
      c + Offset(-s * 0.7, s * 0.85),
      bone,
    );
    for (final tip in [
      Offset(-s * 0.7, s * 0.15),
      Offset(s * 0.7, s * 0.85),
      Offset(s * 0.7, s * 0.15),
      Offset(-s * 0.7, s * 0.85),
    ]) {
      canvas.drawCircle(c + tip, s * 0.12, fill);
      canvas.drawCircle(c + tip, s * 0.12, stroke);
      canvas.drawCircle(c + tip + Offset(s * 0.08, -s * 0.02), s * 0.1, fill);
      canvas.drawCircle(c + tip + Offset(s * 0.08, -s * 0.02), s * 0.1, stroke);
    }

    // Caveira.
    final skull = Rect.fromCenter(
      center: c + Offset(0, -s * 0.05),
      width: s * 1.2,
      height: s * 1.15,
    );
    canvas.drawOval(skull, fill);
    canvas.drawOval(skull, stroke);
    // Olhos.
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-s * 0.28, -s * 0.1), width: s * 0.32, height: s * 0.38),
      Paint()..color = Colors.black,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(s * 0.28, -s * 0.1), width: s * 0.32, height: s * 0.38),
      Paint()..color = Colors.black,
    );
    // Nariz.
    final nose = Path()
      ..moveTo(c.dx, c.dy + s * 0.08)
      ..lineTo(c.dx - s * 0.1, c.dy + s * 0.28)
      ..lineTo(c.dx + s * 0.1, c.dy + s * 0.28)
      ..close();
    canvas.drawPath(nose, Paint()..color = Colors.black);
    // Dentes / queixo ondulado.
    canvas.drawArc(
      Rect.fromCenter(center: c + Offset(0, s * 0.38), width: s * 0.7, height: s * 0.28),
      0.15,
      pi - 0.3,
      false,
      stroke,
    );
    for (final x in [-0.18, 0.0, 0.18]) {
      canvas.drawLine(
        c + Offset(s * x, s * 0.32),
        c + Offset(s * x, s * 0.48),
        stroke,
      );
    }
  }

  void _paintCommandMark(Canvas canvas, Rect cell, MoveCommand cmd) {
    final c = cell.center;
    final s = min(cell.width, cell.height);
    canvas.drawCircle(
      c,
      s * 0.18,
      Paint()..color = const Color(0xFFFFF176).withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      c,
      s * 0.18,
      Paint()
        ..color = const Color(0xFFF9A825)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: cmd.label,
        style: TextStyle(
          color: const Color(0xFF1A237E),
          fontSize: s * 0.22,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintCommandPreview(Canvas canvas, Rect cell, MoveCommand cmd) {
    final c = cell.center;
    final s = min(cell.width, cell.height);
    final pulse = 0.85 + 0.15 * sin(engine.now * 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: s * 0.72 * pulse, height: s * 0.72 * pulse),
        Radius.circular(s * 0.12),
      ),
      Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: 0.88),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: s * 0.72 * pulse, height: s * 0.72 * pulse),
        Radius.circular(s * 0.12),
      ),
      Paint()
        ..color = const Color(0xFFF57F17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: cmd.label,
        style: TextStyle(
          color: const Color(0xFF1A237E),
          fontSize: s * 0.42,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(blurRadius: 2, color: Colors.white)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintTreasureMark(Canvas canvas, Rect cell) {
    if (engine.phase == GamePhase.won) return;

    final c = cell.center;
    final s = min(cell.width, cell.height);
    final paint = Paint()
      ..color = const Color(0xFFD50000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(7.0, s * 0.14)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // X “rabiscado” (traços levemente tortos, como na referência).
    final a = Path()
      ..moveTo(c.dx - s * 0.28, c.dy - s * 0.30)
      ..quadraticBezierTo(
        c.dx - s * 0.04,
        c.dy - s * 0.02,
        c.dx + s * 0.30,
        c.dy + s * 0.28,
      );
    final b = Path()
      ..moveTo(c.dx + s * 0.28, c.dy - s * 0.30)
      ..quadraticBezierTo(
        c.dx + s * 0.02,
        c.dy + s * 0.04,
        c.dx - s * 0.30,
        c.dy + s * 0.28,
      );
    canvas.drawPath(a, paint);
    canvas.drawPath(b, paint);
  }

  void _paintOpenChest(Canvas canvas, Rect cell) {
    final c = cell.center;
    final s = min(cell.width, cell.height);

    // Brilho de vitória atrás do baú.
    canvas.drawCircle(
      c,
      s * 0.42,
      Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.55),
    );

    // Corpo do baú.
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c + Offset(0, s * 0.14),
        width: s * 0.62,
        height: s * 0.36,
      ),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF8D6E63));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Tampa aberta (inclinada para trás).
    final lid = Path()
      ..moveTo(c.dx - s * 0.31, c.dy - s * 0.02)
      ..lineTo(c.dx - s * 0.28, c.dy - s * 0.34)
      ..lineTo(c.dx + s * 0.28, c.dy - s * 0.34)
      ..lineTo(c.dx + s * 0.31, c.dy - s * 0.02)
      ..close();
    canvas.drawPath(lid, Paint()..color = const Color(0xFF6D4C41));
    canvas.drawPath(
      lid,
      Paint()
        ..color = const Color(0xFF3E2723)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Interior dourado.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + Offset(0, s * 0.08),
          width: s * 0.5,
          height: s * 0.18,
        ),
        Radius.circular(s * 0.03),
      ),
      Paint()..color = const Color(0xFFFFD54F),
    );

    // Jóias.
    final jewels = [
      (const Offset(-0.14, 0.0), const Color(0xFFE53935), 0.07),
      (const Offset(-0.02, -0.06), const Color(0xFF1E88E5), 0.065),
      (const Offset(0.12, -0.02), const Color(0xFF43A047), 0.07),
      (const Offset(0.0, 0.08), const Color(0xFFFFD600), 0.06),
      (const Offset(0.16, 0.08), const Color(0xFFAB47BC), 0.055),
      (const Offset(-0.16, 0.1), const Color(0xFFFF7043), 0.05),
    ];
    for (final j in jewels) {
      final jewelCenter = c + Offset(j.$1.dx * s, j.$1.dy * s);
      canvas.drawCircle(jewelCenter, s * j.$3, Paint()..color = j.$2);
      canvas.drawCircle(
        jewelCenter + Offset(-s * j.$3 * 0.25, -s * j.$3 * 0.25),
        s * j.$3 * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }

    // Fecho dourado.
    canvas.drawCircle(
      c + Offset(0, s * 0.22),
      s * 0.055,
      Paint()..color = const Color(0xFFFFC107),
    );
  }

  void _paintPirate(Canvas canvas, Rect cell) {
    final smashed = engine.piratePhase == PiratePhase.smashed;
    final fainted = engine.piratePhase == PiratePhase.fainted;
    final dir = engine.crashDirection;

    var c = cell.center;
    var s = min(cell.width, cell.height) * 0.42;

    double squashX = 1;
    double squashY = 1;
    if (smashed && dir != null) {
      switch (dir) {
        case MoveCommand.up:
          c = Offset(c.dx, cell.top + s * 0.95);
          squashY = 0.45;
          squashX = 1.25;
        case MoveCommand.down:
          c = Offset(c.dx, cell.bottom - s * 0.85);
          squashY = 0.45;
          squashX = 1.25;
        case MoveCommand.left:
          c = Offset(cell.left + s * 0.95, c.dy);
          squashX = 0.45;
          squashY = 1.25;
        case MoveCommand.right:
          c = Offset(cell.right - s * 0.85, c.dy);
          squashX = 0.45;
          squashY = 1.25;
      }
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(squashX, squashY);

    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.2, s * 0.11)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final faceFill = Paint()..color = engine.pirateFaceColor;
    final bandanaFill = Paint()..color = engine.pirateBandanaColor;
    final ink = Paint()..color = Colors.black;

    // Contorno da cabeça + barba arredondada.
    final head = Path()
      ..moveTo(-s * 0.62, -s * 0.05)
      ..quadraticBezierTo(-s * 0.68, -s * 0.55, -s * 0.28, -s * 0.78)
      ..quadraticBezierTo(0, -s * 0.92, s * 0.28, -s * 0.78)
      ..quadraticBezierTo(s * 0.68, -s * 0.55, s * 0.62, -s * 0.05)
      ..quadraticBezierTo(s * 0.72, s * 0.55, 0, s * 0.82)
      ..quadraticBezierTo(-s * 0.72, s * 0.55, -s * 0.62, -s * 0.05)
      ..close();
    canvas.drawPath(head, faceFill);
    canvas.drawPath(head, stroke);

    // Bandana (faixa curva no topo).
    final bandana = Path()
      ..moveTo(-s * 0.58, -s * 0.28)
      ..quadraticBezierTo(-s * 0.35, -s * 0.72, 0, -s * 0.82)
      ..quadraticBezierTo(s * 0.35, -s * 0.72, s * 0.58, -s * 0.28)
      ..quadraticBezierTo(s * 0.2, -s * 0.42, 0, -s * 0.45)
      ..quadraticBezierTo(-s * 0.2, -s * 0.42, -s * 0.58, -s * 0.28)
      ..close();
    canvas.drawPath(bandana, bandanaFill);
    canvas.drawPath(bandana, stroke);

    // X na bandana.
    final xPaint = Paint()
      ..color = const Color(0xFFD50000)
      ..strokeWidth = max(2.0, s * 0.1)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-s * 0.12, -s * 0.68), Offset(s * 0.12, -s * 0.52), xPaint);
    canvas.drawLine(Offset(s * 0.12, -s * 0.68), Offset(-s * 0.12, -s * 0.52), xPaint);

    // Nó da bandana (direita do espectador).
    canvas.drawCircle(Offset(s * 0.62, -s * 0.22), s * 0.1, bandanaFill);
    canvas.drawCircle(Offset(s * 0.62, -s * 0.22), s * 0.1, stroke);
    canvas.drawLine(Offset(s * 0.68, -s * 0.18), Offset(s * 0.95, -s * 0.05), stroke);
    canvas.drawLine(Offset(s * 0.68, -s * 0.28), Offset(s * 0.92, -s * 0.42), stroke);

    // Tira do tapa-olho.
    canvas.drawLine(Offset(-s * 0.55, -s * 0.35), Offset(s * 0.55, -s * 0.05), stroke);

    if (fainted || smashed) {
      // Olhos em X (desmaio / batida).
      final eyeX = Paint()
        ..color = Colors.black
        ..strokeWidth = max(2.0, s * 0.1)
        ..strokeCap = StrokeCap.round;
      for (final side in [-1.0, 1.0]) {
        final eye = Offset(side * s * 0.28, -s * 0.12);
        canvas.drawLine(eye + Offset(-s * 0.1, -s * 0.1), eye + Offset(s * 0.1, s * 0.1), eyeX);
        canvas.drawLine(eye + Offset(s * 0.1, -s * 0.1), eye + Offset(-s * 0.1, s * 0.1), eyeX);
      }
    } else {
      // Olho esquerdo (ponto) e tapa-olho à direita.
      canvas.drawCircle(Offset(-s * 0.28, -s * 0.12), s * 0.07, ink);
      canvas.drawCircle(Offset(s * 0.28, -s * 0.08), s * 0.16, ink);
    }

    // Nariz em U.
    canvas.drawArc(
      Rect.fromCenter(center: Offset(0, s * 0.08), width: s * 0.22, height: s * 0.2),
      0.15,
      pi - 0.3,
      false,
      stroke,
    );

    // Bigode.
    final mustache = Path()
      ..moveTo(-s * 0.42, s * 0.28)
      ..quadraticBezierTo(-s * 0.28, s * 0.08, 0, s * 0.22)
      ..quadraticBezierTo(s * 0.28, s * 0.08, s * 0.42, s * 0.28)
      ..quadraticBezierTo(s * 0.22, s * 0.38, 0, s * 0.32)
      ..quadraticBezierTo(-s * 0.22, s * 0.38, -s * 0.42, s * 0.28)
      ..close();
    canvas.drawPath(mustache, ink);

    // Boca.
    canvas.drawLine(Offset(-s * 0.08, s * 0.42), Offset(s * 0.08, s * 0.42), stroke);

    // Contorno extra da barba (ondinhas).
    canvas.drawArc(
      Rect.fromCenter(center: Offset(0, s * 0.55), width: s * 1.0, height: s * 0.55),
      0.25,
      pi - 0.5,
      false,
      stroke,
    );

    if (smashed && dir != null) {
      final bruise = Paint()..color = const Color(0xFFE57373).withValues(alpha: 0.55);
      switch (dir) {
        case MoveCommand.up:
          canvas.drawOval(
            Rect.fromCenter(center: Offset(0, -s * 0.55), width: s * 0.7, height: s * 0.18),
            bruise,
          );
        case MoveCommand.down:
          canvas.drawOval(
            Rect.fromCenter(center: Offset(0, s * 0.55), width: s * 0.7, height: s * 0.18),
            bruise,
          );
        case MoveCommand.left:
          canvas.drawOval(
            Rect.fromCenter(center: Offset(-s * 0.45, 0), width: s * 0.18, height: s * 0.7),
            bruise,
          );
        case MoveCommand.right:
          canvas.drawOval(
            Rect.fromCenter(center: Offset(s * 0.45, 0), width: s * 0.18, height: s * 0.7),
            bruise,
          );
      }
    }

    canvas.restore();
  }

  void _paintBump(Canvas canvas, Rect cell) {
    final c = cell.center;
    final s = min(cell.width, cell.height);
    final paint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + engine.now * 8;
      final inner = s * 0.28;
      final outer = s * 0.48;
      canvas.drawLine(
        c + Offset(cos(a) * inner, sin(a) * inner),
        c + Offset(cos(a) * outer, sin(a) * outer),
        paint,
      );
    }
    final star = TextPainter(
      text: const TextSpan(
        text: 'BANG!',
        style: TextStyle(
          color: Color(0xFFD50000),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    star.paint(canvas, c + Offset(-star.width / 2, -s * 0.55));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
