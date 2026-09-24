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
    final groundY = size.height * 0.72;

    final scroll = engine.scrollT;
    final dx = -scroll * size.width;

    canvas.save();
    canvas.translate(dx, 0);
    _paintSegment(canvas, size, groundY, engine.obstacles, engine.explorerX, showHero: scroll < 0.5);
    canvas.restore();

    if (engine.phase == ExplorerPhase.scrolling && engine.nextObstacles.isNotEmpty) {
      canvas.save();
      canvas.translate(dx + size.width, 0);
      _paintSegment(
        canvas,
        size,
        groundY,
        engine.nextObstacles,
        0.06,
        showHero: scroll >= 0.5,
      );
      canvas.restore();
    }
  }

  void _paintSegment(
    Canvas canvas,
    Size size,
    double groundY,
    List<PlacedObstacle> obstacles,
    double explorerX, {
    required bool showHero,
  }) {
    _paintTrees(canvas, size, groundY);
    _paintGround(canvas, size, groundY);
    for (final o in obstacles) {
      final action = obstacleCatalog[o.kind]!.action;
      final keepVisible =
          action == ResolveAction.crossOver || action == ResolveAction.climb;
      final fleeingAway = o.fleeT > 0 && o.fleeT < 1;

      if (o.cleared && !keepVisible && !fleeingAway) {
        // Destruídos / apagados / já fugiram para fora da tela.
        if (engine.phase == ExplorerPhase.resolving &&
            o == engine.activeObstacle) {
          // ainda está na animação de resolução
        } else {
          continue;
        }
      }

      // Posição: fuga para a direita (outra ponta da tela).
      final fleeX = o.x + o.fleeT * (1.2 - o.x);
      final ox = fleeX * size.width;

      final resolvingHere = engine.phase == ExplorerPhase.resolving &&
          o == engine.activeObstacle;
      // Só some no fim se for destruir/apagar (atravessar/subir/espantar ficam).
      final shouldFade = resolvingHere &&
          (action == ResolveAction.destroy ||
              action == ResolveAction.extinguish);
      final fade = shouldFade
          ? (1 - ((engine.animT / resolveSeconds - 0.55) / 0.45).clamp(0.0, 1.0))
          : 1.0;
      if (fade <= 0.02) continue;

      // Bobbing leve na fuga.
      final fleeBob = fleeingAway ? sin(engine.now * 18) * 6.0 : 0.0;

      canvas.saveLayer(
        Rect.fromCenter(
          center: Offset(ox, groundY - 60 + fleeBob),
          width: 220,
          height: 220,
        ),
        Paint()..color = Color.fromRGBO(255, 255, 255, fade),
      );
      canvas.translate(0, fleeBob);
      // Inclina um pouco ao fugir.
      if (fleeingAway || (resolvingHere && action == ResolveAction.scare)) {
        canvas.translate(ox, groundY);
        canvas.rotate(-0.12 - o.fleeT * 0.15);
        _paintObstacle(canvas, Offset.zero, o.kind, size);
      } else {
        _paintObstacle(canvas, Offset(ox, groundY), o.kind, size);
      }
      if (o.cleared && o.resolveResource == ResourceKind.board ||
          resolvingHere && engine.resolvingResource == ResourceKind.board) {
        _paintPlacedBoard(canvas, Offset(ox, groundY), size);
      }
      canvas.restore();
    }
    if (showHero) {
      final ropeSwing = engine.phase == ExplorerPhase.resolving &&
          engine.resolvingResource == ResourceKind.rope &&
          engine.activeObstacle != null;

      if (ropeSwing) {
        _paintRopeSwing(
          canvas,
          size,
          groundY,
          engine.activeObstacle!.x * size.width,
          explorerX * size.width,
        );
      } else {
        _paintExplorer(
          canvas,
          Offset(explorerX * size.width, groundY),
          size,
        );
      }

      if (engine.phase == ExplorerPhase.showcasing &&
          engine.activeObstacle != null &&
          engine.resolvingResource != null) {
        _paintResourceShowcase(
          canvas,
          Offset(engine.activeObstacle!.x * size.width, groundY),
          size,
          engine.resolvingResource!,
        );
      }
      if (engine.phase == ExplorerPhase.resolving &&
          engine.activeObstacle != null &&
          engine.resolvingResource != ResourceKind.rope &&
          engine.resolvingResource != ResourceKind.board &&
          engine.resolvingAction != ResolveAction.scare) {
        _paintResolveFx(
          canvas,
          Offset(engine.activeObstacle!.x * size.width, groundY),
          size,
        );
      }
      if (engine.phase == ExplorerPhase.resolving &&
          engine.resolvingAction == ResolveAction.scare &&
          engine.activeObstacle != null) {
        final o = engine.activeObstacle!;
        final fleeX = o.x + o.fleeT * (1.2 - o.x);
        _paintResolveFx(
          canvas,
          Offset(fleeX * size.width, groundY),
          size,
        );
      }
    }
  }

  /// Corda amarrada no topo das árvores; o explorador balança e atravessa.
  void _paintRopeSwing(
    Canvas canvas,
    Size size,
    double groundY,
    double obstacleX,
    double startX,
  ) {
    final t = Curves.easeInOut.transform(
      (engine.animT / resolveSeconds).clamp(0.0, 1.0),
    );
    // Altura do topo das árvores de fundo.
    final treeTopY = groundY - size.height * 0.38;
    final endX = obstacleX + size.width * 0.1;
    final anchor = Offset((startX + endX) * 0.5, treeTopY);
    final ropeLen = (groundY - treeTopY) * 0.92;

    double angleForX(double x) {
      final dx = (x - anchor.dx).clamp(-ropeLen + 1, ropeLen - 1);
      return asin(dx / ropeLen);
    }

    final startAngle = angleForX(startX);
    final endAngle = angleForX(endX);
    final angle = startAngle + (endAngle - startAngle) * t;
    final hang = Offset(
      anchor.dx + sin(angle) * ropeLen,
      anchor.dy + cos(angle) * ropeLen,
    );

    // Nó / amarração no galho.
    canvas.drawCircle(anchor, 6, Paint()..color = const Color(0xFF5D4037));
    canvas.drawLine(
      anchor + const Offset(-14, -4),
      anchor + const Offset(14, -2),
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Corda.
    final ropePaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(anchor, hang, ropePaint);
    // Torção leve na corda.
    canvas.drawLine(
      Offset.lerp(anchor, hang, 0.25)!,
      Offset.lerp(anchor, hang, 0.28)!,
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 2,
    );

    // Explorador pendurado, levemente inclinado com o balanço.
    canvas.save();
    canvas.translate(hang.dx, hang.dy);
    canvas.rotate(angle * 0.55);
    _paintExplorer(canvas, Offset(0, 0), size, hanging: true);
    canvas.restore();
  }

  void _paintSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF81D4FA), Color(0xFFE1F5FE), Color(0xFFC8E6C9)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  void _paintTrees(Canvas canvas, Size size, double groundY) {
    final rnd = Random(engine.segmentIndex * 97 + 13);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (0.05 + i * 0.14 + rnd.nextDouble() * 0.04);
      final h = size.height * (0.28 + rnd.nextDouble() * 0.18);
      final trunk = Paint()..color = const Color(0xFF5D4037);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, groundY - h * 0.35),
          width: size.width * 0.035,
          height: h * 0.55,
        ),
        trunk,
      );
      canvas.drawCircle(
        Offset(x, groundY - h * 0.7),
        h * 0.28,
        Paint()..color = Color.lerp(const Color(0xFF2E7D32), const Color(0xFF66BB6A), rnd.nextDouble())!,
      );
      canvas.drawCircle(
        Offset(x - h * 0.15, groundY - h * 0.55),
        h * 0.2,
        Paint()..color = const Color(0xFF388E3C),
      );
      canvas.drawCircle(
        Offset(x + h * 0.16, groundY - h * 0.58),
        h * 0.18,
        Paint()..color = const Color(0xFF43A047),
      );
    }
  }

  void _paintGround(Canvas canvas, Size size, double groundY) {
    canvas.drawRect(
      Rect.fromLTRB(0, groundY, size.width, size.height),
      Paint()..color = const Color(0xFF6D4C41),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, groundY, size.width, groundY + size.height * 0.04),
      Paint()..color = const Color(0xFF558B2F),
    );
  }

  void _paintExplorer(
    Canvas canvas,
    Offset feet,
    Size size, {
    bool hanging = false,
  }) {
    final s = min(size.width, size.height) * 0.048;
    final stroke = Paint()
      ..color = Colors.black
      ..strokeWidth = max(3.0, s * 0.28)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = Colors.black;

    var bob = 0.0;
    var jump = 0.0;
    var walkT = 0.0;
    var walking = false;
    if (!hanging) {
      if (engine.phase == ExplorerPhase.walking) {
        walking = true;
        walkT = engine.now * 9.5;
        // Sobe no apoio simples, desce no apoio duplo.
        bob = (1 - cos(walkT * 2)) * s * 0.07;
      } else if (engine.phase == ExplorerPhase.celebrating) {
        jump = (sin(engine.animT * 10).abs()) * s * 1.6;
        walkT = engine.animT * 14;
      } else if (engine.phase == ExplorerPhase.resolving &&
          engine.resolvingAction == ResolveAction.climb &&
          engine.resolvingResource != ResourceKind.rope) {
        jump = (engine.animT / resolveSeconds).clamp(0, 1) * s * 2.2;
      } else if (engine.phase == ExplorerPhase.resolving &&
          engine.resolvingAction == ResolveAction.crossOver &&
          engine.resolvingResource != ResourceKind.rope) {
        walking = true;
        walkT = engine.animT * 9;
        bob = (1 - cos(walkT * 2)) * s * 0.06;
      }
    }

    final thighLen = s * 0.9;
    final shinLen = s * 0.9;
    final armUpper = s * 0.72;
    final armLower = s * 0.68;
    final lean = walking ? s * 0.1 : 0.0;

    final hip = hanging
        ? feet + Offset(0, s * 1.55)
        : Offset(feet.dx + lean, feet.dy - thighLen - shinLen * 0.92 - bob - jump);
    final shoulder = hip + Offset(lean * 0.35, -s * 1.5);
    final headC = shoulder + Offset(lean * 0.15, -s * 0.85);
    final sad = engine.phase == ExplorerPhase.sad;

    /// IK de 2 ossos (perfil, joelho “para frente” = +x).
    (Offset, Offset) solveLimb(
      Offset root,
      Offset target,
      double upper,
      double lower, {
      bool bendForward = true,
    }) {
      var delta = target - root;
      var dist = delta.distance;
      if (dist < 0.001) {
        delta = Offset(0, upper + lower);
        dist = delta.distance;
      }
      final maxReach = upper + lower - 0.5;
      final minReach = (upper - lower).abs() + 0.5;
      if (dist > maxReach) {
        delta = delta * (maxReach / dist);
        dist = maxReach;
        target = root + delta;
      } else if (dist < minReach) {
        delta = delta * (minReach / dist);
        dist = minReach;
        target = root + delta;
      }
      final cosA =
          ((upper * upper + dist * dist - lower * lower) / (2 * upper * dist))
              .clamp(-1.0, 1.0);
      final a = acos(cosA);
      final base = atan2(delta.dx, delta.dy);
      final sign = bendForward ? 1.0 : -1.0;
      final mid = root + Offset(sin(base + sign * a) * upper, cos(base + sign * a) * upper);
      return (mid, target);
    }

    /// Alvo do pé no ciclo: apoio no chão (vai para trás) e balanço (levanta à frente).
    Offset footTarget(double phase) {
      final stride = s * 0.52;
      final lift = s * 0.38;
      final cx = cos(phase);
      final sn = sin(phase);
      // phase 0 → pé à frente; π → pé atrás.
      // sn >= 0: apoio (y = chão); sn < 0: balanço (levanta).
      final x = hip.dx - lean + cx * stride;
      final y = feet.dy + (sn < 0 ? sn * lift : 0.0);
      return Offset(x, y);
    }

    void drawLeg(double phase) {
      final target = footTarget(phase);
      final (knee, foot) = solveLimb(hip, target, thighLen, shinLen);
      canvas.drawLine(hip, knee, stroke);
      canvas.drawLine(knee, foot, stroke);
    }

    void drawArm(double phase, {required bool front}) {
      // Braço em contrafase com a perna (pé à frente → braço atrás).
      final swing = cos(phase);
      final hand = shoulder +
          Offset(
            (front ? 1 : -1) * s * 0.15 - swing * s * 0.55,
            s * 0.95 + (1 - swing.abs()) * s * 0.08,
          );
      final (elbow, end) = solveLimb(
        shoulder,
        hand,
        armUpper,
        armLower,
        bendForward: false,
      );
      canvas.drawLine(shoulder, elbow, stroke);
      canvas.drawLine(elbow, end, stroke);
    }

    if (hanging) {
      canvas.drawLine(feet, shoulder + Offset(-s * 0.15, 0), stroke);
      canvas.drawLine(feet, shoulder + Offset(s * 0.15, 0), stroke);
      canvas.drawCircle(feet, s * 0.12, fill);
      final sway = sin(engine.animT * 10);
      for (final side in [-1.0, 1.0]) {
        final target = hip +
            Offset(side * s * 0.45 + sway * s * 0.2, s * 1.55);
        final (knee, foot) = solveLimb(hip, target, thighLen * 0.95, shinLen * 0.95);
        canvas.drawLine(hip, knee, stroke);
        canvas.drawLine(knee, foot, stroke);
      }
    } else if (engine.phase == ExplorerPhase.celebrating) {
      canvas.drawLine(shoulder, shoulder + Offset(-s * 0.85, -s * 0.55), stroke);
      canvas.drawLine(shoulder, shoulder + Offset(s * 0.85, -s * 0.55), stroke);
      canvas.drawLine(hip, hip + Offset(-s * 0.75, s * 0.35), stroke);
      canvas.drawLine(hip + Offset(-s * 0.75, s * 0.35), feet + Offset(-s * 0.55, 0), stroke);
      canvas.drawLine(hip, hip + Offset(s * 0.55, s * 0.7), stroke);
      canvas.drawLine(hip + Offset(s * 0.55, s * 0.7), feet + Offset(s * 0.25, 0), stroke);
    } else if (walking) {
      drawArm(walkT, front: false);
      drawArm(walkT + pi, front: true);
      drawLeg(walkT);
      drawLeg(walkT + pi);
    } else {
      // Em pé: leve abertura e joelhos flexionados via IK.
      for (final side in [-1.0, 1.0]) {
        final target = Offset(hip.dx + side * s * 0.22, feet.dy);
        final (knee, foot) = solveLimb(hip, target, thighLen, shinLen);
        canvas.drawLine(hip, knee, stroke);
        canvas.drawLine(knee, foot, stroke);
      }
      canvas.drawLine(shoulder, shoulder + Offset(-s * 0.7, s * 0.55), stroke);
      canvas.drawLine(shoulder, shoulder + Offset(s * 0.7, s * 0.55), stroke);
    }

    canvas.drawLine(shoulder, hip, stroke);
    canvas.drawCircle(headC, s * 0.55, fill);

    if (sad) {
      final eye = Paint()
        ..color = Colors.white
        ..strokeWidth = max(1.8, s * 0.12)
        ..strokeCap = StrokeCap.round;
      for (final side in [-1.0, 1.0]) {
        final e = headC + Offset(side * s * 0.22, -s * 0.05);
        canvas.drawLine(e + Offset(-s * 0.12, -s * 0.12), e + Offset(s * 0.12, s * 0.12), eye);
        canvas.drawLine(e + Offset(s * 0.12, -s * 0.12), e + Offset(-s * 0.12, s * 0.12), eye);
      }
    }
  }

  void _paintResourceShowcase(
    Canvas canvas,
    Offset feet,
    Size size,
    ResourceKind resource,
  ) {
    final t = (engine.animT / showcaseSeconds).clamp(0.0, 1.0);
    final pop = Curves.easeOutBack.transform(t);
    final iconSize = min(size.width, size.height) * (0.22 + 0.05 * pop.clamp(0.0, 1.0));
    final midX = (feet.dx + engine.explorerX * size.width) / 2;
    final center = Offset(
      midX,
      feet.dy - min(size.height, size.width) * (0.30 + 0.03 * sin(t * pi)),
    );

    canvas.drawCircle(
      center,
      iconSize * (0.75 + 0.06 * sin(engine.now * 10)),
      Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.6),
    );
    canvas.drawCircle(
      center,
      iconSize * 0.7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pop.clamp(0.25, 1.2));
    canvas.translate(-iconSize / 2, -iconSize / 2);
    ResourceIconPainter(resource).paint(canvas, Size(iconSize, iconSize));
    canvas.restore();

    final label = TextPainter(
      text: TextSpan(
        text: resource.label,
        style: TextStyle(
          color: const Color(0xFF3E2723),
          fontSize: min(size.width, size.height) * 0.035,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(blurRadius: 4, color: Colors.white),
            Shadow(blurRadius: 2, color: Colors.white),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(center.dx - label.width / 2, center.dy + iconSize * 0.58),
    );
  }

  void _paintResolveFx(Canvas canvas, Offset at, Size size) {
    final s = min(size.width, size.height) * 0.06;
    final t = (engine.animT / resolveSeconds).clamp(0.0, 1.0);
    final action = engine.resolvingAction;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white;

    switch (action) {
      case ResolveAction.crossOver:
        if (engine.resolvingResource != ResourceKind.board) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: at + Offset(0, -s * 0.2), width: s * 3.2, height: s * 0.35),
              Radius.circular(4),
            ),
            Paint()..color = const Color(0xFF8D6E63),
          );
        }
      case ResolveAction.extinguish:
        for (var i = 0; i < 6; i++) {
          final a = -pi / 2 + i * 0.35 - 0.8;
          canvas.drawLine(
            at + Offset(0, -s),
            at + Offset(cos(a) * s * (1 + t), -s - sin(a).abs() * s * (1.5 + t)),
            paint..color = const Color(0xFF29B6F6),
          );
        }
      case ResolveAction.climb:
        canvas.drawLine(
          at + Offset(-s * 0.6, 0),
          at + Offset(-s * 0.6, -s * 3.2),
          Paint()
            ..color = const Color(0xFF6D4C41)
            ..strokeWidth = 4,
        );
        for (var i = 0; i < 5; i++) {
          final y = -s * 0.4 - i * s * 0.55;
          canvas.drawLine(at + Offset(-s * 0.9, y), at + Offset(-s * 0.3, y), Paint()..color = const Color(0xFF8D6E63)..strokeWidth = 3);
        }
      case ResolveAction.destroy:
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4 + t * 3;
          canvas.drawLine(
            at + Offset(cos(a) * s * 0.4, -s + sin(a) * s * 0.4),
            at + Offset(cos(a) * s * (1.2 + t), -s + sin(a) * s * (1.2 + t)),
            Paint()
              ..color = const Color(0xFFFFF176)
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
        }
      case ResolveAction.scare:
        canvas.drawCircle(
          at + Offset(0, -s),
          s * (0.8 + t * 1.2),
          Paint()
            ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.35 * (1 - t))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      case null:
        break;
    }
  }

  void _paintPlacedBoard(Canvas canvas, Offset at, Size size) {
    final s = min(size.width, size.height) * 0.06;
    final plank = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at + Offset(0, -s * 0.22), width: s * 3.4, height: s * 0.42),
      Radius.circular(4),
    );
    canvas.drawRRect(plank, Paint()..color = const Color(0xFF6D4C41));
    canvas.drawRRect(plank, Paint()..color = const Color(0xFF8D6E63));
    canvas.drawLine(
      at + Offset(-s * 1.2, -s * 0.22),
      at + Offset(s * 1.2, -s * 0.22),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 2,
    );
    for (final x in [-0.7, 0.0, 0.7]) {
      canvas.drawCircle(
        at + Offset(x * s, -s * 0.22),
        s * 0.05,
        Paint()..color = const Color(0xFF4E342E),
      );
    }
  }

  void _paintObstacle(Canvas canvas, Offset feet, ObstacleKind kind, Size size) {
    final s = min(size.width, size.height) * 0.075;
    switch (kind) {
      case ObstacleKind.hole:
        _obsHole(canvas, feet, s);
      case ObstacleKind.campfire:
        _obsCampfire(canvas, feet, s);
      case ObstacleKind.river:
        _obsRiver(canvas, feet, s);
      case ObstacleKind.wall:
        _obsWall(canvas, feet, s);
      case ObstacleKind.rock:
        _obsRock(canvas, feet, s);
      case ObstacleKind.quicksand:
        _obsQuicksand(canvas, feet, s);
      case ObstacleKind.ice:
        _obsIce(canvas, feet, s);
      case ObstacleKind.spikes:
        _obsSpikes(canvas, feet, s);
      case ObstacleKind.vegetation:
        _obsVegetation(canvas, feet, s);
      case ObstacleKind.tree:
        _obsTree(canvas, feet, s);
      case ObstacleKind.brokenBridge:
        _obsBrokenBridge(canvas, feet, s);
      case ObstacleKind.hurricane:
        _obsHurricane(canvas, feet, s);
      case ObstacleKind.monster:
        _obsMonster(canvas, feet, s);
      case ObstacleKind.animal:
        _obsAnimal(canvas, feet, s);
      case ObstacleKind.swarm:
        _obsSwarm(canvas, feet, s);
      case ObstacleKind.carnivorousPlant:
        _obsCarnivorousPlant(canvas, feet, s);
      case ObstacleKind.spiderWeb:
        _obsSpiderWeb(canvas, feet, s);
      case ObstacleKind.pit:
        _obsPit(canvas, feet, s);
      case ObstacleKind.lava:
        _obsLava(canvas, feet, s);
      case ObstacleKind.mud:
        _obsMud(canvas, feet, s);
      case ObstacleKind.canyon:
        _obsCanyon(canvas, feet, s);
      case ObstacleKind.fence:
        _obsFence(canvas, feet, s);
      case ObstacleKind.boulder:
        _obsBoulder(canvas, feet, s);
      case ObstacleKind.thornBush:
        _obsThornBush(canvas, feet, s);
      case ObstacleKind.fallenLog:
        _obsFallenLog(canvas, feet, s);
      case ObstacleKind.mudSlide:
        _obsMudSlide(canvas, feet, s);
      case ObstacleKind.snowDrift:
        _obsSnowDrift(canvas, feet, s);
      case ObstacleKind.electricWire:
        _obsElectricWire(canvas, feet, s);
      case ObstacleKind.tornado:
        _obsTornado(canvas, feet, s);
      case ObstacleKind.bear:
        _obsBear(canvas, feet, s);
      case ObstacleKind.snake:
        _obsSnake(canvas, feet, s);
      case ObstacleKind.beehive:
        _obsBeehive(canvas, feet, s);
      case ObstacleKind.giantMushroom:
        _obsGiantMushroom(canvas, feet, s);
      case ObstacleKind.bambooGrove:
        _obsBambooGrove(canvas, feet, s);
    }
  }

  void _obsHole(Canvas canvas, Offset feet, double s) {
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, s * 0.05), width: s * 2.8, height: s * 0.95),
      Paint()..color = const Color(0xFF3E2723),
    );
    canvas.drawOval(
      Rect.fromCenter(center: feet, width: s * 2.35, height: s * 0.7),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, -s * 0.05), width: s * 1.5, height: s * 0.35),
      Paint()..color = const Color(0xFF0D0D0D),
    );
    // Borda de terra irregular.
    final rim = Paint()
      ..color = const Color(0xFF6D4C41)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, s * 0.08);
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, s * 0.02), width: s * 2.7, height: s * 0.85),
      rim,
    );
    for (final o in [Offset(-0.9, -0.15), Offset(0.75, -0.1), Offset(-0.2, 0.25)]) {
      canvas.drawCircle(
        feet + Offset(o.dx * s, o.dy * s),
        s * 0.12,
        Paint()..color = const Color(0xFF8D6E63),
      );
    }
  }

  void _obsCampfire(Canvas canvas, Offset feet, double s) {
    // Cinzas / pedras em círculo.
    for (var i = 0; i < 7; i++) {
      final a = i * (2 * pi / 7);
      canvas.drawCircle(
        feet + Offset(cos(a) * s * 0.75, sin(a) * s * 0.28 - s * 0.05),
        s * 0.16,
        Paint()..color = Color.lerp(const Color(0xFF78909C), const Color(0xFF546E7A), i / 7)!,
      );
    }
    // Lenha em X.
    final log = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = max(4.0, s * 0.18)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(feet + Offset(-s * 0.7, -s * 0.15), feet + Offset(s * 0.7, -s * 0.45), log);
    canvas.drawLine(feet + Offset(s * 0.7, -s * 0.15), feet + Offset(-s * 0.7, -s * 0.45), log);
    // Chamas em camadas.
    void flame(Offset o, double w, double h, Color color) {
      final p = Path()
        ..moveTo(feet.dx + o.dx - w / 2, feet.dy + o.dy)
        ..quadraticBezierTo(
          feet.dx + o.dx - w * 0.15,
          feet.dy + o.dy - h * 0.55,
          feet.dx + o.dx,
          feet.dy + o.dy - h,
        )
        ..quadraticBezierTo(
          feet.dx + o.dx + w * 0.15,
          feet.dy + o.dy - h * 0.55,
          feet.dx + o.dx + w / 2,
          feet.dy + o.dy,
        )
        ..close();
      canvas.drawPath(p, Paint()..color = color);
    }

    flame(Offset(0, -s * 0.35), s * 0.95, s * 1.45, const Color(0xFFE65100));
    flame(Offset(-s * 0.18, -s * 0.3), s * 0.55, s * 1.1, const Color(0xFFFF6F00));
    flame(Offset(s * 0.2, -s * 0.32), s * 0.5, s * 1.05, const Color(0xFFFF8F00));
    flame(Offset(0, -s * 0.35), s * 0.4, s * 0.85, const Color(0xFFFFEB3B));
    // Brasa.
    canvas.drawCircle(feet + Offset(0, -s * 0.25), s * 0.18, Paint()..color = const Color(0xFFFF3D00));
  }

  void _obsRiver(Canvas canvas, Offset feet, double s) {
    final water = Rect.fromCenter(
      center: feet + Offset(0, -s * 0.08),
      width: s * 3.2,
      height: s * 1.05,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(water, Radius.circular(s * 0.2)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0277BD), Color(0xFF4FC3F7), Color(0xFF0288D1)],
        ).createShader(water),
    );
    // Margens.
    canvas.drawRect(
      Rect.fromLTRB(water.left, water.top - s * 0.08, water.right, water.top),
      Paint()..color = const Color(0xFF6D4C41),
    );
    canvas.drawRect(
      Rect.fromLTRB(water.left, water.bottom, water.right, water.bottom + s * 0.08),
      Paint()..color = const Color(0xFF6D4C41),
    );
    // Ondas.
    final wave = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, s * 0.06)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = feet.dy - s * 0.25 + i * s * 0.22;
      final path = Path()..moveTo(feet.dx - s * 1.3, y);
      for (var x = -1.2; x <= 1.2; x += 0.35) {
        path.quadraticBezierTo(
          feet.dx + (x + 0.1) * s,
          y + sin(engine.now * 3 + x * 4 + i) * s * 0.06,
          feet.dx + (x + 0.3) * s,
          y,
        );
      }
      canvas.drawPath(path, wave);
    }
    // Pedrinhas na margem.
    canvas.drawCircle(feet + Offset(-s * 1.35, s * 0.35), s * 0.1, Paint()..color = const Color(0xFF90A4AE));
    canvas.drawCircle(feet + Offset(s * 1.3, s * 0.3), s * 0.12, Paint()..color = const Color(0xFF78909C));
  }

  void _obsWall(Canvas canvas, Offset feet, double s) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: feet + Offset(0, -s * 1.45), width: s * 2.0, height: s * 2.9),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF90A4AE));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF546E7A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Tijolos.
    final mortar = Paint()
      ..color = const Color(0xFF607D8B)
      ..strokeWidth = 1.4;
    for (var row = 0; row < 6; row++) {
      final y = feet.dy - s * 0.25 - row * s * 0.45;
      canvas.drawLine(Offset(feet.dx - s, y), Offset(feet.dx + s, y), mortar);
      final offset = row.isEven ? 0.0 : s * 0.45;
      for (var col = -1; col <= 1; col++) {
        final x = feet.dx + offset + col * s * 0.9;
        if (x > feet.dx - s && x < feet.dx + s) {
          canvas.drawLine(Offset(x, y), Offset(x, y - s * 0.45), mortar);
        }
      }
    }
    // Sombra no topo.
    canvas.drawRect(
      Rect.fromLTRB(feet.dx - s, feet.dy - s * 2.9, feet.dx + s, feet.dy - s * 2.7),
      Paint()..color = const Color(0xFF78909C),
    );
  }

  void _obsRock(Canvas canvas, Offset feet, double s) {
    final rock = Path()
      ..moveTo(feet.dx - s * 1.1, feet.dy)
      ..lineTo(feet.dx - s * 1.2, feet.dy - s * 0.55)
      ..quadraticBezierTo(feet.dx - s * 0.9, feet.dy - s * 1.5, feet.dx - s * 0.2, feet.dy - s * 1.65)
      ..quadraticBezierTo(feet.dx + s * 0.55, feet.dy - s * 1.7, feet.dx + s * 1.05, feet.dy - s * 1.0)
      ..quadraticBezierTo(feet.dx + s * 1.25, feet.dy - s * 0.4, feet.dx + s * 1.05, feet.dy)
      ..close();
    canvas.drawPath(
      rock,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFF90A4AE), Color(0xFF546E7A), Color(0xFF455A64)],
        ).createShader(Rect.fromCenter(center: feet + Offset(0, -s * 0.8), width: s * 2.5, height: s * 1.8)),
    );
    canvas.drawPath(
      rock,
      Paint()
        ..color = const Color(0xFF37474F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Rachaduras e highlight.
    final crack = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(feet + Offset(-s * 0.3, -s * 1.2), feet + Offset(s * 0.1, -s * 0.5), crack);
    canvas.drawLine(feet + Offset(s * 0.35, -s * 1.35), feet + Offset(s * 0.55, -s * 0.7), crack);
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(-s * 0.45, -s * 1.15), width: s * 0.45, height: s * 0.25),
      Paint()..color = const Color(0xFFB0BEC5).withValues(alpha: 0.55),
    );
  }

  void _obsQuicksand(Canvas canvas, Offset feet, double s) {
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, s * 0.08), width: s * 3.0, height: s * 1.1),
      Paint()..color = const Color(0xFFA1887F),
    );
    canvas.drawOval(
      Rect.fromCenter(center: feet, width: s * 2.5, height: s * 0.85),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFD7CCC8), Color(0xFFBCAAA4), Color(0xFF8D6E63)],
        ).createShader(Rect.fromCenter(center: feet, width: s * 2.5, height: s * 0.85)),
    );
    // Redemoinhos.
    final swirl = Paint()
      ..color = const Color(0xFF6D4C41).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: feet + Offset(sin(engine.now) * s * 0.05, 0),
          width: s * 0.55 * i,
          height: s * 0.22 * i,
        ),
        engine.now * 2 + i,
        pi * 1.2,
        false,
        swirl,
      );
    }
    // Bolhas.
    for (final o in [Offset(-0.4, -0.1), Offset(0.35, 0.05), Offset(0.0, -0.15)]) {
      canvas.drawCircle(
        feet + Offset(o.dx * s, o.dy * s + sin(engine.now * 5 + o.dx) * s * 0.04),
        s * 0.08,
        Paint()..color = const Color(0xFFEFEBE9).withValues(alpha: 0.7),
      );
    }
  }

  void _obsIce(Canvas canvas, Offset feet, double s) {
    final ice = Path()
      ..moveTo(feet.dx - s * 0.95, feet.dy)
      ..lineTo(feet.dx - s * 1.05, feet.dy - s * 0.7)
      ..lineTo(feet.dx - s * 0.35, feet.dy - s * 1.75)
      ..lineTo(feet.dx + s * 0.45, feet.dy - s * 1.85)
      ..lineTo(feet.dx + s * 1.1, feet.dy - s * 0.9)
      ..lineTo(feet.dx + s * 0.95, feet.dy)
      ..close();
    canvas.drawPath(
      ice,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE1F5FE), Color(0xFF81D4FA), Color(0xFF4FC3F7)],
        ).createShader(Rect.fromCenter(center: feet + Offset(0, -s), width: s * 2.2, height: s * 2)),
    );
    canvas.drawPath(
      ice,
      Paint()
        ..color = const Color(0xFF0277BD).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Reflexos.
    canvas.drawLine(
      feet + Offset(-s * 0.35, -s * 1.4),
      feet + Offset(-s * 0.1, -s * 0.5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      feet + Offset(s * 0.2, -s * 1.5),
      feet + Offset(s * 0.45, -s * 0.7),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 2,
    );
  }

  void _obsSpikes(Canvas canvas, Offset feet, double s) {
    canvas.drawRect(
      Rect.fromCenter(center: feet + Offset(0, -s * 0.08), width: s * 2.6, height: s * 0.25),
      Paint()..color = const Color(0xFF5D4037),
    );
    for (var i = -3; i <= 3; i++) {
      final x = feet.dx + i * s * 0.32;
      final h = s * (0.95 + (i.abs() % 2) * 0.25);
      final spike = Path()
        ..moveTo(x - s * 0.14, feet.dy - s * 0.1)
        ..lineTo(x, feet.dy - h)
        ..lineTo(x + s * 0.14, feet.dy - s * 0.1)
        ..close();
      canvas.drawPath(
        spike,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFFCFD8DC), Color(0xFF546E7A), Color(0xFF37474F)],
          ).createShader(Rect.fromLTRB(x - s * 0.14, feet.dy - h, x + s * 0.14, feet.dy)),
      );
      canvas.drawLine(
        Offset(x - s * 0.04, feet.dy - h * 0.85),
        Offset(x - s * 0.02, feet.dy - h * 0.2),
        Paint()
          ..color = Colors.white54
          ..strokeWidth = 1.2,
      );
    }
  }

  void _obsVegetation(Canvas canvas, Offset feet, double s) {
    void bush(Offset o, double scale, Color color) {
      final c = feet + o;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: s * 1.3 * scale, height: s * 1.1 * scale),
        Paint()..color = color,
      );
      canvas.drawOval(
        Rect.fromCenter(center: c + Offset(-s * 0.35 * scale, -s * 0.15 * scale), width: s * 0.8 * scale, height: s * 0.7 * scale),
        Paint()..color = Color.lerp(color, const Color(0xFF1B5E20), 0.25)!,
      );
      canvas.drawOval(
        Rect.fromCenter(center: c + Offset(s * 0.3 * scale, -s * 0.2 * scale), width: s * 0.75 * scale, height: s * 0.65 * scale),
        Paint()..color = Color.lerp(color, const Color(0xFF66BB6A), 0.3)!,
      );
    }

    bush(Offset(-s * 0.55, -s * 0.7), 1.0, const Color(0xFF2E7D32));
    bush(Offset(s * 0.5, -s * 0.65), 0.95, const Color(0xFF388E3C));
    bush(Offset(0, -s * 1.05), 1.15, const Color(0xFF1B5E20));
    // Galhos saindo.
    final twig = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(feet + Offset(-s * 0.2, -s * 1.4), feet + Offset(-s * 0.7, -s * 1.9), twig);
    canvas.drawLine(feet + Offset(s * 0.25, -s * 1.35), feet + Offset(s * 0.75, -s * 1.85), twig);
  }

  void _obsTree(Canvas canvas, Offset feet, double s) {
    // Tronco com textura.
    final trunk = RRect.fromRectAndRadius(
      Rect.fromCenter(center: feet + Offset(0, -s * 1.0), width: s * 0.55, height: s * 2.0),
      Radius.circular(s * 0.08),
    );
    canvas.drawRRect(trunk, Paint()..color = const Color(0xFF5D4037));
    canvas.drawLine(
      feet + Offset(-s * 0.12, -s * 1.7),
      feet + Offset(-s * 0.08, -s * 0.3),
      Paint()
        ..color = const Color(0xFF3E2723)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      feet + Offset(s * 0.1, -s * 1.5),
      feet + Offset(s * 0.14, -s * 0.4),
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..strokeWidth = 1.5,
    );
    // Copa em camadas.
    void canopy(Offset o, double r, Color c) {
      canvas.drawCircle(feet + o, r, Paint()..color = c);
    }

    canopy(Offset(0, -s * 2.35), s * 0.95, const Color(0xFF1B5E20));
    canopy(Offset(-s * 0.55, -s * 2.0), s * 0.7, const Color(0xFF2E7D32));
    canopy(Offset(s * 0.55, -s * 2.05), s * 0.72, const Color(0xFF388E3C));
    canopy(Offset(0, -s * 2.55), s * 0.55, const Color(0xFF43A047));
    // Raízes.
    canvas.drawLine(feet + Offset(-s * 0.15, 0), feet + Offset(-s * 0.55, s * 0.05), Paint()..color = const Color(0xFF4E342E)..strokeWidth = 3);
    canvas.drawLine(feet + Offset(s * 0.15, 0), feet + Offset(s * 0.5, s * 0.05), Paint()..color = const Color(0xFF4E342E)..strokeWidth = 3);
  }

  void _obsBrokenBridge(Canvas canvas, Offset feet, double s) {
    // Pilares.
    canvas.drawRect(
      Rect.fromCenter(center: feet + Offset(-s * 1.35, -s * 0.35), width: s * 0.28, height: s * 0.7),
      Paint()..color = const Color(0xFF6D4C41),
    );
    canvas.drawRect(
      Rect.fromCenter(center: feet + Offset(s * 1.35, -s * 0.35), width: s * 0.28, height: s * 0.7),
      Paint()..color = const Color(0xFF6D4C41),
    );
    // Tabuas esquerda / direita com gap.
    void plank(double x0, double x1, double y, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(feet.dx + x0, feet.dy + y - s * 0.12, feet.dx + x1, feet.dy + y + s * 0.12),
          Radius.circular(2),
        ),
        Paint()..color = c,
      );
    }

    plank(-s * 1.5, -s * 0.15, -s * 0.55, const Color(0xFF8D6E63));
    plank(-s * 1.45, -s * 0.25, -s * 0.75, const Color(0xFFA1887F));
    plank(s * 0.2, s * 1.5, -s * 0.55, const Color(0xFF8D6E63));
    plank(s * 0.3, s * 1.45, -s * 0.75, const Color(0xFFA1887F));
    // Tábua quebrada caindo.
    canvas.save();
    canvas.translate(feet.dx, feet.dy - s * 0.2);
    canvas.rotate(0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * 0.7, height: s * 0.18),
        Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF6D4C41),
    );
    canvas.restore();
    // Cordas soltas.
    final rope = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCenter(center: feet + Offset(-s * 0.4, -s * 0.9), width: s * 0.8, height: s * 0.6),
      0.2,
      pi,
      false,
      rope,
    );
  }

  void _obsHurricane(Canvas canvas, Offset feet, double s) {
    final c = feet + Offset(0, -s * 1.1);
    for (var i = 5; i >= 1; i--) {
      final t = i / 5;
      canvas.drawArc(
        Rect.fromCenter(center: c, width: s * 2.4 * t, height: s * 2.0 * t),
        engine.now * 3 + i * 0.4,
        pi * 1.4,
        false,
        Paint()
          ..color = Color.lerp(const Color(0xFF90A4AE), const Color(0xFF455A64), 1 - t)!.withValues(alpha: 0.35 + t * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.5, s * 0.12 * t)
          ..strokeCap = StrokeCap.round,
      );
    }
    // Folhas voando.
    for (var i = 0; i < 6; i++) {
      final a = engine.now * 4 + i * 1.1;
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(cos(a) * s * 1.1, sin(a) * s * 0.7),
          width: s * 0.22,
          height: s * 0.12,
        ),
        Paint()..color = const Color(0xFF66BB6A),
      );
    }
  }

  void _obsMonster(Canvas canvas, Offset feet, double s) {
    final body = Rect.fromCenter(center: feet + Offset(0, -s * 1.2), width: s * 1.85, height: s * 2.2);
    canvas.drawOval(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9575CD), Color(0xFF5E35B1)],
        ).createShader(body),
    );
    // Barriga.
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, -s * 0.85), width: s * 1.1, height: s * 1.0),
      Paint()..color = const Color(0xFFB39DDB),
    );
    // Chifres.
    final horn = Paint()..color = const Color(0xFF4527A0);
    canvas.drawPath(
      Path()
        ..moveTo(feet.dx - s * 0.45, feet.dy - s * 2.0)
        ..lineTo(feet.dx - s * 0.75, feet.dy - s * 2.55)
        ..lineTo(feet.dx - s * 0.2, feet.dy - s * 2.15)
        ..close(),
      horn,
    );
    canvas.drawPath(
      Path()
        ..moveTo(feet.dx + s * 0.45, feet.dy - s * 2.0)
        ..lineTo(feet.dx + s * 0.75, feet.dy - s * 2.55)
        ..lineTo(feet.dx + s * 0.2, feet.dy - s * 2.15)
        ..close(),
      horn,
    );
    // Olhos.
    canvas.drawCircle(feet + Offset(-s * 0.35, -s * 1.45), s * 0.22, Paint()..color = Colors.white);
    canvas.drawCircle(feet + Offset(s * 0.35, -s * 1.45), s * 0.22, Paint()..color = Colors.white);
    canvas.drawCircle(feet + Offset(-s * 0.32, -s * 1.42), s * 0.1, Paint()..color = const Color(0xFFD50000));
    canvas.drawCircle(feet + Offset(s * 0.38, -s * 1.42), s * 0.1, Paint()..color = const Color(0xFFD50000));
    // Boca com dentes.
    canvas.drawArc(
      Rect.fromCenter(center: feet + Offset(0, -s * 0.95), width: s * 0.9, height: s * 0.55),
      0.15,
      pi - 0.3,
      true,
      Paint()..color = const Color(0xFF311B92),
    );
    for (final x in [-0.22, 0.0, 0.22]) {
      canvas.drawPath(
        Path()
          ..moveTo(feet.dx + x * s - s * 0.08, feet.dy - s * 1.05)
          ..lineTo(feet.dx + x * s, feet.dy - s * 0.85)
          ..lineTo(feet.dx + x * s + s * 0.08, feet.dy - s * 1.05)
          ..close(),
        Paint()..color = Colors.white,
      );
    }
  }

  void _obsAnimal(Canvas canvas, Offset feet, double s) {
    // Corpo de lobo/urso agressivo.
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(-s * 0.15, -s * 0.75), width: s * 2.0, height: s * 1.2),
      Paint()..color = const Color(0xFF6D4C41),
    );
    // Cabeça.
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(s * 0.85, -s * 1.05), width: s * 0.95, height: s * 0.85),
      Paint()..color = const Color(0xFF5D4037),
    );
    // Orelhas.
    canvas.drawPath(
      Path()
        ..moveTo(feet.dx + s * 0.55, feet.dy - s * 1.35)
        ..lineTo(feet.dx + s * 0.45, feet.dy - s * 1.7)
        ..lineTo(feet.dx + s * 0.75, feet.dy - s * 1.4)
        ..close(),
      Paint()..color = const Color(0xFF4E342E),
    );
    canvas.drawPath(
      Path()
        ..moveTo(feet.dx + s * 1.05, feet.dy - s * 1.35)
        ..lineTo(feet.dx + s * 1.2, feet.dy - s * 1.7)
        ..lineTo(feet.dx + s * 0.9, feet.dy - s * 1.4)
        ..close(),
      Paint()..color = const Color(0xFF4E342E),
    );
    // Focinho e dentes.
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(s * 1.15, -s * 0.9), width: s * 0.55, height: s * 0.4),
      Paint()..color = const Color(0xFF8D6E63),
    );
    canvas.drawCircle(feet + Offset(s * 0.75, -s * 1.15), s * 0.08, Paint()..color = const Color(0xFFFFEB3B));
    canvas.drawCircle(feet + Offset(s * 1.0, -s * 1.18), s * 0.08, Paint()..color = const Color(0xFFFFEB3B));
    canvas.drawPath(
      Path()
        ..moveTo(feet.dx + s * 1.05, feet.dy - s * 0.85)
        ..lineTo(feet.dx + s * 1.12, feet.dy - s * 0.7)
        ..lineTo(feet.dx + s * 1.2, feet.dy - s * 0.85)
        ..close(),
      Paint()..color = Colors.white,
    );
    // Pernas.
    final leg = Paint()
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = s * 0.2
      ..strokeCap = StrokeCap.round;
    for (final x in [-0.7, -0.25, 0.2, 0.55]) {
      canvas.drawLine(feet + Offset(x * s, -s * 0.35), feet + Offset(x * s, 0), leg);
    }
    // Cauda.
    canvas.drawArc(
      Rect.fromCenter(center: feet + Offset(-s * 1.1, -s * 0.9), width: s * 0.7, height: s * 0.55),
      0.5,
      pi,
      false,
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  void _obsSwarm(Canvas canvas, Offset feet, double s) {
    // Nuvem do enxame.
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, -s * 1.0), width: s * 2.4, height: s * 1.6),
      Paint()..color = const Color(0xFF455A64).withValues(alpha: 0.25),
    );
    for (var i = 0; i < 16; i++) {
      final a = i * 0.85 + engine.now * 5;
      final r = s * (0.35 + (i % 4) * 0.22);
      final p = feet + Offset(cos(a) * r * 1.3, -s + sin(a * 1.4) * r * 0.9);
      // Corpo do inseto.
      canvas.drawOval(
        Rect.fromCenter(center: p, width: s * 0.18, height: s * 0.1),
        Paint()..color = const Color(0xFF263238),
      );
      // Asas.
      canvas.drawOval(
        Rect.fromCenter(center: p + Offset(-s * 0.05, -s * 0.06), width: s * 0.14, height: s * 0.08),
        Paint()..color = const Color(0xFF90A4AE).withValues(alpha: 0.7),
      );
      canvas.drawOval(
        Rect.fromCenter(center: p + Offset(s * 0.05, -s * 0.06), width: s * 0.14, height: s * 0.08),
        Paint()..color = const Color(0xFF90A4AE).withValues(alpha: 0.7),
      );
    }
  }

  void _obsCarnivorousPlant(Canvas canvas, Offset feet, double s) {
    // Caule sinuoso.
    final stem = Path()
      ..moveTo(feet.dx, feet.dy)
      ..quadraticBezierTo(feet.dx + s * 0.35, feet.dy - s * 0.5, feet.dx, feet.dy - s * 1.0)
      ..quadraticBezierTo(feet.dx - s * 0.3, feet.dy - s * 1.35, feet.dx, feet.dy - s * 1.55);
    canvas.drawPath(
      stem,
      Paint()
        ..color = const Color(0xFF2E7D32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(4.0, s * 0.16)
        ..strokeCap = StrokeCap.round,
    );
    // Folhas.
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(-s * 0.45, -s * 0.55), width: s * 0.7, height: s * 0.35),
      Paint()..color = const Color(0xFF43A047),
    );
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(s * 0.45, -s * 0.85), width: s * 0.65, height: s * 0.32),
      Paint()..color = const Color(0xFF388E3C),
    );
    // Boca / armadilha.
    final jaw = Rect.fromCenter(center: feet + Offset(0, -s * 1.85), width: s * 1.5, height: s * 1.15);
    canvas.drawOval(jaw, Paint()..color = const Color(0xFFC62828));
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, -s * 1.75), width: s * 1.1, height: s * 0.7),
      Paint()..color = const Color(0xFF4A148C),
    );
    // Dentes.
    for (var i = -2; i <= 2; i++) {
      final x = feet.dx + i * s * 0.22;
      canvas.drawPath(
        Path()
          ..moveTo(x - s * 0.08, feet.dy - s * 1.55)
          ..lineTo(x, feet.dy - s * 1.35)
          ..lineTo(x + s * 0.08, feet.dy - s * 1.55)
          ..close(),
        Paint()..color = const Color(0xFFFFF8E1),
      );
      canvas.drawPath(
        Path()
          ..moveTo(x - s * 0.08, feet.dy - s * 2.1)
          ..lineTo(x, feet.dy - s * 1.9)
          ..lineTo(x + s * 0.08, feet.dy - s * 2.1)
          ..close(),
        Paint()..color = const Color(0xFFFFF8E1),
      );
    }
  }

  void _obsSpiderWeb(Canvas canvas, Offset feet, double s) {
    final c = feet + Offset(0, -s * 1.15);
    // Âncoras nos galhos.
    final anchor = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + Offset(-s * 1.2, -s * 0.9), c + Offset(-s * 0.3, -s * 0.2), anchor);
    canvas.drawLine(c + Offset(s * 1.2, -s * 0.85), c + Offset(s * 0.3, -s * 0.15), anchor);
    canvas.drawLine(c + Offset(-s * 1.0, s * 0.9), c + Offset(-s * 0.25, s * 0.25), anchor);
    canvas.drawLine(c + Offset(s * 1.05, s * 0.85), c + Offset(s * 0.25, s * 0.2), anchor);

    final web = Paint()
      ..color = const Color(0xFFECEFF1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: s * 0.45 * ring, height: s * 0.4 * ring),
        web,
      );
    }
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(
        c,
        c + Offset(cos(a) * s * 1.05, sin(a) * s * 0.95),
        web,
      );
    }
    // Aranha.
    canvas.drawCircle(c + Offset(s * 0.25, -s * 0.1), s * 0.16, Paint()..color = const Color(0xFF212121));
    canvas.drawCircle(c + Offset(s * 0.4, -s * 0.12), s * 0.1, Paint()..color = const Color(0xFF424242));
    final leg = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 4; i++) {
        canvas.drawLine(
          c + Offset(s * 0.25, -s * 0.1),
          c + Offset(s * 0.25 + side * s * (0.35 + i * 0.05), -s * 0.25 + i * s * 0.12),
          leg,
        );
      }
    }
  }

  void _obsPit(Canvas canvas, Offset feet, double s) {
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, s * 0.08), width: s * 3.0, height: s * 1.1),
      Paint()..color = const Color(0xFF4E342E),
    );
    canvas.drawOval(
      Rect.fromCenter(center: feet, width: s * 2.5, height: s * 0.85),
      Paint()..color = const Color(0xFF0A0A0A),
    );
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, s * 0.05), width: s * 1.2, height: s * 0.5),
      Paint()..color = const Color(0xFF000000),
    );
    final brick = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(feet + Offset(-s * 1.1, -s * 0.35), feet + Offset(s * 1.1, -s * 0.35), brick);
    canvas.drawLine(feet + Offset(-s * 0.9, s * 0.25), feet + Offset(s * 0.9, s * 0.25), brick);
  }

  void _obsLava(Canvas canvas, Offset feet, double s) {
    final pool = Rect.fromCenter(center: feet + Offset(0, -s * 0.05), width: s * 3.0, height: s * 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pool, Radius.circular(s * 0.2)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF6F00), Color(0xFFFF3D00), Color(0xFFB71C1C)],
        ).createShader(pool),
    );
    for (var i = 0; i < 5; i++) {
      final x = feet.dx + (i - 2) * s * 0.55;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, feet.dy - s * 0.15 + sin(engine.now * 4 + i) * s * 0.05), width: s * 0.35, height: s * 0.18),
        Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: 0.75),
      );
    }
    for (final o in [Offset(-1.0, 0.2), Offset(0.6, 0.15), Offset(-0.3, -0.25)]) {
      canvas.drawCircle(
        feet + Offset(o.dx * s, o.dy * s),
        s * 0.14,
        Paint()..color = const Color(0xFF78909C),
      );
    }
  }

  void _obsMud(Canvas canvas, Offset feet, double s) {
    final mud = Rect.fromCenter(center: feet + Offset(0, -s * 0.02), width: s * 2.8, height: s * 0.95);
    canvas.drawOval(
      mud,
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawOval(
      mud.inflate(s * 0.08),
      Paint()..color = const Color(0xFF4E342E).withValues(alpha: 0.5),
    );
    final bubble = Paint()..color = const Color(0xFF6D4C41);
    for (var i = 0; i < 6; i++) {
      final a = engine.now * 2 + i * 1.1;
      canvas.drawCircle(
        feet + Offset(cos(a) * s * 0.9, -s * 0.1 + sin(a * 1.3) * s * 0.2),
        s * (0.06 + (i % 3) * 0.02),
        bubble,
      );
    }
  }

  void _obsCanyon(Canvas canvas, Offset feet, double s) {
    canvas.drawRect(
      Rect.fromCenter(center: feet + Offset(0, s * 0.15), width: s * 1.1, height: s * 1.4),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    void cliff(double side) {
      final cliffPath = Path()
        ..moveTo(feet.dx + side * s * 0.55, feet.dy + s * 0.35)
        ..lineTo(feet.dx + side * s * 1.55, feet.dy - s * 2.2)
        ..lineTo(feet.dx + side * s * 1.35, feet.dy + s * 0.35)
        ..close();
      canvas.drawPath(
        cliffPath,
        Paint()
          ..shader = LinearGradient(
            begin: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
            end: side < 0 ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [Color(0xFF6D4C41), Color(0xFF8D6E63), Color(0xFF5D4037)],
          ).createShader(Rect.fromCenter(center: feet, width: s * 3, height: s * 3)),
      );
    }

    cliff(-1);
    cliff(1);
    canvas.drawLine(feet + Offset(-s * 0.55, s * 0.35), feet + Offset(s * 0.55, s * 0.35), Paint()..color = const Color(0xFF3E2723)..strokeWidth = 3);
  }

  void _obsFence(Canvas canvas, Offset feet, double s) {
    final post = Paint()..color = const Color(0xFF6D4C41);
    for (final x in [-1.0, -0.35, 0.35, 1.0]) {
      canvas.drawRect(
        Rect.fromCenter(center: feet + Offset(x * s * 0.95, -s * 1.0), width: s * 0.18, height: s * 2.1),
        post,
      );
    }
    for (var i = 0; i < 4; i++) {
      final y = feet.dy - s * (0.35 + i * 0.45);
      canvas.drawRect(
        Rect.fromLTRB(feet.dx - s * 1.05, y - s * 0.08, feet.dx + s * 1.05, y + s * 0.08),
        Paint()..color = const Color(0xFF8D6E63),
      );
    }
    for (final x in [-0.7, 0.0, 0.7]) {
      canvas.drawCircle(feet + Offset(x * s, -s * 1.85), s * 0.07, Paint()..color = const Color(0xFF5D4037));
    }
  }

  void _obsBoulder(Canvas canvas, Offset feet, double s) {
    final rock = Path()
      ..moveTo(feet.dx - s * 1.35, feet.dy - s * 0.15)
      ..lineTo(feet.dx - s * 0.95, feet.dy - s * 1.55)
      ..lineTo(feet.dx + s * 0.25, feet.dy - s * 1.75)
      ..lineTo(feet.dx + s * 1.45, feet.dy - s * 0.95)
      ..lineTo(feet.dx + s * 1.15, feet.dy - s * 0.05)
      ..close();
    canvas.drawPath(rock, Paint()..color = const Color(0xFF78909C));
    canvas.drawPath(rock, Paint()..color = const Color(0xFF455A64)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawLine(feet + Offset(-s * 0.4, -s * 1.1), feet + Offset(s * 0.5, -s * 0.55), Paint()..color = Colors.white38..strokeWidth = 2);
    canvas.drawCircle(feet + Offset(s * 0.65, -s * 1.2), s * 0.12, Paint()..color = const Color(0xFF607D8B));
  }

  void _obsThornBush(Canvas canvas, Offset feet, double s) {
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, -s * 0.85), width: s * 2.1, height: s * 1.5),
      Paint()..color = const Color(0xFF33691E),
    );
    for (var i = 0; i < 9; i++) {
      final a = -pi / 2 + (i - 4) * 0.28;
      final tip = feet + Offset(cos(a) * s * 1.05, -s * 0.85 + sin(a) * s * 0.75);
      canvas.drawLine(
        feet + Offset(cos(a) * s * 0.45, -s * 0.85 + sin(a) * s * 0.35),
        tip,
        Paint()
          ..color = const Color(0xFF8D6E63)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(tip, s * 0.06, Paint()..color = const Color(0xFFC62828));
    }
  }

  void _obsFallenLog(Canvas canvas, Offset feet, double s) {
    final log = RRect.fromRectAndRadius(
      Rect.fromCenter(center: feet + Offset(0, -s * 0.55), width: s * 2.8, height: s * 0.75),
      Radius.circular(s * 0.35),
    );
    canvas.drawRRect(log, Paint()..color = const Color(0xFF5D4037));
    canvas.drawRRect(log, Paint()..color = const Color(0xFF3E2723)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(feet + Offset(-s * 1.15, -s * 0.55), s * 0.22, Paint()..color = const Color(0xFF8D6E63));
    canvas.drawCircle(feet + Offset(-s * 1.15, -s * 0.55), s * 0.12, Paint()..color = const Color(0xFF6D4C41));
    for (final x in [-0.6, 0.0, 0.55]) {
      canvas.drawLine(
        feet + Offset(x * s, -s * 0.2),
        feet + Offset(x * s, -s * 0.9),
        Paint()..color = const Color(0xFF4E342E)..strokeWidth = 2,
      );
    }
  }

  void _obsMudSlide(Canvas canvas, Offset feet, double s) {
    final slide = Path()
      ..moveTo(feet.dx - s * 1.4, feet.dy - s * 2.0)
      ..lineTo(feet.dx + s * 1.4, feet.dy - s * 2.0)
      ..lineTo(feet.dx + s * 1.1, feet.dy + s * 0.1)
      ..lineTo(feet.dx - s * 1.1, feet.dy + s * 0.1)
      ..close();
    canvas.drawPath(slide, Paint()..color = const Color(0xFF6D4C41));
    for (var i = 0; i < 5; i++) {
      final y = feet.dy - s * (0.4 + i * 0.35);
      canvas.drawLine(
        Offset(feet.dx - s * 1.2 + i * s * 0.08, y),
        Offset(feet.dx + s * 1.2 - i * s * 0.08, y + s * 0.12),
        Paint()..color = const Color(0xFF5D4037)..strokeWidth = 3,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, s * 0.05), width: s * 2.2, height: s * 0.35),
      Paint()..color = const Color(0xFF4E342E),
    );
  }

  void _obsSnowDrift(Canvas canvas, Offset feet, double s) {
    final drift = Path()
      ..moveTo(feet.dx - s * 1.5, feet.dy + s * 0.05)
      ..quadraticBezierTo(feet.dx - s * 0.4, feet.dy - s * 1.8, feet.dx, feet.dy - s * 1.35)
      ..quadraticBezierTo(feet.dx + s * 0.5, feet.dy - s * 2.0, feet.dx + s * 1.5, feet.dy + s * 0.05)
      ..close();
    canvas.drawPath(drift, Paint()..color = const Color(0xFFECEFF1));
    canvas.drawPath(drift, Paint()..color = const Color(0xFFB0BEC5)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(-s * 0.35, -s * 0.95), width: s * 0.5, height: s * 0.22),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(s * 0.45, -s * 1.25), width: s * 0.35, height: s * 0.16),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _obsElectricWire(Canvas canvas, Offset feet, double s) {
    final pole = Paint()..color = const Color(0xFF546E7A);
    canvas.drawRect(
      Rect.fromCenter(center: feet + Offset(-s * 1.2, -s * 0.9), width: s * 0.2, height: s * 1.8),
      pole,
    );
    canvas.drawRect(
      Rect.fromCenter(center: feet + Offset(s * 1.2, -s * 0.9), width: s * 0.2, height: s * 1.8),
      pole,
    );
    final wire = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final spark = Paint()..color = const Color(0xFFFFEB3B);
    for (var i = 0; i < 3; i++) {
      final y = feet.dy - s * (0.55 + i * 0.45);
      final path = Path()
        ..moveTo(feet.dx - s * 1.2, y)
        ..quadraticBezierTo(feet.dx, y + sin(engine.now * 8 + i) * s * 0.15, feet.dx + s * 1.2, y - s * 0.08);
      canvas.drawPath(path, wire);
      canvas.drawCircle(Offset(feet.dx, y + sin(engine.now * 8 + i) * s * 0.1), s * 0.07, spark);
    }
  }

  void _obsTornado(Canvas canvas, Offset feet, double s) {
    final base = feet + Offset(0, -s * 0.2);
    final funnel = Path()
      ..moveTo(base.dx - s * 1.1, base.dy)
      ..lineTo(base.dx - s * 0.15, base.dy - s * 2.3)
      ..lineTo(base.dx + s * 0.15, base.dy - s * 2.3)
      ..lineTo(base.dx + s * 1.1, base.dy)
      ..close();
    canvas.drawPath(
      funnel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF78909C).withValues(alpha: 0.55),
            const Color(0xFF455A64).withValues(alpha: 0.85),
          ],
        ).createShader(Rect.fromCenter(center: base, width: s * 2.2, height: s * 2.4)),
    );
    for (var i = 0; i < 4; i++) {
      final t = i / 4;
      canvas.drawArc(
        Rect.fromCenter(center: base + Offset(0, -s * (0.4 + t * 1.5)), width: s * (2.0 - t * 1.2), height: s * 0.35),
        engine.now * 5 + i,
        pi * 1.2,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _obsBear(Canvas canvas, Offset feet, double s) {
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, -s * 0.95), width: s * 2.2, height: s * 1.55),
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawCircle(feet + Offset(-s * 0.55, -s * 1.75), s * 0.28, Paint()..color = const Color(0xFF4E342E));
    canvas.drawCircle(feet + Offset(s * 0.55, -s * 1.75), s * 0.28, Paint()..color = const Color(0xFF4E342E));
    canvas.drawCircle(feet + Offset(-s * 0.22, -s * 1.15), s * 0.08, Paint()..color = Colors.black);
    canvas.drawCircle(feet + Offset(s * 0.22, -s * 1.15), s * 0.08, Paint()..color = Colors.black);
    canvas.drawOval(
      Rect.fromCenter(center: feet + Offset(0, -s * 0.95), width: s * 0.35, height: s * 0.22),
      Paint()..color = const Color(0xFF3E2723),
    );
    canvas.drawArc(
      Rect.fromCenter(center: feet + Offset(0, -s * 0.75), width: s * 0.55, height: s * 0.35),
      0.2,
      pi - 0.4,
      false,
      Paint()..color = const Color(0xFFD32F2F)..style = PaintingStyle.stroke..strokeWidth = 2,
    );
  }

  void _obsSnake(Canvas canvas, Offset feet, double s) {
    final body = Path()..moveTo(feet.dx - s * 1.2, feet.dy - s * 0.2);
    for (var i = 0; i <= 8; i++) {
      final t = i / 8;
      final x = feet.dx - s * 1.2 + t * s * 2.4;
      final y = feet.dy - s * 0.35 - sin(t * pi * 2.2) * s * 0.35;
      body.lineTo(x, y);
    }
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF2E7D32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.22
        ..strokeCap = StrokeCap.round,
    );
    final headPos = Offset(feet.dx + s * 1.05, feet.dy - s * 0.55);
    canvas.drawOval(
      Rect.fromCenter(center: headPos, width: s * 0.45, height: s * 0.28),
      Paint()..color = const Color(0xFF1B5E20),
    );
    canvas.drawCircle(headPos + Offset(s * 0.12, -s * 0.05), s * 0.04, Paint()..color = Colors.red);
    canvas.drawLine(headPos + Offset(s * 0.18, 0), headPos + Offset(s * 0.32, -s * 0.04), Paint()..color = Colors.red..strokeWidth = 1.5);
  }

  void _obsBeehive(Canvas canvas, Offset feet, double s) {
    final hive = RRect.fromRectAndRadius(
      Rect.fromCenter(center: feet + Offset(0, -s * 1.05), width: s * 1.1, height: s * 1.35),
      Radius.circular(s * 0.2),
    );
    canvas.drawRRect(hive, Paint()..color = const Color(0xFFFFB300));
    for (var i = 0; i < 5; i++) {
      final y = feet.dy - s * (0.55 + i * 0.22);
      canvas.drawLine(Offset(feet.dx - s * 0.45, y), Offset(feet.dx + s * 0.45, y), Paint()..color = const Color(0xFF5D4037)..strokeWidth = 2);
    }
    canvas.drawArc(
      Rect.fromCenter(center: feet + Offset(0, -s * 1.65), width: s * 0.35, height: s * 0.25),
      pi,
      pi,
      false,
      Paint()..color = const Color(0xFF6D4C41)..style = PaintingStyle.stroke..strokeWidth = 3,
    );
    for (var i = 0; i < 8; i++) {
      final a = engine.now * 6 + i * 0.9;
      canvas.drawCircle(
        feet + Offset(cos(a) * s * 0.95, -s * 1.1 + sin(a * 1.5) * s * 0.55),
        s * 0.05,
        Paint()..color = const Color(0xFFFFEB3B),
      );
    }
  }

  void _obsGiantMushroom(Canvas canvas, Offset feet, double s) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: feet + Offset(0, -s * 0.55), width: s * 0.45, height: s * 1.1),
        Radius.circular(s * 0.1),
      ),
      Paint()..color = const Color(0xFFFFF8E1),
    );
    final cap = Rect.fromCenter(center: feet + Offset(0, -s * 1.45), width: s * 2.2, height: s * 1.2);
    canvas.drawOval(cap, Paint()..color = const Color(0xFFE53935));
    canvas.drawOval(cap, Paint()..color = const Color(0xFFB71C1C)..style = PaintingStyle.stroke..strokeWidth = 2);
    for (final o in [Offset(-0.55, -0.15), Offset(0.1, -0.25), Offset(0.55, 0.05), Offset(-0.15, 0.2)]) {
      canvas.drawCircle(feet + Offset(o.dx * s, o.dy * s - s * 1.45), s * 0.1, Paint()..color = Colors.white);
    }
  }

  void _obsBambooGrove(Canvas canvas, Offset feet, double s) {
    for (final x in [-0.95, -0.45, 0.0, 0.45, 0.95]) {
      final stalk = Rect.fromCenter(
        center: feet + Offset(x * s, -s * 1.0),
        width: s * 0.16,
        height: s * 2.1,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(stalk, Radius.circular(s * 0.05)),
        Paint()..color = const Color(0xFF558B2F),
      );
      for (var seg = 0; seg < 4; seg++) {
        final y = feet.dy - s * (0.25 + seg * 0.45);
        canvas.drawLine(
          Offset(feet.dx + x * s - s * 0.1, y),
          Offset(feet.dx + x * s + s * 0.1, y),
          Paint()..color = const Color(0xFF33691E)..strokeWidth = 2,
        );
      }
      if (x.abs() < 0.5) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(feet.dx + x * s + s * 0.35, feet.dy - s * 1.35), width: s * 0.45, height: s * 0.14),
          Paint()..color = const Color(0xFF689F38),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}

/// Mini ícone do recurso para o popup.
class ResourceIconPainter extends CustomPainter {
  ResourceIconPainter(this.resource);

  final ResourceKind resource;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = min(size.width, size.height) * 0.35;
    final stroke = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    switch (resource) {
      case ResourceKind.board:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: s * 2.2, height: s * 0.55),
            Radius.circular(3),
          ),
          Paint()..color = const Color(0xFF8D6E63),
        );
        canvas.drawLine(c + Offset(-s * 0.7, 0), c + Offset(s * 0.7, 0), stroke);
      case ResourceKind.rope:
        canvas.drawArc(
          Rect.fromCenter(center: c, width: s * 1.6, height: s * 1.6),
          0.4,
          pi * 1.4,
          false,
          stroke..color = const Color(0xFF6D4C41)..strokeWidth = 4,
        );
      case ResourceKind.water:
        final drop = Path()
          ..moveTo(c.dx, c.dy - s)
          ..quadraticBezierTo(c.dx + s, c.dy, c.dx, c.dy + s)
          ..quadraticBezierTo(c.dx - s, c.dy, c.dx, c.dy - s);
        canvas.drawPath(drop, Paint()..color = const Color(0xFF29B6F6));
      case ResourceKind.wind:
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
            Rect.fromCenter(center: c + Offset(0, -s * 0.4 + i * s * 0.4), width: s * 1.8, height: s * 0.7),
            0.2,
            pi - 0.4,
            false,
            stroke..color = const Color(0xFF90CAF9),
          );
        }
      case ResourceKind.stone:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: s * 1.6, height: s * 1.2),
            Radius.circular(s * 0.3),
          ),
          Paint()..color = const Color(0xFF78909C),
        );
      case ResourceKind.ladder:
        canvas.drawLine(c + Offset(-s * 0.5, -s), c + Offset(-s * 0.5, s), stroke);
        canvas.drawLine(c + Offset(s * 0.5, -s), c + Offset(s * 0.5, s), stroke);
        for (var i = -2; i <= 2; i++) {
          canvas.drawLine(c + Offset(-s * 0.5, i * s * 0.35), c + Offset(s * 0.5, i * s * 0.35), stroke);
        }
      case ResourceKind.fire:
        canvas.drawOval(
          Rect.fromCenter(center: c + Offset(0, s * 0.1), width: s * 0.9, height: s * 1.5),
          Paint()..color = const Color(0xFFFF6F00),
        );
        canvas.drawOval(
          Rect.fromCenter(center: c + Offset(0, s * 0.2), width: s * 0.45, height: s * 0.8),
          Paint()..color = const Color(0xFFFFEB3B),
        );
      case ResourceKind.pickaxe:
        canvas.drawLine(c + Offset(-s * 0.2, s * 0.8), c + Offset(s * 0.4, -s * 0.6), stroke..strokeWidth = 3);
        canvas.drawArc(
          Rect.fromCenter(center: c + Offset(s * 0.35, -s * 0.55), width: s, height: s * 0.7),
          -0.5,
          pi,
          false,
          stroke..color = const Color(0xFF546E7A)..strokeWidth = 5,
        );
      case ResourceKind.axe:
        canvas.drawLine(c + Offset(0, s), c + Offset(0, -s * 0.4), stroke..strokeWidth = 3);
        final blade = Path()
          ..moveTo(c.dx, c.dy - s * 0.5)
          ..lineTo(c.dx + s * 0.9, c.dy - s * 0.1)
          ..lineTo(c.dx, c.dy + s * 0.1)
          ..close();
        canvas.drawPath(blade, Paint()..color = const Color(0xFF90A4AE));
      case ResourceKind.scissors:
        canvas.drawCircle(c + Offset(-s * 0.35, s * 0.45), s * 0.28, stroke);
        canvas.drawCircle(c + Offset(s * 0.35, s * 0.45), s * 0.28, stroke);
        canvas.drawLine(c + Offset(-s * 0.2, s * 0.25), c + Offset(s * 0.5, -s * 0.7), stroke);
        canvas.drawLine(c + Offset(s * 0.2, s * 0.25), c + Offset(-s * 0.5, -s * 0.7), stroke);
      case ResourceKind.bomb:
        canvas.drawCircle(c + Offset(0, s * 0.15), s * 0.7, Paint()..color = const Color(0xFF212121));
        canvas.drawCircle(c + Offset(-s * 0.2, 0), s * 0.12, Paint()..color = const Color(0xFF616161));
        canvas.drawLine(
          c + Offset(0, -s * 0.5),
          c + Offset(s * 0.15, -s * 0.95),
          Paint()
            ..color = const Color(0xFF8D6E63)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          c + Offset(s * 0.2, -s * 1.05),
          s * 0.18,
          Paint()..color = const Color(0xFFFF6F00),
        );
    }
  }

  @override
  bool shouldRepaint(covariant ResourceIconPainter oldDelegate) =>
      oldDelegate.resource != resource;
}
