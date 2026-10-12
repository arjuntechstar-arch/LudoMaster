import '../models/domain_event.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/ruleset_config.dart';
import '../models/token.dart';
import 'capture_resolver.dart';
import 'invariant_checker.dart';
import 'move_validator.dart';
import 'turn_manager.dart';

/// Result envelope containing updated immutable [state] and list of emitted [events].
class GameTransitionResult {
  const GameTransitionResult({
    required this.state,
    required this.events,
  });

  final GameState state;
  final List<DomainEvent> events;
}

/// Pure, deterministic Ludo engine domain module.
/// Operates strictly as a functional reducer with zero side effects or I/O.
class LudoEngine {
  const LudoEngine._();

  /// Initializes a brand new match with the given [players] and [ruleset].
  static GameTransitionResult initializeGame({
    required String matchId,
    RulesetConfig ruleset = RulesetConfig.classic,
    required List<PlayerState> players,
    String? serverTime,
  }) {
    if (players.length < 2 || players.length > 4) {
      throw ArgumentError('Players count must be between 2 and 4 (got ${players.length})');
    }

    final now = serverTime ?? DateTime.now().toUtc().toIso8601String();

    // Prepare player tokens (generate fresh tokens in YARD if empty)
    final initializedPlayers = players.map((player) {
      final tokens = player.tokens.isNotEmpty
          ? player.tokens
          : List.generate(
              ruleset.tokensPerPlayer,
              (i) => Token(
                id: '${player.color.name}_$i',
                color: player.color,
                state: TokenState.yard,
                stepCount: 0,
                laneStep: 0,
                trackCell: null,
              ),
            );
      final assignedTeam = ruleset.isTeamMode
          ? (player.teamId ?? (player.seat % 2 == 0 ? 0 : 1))
          : player.teamId;
      return player.copyWith(
        teamId: assignedTeam,
        tokens: tokens,
        hasFinished: false,
        placement: null,
      );
    }).toList();

    final firstSeat = initializedPlayers.first.seat;

    var seq = 1;
    final events = <DomainEvent>[
      DomainEvent(
        event: EventType.matchStarted,
        matchId: matchId,
        sequence: seq++,
        serverTime: now,
        payload: {
          'ruleset': ruleset.toJson(),
          'players': initializedPlayers.map((p) => p.toJson()).toList(),
          'firstSeat': firstSeat,
        },
      ),
      DomainEvent(
        event: EventType.turnStarted,
        matchId: matchId,
        sequence: seq++,
        serverTime: now,
        payload: {
          'seat': firstSeat,
          'playerId': initializedPlayers.first.id,
        },
      ),
    ];

    final state = GameState(
      matchId: matchId,
      ruleset: ruleset,
      status: GameStatus.inProgress,
      phase: GamePhase.rollRequired,
      players: initializedPlayers,
      currentSeat: firstSeat,
      diceValue: null,
      consecutiveSixes: 0,
      legalMoves: const [],
      placements: const [],
      turnDeadline: null,
      sequence: seq,
      rngAudit: null,
      lastAction: {'type': 'INITIALIZED', 'time': now},
    );

    InvariantChecker.validate(state);
    return GameTransitionResult(state: state, events: List.unmodifiable(events));
  }

  /// Checks if roll action is permitted for [player].
  static bool rollAllowed(GameState state, PlayerState player) {
    if (state.status != GameStatus.inProgress) return false;
    if (state.currentSeat != player.seat) return false;
    if (state.phase != GamePhase.rollRequired) return false;
    if (player.hasFinished) {
      final canAssistPartner = state.ruleset.isTeamMode &&
          state.ruleset.partnerControlWhenFinished &&
          player.teamId != null &&
          state.players.any(
            (p) => p.teamId == player.teamId && !p.areAllTokensHome,
          );
      if (!canAssistPartner) return false;
    }
    return true;
  }

  /// Computes all legal moves available in the given [state] for [player] with [diceValue].
  static List<MoveOption> legalMoves(GameState state, PlayerState player, int diceValue) {
    return MoveValidator.calculateLegalMoves(
      state: state,
      player: player,
      diceValue: diceValue,
    );
  }

  /// Applies a server-generated dice roll to the current match state.
  static GameTransitionResult applyRoll({
    required GameState state,
    required PlayerState player,
    required int diceValue,
    String? serverTime,
    Map<String, dynamic>? rngAudit,
  }) {
    if (!rollAllowed(state, player)) {
      throw StateError(
        'Roll not allowed for player ${player.id} (seat ${player.seat}). '
        'Status: ${state.status.name}, Phase: ${state.phase.name}, Active seat: ${state.currentSeat}',
      );
    }

    if (diceValue < 1 || diceValue > 6) {
      throw ArgumentError('Dice value must be between 1 and 6 (got $diceValue)');
    }

    final now = serverTime ?? DateTime.now().toUtc().toIso8601String();
    var seq = state.sequence + 1;
    final events = <DomainEvent>[];

    events.add(
      DomainEvent(
        event: EventType.diceRolled,
        matchId: state.matchId,
        sequence: seq++,
        serverTime: now,
        payload: {
          'seat': player.seat,
          'playerId': player.id,
          'diceValue': diceValue,
          if (rngAudit != null) 'rngAudit': rngAudit,
        },
      ),
    );

    // Track consecutive sixes
    final isSix = diceValue == 6;
    final newConsecutiveSixes = isSix ? state.consecutiveSixes + 1 : 0;

    // Check consecutive sixes rule (e.g., 3 consecutive sixes forfeits turn)
    if (isSix && newConsecutiveSixes >= state.ruleset.maxConsecutiveSixes) {
      events.add(
        DomainEvent(
          event: EventType.turnTimeout,
          matchId: state.matchId,
          sequence: seq++,
          serverTime: now,
          payload: {
            'seat': player.seat,
            'playerId': player.id,
            'reason': 'CONSECUTIVE_SIXES_EXCEEDED',
            'limit': state.ruleset.maxConsecutiveSixes,
          },
        ),
      );

      // Turn immediately passes to the next active player
      final nextSeat = TurnManager.getNextActiveSeat(
        players: state.players,
        currentSeat: state.currentSeat,
        isTeamMode: state.ruleset.isTeamMode,
      );
      final nextPlayer = state.getPlayerBySeat(nextSeat)!;

      events.add(
        DomainEvent(
          event: EventType.turnStarted,
          matchId: state.matchId,
          sequence: seq++,
          serverTime: now,
          payload: {
            'seat': nextSeat,
            'playerId': nextPlayer.id,
          },
        ),
      );

      final nextState = state.copyWith(
        phase: GamePhase.rollRequired,
        currentSeat: nextSeat,
        diceValue: diceValue,
        consecutiveSixes: 0,
        legalMoves: const [],
        sequence: seq,
        rngAudit: rngAudit,
        lastAction: {
          'type': 'ROLL_FORFEIT_THREE_SIXES',
          'seat': player.seat,
          'time': now,
        },
      );

      InvariantChecker.validate(nextState);
      return GameTransitionResult(state: nextState, events: List.unmodifiable(events));
    }

    // Calculate legal moves with rolled dice
    final legalOptions = MoveValidator.calculateLegalMoves(
      state: state,
      player: player,
      diceValue: diceValue,
    );

    events.add(
      DomainEvent(
        event: EventType.legalMoves,
        matchId: state.matchId,
        sequence: seq++,
        serverTime: now,
        payload: {
          'seat': player.seat,
          'playerId': player.id,
          'diceValue': diceValue,
          'moves': legalOptions.map((m) => m.toJson()).toList(),
        },
      ),
    );

    if (legalOptions.isEmpty) {
      // No legal moves possible -> turn immediately ends and passes to next player
      final nextSeat = TurnManager.getNextActiveSeat(
        players: state.players,
        currentSeat: state.currentSeat,
        isTeamMode: state.ruleset.isTeamMode,
      );
      final nextPlayer = state.getPlayerBySeat(nextSeat)!;

      events.add(
        DomainEvent(
          event: EventType.turnStarted,
          matchId: state.matchId,
          sequence: seq++,
          serverTime: now,
          payload: {
            'seat': nextSeat,
            'playerId': nextPlayer.id,
          },
        ),
      );

      final nextState = state.copyWith(
        phase: GamePhase.rollRequired,
        currentSeat: nextSeat,
        diceValue: diceValue,
        consecutiveSixes: 0,
        legalMoves: const [],
        sequence: seq,
        rngAudit: rngAudit,
        lastAction: {
          'type': 'ROLL_NO_LEGAL_MOVES',
          'seat': player.seat,
          'dice': diceValue,
          'time': now,
        },
      );

      InvariantChecker.validate(nextState);
      return GameTransitionResult(state: nextState, events: List.unmodifiable(events));
    }

    // Legal moves available -> wait for player to pick move
    final nextState = state.copyWith(
      phase: GamePhase.moveRequired,
      diceValue: diceValue,
      consecutiveSixes: newConsecutiveSixes,
      legalMoves: legalOptions,
      sequence: seq,
      rngAudit: rngAudit,
      lastAction: {
        'type': 'ROLL_SUCCESS',
        'seat': player.seat,
        'dice': diceValue,
        'time': now,
      },
    );

    InvariantChecker.validate(nextState);
    return GameTransitionResult(state: nextState, events: List.unmodifiable(events));
  }

  /// Applies a token move chosen by [player].
  static GameTransitionResult applyMove({
    required GameState state,
    required PlayerState player,
    required String tokenId,
    String? serverTime,
  }) {
    if (state.status != GameStatus.inProgress) {
      throw StateError('Cannot apply move: match is ${state.status.name}');
    }
    if (state.currentSeat != player.seat) {
      throw StateError('Cannot apply move: not player ${player.id}\'s turn');
    }
    if (state.phase != GamePhase.moveRequired) {
      throw StateError('Cannot apply move: current phase is ${state.phase.name}');
    }

    // Match chosen token with validated legal options
    final moveOption = state.legalMoves.firstWhere(
      (m) => m.tokenId == tokenId,
      orElse: () => throw ArgumentError(
        'Illegal move: token $tokenId is not in the legal moves list',
      ),
    );

    final now = serverTime ?? DateTime.now().toUtc().toIso8601String();
    var seq = state.sequence + 1;
    final events = <DomainEvent>[];

    // 1. Move token to its destination
    // In Team Mode partner assistance, token may belong to active player's teammate
    final tokenOwner = state.players.firstWhere(
      (p) => p.getToken(tokenId) != null,
      orElse: () => player,
    );
    final movingToken = tokenOwner.getToken(tokenId)!;
    final updatedMovingToken = movingToken.copyWith(
      state: moveOption.toState,
      trackCell: moveOption.toTrackCell,
      clearTrackCell: moveOption.toTrackCell == null,
      stepCount: moveOption.toState == TokenState.track
          ? (movingToken.state == TokenState.yard
              ? 0
              : movingToken.stepCount + (state.diceValue ?? 0))
          : movingToken.stepCount,
      laneStep: moveOption.toLaneStep,
    );

    final updatedOwnerTokens = tokenOwner.tokens.map((t) {
      return t.id == tokenId ? updatedMovingToken : t;
    }).toList();

    var updatedOwner = tokenOwner.copyWith(tokens: updatedOwnerTokens);
    var updatedPlayers = state.players.map((p) {
      return p.id == tokenOwner.id ? updatedOwner : p;
    }).toList();

    events.add(
      DomainEvent(
        event: EventType.moveApplied,
        matchId: state.matchId,
        sequence: seq++,
        serverTime: now,
        payload: {
          'seat': player.seat,
          'playerId': player.id,
          'tokenId': tokenId,
          'fromState': moveOption.fromState.name,
          'toState': moveOption.toState.name,
          'fromTrackCell': moveOption.fromTrackCell,
          'toTrackCell': moveOption.toTrackCell,
          'laneStep': moveOption.toLaneStep,
        },
      ),
    );

    // 2. Resolve capture
    var captureBonus = false;
    if (moveOption.willCapture) {
      final (playersAfterCapture, captureEvent, grantsBonus) =
          CaptureResolver.resolveCapture(
        state: state.copyWith(players: updatedPlayers),
        movingPlayer: updatedPlayers.firstWhere((p) => p.id == player.id),
        move: moveOption,
        sequence: seq++,
        serverTime: now,
      );

      updatedPlayers = playersAfterCapture;
      captureBonus = grantsBonus;
      if (captureEvent != null) {
        events.add(captureEvent);
      }
    }

    // 3. Resolve Home entry
    var homeBonus = false;
    if (moveOption.willReachHome) {
      events.add(
        DomainEvent(
          event: EventType.tokenHome,
          matchId: state.matchId,
          sequence: seq++,
          serverTime: now,
          payload: {
            'seat': player.seat,
            'playerId': player.id,
            'tokenId': tokenId,
          },
        ),
      );
      homeBonus = state.ruleset.homeEntryGrantsBonusTurn;
    }

    // Re-fetch updated token owner after possible captures
    updatedOwner = updatedPlayers.firstWhere((p) => p.id == tokenOwner.id);

    // 4. Check if player has finished all tokens
    final placements = List<String>.from(state.placements);
    if (updatedOwner.areAllTokensHome && !updatedOwner.hasFinished) {
      placements.add(updatedOwner.id);
      updatedOwner = updatedOwner.copyWith(
        hasFinished: true,
        placement: placements.length,
      );
      updatedPlayers = updatedPlayers.map((p) {
        return p.id == updatedOwner.id ? updatedOwner : p;
      }).toList();
    }

    // 5. Check if game is completed
    final (isGameFinished, finalPlacements, finalPlayers) =
        TurnManager.evaluateGameCompletion(
      players: updatedPlayers,
      currentPlacements: placements,
      isTeamMode: state.ruleset.isTeamMode,
    );

    if (isGameFinished) {
      events.add(
        DomainEvent(
          event: EventType.matchFinished,
          matchId: state.matchId,
          sequence: seq++,
          serverTime: now,
          payload: {
            'placements': finalPlacements,
            'winner': finalPlacements.isNotEmpty ? finalPlacements.first : null,
          },
        ),
      );

      final finishedState = state.copyWith(
        status: GameStatus.finished,
        phase: GamePhase.finished,
        players: finalPlayers,
        placements: finalPlacements,
        legalMoves: const [],
        sequence: seq,
        lastAction: {
          'type': 'MATCH_FINISHED',
          'winner': finalPlacements.isNotEmpty ? finalPlacements.first : null,
          'time': now,
        },
      );

      InvariantChecker.validate(finishedState);
      return GameTransitionResult(
        state: finishedState,
        events: List.unmodifiable(events),
      );
    }

    // 6. Check bonus turn
    final activePlayerAfterMove = finalPlayers.firstWhere((p) => p.id == player.id);
    final rolledSix = state.diceValue == 6;
    final grantBonus = TurnManager.shouldGrantBonusTurn(
      player: activePlayerAfterMove,
      rolledSix: rolledSix,
      madeCapture: captureBonus,
      tokenReachedHome: homeBonus,
      consecutiveSixForfeit: false,
      state: state,
    );

    if (grantBonus) {
      events.add(
        DomainEvent(
          event: EventType.bonusTurn,
          matchId: state.matchId,
          sequence: seq++,
          serverTime: now,
          payload: {
            'seat': activePlayerAfterMove.seat,
            'playerId': activePlayerAfterMove.id,
            'reason': rolledSix
                ? 'ROLLED_SIX'
                : (captureBonus ? 'CAPTURE_BONUS' : 'HOME_ENTRY_BONUS'),
          },
        ),
      );

      events.add(
        DomainEvent(
          event: EventType.turnStarted,
          matchId: state.matchId,
          sequence: seq++,
          serverTime: now,
          payload: {
            'seat': activePlayerAfterMove.seat,
            'playerId': activePlayerAfterMove.id,
            'isBonusTurn': true,
          },
        ),
      );

      final nextState = state.copyWith(
        players: finalPlayers,
        placements: finalPlacements,
        phase: GamePhase.rollRequired,
        clearDiceValue: true,
        legalMoves: const [],
        sequence: seq,
        lastAction: {
          'type': 'MOVE_APPLIED_BONUS_TURN',
          'token': tokenId,
          'seat': activePlayerAfterMove.seat,
          'time': now,
        },
      );

      InvariantChecker.validate(nextState);
      return GameTransitionResult(state: nextState, events: List.unmodifiable(events));
    }

    // 7. No bonus turn -> advance to next active seat
    final nextSeat = TurnManager.getNextActiveSeat(
      players: finalPlayers,
      currentSeat: state.currentSeat,
      isTeamMode: state.ruleset.isTeamMode,
    );
    final nextPlayer = finalPlayers.firstWhere((p) => p.seat == nextSeat);

    events.add(
      DomainEvent(
        event: EventType.turnStarted,
        matchId: state.matchId,
        sequence: seq++,
        serverTime: now,
        payload: {
          'seat': nextSeat,
          'playerId': nextPlayer.id,
        },
      ),
    );

    final nextState = state.copyWith(
      players: finalPlayers,
      placements: finalPlacements,
      currentSeat: nextSeat,
      phase: GamePhase.rollRequired,
      clearDiceValue: true,
      consecutiveSixes: 0,
      legalMoves: const [],
      sequence: seq,
      lastAction: {
        'type': 'MOVE_APPLIED_NEXT_TURN',
        'token': tokenId,
        'nextSeat': nextSeat,
        'time': now,
      },
    );

    InvariantChecker.validate(nextState);
    return GameTransitionResult(state: nextState, events: List.unmodifiable(events));
  }

  /// Resolves turn timeout when player fails to act within the turn deadline.
  static GameTransitionResult resolveTimeout({
    required GameState state,
    String? serverTime,
  }) {
    if (state.status != GameStatus.inProgress) {
      return GameTransitionResult(state: state, events: const []);
    }

    final now = serverTime ?? DateTime.now().toUtc().toIso8601String();
    var seq = state.sequence + 1;
    final events = <DomainEvent>[];

    events.add(
      DomainEvent(
        event: EventType.turnTimeout,
        matchId: state.matchId,
        sequence: seq++,
        serverTime: now,
        payload: {
          'seat': state.currentSeat,
          'phase': state.phase.name,
        },
      ),
    );

    // If waiting for move and legal moves exist, auto-apply the first legal move
    if (state.phase == GamePhase.moveRequired && state.legalMoves.isNotEmpty) {
      final chosenMove = state.legalMoves.first;
      return applyMove(
        state: state,
        player: state.currentPlayer,
        tokenId: chosenMove.tokenId,
        serverTime: now,
      );
    }

    // Otherwise, advance seat to next player
    final nextSeat = TurnManager.getNextActiveSeat(
      players: state.players,
      currentSeat: state.currentSeat,
      isTeamMode: state.ruleset.isTeamMode,
    );
    final nextPlayer = state.getPlayerBySeat(nextSeat)!;

    events.add(
      DomainEvent(
        event: EventType.turnStarted,
        matchId: state.matchId,
        sequence: seq++,
        serverTime: now,
        payload: {
          'seat': nextSeat,
          'playerId': nextPlayer.id,
        },
      ),
    );

    final nextState = state.copyWith(
      currentSeat: nextSeat,
      phase: GamePhase.rollRequired,
      clearDiceValue: true,
      consecutiveSixes: 0,
      legalMoves: const [],
      sequence: seq,
      lastAction: {'type': 'TIMEOUT_PASS', 'seat': state.currentSeat, 'time': now},
    );

    InvariantChecker.validate(nextState);
    return GameTransitionResult(state: nextState, events: List.unmodifiable(events));
  }

  /// Pure invariant validator matching specification.
  static void validateInvariants(GameState state) {
    InvariantChecker.validate(state);
  }
}
