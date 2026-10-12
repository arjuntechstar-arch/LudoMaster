import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

void main() {
  group('InvariantChecker & Property Invariants', () {
    late GameState baseState;

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
        matchId: 'prop_test',
        players: [red, green],
      );
      baseState = result.state;
    });

    test('valid state passes InvariantChecker without throwing', () {
      expect(() => InvariantChecker.validate(baseState), returnsNormally);
    });

    test('rejects negative sequence', () {
      final corrupted = baseState.copyWith(sequence: -1);
      expect(() => InvariantChecker.validate(corrupted), throwsStateError);
    });

    test('rejects empty matchId', () {
      final corrupted = baseState.copyWith(matchId: '');
      expect(() => InvariantChecker.validate(corrupted), throwsStateError);
    });

    test('rejects token in yard with non-null trackCell', () {
      final corruptedToken = baseState.currentPlayer.tokens.first.copyWith(
        state: TokenState.yard,
        trackCell: 10,
      );
      final updatedPlayer = baseState.currentPlayer.copyWith(
        tokens: [
          corruptedToken,
          baseState.currentPlayer.tokens[1],
          baseState.currentPlayer.tokens[2],
          baseState.currentPlayer.tokens[3],
        ],
      );
      final corrupted = baseState.copyWith(
        players: [updatedPlayer, baseState.players[1]],
      );
      expect(() => InvariantChecker.validate(corrupted), throwsStateError);
    });

    test('rejects token on track with trackCell out of bounds', () {
      final corruptedToken = baseState.currentPlayer.tokens.first.copyWith(
        state: TokenState.track,
        trackCell: 52, // 0..51 valid
        stepCount: 10,
      );
      final updatedPlayer = baseState.currentPlayer.copyWith(
        tokens: [
          corruptedToken,
          baseState.currentPlayer.tokens[1],
          baseState.currentPlayer.tokens[2],
          baseState.currentPlayer.tokens[3],
        ],
      );
      final corrupted = baseState.copyWith(
        players: [updatedPlayer, baseState.players[1]],
      );
      expect(() => InvariantChecker.validate(corrupted), throwsStateError);
    });

    test('rejects non-current player trying to roll', () {
      final nonCurrentPlayer = baseState.players[1]; // Green (seat 1)
      expect(LudoEngine.rollAllowed(baseState, nonCurrentPlayer), isFalse);
      expect(
        () => LudoEngine.applyRoll(
          state: baseState,
          player: nonCurrentPlayer,
          diceValue: 6,
        ),
        throwsStateError,
      );
    });

    test('state immutability: transition does not mutate original state', () {
      final r1 = LudoEngine.applyRoll(
        state: baseState,
        player: baseState.currentPlayer,
        diceValue: 6,
      );

      expect(baseState.phase, equals(GamePhase.rollRequired));
      expect(baseState.diceValue, isNull);
      expect(r1.state.phase, equals(GamePhase.moveRequired));
      expect(r1.state.diceValue, equals(6));
    });

    test('JSON serialization round-trip preservation', () {
      final json = baseState.toJson();
      final restored = GameState.fromJson(json);

      expect(restored.matchId, equals(baseState.matchId));
      expect(restored.currentSeat, equals(baseState.currentSeat));
      expect(restored.status, equals(baseState.status));
      expect(restored.phase, equals(baseState.phase));
      expect(restored.sequence, equals(baseState.sequence));
      expect(restored.players.length, equals(baseState.players.length));
    });
  });
}
