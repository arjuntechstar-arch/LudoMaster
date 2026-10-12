import 'dart:math';
import 'package:game_engine/game_engine.dart';

void main(List<String> args) {
  var gameCount = 100;
  var playerCount = 4;
  var difficulty = BotDifficulty.hard;
  int? seed;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--games' && i + 1 < args.length) {
      gameCount = int.parse(args[i + 1]);
    } else if (args[i] == '--players' && i + 1 < args.length) {
      playerCount = int.parse(args[i + 1]);
    } else if (args[i] == '--seed' && i + 1 < args.length) {
      seed = int.parse(args[i + 1]);
    } else if (args[i] == '--difficulty' && i + 1 < args.length) {
      difficulty = BotDifficulty.fromString(args[i + 1]);
    }
  }

  print('=====================================================');
  print('  LudoMaster Simulation CLI - Phase 1 Verification   ');
  print('=====================================================');
  print('Running $gameCount games ($playerCount players, difficulty: ${difficulty.name}, seed: $seed)...');

  final rng = seed != null ? Random(seed) : Random();
  final stopwatch = Stopwatch()..start();

  var totalTurns = 0;
  var totalCaptures = 0;
  var totalHomeFinishes = 0;
  final diceFrequencies = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
  final winnerCounts = <String, int>{};

  for (var g = 1; g <= gameCount; g++) {
    // Generate players
    final colors = [
      PlayerColor.red,
      PlayerColor.green,
      PlayerColor.yellow,
      PlayerColor.blue,
    ].take(playerCount).toList();

    final players = colors.map((color) {
      return PlayerState(
        id: 'bot_${color.name}',
        name: 'Bot ${color.name.toUpperCase()}',
        seat: color.seatIndex,
        color: color,
        isBot: true,
        tokens: const [],
      );
    }).toList();

    var result = LudoEngine.initializeGame(
      matchId: 'sim_match_$g',
      ruleset: RulesetConfig.classic,
      players: players,
    );

    var turnsInGame = 0;
    const maxSafetyTurns = 5000;

    while (result.state.status == GameStatus.inProgress && turnsInGame < maxSafetyTurns) {
      turnsInGame++;
      totalTurns++;

      final activePlayer = result.state.currentPlayer;

      // 1. Roll Dice (fair CSPRNG / Random simulation)
      final roll = rng.nextInt(6) + 1;
      diceFrequencies[roll] = (diceFrequencies[roll] ?? 0) + 1;

      result = LudoEngine.applyRoll(
        state: result.state,
        player: activePlayer,
        diceValue: roll,
      );

      // Verify invariants after roll
      LudoEngine.validateInvariants(result.state);

      // 2. If move required, bot selects move
      if (result.state.phase == GamePhase.moveRequired) {
        final chosenMove = BotEvaluator.chooseMove(
          state: result.state,
          player: activePlayer,
          legalMoves: result.state.legalMoves,
          difficulty: difficulty,
          rng: rng,
        );

        if (chosenMove.willCapture) totalCaptures++;
        if (chosenMove.willReachHome) totalHomeFinishes++;

        result = LudoEngine.applyMove(
          state: result.state,
          player: activePlayer,
          tokenId: chosenMove.tokenId,
        );

        // Verify invariants after move
        LudoEngine.validateInvariants(result.state);
      }
    }

    if (result.state.status != GameStatus.finished) {
      print('ERROR: Match $g exceeded safety turn limit ($maxSafetyTurns) without finishing!');
      return;
    }

    final winner = result.state.placements.first;
    winnerCounts[winner] = (winnerCounts[winner] ?? 0) + 1;

    if (g % 20 == 0 || g == gameCount) {
      print('Simulated $g/$gameCount matches... (Avg turns/game: ${(totalTurns / g).toStringAsFixed(1)})');
    }
  }

  stopwatch.stop();

  print('\n---------------- Simulation Summary -----------------');
  print('Completed matches:     $gameCount');
  print('Total elapsed time:    ${stopwatch.elapsedMilliseconds} ms (${(stopwatch.elapsedMilliseconds / gameCount).toStringAsFixed(2)} ms/game)');
  print('Total turns simulated: $totalTurns (Avg: ${(totalTurns / gameCount).toStringAsFixed(1)} turns/game)');
  print('Total captures made:   $totalCaptures');
  print('Total tokens home:     $totalHomeFinishes');
  print('\nDice Roll Distribution:');
  final totalRolls = diceFrequencies.values.reduce((a, b) => a + b);
  for (var d = 1; d <= 6; d++) {
    final count = diceFrequencies[d] ?? 0;
    final pct = (count / totalRolls * 100).toStringAsFixed(2);
    print('  Face $d: $count ($pct%)');
  }
  print('\nWinner Distribution:');
  winnerCounts.forEach((winner, count) {
    final pct = (count / gameCount * 100).toStringAsFixed(1);
    print('  $winner: $count wins ($pct%)');
  });
  print('\n[SUCCESS] All invariants verified. Zero deadlocks. Zero invalid states.');
  print('=====================================================');
}
