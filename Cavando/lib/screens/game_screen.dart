import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/game_audio_controller.dart';
import '../game/game_engine.dart';
import '../game/game_painter.dart';
import '../utils/system_ui_controller.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameEngine _engine;
  late final GameAudioController _audio;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _audio = GameAudioController();
    _engine = GameEngine(onSound: (cue) => unawaited(_audio.play(cue)));
    unawaited(_audio.init());
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    unawaited(hideSystemUi());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    unawaited(_audio.dispose());
    unawaited(showSystemUi());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(hideSystemUi());
    }
  }

  void _onTick(Duration elapsed) {
    _engine.tick(elapsed);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7EC8E3),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _engine.setSize(Size(constraints.maxWidth, constraints.maxHeight));
          return Stack(
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _engine.pointerDown(e.localPosition),
                onPointerMove: (e) => _engine.pointerMove(e.localPosition),
                onPointerUp: (_) => _engine.pointerUp(),
                onPointerCancel: (_) => _engine.pointerUp(),
                child: CustomPaint(
                  painter: GamePainter(_engine),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Material(
                      color: const Color(0xFFF4E2C0),
                      elevation: 3,
                      shape: const CircleBorder(
                        side: BorderSide(color: Color(0xFF5A3A22), width: 2),
                      ),
                      child: IconButton(
                        tooltip: 'Reiniciar',
                        onPressed: () {
                          setState(_engine.restart);
                        },
                        icon: const Icon(
                          Icons.replay_rounded,
                          color: Color(0xFF5A3A22),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
