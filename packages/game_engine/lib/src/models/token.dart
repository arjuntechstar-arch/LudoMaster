import 'package:meta/meta.dart';
import 'player_color.dart';

/// State of an individual Ludo token.
enum TokenState {
  yard,
  track,
  homeLane,
  home;

  static TokenState fromString(String val) {
    return TokenState.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown TokenState: $val'),
    );
  }
}

/// Immutable representation of a token on the board.
@immutable
class Token {
  const Token({
    required this.id,
    required this.color,
    this.state = TokenState.yard,
    this.stepCount = 0,
    this.laneStep = 0,
    this.trackCell,
  });

  final String id;
  final PlayerColor color;
  final TokenState state;

  /// Steps taken on the main 52-cell track (0 to 50).
  /// 0 is the start cell for this color.
  /// 50 is the step directly before entering the home lane.
  final int stepCount;

  /// Step inside the colored home lane (1 to 5), or 6 for [TokenState.home].
  final int laneStep;

  /// The absolute board cell (0 to 51) if currently on [TokenState.track].
  final int? trackCell;

  /// Total distance traveled from yard exit (1 to 57).
  /// 0 = in yard.
  /// 1..51 = on main track.
  /// 52..56 = in home lane (step 1 to 5).
  /// 57 = finished in HOME.
  int get totalProgress {
    switch (state) {
      case TokenState.yard:
        return 0;
      case TokenState.track:
        return stepCount + 1;
      case TokenState.homeLane:
        return 51 + laneStep;
      case TokenState.home:
        return 57;
    }
  }

  bool get isInYard => state == TokenState.yard;
  bool get isOnTrack => state == TokenState.track;
  bool get isInHomeLane => state == TokenState.homeLane;
  bool get isHome => state == TokenState.home;

  Token copyWith({
    String? id,
    PlayerColor? color,
    TokenState? state,
    int? stepCount,
    int? laneStep,
    int? trackCell,
    bool clearTrackCell = false,
  }) {
    return Token(
      id: id ?? this.id,
      color: color ?? this.color,
      state: state ?? this.state,
      stepCount: stepCount ?? this.stepCount,
      laneStep: laneStep ?? this.laneStep,
      trackCell: clearTrackCell ? null : (trackCell ?? this.trackCell),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': color.name,
      'state': state.name,
      'stepCount': stepCount,
      'laneStep': laneStep,
      'trackCell': trackCell,
      'totalProgress': totalProgress,
    };
  }

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      id: json['id'] as String,
      color: PlayerColor.fromName(json['color'] as String),
      state: TokenState.fromString(json['state'] as String),
      stepCount: json['stepCount'] as int? ?? 0,
      laneStep: json['laneStep'] as int? ?? 0,
      trackCell: json['trackCell'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          color == other.color &&
          state == other.state &&
          stepCount == other.stepCount &&
          laneStep == other.laneStep &&
          trackCell == other.trackCell;

  @override
  int get hashCode => Object.hash(id, color, state, stepCount, laneStep, trackCell);

  @override
  String toString() =>
      'Token($id, ${color.name}, ${state.name}, step: $stepCount, lane: $laneStep, cell: $trackCell)';
}
