import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/game_audio_controller.dart';
import '../models/game_models.dart';

enum EmojiPack { animals, lettersAndNumbers, varied }

class GameEngine extends ChangeNotifier {
  GameEngine({this.onSound});

  static const animalEmojis = [
    '🐶',
    '🐱',
    '🐭',
    '🐹',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
    '🐔',
    '🐧',
    '🐦',
    '🦄',
    '🐝',
  ];

  static const letterNumberPool = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];

  /// Emoticons de várias categorias (rostos, comida, esporte, viagem, objetos…).
  static const variedEmojiPool = [
    '😀',
    '😎',
    '🤩',
    '🥳',
    '😇',
    '🤗',
    '😴',
    '🤯',
    '🍎',
    '🍌',
    '🍇',
    '🍉',
    '🍕',
    '🍔',
    '🍩',
    '🍦',
    '⚽',
    '🏀',
    '🎾',
    '🏈',
    '🚗',
    '✈️',
    '🚀',
    '🚲',
    '🌈',
    '☀️',
    '⭐',
    '🌙',
    '🌸',
    '🌳',
    '🌵',
    '🍄',
    '🎸',
    '🎹',
    '🎯',
    '🎲',
    '💎',
    '🔑',
    '🎁',
    '🎈',
  ];

  static const tileColors = [
    Color(0xffffe4e8),
    Color(0xffffefc7),
    Color(0xffddf5df),
    Color(0xffdceeff),
    Color(0xffeee2ff),
  ];

  final void Function(GameSoundCue cue)? onSound;
  final Random _random = Random();
  final List<EmojiTile> tiles = [];
  final Map<int, ActiveStroke> activeStrokes = {};
  final List<StrokePoint> finishedStrokes = [];

  Size _bounds = Size.zero;
  double _lastTick = 0;
  double now = 0;
  bool paused = false;
  bool complete = false;
  bool glowing = false;
  bool _acceptingInput = true;
  double _glowStartedAt = 0;
  String targetEmoji = '';
  EmojiPack pack = EmojiPack.animals;

  /// Sorteia 20 figuras distintas do conjunto ativo.
  List<String> _glyphsForCurrentPack() {
    final pool = switch (pack) {
      EmojiPack.animals => animalEmojis,
      EmojiPack.lettersAndNumbers => letterNumberPool,
      EmojiPack.varied => variedEmojiPool,
    };
    final shuffled = pool.toList()..shuffle(_random);
    return shuffled.take(20).toList()..shuffle(_random);
  }

  Size get bounds => _bounds;
  Rect get centerTileBounds {
    final shortest = min(_bounds.width, _bounds.height);
    final width = (shortest * 0.26).clamp(86.0, 142.0);
    final height = width * 0.86;
    return Rect.fromCenter(
      center: Offset(_bounds.width / 2, _bounds.height / 2),
      width: width,
      height: height,
    );
  }

  double get glowProgress =>
      glowing ? ((now - _glowStartedAt) / 0.85).clamp(0, 1) : 0;

  void setBounds(Size size) {
    if (size.width <= 0 || size.height <= 0 || size == _bounds) return;
    _bounds = size;
    if (tiles.isEmpty && !complete) {
      reset();
    } else {
      _layoutTiles();
      notifyListeners();
    }
  }

  /// Reinicia o jogo e alterna o conjunto de figuras.
  void restart() {
    pack = switch (pack) {
      EmojiPack.animals => EmojiPack.lettersAndNumbers,
      EmojiPack.lettersAndNumbers => EmojiPack.varied,
      EmojiPack.varied => EmojiPack.animals,
    };
    reset();
  }

  void reset() {
    if (_bounds.isEmpty) return;
    tiles.clear();
    activeStrokes.clear();
    finishedStrokes.clear();
    final glyphs = _glyphsForCurrentPack();
    for (var index = 0; index < glyphs.length; index++) {
      tiles.add(
        EmojiTile(
          id: index,
          emoji: glyphs[index],
          bounds: Rect.zero,
          rotation: (_random.nextDouble() - 0.5) * 0.16,
          color: tileColors[index % tileColors.length],
        ),
      );
    }
    complete = false;
    glowing = false;
    paused = false;
    _acceptingInput = true;
    now = 0;
    _lastTick = 0;
    _layoutTiles();
    _chooseTarget();
    notifyListeners();
  }

  void tick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final dt = _lastTick == 0 ? 0.0 : min(seconds - _lastTick, 0.05);
    _lastTick = seconds;
    if (paused || dt <= 0) {
      notifyListeners();
      return;
    }
    now += dt;
    if (glowing && now - _glowStartedAt >= 0.85) {
      glowing = false;
      if (tiles.isEmpty) {
        complete = true;
        targetEmoji = '';
        onSound?.call(GameSoundCue.success);
      } else {
        _chooseTarget();
        _acceptingInput = true;
      }
    }
    notifyListeners();
  }

  void pointerDown(int pointer, Offset position) {
    if (paused) return;
    activeStrokes[pointer] = ActiveStroke(
      pointer: pointer,
      points: [
        StrokePoint(
          position: position,
          color: strokeColorForSpeed(0),
          width: strokeWidthForSpeed(0),
          createdAt: DateTime.now(),
        ),
      ],
    );
    notifyListeners();
  }

  void pointerMove(int pointer, Offset position) {
    final stroke = activeStrokes[pointer];
    if (stroke == null || stroke.points.isEmpty) return;

    final prev = stroke.points.last;
    final stamp = DateTime.now();
    final dtMs = max(1, stamp.difference(prev.createdAt).inMilliseconds);
    final distance = (position - prev.position).distance;
    if (distance < 0.8) return;

    final speed = distance / dtMs * 1000;
    stroke.points.add(
      StrokePoint(
        position: position,
        color: strokeColorForSpeed(speed),
        width: strokeWidthForSpeed(speed),
        createdAt: stamp,
      ),
    );
    notifyListeners();
  }

  void pointerUp(int pointer, Offset position) {
    final stroke = activeStrokes.remove(pointer);
    if (stroke == null || stroke.points.isEmpty) {
      notifyListeners();
      return;
    }

    final totalMove = (position - stroke.points.first.position).distance;
    final isTap = stroke.points.length <= 2 && totalMove < tapMoveThreshold;

    if (isTap) {
      _handleTap(position);
    } else {
      if ((position - stroke.points.last.position).distance > 1) {
        final prev = stroke.points.last;
        final stamp = DateTime.now();
        final dtMs = max(1, stamp.difference(prev.createdAt).inMilliseconds);
        final distance = (position - prev.position).distance;
        final speed = distance / dtMs * 1000;
        stroke.points.add(
          StrokePoint(
            position: position,
            color: strokeColorForSpeed(speed),
            width: strokeWidthForSpeed(speed),
            createdAt: stamp,
          ),
        );
      }
      finishedStrokes.addAll(stroke.points);
    }
    notifyListeners();
  }

  void _handleTap(Offset position) {
    if (complete || !_acceptingInput) return;
    EmojiTile? selected;
    for (final tile in tiles.reversed) {
      if (tile.bounds.inflate(3).contains(position)) {
        selected = tile;
        break;
      }
    }
    if (selected == null) return;

    if (selected.emoji == targetEmoji) {
      tiles.remove(selected);
      onSound?.call(GameSoundCue.tada);
      glowing = true;
      _glowStartedAt = now;
      _acceptingInput = false;
    } else {
      onSound?.call(GameSoundCue.failure);
      _chooseTarget(excluding: targetEmoji);
    }
  }

  void setPaused(bool value) {
    paused = value;
    notifyListeners();
  }

  void _chooseTarget({String? excluding}) {
    if (tiles.isEmpty) return;
    final candidates = tiles
        .map((tile) => tile.emoji)
        .where((emoji) => tiles.length == 1 || emoji != excluding)
        .toList();
    targetEmoji = candidates[_random.nextInt(candidates.length)];
  }

  void _layoutTiles() {
    if (_bounds.isEmpty || tiles.isEmpty) return;
    final portrait = _bounds.height >= _bounds.width;
    final columns = portrait ? 4 : 6;
    final rows = portrait ? 6 : 4;
    final excluded = portrait
        ? {(2, 1), (2, 2), (3, 1), (3, 2)}
        : {(1, 2), (1, 3), (2, 2), (2, 3)};
    final slots = <(int, int)>[];
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        if (!excluded.contains((row, column))) slots.add((row, column));
      }
    }
    slots.shuffle(_random);

    final slotWidth = _bounds.width / columns;
    final slotHeight = _bounds.height / rows;
    final tileWidth = slotWidth * 0.82;
    final tileHeight = slotHeight * 0.72;
    for (var index = 0; index < tiles.length; index++) {
      final (row, column) = slots[index];
      final jitterX = (_random.nextDouble() - 0.5) * slotWidth * 0.08;
      final jitterY = (_random.nextDouble() - 0.5) * slotHeight * 0.08;
      tiles[index].bounds = Rect.fromCenter(
        center: Offset(
          (column + 0.5) * slotWidth + jitterX,
          (row + 0.5) * slotHeight + jitterY,
        ),
        width: tileWidth,
        height: tileHeight,
      );
    }
  }
}
