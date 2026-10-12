import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Capture Resolution & Safe Cells', () {
    late GameState initialState;
    late PlayerState redPlayer;
    late PlayerState greenPlayer;

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
      greenPlayer = initialState.players[1];
    });

    test('captures opponent token on unsafe track cell and returns to yard', () {
      // Cell 5 is an unsafe cell (!safeCells.contains(5))
      expect(BoardMetrics.isSafeCell(5), isFalse);

      // Red token at cell 2 (stepCount 2)
      const redToken = Token(
        id: 'red_0',
        color: PlayerColor.red,
        state: TokenState.track,
        stepCount: 2,
        trackCell: 2,
      );

      // Green token at cell 5 (stepCount = (5 - 13 + 52) % 52 = 44)
      const greenToken = Token(
        id: 'green_0',
        color: PlayerColor.green,
        state: TokenState.track,
        stepCount: 44,
        trackCell: 5,
      );

      final state = initialState.copyWith(
        players: [
          redPlayer.copyWith(tokens: [
            redToken,
            redPlayer.tokens[1],
            redPlayer.tokens[2],
            redPlayer.tokens[3],
          ]),
          greenPlayer.copyWith(tokens: [
            greenToken,
            greenPlayer.tokens[1],
            greenPlayer.tokens[2],
            greenPlayer.tokens[3],
          ]),
        ],
      );

      // Red rolls 3: 2 + 3 = 5 (lands on Green token!)
      final rollResult = LudoEngine.applyRoll(
        state: state,
        player: state.currentPlayer,
        diceValue: 3,
      );

      expect(rollResult.state.legalMoves.first.willCapture, isTrue);

      final moveResult = LudoEngine.applyMove(
        state: rollResult.state,
        player: rollResult.state.currentPlayer,
        tokenId: 'red_0',
      );

      // Check captured Green token is returned to YARD
      final updatedGreen = moveResult.state.getPlayerById('p_green')!;
      final capturedGreenToken = updatedGreen.getToken('green_0')!;
      expect(capturedGreenToken.state, equals(TokenState.yard));
      expect(capturedGreenToken.trackCell, isNull);
      expect(capturedGreenToken.stepCount, equals(0));

      // Check TOKEN_CAPTURED event emitted
      final captureEvents = moveResult.events.where(
        (e) => e.event == EventType.tokenCaptured,
      );
      expect(captureEvents, isNotEmpty);
      expect(captureEvents.first.payload['victimPlayerId'], equals('p_green'));
      expect(captureEvents.first.payload['capturedTokenId'], equals('green_0'));

      // Check Red gets BONUS_TURN for the capture
      expect(moveResult.state.currentSeat, equals(0)); // Still Red's turn
      expect(moveResult.state.phase, equals(GamePhase.rollRequired));
      expect(
        moveResult.events.any((e) => e.event == EventType.bonusTurn),
        isTrue,
      );
    });

    test('no capture on safe cells: both tokens coexist', () {
      // Cell 8 is a standard safe cell (star)
      expect(BoardMetrics.isSafeCell(8), isTrue);

      const redToken = Token(
        id: 'red_0',
        color: PlayerColor.red,
        state: TokenState.track,
        stepCount: 4,
        trackCell: 4,
      );

      const greenToken = Token(
        id: 'green_0',
        color: PlayerColor.green,
        state: TokenState.track,
        stepCount: 47,
        trackCell: 8,
      );

      final state = initialState.copyWith(
        players: [
          redPlayer.copyWith(tokens: [
            redToken,
            redPlayer.tokens[1],
            redPlayer.tokens[2],
            redPlayer.tokens[3],
          ]),
          greenPlayer.copyWith(tokens: [
            greenToken,
            greenPlayer.tokens[1],
            greenPlayer.tokens[2],
            greenPlayer.tokens[3],
          ]),
        ],
      );

      // Red rolls 4: 4 + 4 = 8 (lands on safe cell 8 where Green is sitting)
      final rollResult = LudoEngine.applyRoll(
        state: state,
        player: state.currentPlayer,
        diceValue: 4,
      );

      expect(rollResult.state.legalMoves.first.willCapture, isFalse);

      final moveResult = LudoEngine.applyMove(
        state: rollResult.state,
        player: rollResult.state.currentPlayer,
        tokenId: 'red_0',
      );

      // Green token is NOT returned to yard
      final updatedGreen = moveResult.state.getPlayerById('p_green')!;
      final safeGreenToken = updatedGreen.getToken('green_0')!;
      expect(safeGreenToken.state, equals(TokenState.track));
      expect(safeGreenToken.trackCell, equals(8));

      // No capture event
      expect(
        moveResult.events.any((e) => e.event == EventType.tokenCaptured),
        isFalse,
      );
    });
  });
}
