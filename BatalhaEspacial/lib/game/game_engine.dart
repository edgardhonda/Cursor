import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/game_audio_controller.dart';
import '../models/game_models.dart';

class GameEngine extends ChangeNotifier {
  GameEngine({this.onSound});

  final void Function(GameSoundCue cue)? onSound;
  final Random _random = Random();

  GamePhase phase = GamePhase.waiting;
  double now = 0;
  double terrainScroll = 0;
  double _lastTickSeconds = 0;
  double _nextEnemyAt = 0;
  double _phaseStartedAt = 0;
  double _approachAtFailure = 0;

  EnemyModel? enemy;
  List<int> choices = const [];
  int score = 0;
  int bestScore = 0;
  int rounds = 0;

  double get phaseElapsed => now - _phaseStartedAt;

  bool get isRunning =>
      phase == GamePhase.cruising ||
      phase == GamePhase.combat ||
      phase == GamePhase.firingLaser ||
      phase == GamePhase.enemyDestroyed ||
      phase == GamePhase.playerScared ||
      phase == GamePhase.enemyCharging ||
      phase == GamePhase.playerExploding;

  double get combatTimeLeft {
    if (phase != GamePhase.combat || enemy == null) return 0;
    return max(0, combatDurationSeconds - (now - _phaseStartedAt));
  }

  double _chargeDuration() {
    final remaining = collisionApproach - _approachAtFailure;
    return max(0.55, remaining * enemyChargeBaseSeconds);
  }

  void start() {
    now = 0;
    _lastTickSeconds = 0;
    terrainScroll = 0;
    score = 0;
    rounds = 0;
    enemy = null;
    choices = const [];
    _approachAtFailure = 0;
    _scheduleNextEnemy();
    phase = GamePhase.cruising;
    _phaseStartedAt = now;
    notifyListeners();
  }

  void reset() {
    phase = GamePhase.waiting;
    now = 0;
    _lastTickSeconds = 0;
    terrainScroll = 0;
    enemy = null;
    choices = const [];
    score = 0;
    rounds = 0;
    _approachAtFailure = 0;
    notifyListeners();
  }

  void tick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final dt = _lastTickSeconds == 0 ? 0 : min(seconds - _lastTickSeconds, 0.05);
    _lastTickSeconds = seconds;
    if (dt <= 0 || !isRunning) return;

    now += dt;
    terrainScroll = (terrainScroll + dt * 2.4) % 1.0;

    switch (phase) {
      case GamePhase.waiting:
      case GamePhase.playerDestroyed:
        return;
      case GamePhase.cruising:
        if (now >= _nextEnemyAt) _beginCombat();
        break;
      case GamePhase.combat:
        enemy?.approach = ((now - _phaseStartedAt) / combatDurationSeconds * combatMaxApproach)
            .clamp(0.0, combatMaxApproach);
        if (now - _phaseStartedAt >= combatDurationSeconds) {
          _beginFailureSequence();
        }
        break;
      case GamePhase.firingLaser:
        if (now - _phaseStartedAt >= laserDurationSeconds) {
          final defeated = enemy;
          if (defeated != null) {
            score += defeated.strength;
            if (score > bestScore) bestScore = score;
          }
          phase = GamePhase.enemyDestroyed;
          _phaseStartedAt = now;
          onSound?.call(GameSoundCue.destroy);
        }
        break;
      case GamePhase.enemyDestroyed:
        if (now - _phaseStartedAt >= enemyDestroyedPauseSeconds) {
          enemy = null;
          choices = const [];
          _scheduleNextEnemy();
          phase = GamePhase.cruising;
        }
        break;
      case GamePhase.playerScared:
        if (now - _phaseStartedAt >= scaredFaceDurationSeconds) {
          phase = GamePhase.enemyCharging;
          _phaseStartedAt = now;
        }
        break;
      case GamePhase.enemyCharging:
        final t = (phaseElapsed / _chargeDuration()).clamp(0.0, 1.0);
        enemy?.approach =
            uiLerp(_approachAtFailure, collisionApproach, t);
        if (t >= 1.0) {
          phase = GamePhase.playerExploding;
          _phaseStartedAt = now;
          onSound?.call(GameSoundCue.blast);
        }
        break;
      case GamePhase.playerExploding:
        if (now - _phaseStartedAt >= playerExplosionDurationSeconds) {
          _finishPlayerDefeat();
        }
        break;
    }
    notifyListeners();
  }

  void pickChoice(int value) {
    if (phase != GamePhase.combat || enemy == null) return;
    if (value == enemy!.strength) {
      phase = GamePhase.firingLaser;
      _phaseStartedAt = now;
      onSound?.call(GameSoundCue.laser);
    } else {
      _beginFailureSequence();
    }
    notifyListeners();
  }

  void _beginCombat() {
    rounds++;
    final strength =
        minEnemyStrength + _random.nextInt(maxEnemyStrength - minEnemyStrength + 1);
    final kind = EnemyKind.values[_random.nextInt(EnemyKind.values.length)];
    enemy = EnemyModel(kind: kind, strength: strength, spawnedAt: now);
    choices = _buildChoices(strength);
    phase = GamePhase.combat;
    _phaseStartedAt = now;
    onSound?.call(GameSoundCue.alert);
  }

  void _beginFailureSequence() {
    _approachAtFailure = enemy?.approach ?? 0;
    choices = const [];
    phase = GamePhase.playerScared;
    _phaseStartedAt = now;
    onSound?.call(GameSoundCue.wrong);
  }

  List<int> _buildChoices(int correct) {
    final options = <int>{correct};
    var guard = 0;
    while (options.length < 3 && guard < 40) {
      guard++;
      final delta = 1 + _random.nextInt(4);
      final sign = _random.nextBool() ? 1 : -1;
      final candidate =
          (correct + sign * delta).clamp(minEnemyStrength, maxEnemyStrength);
      if (candidate != correct) options.add(candidate);
    }
    final list = options.toList()..shuffle(_random);
    return list;
  }

  void _scheduleNextEnemy() {
    _nextEnemyAt = now + minCruiseSeconds + _random.nextDouble() * (maxCruiseSeconds - minCruiseSeconds);
  }

  void _finishPlayerDefeat() {
    if (score > bestScore) bestScore = score;
    phase = GamePhase.playerDestroyed;
    enemy = null;
    choices = const [];
    notifyListeners();
  }

  double uiLerp(double a, double b, double t) => a + (b - a) * t;
}
