import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/services/api_client.dart';
import 'package:mobile/src/controllers/online_match_controller.dart';
import 'package:mobile/src/services/realtime_client.dart';

void main() {
  group('RoomModel Tests', () {
    test('RoomModel parses from API JSON successfully', () {
      final json = {
        'id': 'room_123',
        'code': 'ABC456',
        'host_user_id': 'user_1',
        'mode': 'CLASSIC',
        'max_players': 4,
        'status': 'WAITING',
        'bet_coins': 50,
        'members': [
          {
            'id': 'mem_1',
            'user_id': 'user_1',
            'seat_index': 0,
            'is_ready': true,
            'is_host': true,
            'display_name': 'HostPlayer',
            'avatar_id': 'avatar_1',
            'level': 5,
            'joined_at': '2026-10-01T00:00:00Z',
          },
          {
            'id': 'mem_2',
            'user_id': 'user_2',
            'seat_index': 1,
            'is_ready': false,
            'is_host': false,
            'display_name': 'GuestPlayer',
            'avatar_id': 'avatar_0',
            'level': 1,
            'joined_at': '2026-10-01T00:01:00Z',
          }
        ],
        'match_id': null,
      };

      final room = RoomModel.fromJson(json);
      expect(room.id, 'room_123');
      expect(room.code, 'ABC456');
      expect(room.mode, 'CLASSIC');
      expect(room.members.length, 2);
      expect(room.members[0].isHost, isTrue);
      expect(room.members[0].displayName, 'HostPlayer');
      expect(room.members[1].seatIndex, 1);
      expect(room.members[1].isReady, isFalse);
    });
  });

  group('OnlineMatchState Tests', () {
    test('isMyTurn evaluates correctly', () {
      const state = OnlineMatchState(
        connectionStatus: RealtimeConnectionStatus.connected,
        matchId: 'match_1',
        mySeatIndex: 0,
        currentSeatIndex: 0,
        phase: 'ROLL_REQUIRED',
      );
      expect(state.isMyTurn, isTrue);

      final stateOtherTurn = state.copyWith(currentSeatIndex: 1);
      expect(stateOtherTurn.isMyTurn, isFalse);

      final stateGameOver = state.copyWith(isGameOver: true);
      expect(stateGameOver.isMyTurn, isFalse);
    });

    test('copyWith preserves and overrides values cleanly', () {
      const initial = OnlineMatchState(
        connectionStatus: RealtimeConnectionStatus.connected,
        matchId: 'm1',
        mySeatIndex: 0,
        currentSeatIndex: 1,
        phase: 'ROLL_REQUIRED',
        diceValue: 6,
      );

      final updated = initial.copyWith(
        phase: 'MOVE_REQUIRED',
        clearDiceValue: true,
      );

      expect(updated.phase, 'MOVE_REQUIRED');
      expect(updated.diceValue, isNull);
      expect(updated.currentSeatIndex, 1);
      expect(updated.mySeatIndex, 0);
    });
  });
}
