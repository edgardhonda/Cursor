import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'battle_engine.dart';
import 'unit_art.dart';

class BattlePainter extends CustomPainter {
  BattlePainter({required this.engine});

  final BattleEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    _drawField(canvas, size);
    _drawZones(canvas);
    for (final u in engine.units.where((u) => !u.alive)) {
      _drawUnit(canvas, u);
    }
    for (final u in engine.units.where((u) => u.alive)) {
      _drawUnit(canvas, u);
    }
    for (final p in engine.projectiles) {
      if (p.fromCannon) {
        _drawCannonball(canvas, p);
      } else {
        _drawArrow(canvas, p);
      }
    }
  }

  void _drawArrow(Canvas canvas, Projectile p) {
    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(p.angle);
    final shaft = Paint()
      ..color = const Color(0xFF5A3A18)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-10, 0), const Offset(8, 0), shaft);
    final head = Path()
      ..moveTo(12, 0)
      ..lineTo(4, -3.5)
      ..lineTo(4, 3.5)
      ..close();
    canvas.drawPath(head, Paint()..color = const Color(0xFF3A3A40));
    canvas.drawPath(
      head,
      Paint()
        ..color = const Color(0xFF2B2118)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final fletch = Path()
      ..moveTo(-10, 0)
      ..lineTo(-14, -3.5)
      ..moveTo(-10, 0)
      ..lineTo(-14, 3.5);
    canvas.drawPath(
      fletch,
      Paint()
        ..color = const Color(0xFF4A8A4A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _drawCannonball(Canvas canvas, Projectile p) {
    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(p.angle);
    canvas.drawCircle(
      const Offset(-9, 0),
      3.8,
      Paint()..color = const Color(0x66BBBBBB),
    );
    canvas.drawCircle(Offset.zero, 7, Paint()..color = const Color(0xFF3A3A42));
    canvas.drawCircle(
      Offset.zero,
      7,
      Paint()
        ..color = const Color(0xFF1E1E22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(
      const Offset(-2, -2.2),
      2.2,
      Paint()..color = const Color(0x88C8C8D0),
    );
    canvas.restore();
  }

  void _drawField(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF6FA35A),
    );
    final stripe = Paint()..color = const Color(0xFF7BB365);
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 14), stripe);
    }
    final path = Paint()..color = const Color(0xFFC9A36A).withValues(alpha: 0.35);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.42,
        height: size.height * 0.22,
      ),
      path,
    );
  }

  void _drawZones(Canvas canvas) {
    final left = Rect.fromLTWH(
      engine.leftOriginX,
      engine.leftOriginY,
      engine.gridCols * engine.cell,
      engine.gridRows * engine.cell,
    );
    final right = Rect.fromLTWH(
      engine.rightOriginX,
      engine.rightOriginY,
      engine.gridCols * engine.cell,
      engine.gridRows * engine.cell,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(left.inflate(4), const Radius.circular(8)),
      Paint()..color = const Color(0x553A6FCF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(right.inflate(4), const Radius.circular(8)),
      Paint()..color = const Color(0x55C4483A),
    );
    if (engine.phase == BattlePhase.setup) {
      _grid(canvas, left, const Color(0x663A6FCF));
      _grid(canvas, right, const Color(0x66C4483A));
    }
  }

  void _grid(Canvas canvas, Rect zone, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i <= engine.gridCols; i++) {
      final x = zone.left + i * engine.cell;
      canvas.drawLine(Offset(x, zone.top), Offset(x, zone.bottom), p);
    }
    for (var i = 0; i <= engine.gridRows; i++) {
      final y = zone.top + i * engine.cell;
      canvas.drawLine(Offset(zone.left, y), Offset(zone.right, y), p);
    }
  }

  void _drawUnit(Canvas canvas, BattleUnit unit) {
    final w = unit.type.size >= 2 ? 2.0 : 1.15;
    final h = unit.type.size >= 4 ? 2.0 : 1.35;
    final dest = Rect.fromCenter(
      center: Offset(unit.x, unit.y),
      width: engine.cell * w * 1.15,
      height: engine.cell * h * 1.15,
    );
    canvas.save();
    canvas.translate(unit.x, unit.y);
    if (unit.team == Team.right) canvas.scale(-1, 1);
    canvas.translate(-unit.x, -unit.y);
    UnitArt.paintUnit(canvas, unit, dest);
    canvas.restore();
    if (unit.alive && unit.hp < unit.type.defense) {
      final bar = Rect.fromCenter(
        center: Offset(unit.x, dest.top - 4),
        width: dest.width * 0.7,
        height: 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        Paint()..color = const Color(0xAA000000),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            bar.left,
            bar.top,
            bar.width * (unit.hp / unit.type.defense).clamp(0, 1),
            bar.height,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFDE3B3B),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BattlePainter oldDelegate) => true;
}
