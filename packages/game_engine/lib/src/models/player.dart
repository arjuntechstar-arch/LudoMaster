import 'package:meta/meta.dart';
import 'player_color.dart';
import 'token.dart';

/// Representation of a seated player in a match.
@immutable
class PlayerState {
  const PlayerState({
    required this.id,
    required this.name,
    required this.seat,
    required this.color,
    this.isBot = false,
    this.isConnected = true,
    this.hasFinished = false,
    this.placement,
    this.teamId,
    this.hasCaptured = false,
    required this.tokens,
  });

  final String id;
  final String name;
  final int seat;
  final PlayerColor color;
  final bool isBot;
  final bool isConnected;
  final bool hasFinished;
  final int? placement;

  /// Assigned team index for Team Mode (e.g. 0 for seats 0 & 2, 1 for seats 1 & 3).
  final int? teamId;

  /// Whether this player has performed at least one capture in the match
  /// (critical for Quick Mode's home lane entry condition).
  final bool hasCaptured;

  final List<Token> tokens;

  List<Token> get tokensInYard =>
      tokens.where((t) => t.state == TokenState.yard).toList();

  List<Token> get tokensOnTrack =>
      tokens.where((t) => t.state == TokenState.track).toList();

  List<Token> get tokensInHomeLane =>
      tokens.where((t) => t.state == TokenState.homeLane).toList();

  List<Token> get tokensInHome =>
      tokens.where((t) => t.state == TokenState.home).toList();

  bool get areAllTokensHome => tokens.every((t) => t.state == TokenState.home);

  Token? getToken(String tokenId) {
    for (final t in tokens) {
      if (t.id == tokenId) return t;
    }
    return null;
  }

  PlayerState copyWith({
    String? id,
    String? name,
    int? seat,
    PlayerColor? color,
    bool? isBot,
    bool? isConnected,
    bool? hasFinished,
    int? placement,
    int? teamId,
    bool? hasCaptured,
    List<Token>? tokens,
  }) {
    return PlayerState(
      id: id ?? this.id,
      name: name ?? this.name,
      seat: seat ?? this.seat,
      color: color ?? this.color,
      isBot: isBot ?? this.isBot,
      isConnected: isConnected ?? this.isConnected,
      hasFinished: hasFinished ?? this.hasFinished,
      placement: placement ?? this.placement,
      teamId: teamId ?? this.teamId,
      hasCaptured: hasCaptured ?? this.hasCaptured,
      tokens: tokens ?? this.tokens,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'seat': seat,
      'color': color.name,
      'isBot': isBot,
      'isConnected': isConnected,
      'hasFinished': hasFinished,
      'placement': placement,
      'teamId': teamId,
      'hasCaptured': hasCaptured,
      'tokens': tokens.map((t) => t.toJson()).toList(),
    };
  }

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      id: json['id'] as String,
      name: json['name'] as String,
      seat: json['seat'] as int,
      color: PlayerColor.fromName(json['color'] as String),
      isBot: json['isBot'] as bool? ?? false,
      isConnected: json['isConnected'] as bool? ?? true,
      hasFinished: json['hasFinished'] as bool? ?? false,
      placement: json['placement'] as int?,
      teamId: json['teamId'] as int?,
      hasCaptured: json['hasCaptured'] as bool? ?? false,
      tokens: (json['tokens'] as List<dynamic>)
          .map((t) => Token.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          seat == other.seat &&
          color == other.color &&
          isBot == other.isBot &&
          isConnected == other.isConnected &&
          hasFinished == other.hasFinished &&
          placement == other.placement &&
          teamId == other.teamId &&
          hasCaptured == other.hasCaptured;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        seat,
        color,
        isBot,
        isConnected,
        hasFinished,
        placement,
        teamId,
        hasCaptured,
      );

  @override
  String toString() =>
      'PlayerState($id, seat: $seat, team: $teamId, ${color.name}, finished: $hasFinished, placement: $placement)';
}
