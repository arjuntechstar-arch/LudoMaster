import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';

import '../board/dice_widget.dart';
import '../board/board_perspective.dart';
import '../board/funny_capture_overlay.dart';
import '../board/ludo_board_widget.dart';
import '../board/player_panel_widget.dart';
import '../controllers/game_controller.dart';
import '../controllers/settings_controller.dart';
import '../services/cosmetic_selection.dart';
import '../theme/app_colors.dart';
import 'victory_dialog.dart';

/// Active game screen with centered board, player panels, thumb-friendly dice, and pause controls.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    final settings = ref.watch(settingsProvider);

    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('No active game session')),
      );
    }

    final gameState = session.gameState;
    final activePlayer = gameState.currentPlayer;
    final canRoll =
        gameState.phase == GamePhase.rollRequired &&
        !activePlayer.isBot &&
        !session.isBotThinking &&
        !session.isAnimating;

    if (gameState.status == GameStatus.finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            return VictoryDialog(
              gameState: gameState,
              onRematch: () {
                Navigator.of(dialogCtx).pop();
                ref
                    .read(gameControllerProvider.notifier)
                    .startNewGame(
                      players: gameState.players,
                      ruleset: gameState.ruleset,
                      botDifficulty: session.botDifficulty,
                    );
              },
              onHome: () {
                Navigator.of(dialogCtx).pop();
                ref.read(gameControllerProvider.notifier).quitMatch();
                Navigator.of(context).pop();
              },
            );
          },
        );
      });
    }

    final viewerColor =
        gameState.players.where((p) => !p.isBot).firstOrNull?.color ??
        PlayerColor.blue;
    final ordered = [...gameState.players]
      ..sort(
        (a, b) => BoardPerspective.position(
          a.color,
          viewerColor,
        ).compareTo(BoardPerspective.position(b.color, viewerColor)),
      );
    final topPlayers = ordered
        .where((p) => BoardPerspective.position(p.color, viewerColor) < 2)
        .toList();
    final bottomPlayers = ordered
        .where((p) => BoardPerspective.position(p.color, viewerColor) >= 2)
        .toList()
        .reversed
        .toList();

    final captureEvent = session.latestCaptureEvent;
    String capturingName = 'Player';
    String victimName = 'Opponent';
    if (captureEvent != null) {
      final byId = captureEvent.payload['capturedByPlayerId'];
      final victimId = captureEvent.payload['victimPlayerId'];
      capturingName =
          gameState.players.where((p) => p.id == byId).firstOrNull?.name ??
          'Player';
      victimName =
          gameState.players.where((p) => p.id == victimId).firstOrNull?.name ??
          'Opponent';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(gameState.ruleset.name.toUpperCase()),
        leading: IconButton(
          icon: const Icon(Icons.pause_circle_outline, size: 28),
          onPressed: () => _showPauseDialog(context, ref),
        ),
        actions: [
          IconButton(
            icon: Icon(
              settings.soundEnabled ? Icons.volume_up : Icons.volume_off,
              color: settings.soundEnabled
                  ? AppColors.gold
                  : AppColors.textMuted,
            ),
            onPressed: () => ref.read(settingsProvider.notifier).toggleSound(),
          ),
          IconButton(
            icon: Icon(
              settings.hapticsEnabled ? Icons.vibration : Icons.smartphone,
              color: settings.hapticsEnabled
                  ? AppColors.gold
                  : AppColors.textMuted,
            ),
            onPressed: () =>
                ref.read(settingsProvider.notifier).toggleHaptics(),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: topPlayers.map((player) {
                          return PlayerPanelWidget(
                            player: player,
                            isActiveTurn: gameState.currentSeat == player.seat,
                            tokensFinished: player.tokensInHome.length,
                            totalTokens: gameState.ruleset.tokensPerPlayer,
                          );
                        }).toList(),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: LudoBoardWidget(
                          gameState: gameState,
                          viewerColor: viewerColor,
                          interactionEnabled:
                              !session.isAnimating && !session.isBotThinking,
                          boardThemeAssetKey: CosmeticSelection.boardTheme,
                          onTokenTapped: (tokenId) {
                            ref
                                .read(gameControllerProvider.notifier)
                                .selectMove(tokenId);
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: bottomPlayers.map((player) {
                          return PlayerPanelWidget(
                            player: player,
                            isActiveTurn: gameState.currentSeat == player.seat,
                            tokensFinished: player.tokensInHome.length,
                            totalTokens: gameState.ruleset.tokensPerPlayer,
                          );
                        }).toList(),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.getPlayerColor(
                                    activePlayer.color,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.getPlayerColor(
                                        activePlayer.color,
                                      ).withValues(alpha: 0.8),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 2,
                                child: Text(
                                  activePlayer.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.getPlayerColor(
                                      activePlayer.color,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 3,
                                child: Text(
                                  '• ${_getStatusHint(gameState, session.isBotThinking)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.getPlayerColor(activePlayer.color)
                                        .withValues(alpha: 0.35),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: DiceWidget(
                                diceSkinAssetKey: CosmeticSelection.diceSkin,
                                diceValue: gameState.diceValue,
                                canRoll: canRoll,
                                playerColor: activePlayer.color,
                                rollSequence: session.rollSequence,
                                remainingSeconds:
                                    !session.isAnimating &&
                                        !session.isBotThinking &&
                                        !activePlayer.isBot
                                    ? session.remainingSeconds
                                    : null,
                                onRoll: () {
                                  ref
                                      .read(gameControllerProvider.notifier)
                                      .rollDice();
                                },
                                onDisabledTap: () {
                                  if (gameState.phase ==
                                          GamePhase.rollRequired &&
                                      !activePlayer.isBot) {
                                    ref
                                        .read(gameControllerProvider.notifier)
                                        .rollDice();
                                    return;
                                  }
                                  if (gameState.phase ==
                                      GamePhase.moveRequired) {
                                    if (gameState.legalMoves.isNotEmpty) {
                                      if (gameState.legalMoves.length == 1 &&
                                          !session.isAnimating) {
                                        ref
                                            .read(
                                              gameControllerProvider.notifier,
                                            )
                                            .selectMove(
                                              gameState
                                                  .legalMoves
                                                  .first
                                                  .tokenId,
                                            );
                                        return;
                                      }
                                    }
                                    ScaffoldMessenger.of(context)
                                        .clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Tap a pulsing token on the board to move!',
                                        ),
                                        duration: Duration(seconds: 3),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            if (captureEvent != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: Center(
                    child: FunnyCaptureOverlay(
                      capturingPlayerName: capturingName,
                      capturedPlayerName: victimName,
                      onDismissed: () {
                        ref
                            .read(gameControllerProvider.notifier)
                            .clearCaptureEvent();
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getStatusHint(GameState state, bool isBotThinking) {
    if (state.phase == GamePhase.resolving) return 'Animating...';
    if (state.currentPlayer.isBot || isBotThinking) {
      return 'Thinking...';
    }
    if (state.phase == GamePhase.rollRequired) {
      if (state.lastAction?['type'] == 'MOVE_APPLIED_BONUS_TURN' ||
          state.consecutiveSixes > 0) {
        return '🎉 Bonus Roll! Tap dice to roll again';
      }
      return 'Tap dice to roll';
    }
    if (state.phase == GamePhase.moveRequired) {
      return 'Tap a pulsing token to move';
    }
    return '';
  }

  void _showPauseDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Game Paused',
            style: TextStyle(color: AppColors.gold),
          ),
          content: const Text(
            'Your match progress is automatically saved.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Resume'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Save & Exit'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(gameControllerProvider.notifier).quitMatch();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text(
                'Quit Match',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
