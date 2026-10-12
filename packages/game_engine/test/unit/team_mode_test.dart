import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Team 2v2 Mode Rules (Phase 7)', () {
    test('Teammates cannot capture each other on unsafe cells', () {
      const config = RulesetConfig.team;
      expect(config.isTeamMode, isTrue);
      expect(config.teammateCaptureAllowed, isFalse);

      // Team 0: P0 (Red, Seat 0) & P2 (Yellow, Seat 2)
      // Team 1: P1 (Green, Seat 1) & P3 (Blue, Seat 3)
      const p0 = PlayerState(
        id: 'p0',
        name: 'Player 0',
        seat: 0,
        teamId: 0,
        color: PlayerColor.red,
        tokens: [
          Token(id: 'red_0', color: PlayerColor.red, state: TokenState.track, stepCount: 10, trackCell: 10),
          Token(id: 'red_1', color: PlayerColor.red, state: TokenState.yard),
          Token(id: 'red_2', color: PlayerColor.red, state: TokenState.yard),
          Token(id: 'red_3', color: PlayerColor.red, state: TokenState.yard),
        ],
      );

      const p2 = PlayerState(
        id: 'p2',
        name: 'Player 2',
        seat: 2,
        teamId: 0, // Same team as P0!
        color: PlayerColor.yellow,
        tokens: [
          Token(id: 'yellow_0', color: PlayerColor.yellow, state: TokenState.track, stepCount: 40, trackCell: 14),
          Token(id: 'yellow_1', color: PlayerColor.yellow, state: TokenState.yard),
          Token(id: 'yellow_2', color: PlayerColor.yellow, state: TokenState.yard),
          Token(id: 'yellow_3', color: PlayerColor.yellow, state: TokenState.yard),
        ],
      );

      const p1 = PlayerState(
        id: 'p1',
        name: 'Player 1',
        seat: 1,
        teamId: 1,
        color: PlayerColor.green,
        tokens: [
          Token(id: 'green_0', color: PlayerColor.green, state: TokenState.yard),
          Token(id: 'green_1', color: PlayerColor.green, state: TokenState.yard),
          Token(id: 'green_2', color: PlayerColor.green, state: TokenState.yard),
          Token(id: 'green_3', color: PlayerColor.green, state: TokenState.yard),
        ],
      );

      const p3 = PlayerState(
        id: 'p3',
        name: 'Player 3',
        seat: 3,
        teamId: 1,
        color: PlayerColor.blue,
        tokens: [
          Token(id: 'blue_0', color: PlayerColor.blue, state: TokenState.yard),
          Token(id: 'blue_1', color: PlayerColor.blue, state: TokenState.yard),
          Token(id: 'blue_2', color: PlayerColor.blue, state: TokenState.yard),
          Token(id: 'blue_3', color: PlayerColor.blue, state: TokenState.yard),
        ],
      );

      const state = GameState(
        matchId: 'team-test',
        ruleset: config,
        status: GameStatus.inProgress,
        phase: GamePhase.rollRequired,
        players: [p0, p1, p2, p3],
        currentSeat: 0,
      );

      // P0 rolls 4 to land on cell 14 (where teammate P2's token yellow_0 is)
      final rollRes = LudoEngine.applyRoll(
        state: state,
        player: p0,
        diceValue: 4,
      );

      final moveOption = rollRes.state.legalMoves.firstWhere((m) => m.tokenId == 'red_0');
      expect(moveOption.willCapture, isFalse, reason: 'Teammates must not be captured');

      final moveRes = LudoEngine.applyMove(
        state: rollRes.state,
        player: p0,
        tokenId: 'red_0',
      );

      // Both red_0 and yellow_0 should be happily stacked on cell 14!
      final afterP0 = moveRes.state.players.firstWhere((p) => p.id == 'p0');
      final afterP2 = moveRes.state.players.firstWhere((p) => p.id == 'p2');
      expect(afterP0.tokens.firstWhere((t) => t.id == 'red_0').trackCell, equals(14));
      expect(afterP2.tokens.firstWhere((t) => t.id == 'yellow_0').trackCell, equals(14));
      expect(afterP2.tokens.firstWhere((t) => t.id == 'yellow_0').state, equals(TokenState.track));
    });

    test('Finished player can roll and move partner tokens in Team Mode', () {
      const config = RulesetConfig.team;

      // P0 has all 4 tokens in HOME
      const p0 = PlayerState(
        id: 'p0',
        name: 'Player 0',
        seat: 0,
        teamId: 0,
        color: PlayerColor.red,
        hasFinished: true,
        tokens: [
          Token(id: 'red_0', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
          Token(id: 'red_1', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
          Token(id: 'red_2', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
          Token(id: 'red_3', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
        ],
      );

      // Partner P2 has 1 token on track, 3 in yard
      const p2 = PlayerState(
        id: 'p2',
        name: 'Player 2',
        seat: 2,
        teamId: 0,
        color: PlayerColor.yellow,
        hasFinished: false,
        tokens: [
          Token(id: 'yellow_0', color: PlayerColor.yellow, state: TokenState.track, stepCount: 10, trackCell: 36),
          Token(id: 'yellow_1', color: PlayerColor.yellow, state: TokenState.yard),
          Token(id: 'yellow_2', color: PlayerColor.yellow, state: TokenState.yard),
          Token(id: 'yellow_3', color: PlayerColor.yellow, state: TokenState.yard),
        ],
      );

      const p1 = PlayerState(
        id: 'p1',
        name: 'Player 1',
        seat: 1,
        teamId: 1,
        color: PlayerColor.green,
        tokens: [
          Token(id: 'green_0', color: PlayerColor.green, state: TokenState.track, stepCount: 5, trackCell: 18),
          Token(id: 'green_1', color: PlayerColor.green, state: TokenState.yard),
          Token(id: 'green_2', color: PlayerColor.green, state: TokenState.yard),
          Token(id: 'green_3', color: PlayerColor.green, state: TokenState.yard),
        ],
      );

      const p3 = PlayerState(
        id: 'p3',
        name: 'Player 3',
        seat: 3,
        teamId: 1,
        color: PlayerColor.blue,
        tokens: [
          Token(id: 'blue_0', color: PlayerColor.blue, state: TokenState.yard),
          Token(id: 'blue_1', color: PlayerColor.blue, state: TokenState.yard),
          Token(id: 'blue_2', color: PlayerColor.blue, state: TokenState.yard),
          Token(id: 'blue_3', color: PlayerColor.blue, state: TokenState.yard),
        ],
      );

      const state = GameState(
        matchId: 'team-assist-test',
        ruleset: config,
        status: GameStatus.inProgress,
        phase: GamePhase.rollRequired,
        players: [p0, p1, p2, p3],
        currentSeat: 0, // P0's turn!
      );

      // P0 rolls a 3
      final rollRes = LudoEngine.applyRoll(
        state: state,
        player: p0,
        diceValue: 3,
      );

      // P0's legal moves should be for partner P2's token (yellow_0)
      expect(rollRes.state.legalMoves.any((m) => m.tokenId == 'yellow_0'), isTrue);

      // P0 applies move for yellow_0
      final moveRes = LudoEngine.applyMove(
        state: rollRes.state,
        player: p0,
        tokenId: 'yellow_0',
      );

      final updatedP2 = moveRes.state.players.firstWhere((p) => p.id == 'p2');
      final yellow0 = updatedP2.tokens.firstWhere((t) => t.id == 'yellow_0');
      expect(yellow0.stepCount, equals(13));
    });

    test('Team victory finishes game when both teammates complete all tokens', () {
      const config = RulesetConfig.team;

      // P0 has all 4 tokens in HOME
      const p0 = PlayerState(
        id: 'p0',
        name: 'Player 0',
        seat: 0,
        teamId: 0,
        color: PlayerColor.red,
        hasFinished: true,
        tokens: [
          Token(id: 'red_0', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
          Token(id: 'red_1', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
          Token(id: 'red_2', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
          Token(id: 'red_3', color: PlayerColor.red, state: TokenState.home, laneStep: 6),
        ],
      );

      // Partner P2 has 3 tokens in HOME, and last token in home lane step 5 (1 step away from HOME!)
      const p2 = PlayerState(
        id: 'p2',
        name: 'Player 2',
        seat: 2,
        teamId: 0,
        color: PlayerColor.yellow,
        hasFinished: false,
        tokens: [
          Token(id: 'yellow_0', color: PlayerColor.yellow, state: TokenState.homeLane, laneStep: 5),
          Token(id: 'yellow_1', color: PlayerColor.yellow, state: TokenState.home, laneStep: 6),
          Token(id: 'yellow_2', color: PlayerColor.yellow, state: TokenState.home, laneStep: 6),
          Token(id: 'yellow_3', color: PlayerColor.yellow, state: TokenState.home, laneStep: 6),
        ],
      );

      const p1 = PlayerState(
        id: 'p1',
        name: 'Player 1',
        seat: 1,
        teamId: 1,
        color: PlayerColor.green,
        tokens: [
          Token(id: 'green_0', color: PlayerColor.green, state: TokenState.yard),
          Token(id: 'green_1', color: PlayerColor.green, state: TokenState.yard),
          Token(id: 'green_2', color: PlayerColor.green, state: TokenState.yard),
          Token(id: 'green_3', color: PlayerColor.green, state: TokenState.yard),
        ],
      );

      const p3 = PlayerState(
        id: 'p3',
        name: 'Player 3',
        seat: 3,
        teamId: 1,
        color: PlayerColor.blue,
        tokens: [
          Token(id: 'blue_0', color: PlayerColor.blue, state: TokenState.yard),
          Token(id: 'blue_1', color: PlayerColor.blue, state: TokenState.yard),
          Token(id: 'blue_2', color: PlayerColor.blue, state: TokenState.yard),
          Token(id: 'blue_3', color: PlayerColor.blue, state: TokenState.yard),
        ],
      );

      const state = GameState(
        matchId: 'team-win-test',
        ruleset: config,
        status: GameStatus.inProgress,
        phase: GamePhase.rollRequired,
        players: [p0, p1, p2, p3],
        currentSeat: 2, // P2's turn
      );

      // P2 rolls 1 -> moves yellow_0 to HOME (laneStep 6)
      final rollRes = LudoEngine.applyRoll(
        state: state,
        player: p2,
        diceValue: 1,
      );

      final moveRes = LudoEngine.applyMove(
        state: rollRes.state,
        player: p2,
        tokenId: 'yellow_0',
      );

      // Team 0 should now be crowned champions and match should be finished!
      expect(moveRes.state.status, equals(GameStatus.finished));
      expect(moveRes.state.phase, equals(GamePhase.finished));

      final finalP0 = moveRes.state.players.firstWhere((p) => p.id == 'p0');
      final finalP2 = moveRes.state.players.firstWhere((p) => p.id == 'p2');
      expect(finalP0.placement, equals(1));
      expect(finalP2.placement, equals(1));
    });
  });
}
