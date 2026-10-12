import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Legal Moves & Boundaries', () {
    late GameState initialState;
    late PlayerState redPlayer;

    setUp(() {
      const red = PlayerState(
        id: 'p_red',
        name: 'Red',
        seat: 0,
        color: PlayerColor.red,
        tokens: [],
      );
      const green = PlayerState(
        id: 'p_green',
        name: 'Green',
        seat: 1,
        color: PlayerColor.green,
        tokens: [],
      );

      final result = LudoEngine.initializeGame(
        matchId: 'm1',
        ruleset: RulesetConfig.classic,
        players: [red, green],
      );
      initialState = result.state;
      redPlayer = initialState.currentPlayer;
    });

    test('yard tokens cannot leave on 1..5', () {
      for (var d = 1; d <= 5; d++) {
        final moves = LudoEngine.legalMoves(initialState, redPlayer, d);
        expect(moves, isEmpty, reason: 'Roll $d should yield no legal moves from yard');
      }
    });

    test('yard tokens can leave on 6 to startTrackCell', () {
      final moves = LudoEngine.legalMoves(initialState, redPlayer, 6);
      expect(moves.length, equals(4)); // 4 tokens in yard
      for (final m in moves) {
        expect(m.fromState, equals(TokenState.yard));
        expect(m.toState, equals(TokenState.track));
        expect(m.toTrackCell, equals(PlayerColor.red.startTrackCell));
      }
    });

    test('track token advances correctly by dice roll', () {
      // Setup a token on track cell 0 with stepCount 0
      const tokenOnTrack = Token(
        id: 'red_0',
        color: PlayerColor.red,
        state: TokenState.track,
        stepCount: 0,
        trackCell: 0,
      );
      final updatedPlayer = redPlayer.copyWith(
        tokens: [
          tokenOnTrack,
          redPlayer.tokens[1],
          redPlayer.tokens[2],
          redPlayer.tokens[3],
        ],
      );
      final state = initialState.copyWith(
        players: [updatedPlayer, initialState.players[1]],
      );

      final moves = LudoEngine.legalMoves(state, updatedPlayer, 4);
      expect(moves.length, equals(1));
      final move = moves.first;
      expect(move.tokenId, equals('red_0'));
      expect(move.fromTrackCell, equals(0));
      expect(move.toTrackCell, equals(4));
      expect(move.toState, equals(TokenState.track));
    });

    test('token transitions from track to home lane', () {
      // Step 50 is the last step on the common track for Red (trackCell 50)
      const tokenNearEntrance = Token(
        id: 'red_0',
        color: PlayerColor.red,
        state: TokenState.track,
        stepCount: 49,
        trackCell: 49,
      );
      final updatedPlayer = redPlayer.copyWith(
        tokens: [
          tokenNearEntrance,
          redPlayer.tokens[1],
          redPlayer.tokens[2],
          redPlayer.tokens[3],
        ],
      );
      final state = initialState.copyWith(
        players: [updatedPlayer, initialState.players[1]],
      );

      // Rolling 2 from step 49: progress = 51 -> enters home lane step 1
      final moves = LudoEngine.legalMoves(state, updatedPlayer, 2);
      expect(moves.length, equals(1));
      final move = moves.first;
      expect(move.toState, equals(TokenState.homeLane));
      expect(move.toLaneStep, equals(1));
      expect(move.toTrackCell, isNull);
    });

    test('exact roll required for home entry from home lane', () {
      // Place token in home lane at step 4 (needs exact roll 2 to reach step 6 HOME)
      const tokenInLane = Token(
        id: 'red_0',
        color: PlayerColor.red,
        state: TokenState.homeLane,
        laneStep: 4,
      );
      final updatedPlayer = redPlayer.copyWith(
        tokens: [
          tokenInLane,
          redPlayer.tokens[1],
          redPlayer.tokens[2],
          redPlayer.tokens[3],
        ],
      );
      final state = initialState.copyWith(
        players: [updatedPlayer, initialState.players[1]],
      );

      // Roll 1: advances to step 5
      final moves1 = LudoEngine.legalMoves(state, updatedPlayer, 1);
      expect(moves1.length, equals(1));
      expect(moves1.first.toLaneStep, equals(5));
      expect(moves1.first.willReachHome, isFalse);

      // Roll 2: exact finish into HOME!
      final moves2 = LudoEngine.legalMoves(state, updatedPlayer, 2);
      expect(moves2.length, equals(1));
      expect(moves2.first.toState, equals(TokenState.home));
      expect(moves2.first.toLaneStep, equals(6));
      expect(moves2.first.willReachHome, isTrue);

      // Roll 3, 4, 5, 6: overshoot! Illegal move!
      for (var d = 3; d <= 6; d++) {
        final movesOver = LudoEngine.legalMoves(state, updatedPlayer, d);
        // Yard tokens can move on 6, but token in lane cannot move on 3, 4, 5, 6
        final laneMoves = movesOver.where((m) => m.tokenId == 'red_0').toList();
        expect(laneMoves, isEmpty, reason: 'Roll $d should be illegal overshoot from step 4');
      }
    });

    test('finished tokens in HOME cannot move', () {
      const tokenFinished = Token(
        id: 'red_0',
        color: PlayerColor.red,
        state: TokenState.home,
        laneStep: 6,
      );
      final updatedPlayer = redPlayer.copyWith(
        tokens: [
          tokenFinished,
          redPlayer.tokens[1],
          redPlayer.tokens[2],
          redPlayer.tokens[3],
        ],
      );
      final state = initialState.copyWith(
        players: [updatedPlayer, initialState.players[1]],
      );

      for (var d = 1; d <= 6; d++) {
        final moves = LudoEngine.legalMoves(state, updatedPlayer, d);
        final finishedMoves = moves.where((m) => m.tokenId == 'red_0').toList();
        expect(finishedMoves, isEmpty);
      }
    });
  });
}
