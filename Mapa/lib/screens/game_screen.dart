import 'dart:async';
import 'dart:math' as math;

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

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _systemUiChannel = MethodChannel('com.edgard.mapa/system_ui');

  late final GameAudio _audio;
  late final GameEngine _engine;
  late final Ticker _ticker;
  bool _systemUiVisible = false;

  @override
  void initState() {
    super.initState();
    _audio = GameAudio();
    _engine = GameEngine(audio: _audio)..reset();
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
    setState(() {});
  }

  bool get _canEdit => _engine.phase == GamePhase.programming;

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
        backgroundColor: const Color(0xFF0288D1),
        body: Padding(
          padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
          child: Column(
            children: [
              Expanded(
                flex: tablet ? 7 : 6,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final board = _boardRect(constraints.biggest, tablet);
                    return CustomPaint(
                      painter: GamePainter(_engine, boardRect: board),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
              _CommandPanel(
                tablet: tablet,
                canEdit: _canEdit,
                running: _engine.phase == GamePhase.running,
                program: _engine.program,
                onCommand: (cmd) => setState(() => _engine.addCommand(cmd)),
                onStart: () => setState(() => _engine.start()),
                onRestart: _restart,
                onUndo: () => setState(() => _engine.removeLastCommand()),
                status: _statusText(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText() {
    return switch (_engine.phase) {
      GamePhase.programming => _engine.pirate.row == pirateStartRow &&
              _engine.pirate.col == pirateStartCol &&
              _engine.pathMarks.isEmpty
          ? 'Monte o caminho e toque em Ir!'
          : 'Continue daqui: novos comandos e Ir!',
      GamePhase.running => 'Pirata a caminho…',
      GamePhase.lost => _engine.crashKind == CrashKind.wall
          ? 'Bateu na parede!'
          : 'Bateu no obstáculo e desmaiou!',
      GamePhase.won => 'Tesouro encontrado!',
    };
  }

  Rect _boardRect(Size size, bool tablet) {
    final margin = tablet ? 24.0 : 14.0;
    final side = math.min(size.width - margin * 2, size.height - margin * 2);
    final left = (size.width - side) / 2;
    final top = (size.height - side) / 2;
    return Rect.fromLTWH(left, top, side, side);
  }
}

class _CommandPanel extends StatelessWidget {
  const _CommandPanel({
    required this.tablet,
    required this.canEdit,
    required this.running,
    required this.program,
    required this.onCommand,
    required this.onStart,
    required this.onRestart,
    required this.onUndo,
    required this.status,
  });

  final bool tablet;
  final bool canEdit;
  final bool running;
  final List<MoveCommand> program;
  final ValueChanged<MoveCommand> onCommand;
  final VoidCallback onStart;
  final VoidCallback onRestart;
  final VoidCallback onUndo;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tablet ? 16 : 10,
        tablet ? 12 : 8,
        tablet ? 16 : 10,
        tablet ? 14 : 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF01579B),
        border: Border(top: BorderSide(color: Color(0xFF4FC3F7), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: tablet ? 16 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: tablet ? 10 : 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _ArrowBtn(
                icon: Icons.arrow_upward,
                enabled: canEdit,
                onTap: () => onCommand(MoveCommand.up),
              ),
              _ArrowBtn(
                icon: Icons.arrow_downward,
                enabled: canEdit,
                onTap: () => onCommand(MoveCommand.down),
              ),
              _ArrowBtn(
                icon: Icons.arrow_back,
                enabled: canEdit,
                onTap: () => onCommand(MoveCommand.left),
              ),
              _ArrowBtn(
                icon: Icons.arrow_forward,
                enabled: canEdit,
                onTap: () => onCommand(MoveCommand.right),
              ),
              IconButton(
                onPressed: canEdit && program.isNotEmpty ? onUndo : null,
                tooltip: 'Desfazer',
                icon: const Icon(Icons.backspace_outlined, color: Colors.white70),
              ),
            ],
          ),
          SizedBox(height: tablet ? 12 : 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton(
                  onPressed: canEdit && program.isNotEmpty && !running
                      ? onStart
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    disabledBackgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white54,
                    minimumSize: Size(0, tablet ? 56 : 48),
                    padding: EdgeInsets.symmetric(
                      horizontal: tablet ? 20 : 14,
                      vertical: tablet ? 16 : 14,
                    ),
                    textStyle: TextStyle(
                      fontSize: tablet ? 22 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Ir!'),
                ),
              ),
              SizedBox(width: tablet ? 36 : 28),
              OutlinedButton(
                onPressed: onRestart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white54),
                  minimumSize: Size(0, tablet ? 44 : 40),
                  padding: EdgeInsets.symmetric(
                    horizontal: tablet ? 14 : 10,
                    vertical: tablet ? 12 : 10,
                  ),
                  textStyle: TextStyle(
                    fontSize: tablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Reiniciar'),
              ),
            ],
          ),
          SizedBox(height: tablet ? 10 : 8),
          Container(
            height: tablet ? 52 : 44,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0277BD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4FC3F7)),
            ),
            child: program.isEmpty
                ? Center(
                    child: Text(
                      'Sequência de comandos',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: tablet ? 14 : 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: program.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final cmd = program[index];
                      return Container(
                        width: tablet ? 40 : 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF176),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cmd.label,
                          style: TextStyle(
                            fontSize: tablet ? 20 : 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A237E),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  const _ArrowBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color(0xFFFFA000),
        ),
        child: Icon(icon, size: 26),
      ),
    );
  }
}
