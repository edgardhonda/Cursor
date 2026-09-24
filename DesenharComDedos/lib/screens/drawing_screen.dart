import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/stroke_widths.dart';
import '../utils/system_ui_controller.dart';
import '../widgets/color_palette.dart';
import '../widgets/drawing_canvas.dart';

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen>
    with WidgetsBindingObserver {
  static const _systemUiChannel =
      MethodChannel('com.desenhardedos.desenhar_com_dedos/system_ui');

  final GlobalKey<DrawingCanvasState> _canvasKey = GlobalKey();
  Color _selectedColor = paletteColors.first;
  StrokeWidthLevel _strokeLevel = StrokeWidthLevel.medium;
  bool _canUndo = false;
  bool _systemUiVisible = false;
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _systemUiChannel.setMethodCallHandler(_onPlatformCall);
    _hideSystemUi();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
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

  Future<dynamic> _onPlatformCall(MethodCall call) async {
    if (call.method == 'pinStateChanged') {
      final pinned = call.arguments == true;
      if (pinned != _pinned && mounted) {
        setState(() => _pinned = pinned);
      }
    }
    return null;
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

  void _updateUndoState() {
    setState(() {
      _canUndo = _canvasKey.currentState?.canUndo ?? false;
    });
  }

  bool _isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  double _paletteWidth(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    // 40% mais estreita que a largura original (88 / 120).
    if (shortest >= 600) return 72;
    return 53;
  }

  double _strokeWidth(BuildContext context) =>
      _strokeLevel.widthFor(isTablet: _isTablet(context));

  @override
  Widget build(BuildContext context) {
    final isTablet = _isTablet(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Row(
          children: [
            ColorPalette(
              width: _paletteWidth(context),
              selectedColor: _selectedColor,
              onColorSelected: (color) => setState(() => _selectedColor = color),
              strokeLevel: _strokeLevel,
              onStrokeLevelSelected: (level) =>
                  setState(() => _strokeLevel = level),
              isTablet: isTablet,
              onUndo: () => _canvasKey.currentState?.undo(),
              onClearAll: () => _canvasKey.currentState?.clear(),
              canUndo: _canUndo,
              pinned: _pinned,
              onTogglePin: _onTogglePin,
            ),
            Expanded(
              child: DrawingCanvas(
                key: _canvasKey,
                color: _selectedColor,
                strokeWidth: _strokeWidth(context),
                onClear: () {},
                onHistoryChanged: _updateUndoState,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
