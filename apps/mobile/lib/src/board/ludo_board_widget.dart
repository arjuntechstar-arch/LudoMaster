import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import 'board_coordinate_mapper.dart';
import 'ludo_board_painter.dart';
import 'token_motion_widget.dart';
import 'board_perspective.dart';
import 'six_player_board_geometry.dart';
import 'six_player_board_painter.dart';

/// Full interactive board widget composing vector canvas and animated tokens.
class LudoBoardWidget extends StatelessWidget {
  const LudoBoardWidget({
    super.key,
    required this.gameState,
    required this.onTokenTapped,
    this.boardThemeAssetKey = 'theme_classic_wood',
    this.viewerColor = PlayerColor.blue,
    this.interactionEnabled = true,
  });

  final GameState gameState;
  final ValueChanged<String> onTokenTapped;
  final String boardThemeAssetKey;
  final PlayerColor viewerColor;
  final bool interactionEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSixPlayerBoard = gameState.players.length > 4;
        final gridSize = isSixPlayerBoard
            ? SixPlayerBoardGeometry.gridSize
            : BoardCoordinateMapper.gridSize;
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        // Collect all tokens across all players
        final allTokens = <Token>[];
        for (final p in gameState.players) {
          allTokens.addAll(p.tokens);
        }

        // Group tokens by logical position to calculate stacking offsets
        final cellGroups = <String, List<Token>>{};
        for (final t in allTokens) {
          String key;
          switch (t.state) {
            case TokenState.yard:
              key = 'yard_${t.id}';
              break;
            case TokenState.track:
              key = 'track_${t.trackCell}';
              break;
            case TokenState.homeLane:
              key = 'lane_${t.color.name}_${t.laneStep}';
              break;
            case TokenState.home:
              key = 'home_${t.color.name}';
              break;
          }
          cellGroups.putIfAbsent(key, () => []).add(t);
        }

        final legalTokenIds = gameState.legalMoves
            .map((m) => m.tokenId)
            .toSet();
        final tokenSize = (size / gridSize) * 0.88;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: RotatedBox(
              quarterTurns: isSixPlayerBoard
                  ? 0
                  : BoardPerspective.quarterTurnsFor(viewerColor),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Vector Board Canvas
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: isSixPlayerBoard
                            ? const SixPlayerBoardPainter()
                            : LudoBoardPainter(
                                themeAssetKey: boardThemeAssetKey,
                              ),
                      ),
                    ),
                  ),

                  // 2. Animated Interactive Token Layer
                  ...allTokens.map((token) {
                    String key;
                    switch (token.state) {
                      case TokenState.yard:
                        key = 'yard_${token.id}';
                        break;
                      case TokenState.track:
                        key = 'track_${token.trackCell}';
                        break;
                      case TokenState.homeLane:
                        key = 'lane_${token.color.name}_${token.laneStep}';
                        break;
                      case TokenState.home:
                        key = 'home_${token.color.name}';
                        break;
                    }

                    final group = cellGroups[key] ?? [token];
                    final stackIndex = group.indexOf(token);
                    final totalInStack = group.length;

                    final offset = isSixPlayerBoard
                        ? SixPlayerBoardGeometry.tokenPixelPosition(
                            token: token,
                            boardSize: size,
                            stackIndex: stackIndex,
                            totalInStack: totalInStack,
                          )
                        : BoardCoordinateMapper.getTokenPixelPosition(
                            token: token,
                            boardSize: size,
                            stackIndex: stackIndex,
                            totalInStack: totalInStack,
                          );

                    final isLegal =
                        interactionEnabled &&
                        legalTokenIds.contains(token.id) &&
                        gameState.phase == GamePhase.moveRequired &&
                        !gameState.currentPlayer.isBot;

                    return TokenMotionWidget(
                      key: ValueKey(token.id),
                      token: token,
                      position: offset,
                      boardSize: size,
                      size: tokenSize,
                      isLegal: isLegal,
                      onTap: isLegal ? () => onTokenTapped(token.id) : null,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
