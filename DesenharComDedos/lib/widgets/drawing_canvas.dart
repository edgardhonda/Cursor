import 'dart:async';

import 'package:flutter/material.dart';

import '../models/stroke.dart';
import '../services/drawing_storage.dart';
import '../theme/app_colors.dart';

/// Área de desenho: cada dedo (pointer) traça independentemente.
/// Sem zoom, arrastar ou gestos com vários dedos — só pintar.
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    super.key,
    required this.color,
    required this.strokeWidth,
    required this.onClear,
    this.onHistoryChanged,
  });

  final Color color;
  final double strokeWidth;
  final VoidCallback onClear;
  final VoidCallback? onHistoryChanged;

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas>
    with WidgetsBindingObserver {
  final List<Stroke> _finishedStrokes = [];
  final Map<int, Stroke> _activeStrokes = {};
  final DrawingStorage _storage = DrawingStorage();
  Timer? _saveTimer;

  bool get canUndo => _finishedStrokes.isNotEmpty;

  void _notifyHistory() => widget.onHistoryChanged?.call();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSaved();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _saveNow();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _saveNow();
    }
  }

  Future<void> _loadSaved() async {
    final saved = await _storage.load();
    if (!mounted || saved.isEmpty) return;
    setState(() {
      _finishedStrokes
        ..clear()
        ..addAll(saved);
    });
    _notifyHistory();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), _saveNow);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    _storage.save(List<Stroke>.from(_finishedStrokes));
  }

  void clear() {
    setState(() {
      _finishedStrokes.clear();
      _activeStrokes.clear();
    });
    widget.onClear();
    _notifyHistory();
    _saveNow();
  }

  void undo() {
    if (_finishedStrokes.isEmpty) return;
    setState(() => _finishedStrokes.removeLast());
    _notifyHistory();
    _saveNow();
  }

  void _startStroke(int pointer, Offset position) {
    setState(() {
      _activeStrokes[pointer] = Stroke(
        color: widget.color,
        width: widget.strokeWidth,
      )..addPoint(position);
    });
  }

  void _extendStroke(int pointer, Offset position) {
    final stroke = _activeStrokes[pointer];
    if (stroke == null) return;
    setState(() => stroke.addPoint(position));
  }

  void _endStroke(int pointer) {
    final stroke = _activeStrokes.remove(pointer);
    if (stroke == null || stroke.points.isEmpty) return;
    setState(() => _finishedStrokes.add(stroke));
    _notifyHistory();
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _startStroke(event.pointer, event.localPosition),
      onPointerMove: (event) => _extendStroke(event.pointer, event.localPosition),
      onPointerUp: (event) => _endStroke(event.pointer),
      onPointerCancel: (event) => _endStroke(event.pointer),
      child: ColoredBox(
        color: canvasBackground,
        child: CustomPaint(
          painter: _StrokesPainter(
            strokes: [
              ..._finishedStrokes,
              ..._activeStrokes.values,
            ],
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter({required this.strokes});

  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.width / 2, paint..style = PaintingStyle.fill);
        continue;
      }

      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) => true;
}
