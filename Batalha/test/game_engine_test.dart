import 'dart:ui';

import 'package:batalha/game/battle_engine.dart';
import 'package:batalha/game/unit_art.dart';
import 'package:batalha/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BattleEngine engine() {
    final e = BattleEngine();
    e.layoutField(800, 480);
    return e;
  }

  test('velocidade padrão é a intermediária', () {
    final e = engine();
    expect(e.speed, GameSpeed.medium);
    expect(GameSpeed.medium.factor, closeTo(0.7, 0.001));
    expect(GameSpeed.slow.factor, closeTo(0.5, 0.001));
    expect(GameSpeed.fast.factor, 1.0);
  });

  test('custos impedem combinações invencíveis no orçamento 15', () {
    expect(unitCatalog[UnitKind.cachorro]!.cost, 1);
    expect(unitCatalog[UnitKind.soldado]!.cost, 2);
    expect(unitCatalog[UnitKind.cavaleiro]!.cost, 4);
    expect(unitCatalog[UnitKind.gigante]!.cost, 5);
    expect(unitCatalog[UnitKind.arqueiro]!.cost, 3);
    expect(unitCatalog[UnitKind.canhao]!.cost, 7);

    const budget = 15;
    int maxOf(UnitKind kind) =>
        budget ~/ unitCatalog[kind]!.cost;

    expect(maxOf(UnitKind.canhao), 2);
    expect(maxOf(UnitKind.gigante), 3);
    expect(maxOf(UnitKind.cavaleiro), 3);
    expect(maxOf(UnitKind.arqueiro), 5);
    expect(maxOf(UnitKind.soldado), 7);
    expect(maxOf(UnitKind.cachorro), 15);
    expect(
      unitCatalog[UnitKind.canhao]!.cost + unitCatalog[UnitKind.gigante]!.cost,
      lessThanOrEqualTo(budget),
    );
  });

  test('colocar unidade debita o custo', () {
    final e = engine();
    expect(e.tryPlace(Team.left, UnitKind.soldado), isTrue);
    expect(e.remaining(Team.left), 13);
    expect(e.units, hasLength(1));
  });

  test('não coloca unidade sem custo suficiente', () {
    final e = engine();
    expect(e.tryPlace(Team.left, UnitKind.canhao), isTrue);
    expect(e.tryPlace(Team.left, UnitKind.canhao), isTrue);
    expect(e.tryPlace(Team.left, UnitKind.canhao), isFalse);
    expect(e.tryPlace(Team.left, UnitKind.gigante), isFalse);
    expect(e.tryPlace(Team.left, UnitKind.cachorro), isTrue);
    expect(e.remaining(Team.left), 0);
  });

  test('clicar na unidade colocada devolve o custo', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.cavaleiro);
    final unit = e.units.single;
    expect(e.removeAt(unit.x, unit.y), isTrue);
    expect(e.units, isEmpty);
    expect(e.remaining(Team.left), 15);
  });

  test('preenche casas livres em sequência', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.cachorro);
    e.tryPlace(Team.left, UnitKind.cachorro);
    expect(e.units[0].col, 0);
    expect(e.units[0].row, 0);
    expect(e.units[1].col, 1);
    expect(e.units[1].row, 0);
  });

  test('lutar exige pelo menos uma unidade em cada lado', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.cachorro);
    expect(e.startFight(), isFalse);
    e.tryPlace(Team.right, UnitKind.cachorro);
    expect(e.startFight(), isTrue);
    expect(e.phase, BattlePhase.fighting);
  });

  test('corpo a corpo reduz defesa e mata', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.cavaleiro);
    e.tryPlace(Team.right, UnitKind.cachorro);
    final dog = e.units.firstWhere((u) => u.type.kind == UnitKind.cachorro);
    final knight = e.units.firstWhere((u) => u.type.kind == UnitKind.cavaleiro);
    dog.x = knight.x + 8;
    dog.y = knight.y;
    e.startFight();
    for (var i = 0; i < 40; i++) {
      e.tick(0.05);
    }
    expect(dog.alive, isFalse);
    expect(dog.anim, UnitAnim.dead);
  });

  test('corpo a corpo só ataca ao encostar', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.gigante);
    e.tryPlace(Team.right, UnitKind.cachorro);
    final giant = e.units.firstWhere((u) => u.team == Team.left);
    final dog = e.units.firstWhere((u) => u.team == Team.right);
    dog.x = giant.x + 90;
    dog.y = giant.y;
    e.startFight();
    e.tick(0.05);
    expect(e.inStrikeRange(giant, dog), isFalse);
    expect(dog.hp, dog.type.defense);
    expect(giant.anim, UnitAnim.walk);
    dog.x = giant.x + 8;
    dog.y = giant.y;
    for (var i = 0; i < 40; i++) {
      e.tick(0.05);
    }
    expect(dog.alive, isFalse);
  });

  test('trava o primeiro inimigo na visão', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.soldado);
    e.tryPlace(Team.right, UnitKind.soldado);
    final left = e.units.firstWhere((u) => u.team == Team.left);
    final right = e.units.firstWhere((u) => u.team == Team.right);
    right.x = left.x + 40;
    right.y = left.y;
    e.startFight();
    e.tick(0.016);
    expect(left.targetId, right.id);
  });

  test('exército vence quando o outro é destruído', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.gigante);
    e.tryPlace(Team.right, UnitKind.cachorro);
    final dog = e.units.firstWhere((u) => u.team == Team.right);
    final giant = e.units.firstWhere((u) => u.team == Team.left);
    dog.x = giant.x + 10;
    dog.y = giant.y;
    e.startFight();
    for (var i = 0; i < 80; i++) {
      e.tick(0.05);
    }
    expect(e.phase, BattlePhase.leftWins);
    expect(giant.anim, UnitAnim.celebrate);
    expect(dog.anim, UnitAnim.dead);
  });

  test('exércitos iguais empatam', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.canhao);
    e.tryPlace(Team.right, UnitKind.canhao);
    e.startFight();
    for (var i = 0; i < 400; i++) {
      e.tick(0.05);
      if (e.phase != BattlePhase.fighting) break;
    }
    expect(e.phase, BattlePhase.draw);
    expect(e.units.every((u) => !u.alive), isTrue);
    expect(e.units.every((u) => u.anim != UnitAnim.celebrate), isTrue);
  });

  test('corpo a corpo igual também empata', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.cavaleiro);
    e.tryPlace(Team.right, UnitKind.cavaleiro);
    final left = e.units.firstWhere((u) => u.team == Team.left);
    final right = e.units.firstWhere((u) => u.team == Team.right);
    right.x = left.x + 10;
    right.y = left.y;
    e.startFight();
    for (var i = 0; i < 80; i++) {
      e.tick(0.05);
      if (e.phase != BattlePhase.fighting) break;
    }
    expect(e.phase, BattlePhase.draw);
  });

  test('três arqueiros de cada lado empatam', () {
    final e = engine();
    for (var i = 0; i < 3; i++) {
      expect(e.tryPlace(Team.left, UnitKind.arqueiro), isTrue);
      expect(e.tryPlace(Team.right, UnitKind.arqueiro), isTrue);
    }
    e.startFight();
    for (var i = 0; i < 500; i++) {
      e.tick(0.05);
      if (e.phase != BattlePhase.fighting) break;
    }
    expect(e.phase, BattlePhase.draw);
    expect(e.units.where((u) => u.alive), isEmpty);
  });

  test('projétil de arqueiro segue até o alvo', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.arqueiro);
    e.tryPlace(Team.right, UnitKind.arqueiro);
    final left = e.units.firstWhere((u) => u.team == Team.left);
    final right = e.units.firstWhere((u) => u.team == Team.right);
    left.x = 280;
    left.y = 240;
    right.x = 480;
    right.y = 240;
    e.startFight();
    var appeared = false;
    for (var i = 0; i < 40; i++) {
      e.tick(0.05);
      if (e.projectiles.isNotEmpty) {
        appeared = true;
        break;
      }
    }
    expect(appeared, isTrue, reason: 'dist=${(right.x - left.x).abs()} range=${e.attackPx(left)} vis=${e.visionPx(left)} tgt=${left.targetId}');
    final shot = e.projectiles.first;
    final startX = shot.x;
    final before = (shot.x - right.x).abs();
    e.tick(0.18);
    expect(e.projectiles, isNotEmpty);
    final after = e.projectiles.first;
    expect((after.x - right.x).abs(), lessThan(before));
    expect(after.x, greaterThan(startX));
  });

  test('reiniciar volta à montagem', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.cachorro);
    e.tryPlace(Team.right, UnitKind.cachorro);
    e.startFight();
    e.restart();
    expect(e.phase, BattlePhase.setup);
    expect(e.units, isEmpty);
    expect(e.remaining(Team.left), 15);
  });

  test('arte vetorial desenha todas as poses', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (final kind in UnitKind.values) {
      for (final anim in UnitAnim.values) {
        UnitArt.paintKind(
          canvas,
          kind: kind,
          dest: const Rect.fromLTWH(0, 0, 80, 80),
          anim: anim,
          time: 0.2,
        );
      }
    }
    expect(recorder.endRecording(), isNotNull);
  });

  test('visão dobra no meio do campo e cresce no caminho', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.soldado);
    e.tryPlace(Team.right, UnitKind.soldado);
    final left = e.units.firstWhere((u) => u.team == Team.left);
    final right = e.units.firstWhere((u) => u.team == Team.right);
    final baseLeft = left.type.vision * e.bodyPx(left);
    final baseRight = right.type.vision * e.bodyPx(right);

    expect(e.visionMultiplier(left), inInclusiveRange(1.0, 1.15));
    expect(e.visionPx(left), closeTo(baseLeft * e.visionMultiplier(left), 0.5));

    left.x = e.fieldW / 2;
    expect(e.visionMultiplier(left), closeTo(2.0, 0.02));
    expect(e.visionPx(left), closeTo(baseLeft * 2, 1));

    left.x = e.leftOriginX + (e.fieldW / 2 - e.leftOriginX) * 0.5;
    expect(e.visionMultiplier(left), closeTo(1.5, 0.05));

    left.x = e.fieldW * 0.85;
    expect(e.visionMultiplier(left), greaterThan(2.0));

    left.x = e.rightOriginX + e.gridCols * e.cell;
    expect(e.visionPx(left), greaterThanOrEqualTo(e.fieldDiagonal() - 1));
    expect(e.visionMultiplier(left), closeTo(e.fieldDiagonal() / baseLeft, 0.05));

    right.x = e.fieldW / 2;
    expect(e.visionMultiplier(right), closeTo(2.0, 0.02));
    expect(e.visionPx(right), closeTo(baseRight * 2, 1));
  });

  test('no campo oposto a visão cobre o campo e trava o inimigo', () {
    final e = engine();
    e.tryPlace(Team.left, UnitKind.cachorro);
    e.tryPlace(Team.right, UnitKind.cachorro);
    final left = e.units.firstWhere((u) => u.team == Team.left);
    final right = e.units.firstWhere((u) => u.team == Team.right);
    left.x = e.rightOriginX + e.gridCols * e.cell;
    left.y = e.fieldH * 0.8;
    right.x = e.leftOriginX;
    right.y = e.fieldH * 0.2;
    e.startFight();
    expect(e.visionPx(left), greaterThanOrEqualTo(e.fieldDiagonal() - 1));
    e.tick(0.016);
    expect(left.targetId, right.id);
    expect(right.targetId, left.id);
  });
}
