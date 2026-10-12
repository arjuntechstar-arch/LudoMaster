import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Quick Mode Rules (Phase 7)', () {
    test('Quick mode initializes with 2 tokens per player', () {
      const config = RulesetConfig.quick;
      expect(config.tokensPerPlayer, equals(2));
      expect(config.requireCaptureForHomeEntry, isTrue);

      final res = LudoEngine.initializeGame(
        matchId: 'quick-match-1',
        ruleset: config,
        players: [
          const PlayerState(id: 'p1', name: 'Player 1', seat: 0, color: PlayerColor.red, tokens: []),
          const PlayerState(id: 'p2', name: 'Player 2', seat: 1, color: PlayerColor.green, tokens: []),
        ],
      );
      final state = res.state;

      expect(state.players[0].tokens.length, equals(2));
      expect(state.players[1].tokens.length, equals(2));
      expect(state.players[0].tokensInYard.length, equals(2));
      expect(state.players[0].hasCaptured, isFalse);
    });

    test('requireCaptureForHomeEntry prevents entering home lane without capture', () {
      const config = RulesetConfig.quick;

      // P1 Red token at step 48 (2 steps before home lane entry at step 50)
      const p1 = PlayerState(
        id: 'p1',
        name: 'Player 1',
        seat: 0,
        color: PlayerColor.red,
        hasCaptured: false, // Has NOT made any captures
        tokens: [
          Token(
            id: 'red_0',
            color: PlayerColor.red,
            state: TokenState.track,
            stepCount: 48,
            trackCell: 48,
          ),
          Token(
            id: 'red_1',
            color: PlayerColor.red,
            state: TokenState.yard,
          ),
        ],
      );

      const p2 = PlayerState(
        id: 'p2',
        name: 'Player 2',
        seat: 1,
        color: PlayerColor.green,
        tokens: [
          Token(
            id: 'green_0',
            color: PlayerColor.green,
            state: TokenState.yard,
          ),
          Token(
            id: 'green_1',
            color: PlayerColor.green,
            state: TokenState.yard,
          ),
        ],
      );

      const state = GameState(
        matchId: 'quick-test',
        ruleset: config,
        status: GameStatus.inProgress,
        phase: GamePhase.moveRequired,
        players: [p1, p2],
        currentSeat: 0,
        diceValue: 4, // 48 + 4 = 52 -> would enter home lane step 2!
      );

      // Moves into home lane should be blocked because hasCaptured == false
      final moves = MoveValidator.calculateLegalMoves(
        state: state,
        player: p1,
        diceValue: 4,
      );

      expect(moves.any((m) => m.tokenId == 'red_0'), isFalse,
          reason: 'Token red_0 must not enter home lane without a capture');
    });

    test('requireCaptureForHomeEntry allows entering home lane after a capture is made', () {
      const config = RulesetConfig.quick;

      const p1 = PlayerState(
        id: 'p1',
        name: 'Player 1',
        seat: 0,
        color: PlayerColor.red,
        hasCaptured: true, // P1 has made a capture!
        tokens: [
          Token(
            id: 'red_0',
            color: PlayerColor.red,
            state: TokenState.track,
            stepCount: 48,
            trackCell: 48,
          ),
          Token(
            id: 'red_1',
            color: PlayerColor.red,
            state: TokenState.yard,
          ),
        ],
      );

      const p2 = PlayerState(
        id: 'p2',
        name: 'Player 2',
        seat: 1,
        color: PlayerColor.green,
        tokens: [
          Token(
            id: 'green_0',
            color: PlayerColor.green,
            state: TokenState.yard,
          ),
          Token(
            id: 'green_1',
            color: PlayerColor.green,
            state: TokenState.yard,
          ),
        ],
      );

      const state = GameState(
        matchId: 'quick-test-2',
        ruleset: config,
        status: GameStatus.inProgress,
        phase: GamePhase.moveRequired,
        players: [p1, p2],
        currentSeat: 0,
        diceValue: 4,
      );

      final moves = MoveValidator.calculateLegalMoves(
        state: state,
        player: p1,
        diceValue: 4,
      );

      expect(moves.any((m) => m.tokenId == 'red_0'), isTrue);
      final move = moves.firstWhere((m) => m.tokenId == 'red_0');
      expect(move.toState, equals(TokenState.homeLane));
      expect(move.toLaneStep, equals(2));
    });

    test('Capturing an opponent marks player hasCaptured: true', () {
      const config = RulesetConfig.quick;

      // P1 at cell 10, P2 at cell 14 (unsafe cell)
      const p1 = PlayerState(
        id: 'p1',
        name: 'Player 1',
        seat: 0,
        color: PlayerColor.red,
        hasCaptured: false,
        tokens: [
          Token(
            id: 'red_0',
            color: PlayerColor.red,
            state: TokenState.track,
            stepCount: 10,
            trackCell: 10,
          ),
          Token(id: 'red_1', color: PlayerColor.red, state: TokenState.yard),
        ],
      );

      const p2 = PlayerState(
        id: 'p2',
        name: 'Player 2',
        seat: 1,
        color: PlayerColor.green,
        tokens: [
          Token(
            id: 'green_0',
            color: PlayerColor.green,
            state: TokenState.track,
            stepCount: 1,
            trackCell: 14,
          ),
          Token(id: 'green_1', color: PlayerColor.green, state: TokenState.yard),
        ],
      );

      const state = GameState(
        matchId: 'capture-test',
        ruleset: config,
        status: GameStatus.inProgress,
        phase: GamePhase.rollRequired,
        players: [p1, p2],
        currentSeat: 0,
      );

      // Roll 4 to land on cell 14
      final rollRes = LudoEngine.applyRoll(
        state: state,
        player: p1,
        diceValue: 4,
      );

      expect(rollRes.state.legalMoves.first.willCapture, isTrue);

      final moveRes = LudoEngine.applyMove(
        state: rollRes.state,
        player: p1,
        tokenId: 'red_0',
      );

      final updatedP1 = moveRes.state.players.firstWhere((p) => p.id == 'p1');
      expect(updatedP1.hasCaptured, isTrue);

      final updatedP2 = moveRes.state.players.firstWhere((p) => p.id == 'p2');
      expect(updatedP2.tokens.firstWhere((t) => t.id == 'green_0').state, equals(TokenState.yard));
    });
  });
}
