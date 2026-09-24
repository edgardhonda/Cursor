import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/game_audio.dart';
import '../game/game_engine.dart';
import '../game/game_painter.dart';
import '../models/game_models.dart';
import '../utils/system_ui_controller.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final GameEngine _engine;
  late final GameAudio _audio;
  late final Ticker _ticker;
  bool _showSystemUi = false;

  @override
  void initState() {
    super.initState();
    _audio = GameAudio();
    _engine = GameEngine(onSound: (s) => _audio.play(s))..reset();
    _ticker = createTicker((elapsed) {
      _engine.tick(elapsed);
      if (mounted) setState(() {});
    })..start();
    _audio.init();
    hideSystemUi();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tablet = size.shortestSide >= 600;
    final choosing = _engine.phase == ExplorerPhase.choosing;
    final obstacle = _engine.activeObstacle;
    final spec = obstacle != null ? obstacleCatalog[obstacle.kind] : null;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && isPhysicalSystemKey(event.logicalKey)) {
          setState(() => _showSystemUi = true);
          showSystemUi();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF81D4FA),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tablet ? 20 : 12,
                      tablet ? 12 : 8,
                      tablet ? 20 : 12,
                      4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Obstáculos — Trecho ${_engine.segmentIndex + 1}',
                            style: TextStyle(
                              fontSize: tablet ? 22 : 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                        Text(
                          _statusLabel(),
                          style: TextStyle(
                            fontSize: tablet ? 15 : 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF33691E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (choosing && spec != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        tablet ? 16 : 10,
                        0,
                        tablet ? 16 : 10,
                        tablet ? 8 : 6,
                      ),
                      child: _ChoicePopup(
                        tablet: tablet,
                        title: spec.label,
                        subtitle: 'Como resolver?',
                        choices: _engine.choices,
                        onPick: _engine.selectChoice,
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: tablet ? 12 : 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: GamePainter(_engine),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: tablet ? 12 : 8),
                ],
              ),
              if (_showSystemUi)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    onPressed: () {
                      setState(() => _showSystemUi = false);
                      hideSystemUi();
                    },
                    icon: const Icon(Icons.fullscreen),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel() {
    return switch (_engine.phase) {
      ExplorerPhase.walking => 'Avançando…',
      ExplorerPhase.choosing => 'Escolha um recurso!',
      ExplorerPhase.showcasing => 'Usando recurso…',
      ExplorerPhase.resolving => 'Resolvendo…',
      ExplorerPhase.sad => 'Não funcionou…',
      ExplorerPhase.celebrating => 'Trecho concluído!',
      ExplorerPhase.scrolling => 'Novo trecho…',
    };
  }
}

class _ChoicePopup extends StatelessWidget {
  const _ChoicePopup({
    required this.tablet,
    required this.title,
    required this.subtitle,
    required this.choices,
    required this.onPick,
  });

  final bool tablet;
  final String title;
  final String subtitle;
  final List<ChoiceOption> choices;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: tablet ? 320 : 240),
        child: Material(
          color: const Color(0xFFFFF8E1),
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tablet ? 12 : 8,
              tablet ? 10 : 8,
              tablet ? 12 : 8,
              tablet ? 8 : 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: tablet ? 18 : 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4E342E),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: tablet ? 12 : 11,
                    color: const Color(0xFF6D4C41),
                  ),
                ),
                SizedBox(height: tablet ? 8 : 6),
                ...List.generate(choices.length, (i) {
                  final c = choices[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => onPick(i),
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBCAAA4)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: tablet ? 8 : 6,
                            vertical: tablet ? 6 : 5,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: tablet ? 40 : 34,
                                height: tablet ? 40 : 34,
                                child: CustomPaint(
                                  painter: ResourceIconPainter(c.resource),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.resource.label,
                                  style: TextStyle(
                                    fontSize: tablet ? 14 : 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3E2723),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
