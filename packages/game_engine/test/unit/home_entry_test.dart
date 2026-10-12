import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Home Entry & Bonus Roll', () {
    test('token reaching HOME emits TOKEN_HOME and awards bonus turn', () {
      const red = PlayerState(
        id: 'p_red',
        name: 'Red',
        seat: 0,
        color: PlayerColor.red,
        tokens: [
          Token(
            id: 'red_0',
            color: PlayerColor.red,
            state: TokenState.homeLane,
            laneStep: 5, // 1 step away from HOME
          ),
          Token(id: 'red_1', color: PlayerColor.red, state: TokenState.yard),
          Token(id: 'red_2', color: PlayerColor.red, state: TokenState.yard),
          Token(id: 'red_3', color: PlayerColor.red, state: TokenState.yard),
        ],
      );

      const green = PlayerState(
        id: 'p_green',
        name: 'Green',
        seat: 1,
        color: PlayerColor.green,
        tokens: [],
      );

      final init = LudoEngine.initializeGame(
        matchId: 'm_home',
        players: [red, green],
      );

      // Roll 1: moves from step 5 to HOME (step 6)
      final rollRes = LudoEngine.applyRoll(
        state: init.state,
        player: init.state.currentPlayer,
        diceValue: 1,
      );

      expect(rollRes.state.legalMoves.first.willReachHome, isTrue);

      final moveRes = LudoEngine.applyMove(
        state: rollRes.state,
        player: rollRes.state.currentPlayer,
        tokenId: 'red_0',
      );

      // Verify TOKEN_HOME event
      expect(
        moveRes.events.any((e) => e.event == EventType.tokenHome),
        isTrue,
      );

      // Verify Red retains turn (bonus turn for reaching home)
      expect(moveRes.state.currentSeat, equals(0));
      expect(moveRes.state.phase, equals(GamePhase.rollRequired));
      expect(
        moveRes.events.any((e) => e.event == EventType.bonusTurn),
        isTrue,
      );

      final redToken = moveRes.state.currentPlayer.getToken('red_0')!;
      expect(redToken.state, equals(TokenState.home));
      expect(redToken.laneStep, equals(6));
    });
  });
}
