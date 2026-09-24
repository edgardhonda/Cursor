import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/game_audio.dart';
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
  static const _systemUiChannel = MethodChannel('com.edgard.garras/system_ui');

  late final GameAudio _audio;
  late final GameEngine _engine;
  late final Ticker _ticker;
  Size _lastCanvasSize = Size.zero;
  bool _systemUiVisible = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _audio = GameAudio();
    _engine = GameEngine(audio: _audio);
    unawaited(_audio.init());
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _hideSystemUi();
    _ticker = createTicker((elapsed) {
      _engine.tick(elapsed);
      if (mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _ticker.dispose();
    _engine.dispose();
    unawaited(_audio.dispose());
    _showSystemUi(restoreOnExit: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_systemUiVisible) {
      _hideSystemUi();
    }
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && isPhysicalSystemKey(event.logicalKey)) {
      _showSystemUi();
    }
    return false;
  }

  Future<void> _hideSystemUi() async {
    _systemUiVisible = false;
    await hideSystemUi();
    try {
      await _systemUiChannel.invokeMethod<void>('hide');
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _showSystemUi({bool restoreOnExit = false}) async {
    if (!restoreOnExit && _systemUiVisible) return;
    _systemUiVisible = true;
    try {
      await _systemUiChannel.invokeMethod<void>('show');
    } catch (_) {}
    await showSystemUi();
    if (mounted) setState(() {});
  }

  void _restart() {
    _engine.reset();
    _paused = false;
    setState(() {});
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      _engine.setPaused(_paused);
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final topInset = _systemUiVisible ? padding.top : 0.0;
    final bottomInset = _systemUiVisible ? padding.bottom : 0.0;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showSystemUi();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF29B6F6),
        body: Padding(
          padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    if (size != _lastCanvasSize) {
                      _lastCanvasSize = size;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _engine.setBounds(size);
                      });
                    }
                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        _engine.tapAt(event.localPosition);
                      },
                      child: CustomPaint(
                        painter: GamePainter(_engine),
                        size: Size.infinite,
                      ),
                    );
                  },
                ),
              ),
              Container(
                height: tablet ? 76 : 64,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  border: Border(
                    top: BorderSide(color: Color(0xFF90CAF9), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _restart,
                        style: ButtonStyle(
                          foregroundColor: const WidgetStatePropertyAll(
                            Colors.white,
                          ),
                          side: const WidgetStatePropertyAll(
                            BorderSide(color: Colors.white70),
                          ),
                          textStyle: WidgetStatePropertyAll(
                            TextStyle(fontSize: tablet ? 15 : 12),
                          ),
                        ),
                        icon: const Icon(Icons.refresh, size: 19),
                        label: const Text('Reiniciar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _togglePause,
                        style: ButtonStyle(
                          textStyle: WidgetStatePropertyAll(
                            TextStyle(fontSize: tablet ? 15 : 12),
                          ),
                        ),
                        icon: Icon(
                          _paused ? Icons.play_arrow : Icons.pause,
                          size: 19,
                        ),
                        label: Text(_paused ? 'Continuar' : 'Parar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
