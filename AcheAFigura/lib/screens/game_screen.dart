import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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
  static const _systemUiChannel = MethodChannel(
    'com.edgard.ache_a_figura/system_ui',
  );

  late final GameAudioController _audio;
  late final GameEngine _engine;
  late final Ticker _ticker;
  Size _lastCanvasSize = Size.zero;
  bool _systemUiVisible = false;
  bool _pinned = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _audio = GameAudioController();
    _engine = GameEngine(onSound: (cue) => unawaited(_audio.play(cue)));
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _systemUiChannel.setMethodCallHandler(_onPlatformCall);
    _hideSystemUi();
    _ticker = createTicker(_engine.tick)..start();
  }

  Future<dynamic> _onPlatformCall(MethodCall call) async {
    if (call.method == 'pinStateChanged' && mounted) {
      setState(() => _pinned = call.arguments == true);
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _systemUiChannel.setMethodCallHandler(null);
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

  Future<void> _togglePin() async {
    try {
      if (_pinned) {
        await _systemUiChannel.invokeMethod<void>('unpinScreen');
      } else {
        await _systemUiChannel.invokeMethod<void>('pinScreen');
      }
      final pinned =
          await _systemUiChannel.invokeMethod<bool>('isPinned') ?? _pinned;
      if (mounted) setState(() => _pinned = pinned);
    } catch (_) {}
  }

  void _restart() {
    unawaited(_audio.stopAll());
    _engine.restart();
    _paused = false;
    setState(() {});
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      _engine.setPaused(_paused);
      if (_paused) {
        unawaited(_audio.pauseAll());
      } else {
        unawaited(_audio.resumeAll());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final topInset = _systemUiVisible ? padding.top : 0.0;
    final bottomInset = _systemUiVisible ? padding.bottom : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showSystemUi();
      },
      child: Scaffold(
        backgroundColor: const Color(0xfffffbf2),
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
                    return RepaintBoundary(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) {
                          _engine.pointerDown(
                            event.pointer,
                            event.localPosition,
                          );
                        },
                        onPointerMove: (event) {
                          _engine.pointerMove(
                            event.pointer,
                            event.localPosition,
                          );
                        },
                        onPointerUp: (event) {
                          _engine.pointerUp(event.pointer, event.localPosition);
                        },
                        onPointerCancel: (event) {
                          _engine.pointerUp(event.pointer, event.localPosition);
                        },
                        child: CustomPaint(
                          painter: GamePainter(_engine),
                          size: Size.infinite,
                        ),
                      ),
                    );
                  },
                ),
              ),
              _ControlBar(
                pinned: _pinned,
                paused: _paused,
                onTogglePin: _togglePin,
                onRestart: _restart,
                onTogglePause: _togglePause,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.pinned,
    required this.paused,
    required this.onTogglePin,
    required this.onRestart,
    required this.onTogglePause,
  });

  final bool pinned;
  final bool paused;
  final VoidCallback onTogglePin;
  final VoidCallback onRestart;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 6),
      ),
      textStyle: WidgetStatePropertyAll(TextStyle(fontSize: tablet ? 15 : 12)),
    );
    return Container(
      height: tablet ? 76 : 64,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffded8c9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onTogglePin,
              style: style,
              icon: Icon(pinned ? Icons.lock : Icons.lock_open, size: 19),
              label: Text(pinned ? 'Liberar' : 'Fixar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRestart,
              style: style,
              icon: const Icon(Icons.refresh, size: 19),
              label: const Text('Reiniciar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: onTogglePause,
              style: style,
              icon: Icon(paused ? Icons.play_arrow : Icons.pause, size: 19),
              label: Text(paused ? 'Continuar' : 'Parar'),
            ),
          ),
        ],
      ),
    );
  }
}
