import 'package:meta/meta.dart';
import 'player.dart';
import 'player_color.dart';
import 'ruleset_config.dart';
import 'token.dart';

/// Overall status of the match.
enum GameStatus {
  waiting,
  inProgress,
  finished;

  static GameStatus fromString(String val) {
    return GameStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown GameStatus: $val'),
    );
  }
}

/// Operational phase within a turn.
enum GamePhase {
  waiting,
  rollRequired,
  moveRequired,
  resolving,
  finished;

  static GamePhase fromString(String val) {
    return GamePhase.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown GamePhase: $val'),
    );
  }
}

/// Represents a validated legal move choice available to a player.
@immutable
class MoveOption {
  const MoveOption({
    required this.tokenId,
    required this.color,
    required this.fromState,
    required this.toState,
    this.fromTrackCell,
    this.toTrackCell,
    this.fromLaneStep = 0,
    this.toLaneStep = 0,
    this.willCapture = false,
    this.capturedTokenId,
    this.capturedPlayerId,
    this.willReachHome = false,
  });

  final String tokenId;
  final PlayerColor color;
  final TokenState fromState;
  final TokenState toState;
  final int? fromTrackCell;
  final int? toTrackCell;
  final int fromLaneStep;
  final int toLaneStep;
  final bool willCapture;
  final String? capturedTokenId;
  final String? capturedPlayerId;
  final bool willReachHome;

  Map<String, dynamic> toJson() {
    return {
      'tokenId': tokenId,
      'color': color.name,
      'fromState': fromState.name,
      'toState': toState.name,
      'fromTrackCell': fromTrackCell,
      'toTrackCell': toTrackCell,
      'fromLaneStep': fromLaneStep,
      'toLaneStep': toLaneStep,
      'willCapture': willCapture,
      'capturedTokenId': capturedTokenId,
      'capturedPlayerId': capturedPlayerId,
      'willReachHome': willReachHome,
    };
  }

  factory MoveOption.fromJson(Map<String, dynamic> json) {
    return MoveOption(
      tokenId: json['tokenId'] as String,
      color: PlayerColor.fromName(json['color'] as String),
      fromState: TokenState.fromString(json['fromState'] as String),
      toState: TokenState.fromString(json['toState'] as String),
      fromTrackCell: json['fromTrackCell'] as int?,
      toTrackCell: json['toTrackCell'] as int?,
      fromLaneStep: json['fromLaneStep'] as int? ?? 0,
      toLaneStep: json['toLaneStep'] as int? ?? 0,
      willCapture: json['willCapture'] as bool? ?? false,
      capturedTokenId: json['capturedTokenId'] as String?,
      capturedPlayerId: json['capturedPlayerId'] as String?,
      willReachHome: json['willReachHome'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'MoveOption($tokenId: ${fromState.name} -> ${toState.name}, cap: $willCapture, home: $willReachHome)';
}

/// Immutable, authoritative domain GameState.
@immutable
class GameState {
  const GameState({
    required this.matchId,
    required this.ruleset,
    required this.status,
    required this.phase,
    required this.players,
    required this.currentSeat,
    this.diceValue,
    this.consecutiveSixes = 0,
    this.legalMoves = const [],
    this.placements = const [],
    this.turnDeadline,
    this.sequence = 0,
    this.rngAudit,
    this.lastAction,
  });

  final String matchId;
  final RulesetConfig ruleset;
  final GameStatus status;
  final GamePhase phase;
  final List<PlayerState> players;
  final int currentSeat;
  final int? diceValue;
  final int consecutiveSixes;
  final List<MoveOption> legalMoves;
  final List<String> placements;
  final String? turnDeadline;
  final int sequence;
  final Map<String, dynamic>? rngAudit;
  final Map<String, dynamic>? lastAction;

  PlayerState get currentPlayer =>
      players.firstWhere((p) => p.seat == currentSeat);

  PlayerState? getPlayerBySeat(int seat) {
    for (final p in players) {
      if (p.seat == seat) return p;
    }
    return null;
  }

  PlayerState? getPlayerById(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  GameState copyWith({
    String? matchId,
    RulesetConfig? ruleset,
    GameStatus? status,
    GamePhase? phase,
    List<PlayerState>? players,
    int? currentSeat,
    int? diceValue,
    bool clearDiceValue = false,
    int? consecutiveSixes,
    List<MoveOption>? legalMoves,
    List<String>? placements,
    String? turnDeadline,
    bool clearTurnDeadline = false,
    int? sequence,
    Map<String, dynamic>? rngAudit,
    bool clearRngAudit = false,
    Map<String, dynamic>? lastAction,
  }) {
    return GameState(
      matchId: matchId ?? this.matchId,
      ruleset: ruleset ?? this.ruleset,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      players: players ?? this.players,
      currentSeat: currentSeat ?? this.currentSeat,
      diceValue: clearDiceValue ? null : (diceValue ?? this.diceValue),
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      legalMoves: legalMoves ?? this.legalMoves,
      placements: placements ?? this.placements,
      turnDeadline: clearTurnDeadline ? null : (turnDeadline ?? this.turnDeadline),
      sequence: sequence ?? this.sequence,
      rngAudit: clearRngAudit ? null : (rngAudit ?? this.rngAudit),
      lastAction: lastAction ?? this.lastAction,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'ruleset': ruleset.toJson(),
      'status': status.name,
      'phase': phase.name,
      'players': players.map((p) => p.toJson()).toList(),
      'currentSeat': currentSeat,
      'diceValue': diceValue,
      'consecutiveSixes': consecutiveSixes,
      'legalMoves': legalMoves.map((m) => m.toJson()).toList(),
      'placements': placements,
      'turnDeadline': turnDeadline,
      'sequence': sequence,
      'rngAudit': rngAudit,
      'lastAction': lastAction,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      matchId: json['matchId'] as String,
      ruleset: RulesetConfig.fromJson(json['ruleset'] as Map<String, dynamic>),
      status: GameStatus.fromString(json['status'] as String),
      phase: GamePhase.fromString(json['phase'] as String),
      players: (json['players'] as List<dynamic>)
          .map((p) => PlayerState.fromJson(p as Map<String, dynamic>))
          .toList(),
      currentSeat: json['currentSeat'] as int,
      diceValue: json['diceValue'] as int?,
      consecutiveSixes: json['consecutiveSixes'] as int? ?? 0,
      legalMoves: (json['legalMoves'] as List<dynamic>?)
              ?.map((m) => MoveOption.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
      placements: (json['placements'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList() ??
          const [],
      turnDeadline: json['turnDeadline'] as String?,
      sequence: json['sequence'] as int? ?? 0,
      rngAudit: json['rngAudit'] as Map<String, dynamic>?,
      lastAction: json['lastAction'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() =>
      'GameState(match: $matchId, seq: $sequence, seat: $currentSeat, phase: ${phase.name}, dice: $diceValue)';
}
