import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../audio/game_audio_controller.dart';
import '../game/game_engine.dart';
import '../game/game_painter.dart';
import '../models/game_models.dart';
import '../utils/system_ui_controller.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _systemUiChannel =
      MethodChannel('com.edgard.batalha_espacial/system_ui');

  late final GameAudioController _audio;
  late final GameEngine _engine;
  late final Ticker _ticker;
  bool _systemUiVisible = false;
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    _audio = GameAudioController();
    _engine = GameEngine(onSound: (cue) => unawaited(_audio.play(cue)));
    unawaited(_audio.init());
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _systemUiChannel.setMethodCallHandler(_onPlatformCall);
    _hideSystemUi();
    _ticker = createTicker(_engine.tick);
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

  void _startGame() {
    unawaited(_audio.play(GameSoundCue.start));
    _engine.start();
    if (!_ticker.isActive) _ticker.start();
    setState(() {});
  }

  void _onPronto() => _startGame();

  void _onRestart() => _startGame();

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final topInset = _systemUiVisible ? padding.top : 0.0;
    final bottomInset = _systemUiVisible ? padding.bottom : 0.0;
    final isWide = MediaQuery.sizeOf(context).shortestSide >= 600;
    final buttonHeight = isWide ? 72.0 : 58.0;
    final numberSize = isWide ? 34.0 : 28.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showSystemUi();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF020818),
        body: Padding(
          padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
          child: Column(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: _engine,
                  builder: (context, _) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: GamePainter(_engine),
                          size: Size.infinite,
                        ),
                        if (_engine.phase == GamePhase.combat)
                          _CombatHud(
                            engine: _engine,
                            buttonHeight: buttonHeight,
                            numberSize: numberSize,
                          ),
                        if (_engine.phase == GamePhase.waiting)
                          _CenterMessage(
                            title: 'Batalha Espacial',
                            subtitle:
                                'Conte os raios amarelos e escolha o número certo em 5 segundos.',
                            actionLabel: 'Pronto!',
                            onAction: _onPronto,
                          ),
                        if (_engine.phase == GamePhase.playerDestroyed)
                          _CenterMessage(
                            title: 'Nave destruída!',
                            subtitle: 'Pontuação: ${_engine.score}',
                            actionLabel: 'Jogar de novo',
                            onAction: _onRestart,
                          ),
                        Positioned(
                          left: 12,
                          top: 8,
                          child: _HudChip(
                            label: 'Pontos ${_engine.score}',
                          ),
                        ),
                        if (_engine.bestScore > 0)
                          Positioned(
                            right: 12,
                            top: 8,
                            child: _HudChip(
                              label: 'Recorde ${_engine.bestScore}',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              _ControlBar(
                systemUiVisible: _systemUiVisible,
                pinned: _pinned,
                onMenu: _showSystemUi,
                onPin: _togglePin,
                onRestart: _onRestart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CombatHud extends StatelessWidget {
  const _CombatHud({
    required this.engine,
    required this.buttonHeight,
    required this.numberSize,
  });

  final GameEngine engine;
  final double buttonHeight;
  final double numberSize;

  @override
  Widget build(BuildContext context) {
    final progress =
        (engine.combatTimeLeft / combatDurationSeconds).clamp(0.0, 1.0);
    return Column(
      children: [
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(
                progress > 0.35 ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(
            children: [
              for (final choice in engine.choices)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: Size(0, buttonHeight),
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(
                          fontSize: numberSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: () => engine.pickChoice(choice),
                      child: Text('$choice'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 520 : 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: isWide ? 34 : 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isWide ? 18 : 16,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: Size(isWide ? 220 : 180, isWide ? 64 : 56),
                backgroundColor: const Color(0xFF43A047),
                textStyle: TextStyle(
                  fontSize: isWide ? 22 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.systemUiVisible,
    required this.pinned,
    required this.onMenu,
    required this.onPin,
    required this.onRestart,
  });

  final bool systemUiVisible;
  final bool pinned;
  final VoidCallback onMenu;
  final VoidCallback onPin;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: const Color(0xFF0A1630),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            onPressed: onMenu,
            icon: Icon(
              systemUiVisible ? Icons.fullscreen : Icons.fullscreen_exit,
              color: Colors.white70,
            ),
          ),
          IconButton(
            tooltip: pinned ? 'Desafixar' : 'Fixar tela',
            onPressed: onPin,
            icon: Icon(
              pinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onRestart,
            child: const Text('Reiniciar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
