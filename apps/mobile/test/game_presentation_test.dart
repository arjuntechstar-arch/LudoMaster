import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:mobile/src/board/board_perspective.dart';
import 'package:mobile/src/controllers/game_controller.dart';
import 'package:mobile/src/controllers/settings_controller.dart';
import 'package:mobile/src/services/game_pacing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixedRandom implements Random {
  FixedRandom(this.roll);
  final int roll;
  @override
  int nextInt(int max) => (roll - 1) % max;
  @override
  double nextDouble() => 0.5;
  @override
  bool nextBool() => true;
}

const players = [
  PlayerState(
    id: 'red',
    name: 'Red',
    seat: 0,
    color: PlayerColor.red,
    tokens: [],
  ),
  PlayerState(
    id: 'blue',
    name: 'Blue',
    seat: 3,
    color: PlayerColor.blue,
    tokens: [],
  ),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('every local color maps to bottom left', () {
    for (final color in PlayerColor.values.take(4)) {
      expect(BoardPerspective.position(color, color), 3);
    }
  });

  testWidgets('no legal move waits for dice animation before changing turn', (
    tester,
  ) async {
    final controller = GameController(random: FixedRandom(1));
    addTearDown(controller.dispose);
    controller.startNewGame(players: players);
    controller.rollDice();
    expect(controller.state!.gameState.currentSeat, 0);
    expect(controller.state!.isAnimating, isTrue);
    expect(controller.state!.rollSequence, 1);
    controller.rollDice();
    expect(controller.state!.rollSequence, 1);
    await tester.pump(GamePacing.diceRoll - const Duration(milliseconds: 1));
    expect(controller.state!.gameState.currentSeat, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.state!.gameState.currentSeat, 3);
    expect(controller.state!.isAnimating, isFalse);
    controller.quitMatch();
  });

  testWidgets(
    'several yard moves wait for choice and moving color stays until complete',
    (tester) async {
      final controller = GameController(random: FixedRandom(6));
      addTearDown(controller.dispose);
      controller.startNewGame(players: players);
      controller.rollDice();
      await tester.pump(GamePacing.diceRoll);
      await tester.pump(const Duration(seconds: 2));
      expect(controller.state!.gameState.phase, GamePhase.moveRequired);
      expect(controller.state!.gameState.legalMoves.length, 4);
      final sequence = controller.state!.rollSequence;
      controller.selectMove(
        controller.state!.gameState.legalMoves.first.tokenId,
      );
      expect(controller.state!.isAnimating, isTrue);
      expect(controller.state!.gameState.currentSeat, 0);
      expect(controller.state!.gameState.diceValue, 6);
      expect(controller.state!.rollSequence, sequence);
      await tester.pump(GamePacing.tokenMove);
      expect(controller.state!.gameState.phase, GamePhase.rollRequired);
      expect(controller.state!.isAnimating, isFalse);
      controller.quitMatch();
    },
  );

  testWidgets(
    'single move starts only after rolling and pause; stale auto move is cancelled',
    (tester) async {
      final controller = GameController(random: FixedRandom(1));
      addTearDown(controller.dispose);
      final initial = LudoEngine.initializeGame(
        matchId: 'single',
        players: players,
        ruleset: RulesetConfig.classic,
      ).state;
      final six = LudoEngine.applyRoll(
        state: initial,
        player: initial.currentPlayer,
        diceValue: 6,
      ).state;
      final deployed = LudoEngine.applyMove(
        state: six,
        player: six.currentPlayer,
        tokenId: six.legalMoves.first.tokenId,
      ).state;
      controller.resumeSavedGame(deployed);
      controller.rollDice();
      await tester.pump(GamePacing.diceRoll);
      expect(controller.state!.gameState.legalMoves.length, 1);
      await tester.pump(
        GamePacing.autoMovePause - const Duration(milliseconds: 1),
      );
      expect(controller.state!.isAnimating, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(controller.state!.isAnimating, isTrue);
      expect(controller.state!.gameState.currentSeat, 0);
      await tester.pump(GamePacing.tokenMove);
      expect(controller.state!.gameState.currentSeat, 3);
      controller.resumeSavedGame(deployed);
      controller.rollDice();
      await tester.pump(GamePacing.diceRoll);
      controller.quitMatch();
      controller.startNewGame(players: players);
      await tester.pump(const Duration(seconds: 3));
      expect(controller.state!.gameState.phase, GamePhase.rollRequired);
      controller.quitMatch();
    },
  );

  testWidgets(
    'settings update immediately and persist rapid changes in order',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      final first = controller.toggleSound();
      expect(controller.state.soundEnabled, isFalse);
      final second = controller.toggleSound();
      expect(controller.state.soundEnabled, isTrue);
      final haptics = controller.toggleHaptics();
      expect(controller.state.hapticsEnabled, isFalse);
      await tester.runAsync(() async {
        await Future.wait([first, second, haptics]);
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ludomaster_setting_sound'), isTrue);
      expect(prefs.getBool('ludomaster_setting_haptics'), isFalse);
    },
  );
}
