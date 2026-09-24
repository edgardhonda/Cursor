import 'dart:math';

import '../models/game_models.dart';

typedef SoundCallback = void Function(String sound);

class GameEngine {
  GameEngine({Random? random, this.onSound}) : _random = random ?? Random();

  final Random _random;
  final SoundCallback? onSound;

  ExplorerPhase phase = ExplorerPhase.walking;
  int segmentIndex = 0;
  double explorerX = 0.06;
  double now = 0;
  double phaseUntil = 0;
  double scrollT = 0;
  double animT = 0;
  double _lastTickSeconds = 0;
  double _stepAccum = 0;
  bool paused = false;

  List<PlacedObstacle> obstacles = [];
  List<PlacedObstacle> nextObstacles = [];
  PlacedObstacle? activeObstacle;
  List<ChoiceOption> choices = [];
  ResourceKind? resolvingResource;
  ResolveAction? resolvingAction;

  void reset() {
    segmentIndex = 0;
    explorerX = 0.06;
    phase = ExplorerPhase.walking;
    phaseUntil = 0;
    scrollT = 0;
    animT = 0;
    activeObstacle = null;
    choices = [];
    resolvingResource = null;
    resolvingAction = null;
    obstacles = _generateSegment();
    nextObstacles = [];
  }

  void tick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / 1e6;
    var dt = seconds - _lastTickSeconds;
    _lastTickSeconds = seconds;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;
    if (paused) return;

    now += dt;
    animT += dt;
    _updateFleeing(dt);

    switch (phase) {
      case ExplorerPhase.walking:
        _tickWalking(dt);
      case ExplorerPhase.choosing:
        break;
      case ExplorerPhase.showcasing:
        if (now >= phaseUntil) {
          phase = ExplorerPhase.resolving;
          phaseUntil = now + resolveSeconds;
          animT = 0;
          if (resolvingResource == ResourceKind.rope) {
            onSound?.call('climb');
          } else if (resolvingAction != null) {
            onSound?.call(_soundForAction(resolvingAction!));
          }
        }
      case ExplorerPhase.resolving:
        if (resolvingAction == ResolveAction.scare && activeObstacle != null) {
          // Começa a fugir durante a resolução.
          activeObstacle!.fleeT =
              ((animT / resolveSeconds) * 0.35).clamp(0.0, 0.35);
        }
        if (now >= phaseUntil) {
          if (resolvingResource == ResourceKind.rope && activeObstacle != null) {
            explorerX = (activeObstacle!.x + 0.1).clamp(0.06, 0.92);
          }
          final action = resolvingAction;
          final obs = activeObstacle;
          if (obs != null) {
            obs.cleared = true;
            obs.resolveResource = resolvingResource;
          }
          if (action == ResolveAction.scare && obs != null) {
            obs.fleeing = true;
            if (obs.fleeT < 0.35) obs.fleeT = 0.35;
          }
          activeObstacle = null;
          resolvingResource = null;
          resolvingAction = null;
          phase = ExplorerPhase.walking;
        }
      case ExplorerPhase.sad:
        if (now >= phaseUntil) {
          phase = ExplorerPhase.choosing;
          _buildChoices(activeObstacle!);
        }
      case ExplorerPhase.celebrating:
        if (now >= phaseUntil) {
          _beginScroll();
        }
      case ExplorerPhase.scrolling:
        scrollT = ((now - (phaseUntil - scrollSeconds)) / scrollSeconds)
            .clamp(0.0, 1.0);
        if (now >= phaseUntil) {
          obstacles = nextObstacles;
          nextObstacles = [];
          segmentIndex += 1;
          explorerX = 0.06;
          scrollT = 0;
          phase = ExplorerPhase.walking;
        }
    }
  }

  void _updateFleeing(double dt) {
    for (final o in obstacles) {
      if (!o.fleeing) continue;
      o.fleeT = (o.fleeT + dt / fleeSeconds).clamp(0.0, 1.0);
      if (o.fleeT >= 1) {
        o.fleeing = false;
      }
    }
  }

  void selectChoice(int index) {
    if (phase != ExplorerPhase.choosing) return;
    if (index < 0 || index >= choices.length) return;
    final choice = choices[index];
    if (choice.correct) {
      final spec = obstacleCatalog[activeObstacle!.kind]!;
      resolvingResource = choice.resource;
      resolvingAction = spec.action;
      phase = ExplorerPhase.showcasing;
      phaseUntil = now + showcaseSeconds;
      animT = 0;
      onSound?.call('tick');
    } else {
      phase = ExplorerPhase.sad;
      phaseUntil = now + sadSeconds;
      animT = 0;
      onSound?.call('fail');
    }
  }

  void _tickWalking(double dt) {
    final blocking = _nextBlocking();
    if (blocking != null && explorerX >= blocking.x - 0.04) {
      explorerX = blocking.x - 0.04;
      activeObstacle = blocking;
      phase = ExplorerPhase.choosing;
      _buildChoices(blocking);
      return;
    }

    explorerX += walkSpeed * dt;
    _stepAccum += dt;
    if (_stepAccum >= 0.28) {
      _stepAccum = 0;
      onSound?.call('walk');
    }

    if (explorerX >= 0.92) {
      explorerX = 0.92;
      phase = ExplorerPhase.celebrating;
      phaseUntil = now + cheerSeconds;
      animT = 0;
      onSound?.call('cheer');
    }
  }

  PlacedObstacle? _nextBlocking() {
    for (final o in obstacles) {
      if (!o.cleared) return o;
    }
    return null;
  }

  void _buildChoices(PlacedObstacle obstacle) {
    final spec = obstacleCatalog[obstacle.kind]!;
    final correct =
        spec.validResources[_random.nextInt(spec.validResources.length)];
    final wrongPool = ResourceKind.values
        .where((r) => !spec.validResources.contains(r))
        .toList()
      ..shuffle(_random);
    final picked = <ChoiceOption>[
      ChoiceOption(resource: correct, correct: true),
      ChoiceOption(resource: wrongPool[0], correct: false),
      ChoiceOption(resource: wrongPool[1], correct: false),
    ]..shuffle(_random);
    choices = picked;
  }

  void _beginScroll() {
    nextObstacles = _generateSegment();
    phase = ExplorerPhase.scrolling;
    scrollT = 0;
    phaseUntil = now + scrollSeconds;
    animT = 0;
  }

  List<PlacedObstacle> _generateSegment() {
    final count = minObstaclesPerSegment +
        _random.nextInt(maxObstaclesPerSegment - minObstaclesPerSegment + 1);
    final kinds = ObstacleKind.values.toList()..shuffle(_random);
    final selected = kinds.take(count).toList();
    final list = <PlacedObstacle>[];
    for (var i = 0; i < selected.length; i++) {
      final t = (i + 1) / (selected.length + 1);
      final jitter = (_random.nextDouble() - 0.5) * 0.06;
      list.add(
        PlacedObstacle(
          kind: selected[i],
          x: (t + jitter).clamp(0.22, 0.82),
        ),
      );
    }
    list.sort((a, b) => a.x.compareTo(b.x));
    // Separação mínima.
    for (var i = 1; i < list.length; i++) {
      if (list[i].x - list[i - 1].x < 0.14) {
        list[i] = PlacedObstacle(
          kind: list[i].kind,
          x: (list[i - 1].x + 0.14).clamp(0.22, 0.88),
        );
      }
    }
    return list;
  }

  String _soundForAction(ResolveAction action) => switch (action) {
        ResolveAction.crossOver => 'splash',
        ResolveAction.extinguish => 'splash',
        ResolveAction.climb => 'climb',
        ResolveAction.destroy => 'destroy',
        ResolveAction.scare => 'whoosh',
      };
}
