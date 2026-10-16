import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';

import '../services/audio_service.dart';
import '../services/game_pacing.dart';
import '../services/storage_service.dart';

class GameControllerState {
  const GameControllerState({
    required this.gameState,
    this.botDifficulty = BotDifficulty.hard,
    this.isBotThinking = false,
    this.isAnimating = false,
    this.rollSequence = 0,
    this.remainingSeconds = GamePacing.turnDurationSeconds,
    this.hasSavedGame = false,
    this.latestCaptureEvent,
  });
  final GameState gameState;
  final BotDifficulty botDifficulty;
  final bool isBotThinking;
  final bool isAnimating;
  final int rollSequence;
  final int remainingSeconds;
  final bool hasSavedGame;
  final DomainEvent? latestCaptureEvent;
  GameControllerState copyWith({
    GameState? gameState,
    BotDifficulty? botDifficulty,
    bool? isBotThinking,
    bool? isAnimating,
    int? rollSequence,
    int? remainingSeconds,
    bool? hasSavedGame,
    DomainEvent? latestCaptureEvent,
    bool clearCaptureEvent = false,
  }) => GameControllerState(
    gameState: gameState ?? this.gameState,
    botDifficulty: botDifficulty ?? this.botDifficulty,
    isBotThinking: isBotThinking ?? this.isBotThinking,
    isAnimating: isAnimating ?? this.isAnimating,
    rollSequence: rollSequence ?? this.rollSequence,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    hasSavedGame: hasSavedGame ?? this.hasSavedGame,
    latestCaptureEvent: clearCaptureEvent
        ? null
        : latestCaptureEvent ?? this.latestCaptureEvent,
  );
}

/// Hold the active player's turn until the animation finishes. Save only the
/// engine's final state, so closing during an animation cannot repeat a move.
class GameController extends StateNotifier<GameControllerState?> {
  GameController({Random? random}) : _rng = random ?? Random(), super(null);
  final Random _rng;
  Timer? _actionTimer;
  Timer? _autoMoveTimer;
  Timer? _turnTimer;
  int _generation = 0;

  void _cancelActions() {
    _generation++;
    _actionTimer?.cancel();
    _autoMoveTimer?.cancel();
    _stopTurnTimer();
  }

  void _stopTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
  }

  void startNewGame({
    required List<PlayerState> players,
    RulesetConfig ruleset = RulesetConfig.classic,
    BotDifficulty botDifficulty = BotDifficulty.hard,
  }) {
    _cancelActions();
    AudioService.startGameMusic();
    final result = LudoEngine.initializeGame(
      matchId: 'offline_${DateTime.now().millisecondsSinceEpoch}',
      ruleset: ruleset,
      players: players,
    );
    state = GameControllerState(
      gameState: result.state,
      botDifficulty: botDifficulty,
      hasSavedGame: true,
    );
    StorageService.saveActiveGame(result.state);
    _scheduleNextAction();
  }

  void resumeSavedGame(GameState savedState) {
    _cancelActions();
    AudioService.startGameMusic();
    // Saved move options are a cache. Rebuild them from all tokens and the roll.
    if (savedState.phase == GamePhase.moveRequired &&
        savedState.diceValue != null) {
      savedState = savedState.copyWith(
        legalMoves: MoveValidator.calculateLegalMoves(
          state: savedState,
          player: savedState.currentPlayer,
          diceValue: savedState.diceValue!,
        ),
      );
    }
    state = GameControllerState(gameState: savedState, hasSavedGame: true);
    _scheduleNextAction();
  }

  /// Only a lone deployed token may move without the player's selection.
  /// A second token waiting for an exact home roll still counts as on the board.
  /// On a six, every yard exit is also a separate choice.
  static bool canAutoMove(GameState game) {
    if (game.phase != GamePhase.moveRequired ||
        !game.ruleset.autoMoveSingleLegalMove ||
        game.diceValue == null) {
      return false;
    }
    final moves = MoveValidator.calculateLegalMoves(
      state: game,
      player: game.currentPlayer,
      diceValue: game.diceValue!,
    );
    if (moves.length != 1 ||
        game.legalMoves.length != 1 ||
        moves.single.tokenId != game.legalMoves.single.tokenId) {
      return false;
    }
    final owner = game.players.firstWhere(
      (player) =>
          player.tokens.any((token) => token.id == moves.single.tokenId),
    );
    final candidates = owner.tokens.where(
      (token) =>
          token.state == TokenState.track ||
          token.state == TokenState.homeLane ||
          (token.state == TokenState.yard && game.diceValue == 6),
    );
    return candidates.length == 1;
  }

  void rollDice() {
    final current = state;
    if (current == null ||
        current.isAnimating ||
        current.gameState.currentPlayer.isBot) {
      return;
    }
    if (current.gameState.phase == GamePhase.moveRequired) {
      if (current.gameState.legalMoves.length == 1) {
        selectMove(current.gameState.legalMoves.single.tokenId);
      }
      return;
    }
    _roll(playHaptic: true);
  }

  void _roll({bool playHaptic = false}) {
    final current = state;
    if (current == null || current.isAnimating) return;
    final game = current.gameState;
    if (!LudoEngine.rollAllowed(game, game.currentPlayer)) return;
    final roll = _rng.nextInt(6) + 1;
    final result = LudoEngine.applyRoll(
      state: game,
      player: game.currentPlayer,
      diceValue: roll,
    );
    _stopTurnTimer();
    if (playHaptic) AudioService.playRollHaptic();
    _autoMoveTimer?.cancel();
    state = current.copyWith(
      gameState: game.copyWith(
        diceValue: roll,
        phase: GamePhase.resolving,
        legalMoves: [],
      ),
      isAnimating: true,
      rollSequence: current.rollSequence + 1,
    );
    _finishAfter(GamePacing.diceRoll, result.state, result.events);
  }

  void selectMove(String tokenId) {
    final current = state;
    if (current == null ||
        current.isAnimating ||
        current.gameState.currentPlayer.isBot) {
      return;
    }
    _move(tokenId);
  }

  void _move(String tokenId) {
    final current = state;
    if (current == null || current.isAnimating) return;
    final game = current.gameState;
    if (game.phase != GamePhase.moveRequired ||
        !game.legalMoves.any((move) => move.tokenId == tokenId)) {
      return;
    }
    _autoMoveTimer?.cancel();
    final result = LudoEngine.applyMove(
      state: game,
      player: game.currentPlayer,
      tokenId: tokenId,
    );
    _stopTurnTimer();
    final movingToken = game.players
        .expand((player) => player.tokens)
        .firstWhere((token) => token.id == tokenId);
    final animationSteps = movingToken.state == TokenState.yard
        ? 1
        : (game.diceValue ?? 1);
    AudioService.playMoveHaptic();
    state = current.copyWith(
      gameState: game.copyWith(
        players: game.players
            .map(
              (player) => player.seat == game.currentSeat
                  ? result.state.getPlayerBySeat(player.seat)!
                  : player,
            )
            .toList(),
        phase: GamePhase.resolving,
        legalMoves: [],
      ),
      isAnimating: true,
    );
    _finishAfter(
      GamePacing.tokenMoveForSteps(animationSteps),
      result.state,
      result.events,
    );
  }

  void _finishAfter(
    Duration delay,
    GameState finalState,
    List<DomainEvent> events,
  ) {
    StorageService.saveActiveGame(finalState);
    final generation = _generation;
    _actionTimer?.cancel();
    _actionTimer = Timer(delay, () {
      if (!mounted || generation != _generation || state == null) return;
      DomainEvent? capture;
      for (final event in events) {
        if (event.event == EventType.tokenCaptured) {
          capture = event;
          AudioService.playCaptureHaptic();
        } else if (event.event == EventType.matchFinished) {
          AudioService.playVictoryHaptic();
        }
      }
      state = state!.copyWith(
        gameState: finalState,
        isAnimating: false,
        latestCaptureEvent: capture,
      );
      _scheduleNextAction();
    });
  }

  void _scheduleNextAction() {
    final current = state;
    if (current == null || current.isAnimating) return;
    final game = current.gameState;
    if (game.status == GameStatus.finished) {
      _stopTurnTimer();
      AudioService.stopGameMusic();
      StorageService.clearActiveGame();
      state = current.copyWith(isBotThinking: false);
      return;
    }
    final generation = _generation;
    bool stillCurrent() =>
        mounted &&
        generation == _generation &&
        state != null &&
        state!.gameState.matchId == game.matchId &&
        state!.gameState.sequence == game.sequence &&
        !state!.isAnimating;
    if (game.currentPlayer.isBot) {
      _stopTurnTimer();
      state = current.copyWith(isBotThinking: true);
      _actionTimer?.cancel();
      _actionTimer = Timer(GamePacing.botPause, () {
        if (!stillCurrent()) return;
        if (game.phase == GamePhase.moveRequired) {
          final chosen = BotEvaluator.chooseMove(
            state: game,
            player: game.currentPlayer,
            legalMoves: game.legalMoves,
            difficulty: current.botDifficulty,
            rng: _rng,
          );
          _move(chosen.tokenId);
        } else {
          _roll();
        }
      });
    } else {
      state = current.copyWith(isBotThinking: false);
      _startTurnTimer();
      if (canAutoMove(game)) {
        _autoMoveTimer?.cancel();
        _autoMoveTimer = Timer(GamePacing.autoMovePause, () {
          if (stillCurrent() && canAutoMove(state!.gameState)) {
            selectMove(state!.gameState.legalMoves.single.tokenId);
          }
        });
      }
    }
  }

  void _startTurnTimer() {
    _stopTurnTimer();
    final current = state;
    if (current == null ||
        current.gameState.currentPlayer.isBot ||
        (current.gameState.phase != GamePhase.rollRequired &&
            current.gameState.phase != GamePhase.moveRequired)) {
      return;
    }

    var secondsLeft = GamePacing.turnDurationSeconds;
    state = current.copyWith(remainingSeconds: secondsLeft);
    final matchId = current.gameState.matchId;
    final sequence = current.gameState.sequence;
    final seat = current.gameState.currentSeat;
    final phase = current.gameState.phase;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final latest = state;
      if (!mounted ||
          latest == null ||
          latest.gameState.matchId != matchId ||
          latest.gameState.sequence != sequence ||
          latest.gameState.currentSeat != seat ||
          latest.gameState.phase != phase ||
          latest.isAnimating) {
        timer.cancel();
        if (identical(_turnTimer, timer)) _turnTimer = null;
        return;
      }

      secondsLeft--;
      state = latest.copyWith(remainingSeconds: secondsLeft);
      if (secondsLeft <= 0) {
        timer.cancel();
        _turnTimer = null;
        _handleTurnTimeout(matchId, sequence, seat, phase);
      }
    });
  }

  void _handleTurnTimeout(
    String matchId,
    int sequence,
    int seat,
    GamePhase phase,
  ) {
    final current = state;
    if (current == null ||
        current.gameState.matchId != matchId ||
        current.gameState.sequence != sequence ||
        current.gameState.currentSeat != seat ||
        current.gameState.phase != phase ||
        current.isAnimating ||
        current.gameState.currentPlayer.isBot) {
      return;
    }

    final game = current.gameState;
    if (phase == GamePhase.moveRequired && game.legalMoves.isNotEmpty) {
      final chosen = game.legalMoves[_rng.nextInt(game.legalMoves.length)];
      _move(chosen.tokenId);
      return;
    }

    // A missed roll forfeits this turn; a missed move is handled above.
    final result = LudoEngine.resolveTimeout(state: game);
    StorageService.saveActiveGame(result.state);
    state = current.copyWith(
      gameState: result.state,
      isAnimating: false,
      remainingSeconds: GamePacing.turnDurationSeconds,
    );
    _scheduleNextAction();
  }

  void clearCaptureEvent() {
    if (state != null) state = state!.copyWith(clearCaptureEvent: true);
  }

  void quitMatch() {
    _cancelActions();
    StorageService.clearActiveGame();
    AudioService.stopGameMusic();
    state = null;
  }

  @override
  void dispose() {
    _cancelActions();
    super.dispose();
  }
}

final gameControllerProvider =
    StateNotifierProvider<GameController, GameControllerState?>(
      (ref) => GameController(),
    );
