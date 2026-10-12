import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Consecutive Sixes & Bonus Turns', () {
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
        matchId: 'm_sixes',
        ruleset: RulesetConfig.classic, // maxConsecutiveSixes = 3
        players: [red, green],
      );
      initialState = result.state;
      redPlayer = initialState.currentPlayer;
    });

    test('rolling 6 grants bonus turn after applying move', () {
      final rollResult = LudoEngine.applyRoll(
        state: initialState,
        player: redPlayer,
        diceValue: 6,
      );

      expect(rollResult.state.consecutiveSixes, equals(1));
      expect(rollResult.state.phase, equals(GamePhase.moveRequired));

      final moveResult = LudoEngine.applyMove(
        state: rollResult.state,
        player: redPlayer,
        tokenId: 'red_0',
      );

      // Turn remains with Red for bonus roll
      expect(moveResult.state.currentSeat, equals(0));
      expect(moveResult.state.phase, equals(GamePhase.rollRequired));
      expect(
        moveResult.events.any((e) => e.event == EventType.bonusTurn),
        isTrue,
      );
    });

    test('3rd consecutive six immediately forfeits turn to next player', () {
      // 1st six
      final r1 = LudoEngine.applyRoll(
        state: initialState,
        player: redPlayer,
        diceValue: 6,
      );
      final m1 = LudoEngine.applyMove(
        state: r1.state,
        player: redPlayer,
        tokenId: 'red_0',
      );
      expect(m1.state.consecutiveSixes, equals(1));

      // 2nd six
      final r2 = LudoEngine.applyRoll(
        state: m1.state,
        player: m1.state.currentPlayer,
        diceValue: 6,
      );
      final m2 = LudoEngine.applyMove(
        state: r2.state,
        player: m1.state.currentPlayer,
        tokenId: 'red_1',
      );
      expect(m2.state.consecutiveSixes, equals(2));

      // 3rd consecutive six rolled!
      final r3 = LudoEngine.applyRoll(
        state: m2.state,
        player: m2.state.currentPlayer,
        diceValue: 6,
      );

      // Third six should forfeit turn directly!
      expect(r3.state.currentSeat, equals(1)); // Seat passes to Green (seat 1)
      expect(r3.state.consecutiveSixes, equals(0)); // Reset
      expect(r3.state.phase, equals(GamePhase.rollRequired));

      // Verify turnTimeout / forfeit event emitted
      final timeoutEvents = r3.events.where(
        (e) => e.event == EventType.turnTimeout,
      );
      expect(timeoutEvents, isNotEmpty);
      expect(
        timeoutEvents.first.payload['reason'],
        equals('CONSECUTIVE_SIXES_EXCEEDED'),
      );
    });

    test('rolling non-six resets consecutive sixes counter', () {
      // 1st six
      final r1 = LudoEngine.applyRoll(
        state: initialState,
        player: redPlayer,
        diceValue: 6,
      );
      final m1 = LudoEngine.applyMove(
        state: r1.state,
        player: redPlayer,
        tokenId: 'red_0',
      );
      expect(m1.state.consecutiveSixes, equals(1));

      // Next roll is 4
      final r2 = LudoEngine.applyRoll(
        state: m1.state,
        player: m1.state.currentPlayer,
        diceValue: 4,
      );
      expect(r2.state.consecutiveSixes, equals(0));
    });
  });
}
