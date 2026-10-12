import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Placements & Game Completion', () {
    test('2-player game ends immediately when first player completes all tokens', () {
      const red = PlayerState(
        id: 'p_red',
        name: 'Red',
        seat: 0,
        color: PlayerColor.red,
        tokens: [
          Token(id: 'red_0', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
          Token(id: 'red_1', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
          Token(id: 'red_2', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
          Token(
            id: 'red_3',
            color: PlayerColor.red,
            state: TokenState.homeLane,
            laneStep: 5, // final token 1 step away
          ),
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
        matchId: 'm_placement',
        players: [red, green],
      );

      final rollRes = LudoEngine.applyRoll(
        state: init.state,
        player: init.state.currentPlayer,
        diceValue: 1,
      );

      final moveRes = LudoEngine.applyMove(
        state: rollRes.state,
        player: rollRes.state.currentPlayer,
        tokenId: 'red_3',
      );

      expect(moveRes.state.status, equals(GameStatus.finished));
      expect(moveRes.state.phase, equals(GamePhase.finished));
      expect(moveRes.state.placements, equals(['p_red', 'p_green']));

      final finishEvents = moveRes.events.where(
        (e) => e.event == EventType.matchFinished,
      );
      expect(finishEvents, isNotEmpty);
      expect(finishEvents.first.payload['winner'], equals('p_red'));
    });
  });
}
