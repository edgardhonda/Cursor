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
  static const _systemUiChannel = MethodChannel('com.destruir.destruir/system_ui');

  late final GameEngine _engine;
  late final GameAudio _audio;
  late Ticker _ticker;
  Size _canvasSize = Size.zero;
  bool _systemUiVisible = false;
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _systemUiChannel.setMethodCallHandler(_onPlatformCall);
    _audio = GameAudio();
    _engine = GameEngine(onSound: _audio.play);
    _audio.init();
    _hideSystemUi();
    _ticker = createTicker((_) {
      if (_engine.running) {
        _engine.tick();
      }
    });
  }

  Future<dynamic> _onPlatformCall(MethodCall call) async {
    if (call.method == 'pinStateChanged') {
      final pinned = call.arguments == true;
      if (pinned != _pinned && mounted) {
        setState(() => _pinned = pinned);
      }
    }
    return null;
  }

  Future<void> _onTogglePin() async {
    try {
      if (_pinned) {
        await _systemUiChannel.invokeMethod('unpinScreen');
      } else {
        await _systemUiChannel.invokeMethod('pinScreen');
      }
    } catch (_) {}

    bool pinned = _pinned;
    try {
      pinned = await _systemUiChannel.invokeMethod<bool>('isPinned') ?? _pinned;
    } catch (_) {}
    if (mounted) setState(() => _pinned = pinned);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _showSystemUi(restoreOnExit: true);
    _ticker.dispose();
    _audio.dispose();
    _engine.repaintTick.dispose();
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
      await _systemUiChannel.invokeMethod('hide');
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _showSystemUi({bool restoreOnExit = false}) async {
    if (!restoreOnExit && _systemUiVisible) return;
    _systemUiVisible = true;
    try {
      await _systemUiChannel.invokeMethod('show');
    } catch (_) {}
    await showSystemUi();
    if (mounted) setState(() {});
  }

  void _syncTicker() {
    if (_engine.running) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _onPronto() {
    _engine.start();
    _syncTicker();
    setState(() {});
  }

  void _onRestart() {
    _engine.reset();
    _syncTicker();
    setState(() {});
  }

  void _onPauseResume() {
    if (_engine.running) {
      _engine.stop();
    } else {
      _engine.resume();
    }
    _syncTicker();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final topInset = _systemUiVisible ? padding.top : 0.0;
    final bottomInset = _systemUiVisible ? padding.bottom : 0.0;
    const controlBarHeight = 72.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showSystemUi();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight - controlBarHeight,
                );
                if (_canvasSize != size) {
                  _canvasSize = size;
                  _engine.setBounds(size);
                }

                return Column(
                  children: [
                    Expanded(
                      child: RepaintBoundary(
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (e) =>
                              _engine.pointerDown(e.pointer, e.localPosition),
                          onPointerMove: (e) =>
                              _engine.pointerMove(e.pointer, e.localPosition),
                          onPointerUp: (e) =>
                              _engine.pointerUp(e.pointer, e.localPosition),
                          onPointerCancel: (e) =>
                              _engine.pointerUp(e.pointer, e.localPosition),
                          child: CustomPaint(
                            painter: GamePainter(engine: _engine),
                            size: size,
                          ),
                        ),
                      ),
                    ),
                    _ControlBar(
                      showPronto: !_engine.started,
                      running: _engine.running,
                      pinned: _pinned,
                      onPronto: _onPronto,
                      onRestart: _onRestart,
                      onPauseResume: _onPauseResume,
                      onTogglePin: _onTogglePin,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.showPronto,
    required this.running,
    required this.pinned,
    required this.onPronto,
    required this.onRestart,
    required this.onPauseResume,
    required this.onTogglePin,
  });

  final bool showPronto;
  final bool running;
  final bool pinned;
  final VoidCallback onPronto;
  final VoidCallback onRestart;
  final VoidCallback onPauseResume;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).shortestSide >= 600;
    final btnHeight = isWide ? 56.0 : 48.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          SizedBox(
            height: btnHeight,
            child: FilledButton.tonalIcon(
              onPressed: onTogglePin,
              style: FilledButton.styleFrom(
                minimumSize: Size(0, btnHeight),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor:
                    pinned ? const Color(0xFF1565C0) : null,
                foregroundColor: pinned ? Colors.white : null,
              ),
              icon: Icon(pinned ? Icons.lock : Icons.lock_open, size: 20),
              label: Text(pinned ? 'Liberar' : 'Fixar'),
            ),
          ),
          const SizedBox(width: 8),
          if (showPronto)
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: onPronto,
                style: FilledButton.styleFrom(
                  minimumSize: Size(0, btnHeight),
                  backgroundColor: const Color(0xFF2E7D32),
                ),
                child: const Text(
                  'Pronto!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (!showPronto) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onRestart,
                style: OutlinedButton.styleFrom(minimumSize: Size(0, btnHeight)),
                child: const Text('Reiniciar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onPauseResume,
                style: FilledButton.styleFrom(
                  minimumSize: Size(0, btnHeight),
                  backgroundColor:
                      running ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                ),
                child: Text(running ? 'Parar' : 'Continuar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
