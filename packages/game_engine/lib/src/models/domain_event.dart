import 'package:meta/meta.dart';

/// Realtime domain event types emitted by the engine and authoritative server.
enum EventType {
  connected('CONNECTED'),
  authenticated('AUTHENTICATED'),
  roomState('ROOM_STATE'),
  playerJoined('PLAYER_JOINED'),
  playerLeft('PLAYER_LEFT'),
  readyChanged('READY_CHANGED'),
  matchStarted('MATCH_STARTED'),
  turnStarted('TURN_STARTED'),
  diceRolled('DICE_ROLLED'),
  legalMoves('LEGAL_MOVES'),
  moveApplied('MOVE_APPLIED'),
  tokenCaptured('TOKEN_CAPTURED'),
  tokenHome('TOKEN_HOME'),
  bonusTurn('BONUS_TURN'),
  turnTimeout('TURN_TIMEOUT'),
  playerDisconnected('PLAYER_DISCONNECTED'),
  playerReconnected('PLAYER_RECONNECTED'),
  playerForfeited('PLAYER_FORFEITED'),
  stateSnapshot('STATE_SNAPSHOT'),
  matchFinished('MATCH_FINISHED'),
  chatMessage('CHAT_MESSAGE'),
  emojiSent('EMOJI_SENT'),
  error('ERROR');

  const EventType(this.wireName);
  final String wireName;

  static EventType fromWireName(String wire) {
    return EventType.values.firstWhere(
      (e) => e.wireName == wire,
      orElse: () => throw ArgumentError('Unknown EventType: $wire'),
    );
  }
}

/// Canonical envelope for domain and realtime events.
@immutable
class DomainEvent {
  const DomainEvent({
    required this.event,
    this.version = 1,
    required this.matchId,
    required this.sequence,
    required this.serverTime,
    required this.payload,
  });

  final EventType event;
  final int version;
  final String matchId;
  final int sequence;
  final String serverTime;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return {
      'event': event.wireName,
      'version': version,
      'matchId': matchId,
      'sequence': sequence,
      'serverTime': serverTime,
      'payload': payload,
    };
  }

  factory DomainEvent.fromJson(Map<String, dynamic> json) {
    return DomainEvent(
      event: EventType.fromWireName(json['event'] as String),
      version: json['version'] as int? ?? 1,
      matchId: json['matchId'] as String,
      sequence: json['sequence'] as int,
      serverTime: json['serverTime'] as String,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }

  @override
  String toString() =>
      'DomainEvent(${event.wireName}, seq: $sequence, match: $matchId, payload: $payload)';
}
