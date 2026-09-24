import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/game_audio_controller.dart';
import '../game/battle_engine.dart';
import '../game/battle_painter.dart';
import '../game/unit_art.dart';
import '../models/game_models.dart';
import '../utils/system_ui_controller.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final BattleEngine engine = BattleEngine();
  final GameAudioController audio = GameAudioController();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size _fieldSize = Size.zero;
  double _clock = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    enterImmersiveMode();
    audio.init();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_last == Duration.zero) {
      _last = elapsed;
      return;
    }
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final scaled = dt * engine.speed.factor;
    _clock += scaled;
    if (engine.phase == BattlePhase.fighting) {
      final events = engine.tick(scaled);
      for (final e in events) {
        audio.play(e.sound.name);
      }
    } else {
      engine.pulseAnims(scaled);
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) enterImmersiveMode();
  }

  @override
  void dispose() {
    _ticker.dispose();
    audio.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (engine.phase != BattlePhase.setup) return;
    engine.removeAt(details.localPosition.dx, details.localPosition.dy);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4E7A3E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size != _fieldSize && size.width > 0) {
            _fieldSize = size;
            engine.layoutField(size.width, size.height);
          }
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTapDown: _onTapDown,
                  child: CustomPaint(
                    painter: BattlePainter(engine: engine),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: MediaQuery.paddingOf(context).top + 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TopBar(
                      engine: engine,
                      onFight: () {
                        engine.startFight();
                        setState(() {});
                      },
                      onRestart: () {
                        engine.restart();
                        setState(() {});
                      },
                      onSpeed: (speed) {
                        engine.speed = speed;
                        setState(() {});
                      },
                    ),
                    if (engine.phase == BattlePhase.leftWins ||
                        engine.phase == BattlePhase.rightWins ||
                        engine.phase == BattlePhase.draw) ...[
                      const SizedBox(height: 8),
                      _ResultBanner(
                        text: engine.phase == BattlePhase.draw
                            ? 'Empate!'
                            : engine.phase == BattlePhase.leftWins
                                ? 'Exército azul venceu!'
                                : 'Exército vermelho venceu!',
                      ),
                    ],
                  ],
                ),
              ),
              if (engine.phase == BattlePhase.setup) ...[
                Positioned(
                  left: 6,
                  bottom: MediaQuery.paddingOf(context).bottom + 8,
                  top: MediaQuery.paddingOf(context).top + 58,
                  child: _Palette(
                    team: Team.left,
                    remaining: engine.remaining(Team.left),
                    clock: _clock,
                    onPick: (kind) {
                      engine.tryPlace(Team.left, kind);
                      setState(() {});
                    },
                  ),
                ),
                Positioned(
                  right: 6,
                  top: MediaQuery.paddingOf(context).top + 58,
                  bottom: MediaQuery.paddingOf(context).bottom + 8,
                  child: _Palette(
                    team: Team.right,
                    remaining: engine.remaining(Team.right),
                    clock: _clock,
                    onPick: (kind) {
                      engine.tryPlace(Team.right, kind);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.engine,
    required this.onFight,
    required this.onRestart,
    required this.onSpeed,
  });

  final BattleEngine engine;
  final VoidCallback onFight;
  final VoidCallback onRestart;
  final ValueChanged<GameSpeed> onSpeed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CostChip(
          label: 'Azul',
          value: engine.remaining(Team.left),
          color: const Color(0xFF2E5AA8),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (engine.phase == BattlePhase.setup)
                  _ActionButton(
                    label: 'Lutar!',
                    enabled: engine.canFight,
                    onTap: onFight,
                  )
                else
                  _ActionButton(
                    label: 'Reiniciar',
                    enabled: true,
                    onTap: onRestart,
                  ),
                const SizedBox(width: 8),
                if (engine.phase == BattlePhase.setup) ...[
                  _ActionButton(
                    label: 'Reiniciar',
                    enabled: true,
                    onTap: onRestart,
                  ),
                  const SizedBox(width: 8),
                ],
                _SpeedSelector(speed: engine.speed, onSpeed: onSpeed),
              ],
            ),
          ),
        ),
        _CostChip(
          label: 'Vermelho',
          value: engine.remaining(Team.right),
          color: const Color(0xFFB13228),
        ),
      ],
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.speed, required this.onSpeed});

  final GameSpeed speed;
  final ValueChanged<GameSpeed> onSpeed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xF2F4E2B3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5A3A18), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in GameSpeed.values)
            _SpeedChip(
              speed: option,
              selected: speed == option,
              onTap: () => onSpeed(option),
            ),
        ],
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.selected,
    required this.onTap,
  });

  final GameSpeed speed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final arrows = switch (speed) {
      GameSpeed.slow => '▸',
      GameSpeed.medium => '▸▸',
      GameSpeed.fast => '▸▸▸',
    };
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: speed.label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF5A3A18) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            arrows,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: selected ? const Color(0xFFF4E2B3) : const Color(0xFF3A220C),
            ),
          ),
        ),
      ),
    );
  }
}

class _CostChip extends StatelessWidget {
  const _CostChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label  $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF4E2B3) : const Color(0xFFB7B7B7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF5A3A18), width: 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: enabled ? const Color(0xFF3A220C) : const Color(0xFF5E5E5E),
          ),
        ),
      ),
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette({
    required this.team,
    required this.remaining,
    required this.clock,
    required this.onPick,
  });

  final Team team;
  final int remaining;
  final double clock;
  final ValueChanged<UnitKind> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xEEF7E7C6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: team == Team.left
              ? const Color(0xFF2E5AA8)
              : const Color(0xFFB13228),
          width: 2,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in paletteOrder)
              _PaletteTile(
                type: unitCatalog[kind]!,
                remaining: remaining,
                clock: clock,
                team: team,
                onTap: () => onPick(kind),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.type,
    required this.remaining,
    required this.clock,
    required this.team,
    required this.onTap,
  });

  final UnitType type;
  final int remaining;
  final double clock;
  final Team team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canBuy = remaining >= type.cost;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: canBuy ? onTap : null,
        child: Opacity(
          opacity: canBuy ? 1 : 0.45,
          child: Column(
            children: [
              SizedBox(
                width: 72,
                height: 52,
                child: CustomPaint(
                  painter: _UnitIconPainter(
                    kind: type.kind,
                    clock: clock,
                    team: team,
                  ),
                ),
              ),
              Text(
                type.name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                '${type.cost}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6A3B12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitIconPainter extends CustomPainter {
  _UnitIconPainter({
    required this.kind,
    required this.clock,
    required this.team,
  });

  final UnitKind kind;
  final double clock;
  final Team team;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (team == Team.right) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    UnitArt.paintKind(
      canvas,
      kind: kind,
      dest: Offset.zero & size,
      anim: UnitAnim.idle,
      time: clock,
      team: team,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _UnitIconPainter oldDelegate) =>
      oldDelegate.clock != clock || oldDelegate.team != team;
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xF2FFF4D8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5A3A18), width: 2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Color(0xFF3A220C),
        ),
      ),
    );
  }
}
