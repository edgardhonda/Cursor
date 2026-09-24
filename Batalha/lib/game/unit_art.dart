import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_models.dart';

/// Cartoon units drawn with Flutter Canvas, posed after the reference sheets.
class UnitArt {
  static void paintUnit(Canvas canvas, BattleUnit unit, Rect dest) {
    paintKind(
      canvas,
      kind: unit.type.kind,
      dest: dest,
      anim: unit.anim,
      time: unit.animTime,
      team: unit.team,
      faded: !unit.alive,
    );
  }

  static void paintKind(
    Canvas canvas, {
    required UnitKind kind,
    required Rect dest,
    UnitAnim anim = UnitAnim.idle,
    double time = 0,
    Team team = Team.left,
    bool faded = false,
  }) {
    final pose = _Pose(anim: anim, time: time);
    canvas.save();
    canvas.translate(dest.center.dx, dest.center.dy);
    canvas.scale(dest.width / 100, dest.height / 100);
    if (faded) {
      canvas.saveLayer(
        const Rect.fromLTWH(-55, -55, 110, 110),
        Paint()..color = const Color(0x99FFFFFF),
      );
    }
    _teamShadow(canvas, team, pose.jump);
    canvas.translate(0, -pose.jump);
    switch (kind) {
      case UnitKind.cachorro:
        _dog(canvas, pose);
      case UnitKind.soldado:
        _soldier(canvas, pose);
      case UnitKind.cavaleiro:
        _knight(canvas, pose);
      case UnitKind.gigante:
        _giant(canvas, pose);
      case UnitKind.arqueiro:
        _archer(canvas, pose);
      case UnitKind.canhao:
        _cannon(canvas, pose);
    }
    if (faded) canvas.restore();
    canvas.restore();
  }

  static void _teamShadow(Canvas canvas, Team team, [double jump = 0]) {
    final squash = (1 - (jump / 28).clamp(0.0, 0.55));
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 40),
        width: 52 * squash,
        height: 12 * squash,
      ),
      Paint()
        ..color = (team == Team.left
                ? const Color(0xFF2E5AA8)
                : const Color(0xFFB13228))
            .withValues(alpha: 0.28),
    );
  }
}

class _Pose {
  _Pose({required this.anim, required this.time});

  final UnitAnim anim;
  final double time;

  bool get dead => anim == UnitAnim.dead;
  bool get attacking => anim == UnitAnim.attack;
  bool get walking => anim == UnitAnim.walk;

  bool get celebrating => anim == UnitAnim.celebrate;

  double get bob => anim == UnitAnim.idle ? math.sin(time * 4) * 1.4 : 0;
  double get gait => walking ? time * math.pi * 6 : 0;
  double get swing => walking ? math.sin(gait) : 0;
  double get attackT => attacking ? (time / 0.28).clamp(0.0, 1.0) : 0;

  double get jump {
    if (!celebrating || time < 0) return 0;
    const period = 0.48;
    final cycle = (time % period) / period;
    final lift = cycle < 0.72 ? math.sin(cycle / 0.72 * math.pi) : 0.0;
    return lift * 22;
  }
}

const _ink = Color(0xFF2B2118);
const _dogFur = Color(0xFFC9965A);
const _dogDark = Color(0xFFA8763E);
const _skin = Color(0xFFE2B48A);
const _green = Color(0xFF4A8A4A);
const _greenDark = Color(0xFF2F6234);
const _helm = Color(0xFF8E9A8C);
const _steel = Color(0xFF8E99A8);
const _horse = Color(0xFF8A5A32);
const _horseDark = Color(0xFF6A4224);
const _plume = Color(0xFF3F78C8);
const _wood = Color(0xFF7A4A24);
const _log = Color(0xFF8B6234);
const _grey = Color(0xFFB0B0B4);
const _greyDark = Color(0xFF8A8A90);
const _cloth = Color(0xFF8B5A32);
const _blond = Color(0xFFE2C45A);
const _iron = Color(0xFF4A4A4E);
const _ironLight = Color(0xFF6A6A70);

void _fillStroke(
  Canvas canvas,
  Path path,
  Color color, {
  double width = 2.1,
}) {
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(
    path,
    Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round,
  );
}

void _oval(Canvas canvas, Rect rect, Color color, {double width = 2.1}) {
  canvas.drawOval(rect, Paint()..color = color);
  canvas.drawOval(
    rect,
    Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width,
  );
}

void _rrect(
  Canvas canvas,
  RRect rrect,
  Color color, {
  double width = 2.1,
}) {
  canvas.drawRRect(rrect, Paint()..color = color);
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width,
  );
}

void _line(Canvas canvas, Offset a, Offset b, {double width = 2.6}) {
  canvas.drawLine(
    a,
    b,
    Paint()
      ..color = _ink
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
}

void _limb(
  Canvas canvas,
  Offset hip,
  double length,
  double angle,
  Color color, {
  double thick = 7,
}) {
  canvas.save();
  canvas.translate(hip.dx, hip.dy);
  canvas.rotate(angle);
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, length / 2), width: thick, height: length),
      const Radius.circular(4),
    ),
    color,
  );
  canvas.restore();
}

void _dog(Canvas canvas, _Pose pose) {
  canvas.save();
  if (pose.dead) {
    canvas.translate(0, 18);
    canvas.rotate(1.15);
  } else {
    canvas.translate(pose.attacking ? 6 : 0, pose.bob + (pose.walking ? -2 : 0));
  }
  final stretch = pose.attacking ? 1.18 : 1.0;
  final legA = pose.dead ? 0.4 : pose.swing * 0.55;
  final legB = pose.dead ? 0.15 : -pose.swing * 0.55;
  _limb(canvas, const Offset(-10, 14), 18, 0.15 + legA, _dogDark, thick: 6);
  _limb(canvas, const Offset(10, 14), 18, -0.1 + legB, _dogDark, thick: 6);
  _limb(canvas, const Offset(-4, 14), 16, -0.05 + legB, _dogFur, thick: 6);
  _limb(canvas, const Offset(14, 14), 16, 0.2 + legA, _dogFur, thick: 6);
  _oval(
    canvas,
    Rect.fromCenter(
      center: Offset(pose.attacking ? 4 : 0, 4),
      width: 44 * stretch,
      height: 26,
    ),
    _dogFur,
  );
  _oval(
    canvas,
    Rect.fromCenter(center: Offset(22 * stretch, -6), width: 22, height: 20),
    _dogFur,
  );
  final ear = Path()
    ..moveTo(16, -14)
    ..lineTo(10, -26)
    ..lineTo(22, -18)
    ..close();
  _fillStroke(canvas, ear, _dogDark, width: 1.6);
  canvas.drawCircle(const Offset(26, -8), 2.1, Paint()..color = _ink);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(32, -4), width: 6, height: 4),
    Paint()..color = const Color(0xFF3A2A20),
  );
  if (pose.attacking || pose.dead) {
    final mouth = Path()
      ..moveTo(30, -1)
      ..quadraticBezierTo(36, 4, 28, 6)
      ..close();
    _fillStroke(canvas, mouth, const Color(0xFF3A1C14), width: 1.4);
  }
  if (pose.dead) {
    final tongue = Path()
      ..moveTo(32, 2)
      ..quadraticBezierTo(42, 8, 38, 4)
      ..close();
    _fillStroke(canvas, tongue, const Color(0xFFE07A8A), width: 1.3);
  }
  final tail = Path()
    ..moveTo(-22, 0)
    ..quadraticBezierTo(-32, pose.walking ? -18 + pose.swing * 6 : -14, -24, -8);
  canvas.drawPath(
    tail,
    Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round,
  );
  canvas.restore();
}

void _soldier(Canvas canvas, _Pose pose) {
  canvas.save();
  if (pose.dead) {
    canvas.translate(4, 16);
    canvas.rotate(1.25);
  } else {
    canvas.translate(0, pose.bob);
  }
  final step = pose.dead ? 0.0 : pose.swing;
  _limb(canvas, const Offset(-6, 18), 22, 0.12 + step * 0.45, const Color(0xFF3A2A20));
  _limb(canvas, const Offset(6, 18), 22, -0.08 - step * 0.45, const Color(0xFF3A2A20));
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 6), width: 22, height: 28),
      const Radius.circular(6),
    ),
    _green,
  );
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 20), width: 20, height: 12),
      const Radius.circular(4),
    ),
    _greenDark,
  );
  final spearAngle = pose.attacking ? -0.55 : (pose.walking ? -0.35 : -1.25);
  canvas.save();
  canvas.translate(pose.attacking ? 10 : 8, pose.attacking ? 0 : -6);
  canvas.rotate(spearAngle);
  _line(canvas, const Offset(0, 28), const Offset(0, -34), width: 2.4);
  final head = Path()
    ..moveTo(0, -36)
    ..lineTo(-4, -26)
    ..lineTo(4, -26)
    ..close();
  _fillStroke(canvas, head, _steel, width: 1.6);
  canvas.restore();
  if (!pose.dead) {
    _oval(
      canvas,
      Rect.fromCenter(center: Offset(-12, 8), width: 14, height: 16),
      const Color(0xFFC4A574),
    );
    canvas.drawCircle(const Offset(-12, 8), 3, Paint()..color = const Color(0xFF7A5A32));
  }
  _oval(
    canvas,
    Rect.fromCenter(center: Offset(0, -14), width: 16, height: 16),
    _skin,
  );
  if (pose.dead) {
    _oval(
      canvas,
      Rect.fromCenter(center: Offset(18, 22), width: 14, height: 10),
      _helm,
    );
  } else {
    _rrect(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -22), width: 20, height: 10),
        const Radius.circular(8),
      ),
      _helm,
    );
  }
  canvas.restore();
}

void _knight(Canvas canvas, _Pose pose) {
  canvas.save();
  if (pose.dead) {
    canvas.translate(0, 10);
    canvas.rotate(0.85);
  } else {
    canvas.translate(0, pose.bob * 0.6 + (pose.walking ? math.sin(pose.gait) * 1.5 : 0));
  }
  final gallop = pose.dead ? 0.5 : (pose.attacking ? 0.7 : pose.swing);
  _limb(canvas, const Offset(-16, 16), 20, 0.2 + gallop * 0.5, _horseDark, thick: 6);
  _limb(canvas, const Offset(-8, 16), 18, 0.05 - gallop * 0.45, _horseDark, thick: 6);
  _limb(canvas, const Offset(10, 16), 20, -0.05 + gallop * 0.4, _horseDark, thick: 6);
  _limb(canvas, const Offset(18, 16), 18, 0.15 - gallop * 0.5, _horseDark, thick: 6);
  _oval(
    canvas,
    Rect.fromCenter(center: Offset(0, 4), width: 48, height: 24),
    _horse,
  );
  _oval(
    canvas,
    Rect.fromCenter(center: Offset(24, -4), width: 16, height: 14),
    _horse,
  );
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(30, -2), width: 12, height: 8),
      const Radius.circular(4),
    ),
    _horseDark,
  );
  canvas.drawCircle(const Offset(34, -4), 1.6, Paint()..color = _ink);
  final tail = Path()
    ..moveTo(-24, 2)
    ..quadraticBezierTo(-34, 16, -28, 18);
  canvas.drawPath(
    tail,
    Paint()
      ..color = _horseDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round,
  );
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -6), width: 16, height: 10),
      const Radius.circular(3),
    ),
    const Color(0xFFA65A32),
  );
  canvas.save();
  canvas.translate(2, -18);
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 6), width: 14, height: 20),
      const Radius.circular(5),
    ),
    _steel,
  );
  _oval(
    canvas,
    Rect.fromCenter(center: Offset(0, -8), width: 12, height: 12),
    _steel,
  );
  final plume = Path()
    ..moveTo(2, -14)
    ..quadraticBezierTo(16, -28, 8, -10)
    ..close();
  _fillStroke(canvas, plume, _plume, width: 1.5);
  canvas.restore();
  final lanceY = pose.attacking ? -8.0 : (pose.walking || pose.dead ? 2.0 : -22.0);
  canvas.save();
  canvas.translate(8, lanceY);
  canvas.rotate(pose.attacking || pose.walking || pose.dead ? 0.02 : -0.9);
  _line(canvas, const Offset(-18, 0), const Offset(42, 0), width: 2.3);
  final tip = Path()
    ..moveTo(42, 0)
    ..lineTo(36, -4)
    ..lineTo(36, 4)
    ..close();
  _fillStroke(canvas, tip, _steel, width: 1.4);
  canvas.restore();
  canvas.restore();
}

void _giant(Canvas canvas, _Pose pose) {
  canvas.save();
  if (pose.dead) {
    canvas.translate(0, 16);
    canvas.rotate(1.35);
  } else {
    canvas.translate(0, pose.bob * 0.5);
  }
  final stomp = pose.dead ? 0.0 : pose.swing * 0.25;
  _limb(canvas, const Offset(-10, 18), 24, 0.08 + stomp, _greyDark, thick: 10);
  _limb(canvas, const Offset(10, 18), 24, -0.08 - stomp, _greyDark, thick: 10);
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 2), width: 36, height: 36),
      const Radius.circular(10),
    ),
    _grey,
  );
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 18), width: 28, height: 12),
      const Radius.circular(4),
    ),
    _cloth,
  );
  _oval(
    canvas,
    Rect.fromCenter(center: Offset(0, -22), width: 22, height: 20),
    _grey,
  );
  canvas.drawCircle(const Offset(-5, -24), 2, Paint()..color = _ink);
  canvas.drawCircle(const Offset(5, -24), 2, Paint()..color = _ink);
  final logAngle = pose.attacking
      ? 1.1
      : pose.walking
          ? -0.4 + pose.swing * 0.25
          : -0.15;
  final logLift = pose.attacking ? 8.0 : (pose.walking && pose.swing > 0.3 ? -16.0 : 4.0);
  canvas.save();
  canvas.translate(18, logLift);
  canvas.rotate(logAngle);
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 0), width: 14, height: 46),
      const Radius.circular(6),
    ),
    _log,
  );
  canvas.drawLine(
    const Offset(-4, -16),
    const Offset(4, -8),
    Paint()
      ..color = const Color(0xFF5A3418)
      ..strokeWidth = 1.4,
  );
  canvas.restore();
  canvas.restore();
}

void _archer(Canvas canvas, _Pose pose) {
  canvas.save();
  if (pose.dead) {
    canvas.translate(2, 18);
    canvas.rotate(0.95);
  } else {
    canvas.translate(0, pose.bob);
  }
  final step = pose.dead ? 0.0 : pose.swing;
  _limb(canvas, const Offset(-5, 18), 20, 0.1 + step * 0.4, _greenDark);
  _limb(canvas, const Offset(6, 18), 20, -0.08 - step * 0.4, _greenDark);
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 6), width: 18, height: 24),
      const Radius.circular(6),
    ),
    _green,
  );
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 18), width: 16, height: 10),
      const Radius.circular(3),
    ),
    _greenDark,
  );
  _oval(
    canvas,
    Rect.fromCenter(center: Offset(0, -14), width: 14, height: 14),
    _skin,
  );
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -20), width: 16, height: 8),
      const Radius.circular(6),
    ),
    _blond,
  );
  final bowDraw = pose.attacking ? 10.0 : 0.0;
  canvas.save();
  canvas.translate(14, -2);
  final bow = Path()
    ..moveTo(0, -18)
    ..quadraticBezierTo(16 + bowDraw * 0.2, 0, 0, 18);
  canvas.drawPath(
    bow,
    Paint()
      ..color = _wood
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round,
  );
  _line(canvas, Offset(-bowDraw, -16), Offset(-bowDraw, 16), width: 1.3);
  if (pose.attacking) {
    _line(canvas, Offset(-bowDraw, 0), const Offset(12, 0), width: 1.6);
  }
  canvas.restore();
  final quiver = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-16, -8, 7, 16),
        const Radius.circular(2),
      ),
    );
  _fillStroke(canvas, quiver, _wood, width: 1.5);
  canvas.restore();
}

void _cannon(Canvas canvas, _Pose pose) {
  canvas.save();
  if (pose.dead) {
    canvas.translate(0, 8);
    canvas.rotate(0.22);
  } else {
    canvas.translate(0, pose.walking ? math.sin(pose.gait) * 1.2 : pose.bob * 0.3);
  }
  final wheelSpin = pose.walking ? pose.time * 8 : 0.0;
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(-2, 10), width: 36, height: 22),
      const Radius.circular(4),
    ),
    _wood,
  );
  _wheel(canvas, const Offset(-16, 22), wheelSpin);
  _wheel(canvas, const Offset(12, 22), wheelSpin);
  if (pose.walking && !pose.dead) {
    _oval(
      canvas,
      Rect.fromCenter(center: Offset(-6, 26), width: 10, height: 8),
      _skin,
    );
    _oval(
      canvas,
      Rect.fromCenter(center: Offset(8, 26), width: 10, height: 8),
      _skin,
    );
  }
  canvas.save();
  canvas.translate(6, -2);
  canvas.rotate(pose.dead ? 0.35 : -0.18);
  _rrect(
    canvas,
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(10, 0), width: 46, height: 16),
      const Radius.circular(8),
    ),
    _iron,
  );
  _oval(
    canvas,
    Rect.fromCenter(center: Offset(32, 0), width: 10, height: 14),
    _ironLight,
  );
  canvas.drawCircle(const Offset(34, 0), 3.2, Paint()..color = _ink);
  if (pose.attacking) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(44, 0), width: 18, height: 10),
      Paint()..color = const Color(0xFFFFB347),
    );
    canvas.drawCircle(const Offset(50, -4), 5, Paint()..color = const Color(0x66EEEEEE));
  }
  canvas.restore();
  if (pose.dead) {
    canvas.drawCircle(const Offset(-8, -18), 6, Paint()..color = const Color(0x66AAAAAA));
    canvas.drawCircle(const Offset(4, -24), 4, Paint()..color = const Color(0x55CCCCCC));
    _rrect(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(22, 18), width: 8, height: 6),
        const Radius.circular(1),
      ),
      _wood,
    );
  }
  canvas.restore();
}

void _wheel(Canvas canvas, Offset center, double spin) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(spin);
  canvas.drawCircle(Offset.zero, 9, Paint()..color = const Color(0xFF3A2A20));
  canvas.drawCircle(
    Offset.zero,
    9,
    Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  canvas.drawCircle(Offset.zero, 2.4, Paint()..color = const Color(0xFFC4A574));
  _line(canvas, const Offset(0, -8), const Offset(0, 8), width: 1.6);
  _line(canvas, const Offset(-8, 0), const Offset(8, 0), width: 1.6);
  canvas.restore();
}
