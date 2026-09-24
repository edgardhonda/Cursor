import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.engine) : super(repaint: engine);

  final GameEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    if (engine.complete) {
      _drawTrophy(canvas, size);
      _drawStrokes(canvas);
      return;
    }
    for (final tile in engine.tiles) {
      _drawTile(canvas, tile);
    }
    _drawCenterTile(canvas);
    _drawStrokes(canvas);
  }

  void _drawStrokes(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawPoints(List<StrokePoint> points) {
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1];
        final b = points[i];
        paint
          ..color = b.color
          ..strokeWidth = b.width;
        canvas.drawLine(a.position, b.position, paint);
      }
    }

    for (final stroke in engine.activeStrokes.values) {
      drawPoints(stroke.points);
    }
    drawPoints(engine.finishedStrokes);
  }

  void _drawTile(Canvas canvas, EmojiTile tile) {
    canvas.save();
    canvas.translate(tile.bounds.center.dx, tile.bounds.center.dy);
    canvas.rotate(tile.rotation);
    final local = Rect.fromCenter(
      center: Offset.zero,
      width: tile.bounds.width,
      height: tile.bounds.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        local.shift(const Offset(2, 3)),
        const Radius.circular(13),
      ),
      Paint()..color = const Color(0x24000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(local, const Radius.circular(13)),
      Paint()..color = tile.color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(local, const Radius.circular(13)),
      Paint()
        ..color = const Color(0xff46505a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    _drawEmoji(
      canvas,
      tile.emoji,
      Offset.zero,
      min(local.width, local.height) * 0.62,
    );
    canvas.restore();
  }

  void _drawCenterTile(Canvas canvas) {
    final bounds = engine.centerTileBounds;
    if (engine.glowing) {
      final pulse = sin(engine.glowProgress * pi * 4).abs();
      for (var ring = 0; ring < 4; ring++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            bounds.inflate(8 + ring * 8 + pulse * 5),
            Radius.circular(20 + ring * 5),
          ),
          Paint()
            ..color = [
              const Color(0xffffd54f),
              const Color(0xffff8f00),
              const Color(0xff64dd17),
              const Color(0xff40c4ff),
            ][ring].withValues(alpha: 0.88 - ring * 0.14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 - ring * 0.6,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bounds.shift(const Offset(3, 5)),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0x30000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(18)),
      Paint()..color = const Color(0xffffffff),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(18)),
      Paint()
        ..color = const Color(0xff1565c0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    _drawEmoji(
      canvas,
      engine.targetEmoji,
      bounds.center,
      min(bounds.width, bounds.height) * 0.62,
    );
  }

  void _drawTrophy(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 22);
    _drawEmoji(canvas, '🏆', center, min(size.width, size.height) * 0.31);
    final painter = TextPainter(
      text: const TextSpan(
        text: 'Parabéns!',
        style: TextStyle(
          color: Color(0xff1b5e20),
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 32);
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        center.dy + min(size.width, size.height) * 0.2,
      ),
    );
  }

  void _drawEmoji(Canvas canvas, String emoji, Offset center, double fontSize) {
    final isPlainGlyph = RegExp(r'^[A-Z0-9]$').hasMatch(emoji);
    final painter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: isPlainGlyph ? fontSize * 0.92 : fontSize,
          height: 1,
          fontWeight: isPlainGlyph ? FontWeight.w800 : FontWeight.normal,
          color: isPlainGlyph ? const Color(0xff1a237e) : null,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => false;
}
