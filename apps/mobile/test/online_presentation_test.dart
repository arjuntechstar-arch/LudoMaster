import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:mobile/src/board/board_coordinate_mapper.dart';
import 'package:mobile/src/board/dice_widget.dart';
import 'package:mobile/src/board/token_motion_widget.dart';
import 'package:mobile/src/controllers/online_match_controller.dart';
import 'package:mobile/src/services/game_pacing.dart';
import 'package:mobile/src/services/realtime_client.dart';

class TestRealtimeClient extends RealtimeClient {
  TestRealtimeClient()
    : super(matchId: 'test', token: 'test', wsBaseUrl: 'ws://localhost');
  final incoming = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final statuses = StreamController<RealtimeConnectionStatus>.broadcast(
    sync: true,
  );
  final moves = <int>[];
  var rollRequests = 0;
  @override
  Stream<Map<String, dynamic>> get events => incoming.stream;
  @override
  Stream<RealtimeConnectionStatus> get statusStream => statuses.stream;
  @override
  RealtimeConnectionStatus get status => RealtimeConnectionStatus.connected;
  @override
  void connect() {}
  @override
  void sendMoveRequest(int tokenId) => moves.add(tokenId);
  @override
  void sendRollRequest() => rollRequests++;
  @override
  void dispose() {
    incoming.close();
    statuses.close();
    super.dispose();
  }

  void emit(String name, Map<String, dynamic> payload) =>
      incoming.add({'event': name, 'payload': payload});
}

void main() {
  testWidgets('dice tap cannot roll while its owner is waiting', (
    tester,
  ) async {
    var rollCount = 0;
    Widget buildDice(bool canRoll) => MaterialApp(
      home: Scaffold(
        body: DiceWidget(
          diceValue: 4,
          canRoll: canRoll,
          playerColor: PlayerColor.red,
          onRoll: () => rollCount++,
        ),
      ),
    );

    await tester.pumpWidget(buildDice(false));
    await tester.tap(find.byType(DiceWidget));
    expect(rollCount, 0);

    await tester.pumpWidget(buildDice(true));
    await tester.tap(find.byType(DiceWidget));
    expect(rollCount, 1);
  });

  testWidgets('token follows timed hops along its moved squares', (
    tester,
  ) async {
    const boardSize = 300.0;
    Token token(int cell) => Token(
      id: 'red_0',
      color: PlayerColor.red,
      state: TokenState.track,
      trackCell: cell,
      stepCount: cell,
    );
    Widget buildToken(Token value) {
      final position = BoardCoordinateMapper.getTokenPixelPosition(
        token: value,
        boardSize: boardSize,
      );
      return MaterialApp(
        home: Center(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: Stack(
              children: [
                TokenMotionWidget(
                  key: const ValueKey('moving-token'),
                  token: value,
                  position: position,
                  boardSize: boardSize,
                  size: 20,
                  isLegal: false,
                ),
              ],
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildToken(token(0)));
    await tester.pumpWidget(buildToken(token(3)));
    await tester.pump(GamePacing.tokenMoveForSteps(3));
    expect(find.byKey(const ValueKey('moving-token')), findsOneWidget);
  });

  testWidgets('opponent roll is shown without animating or enabling my die', (
    tester,
  ) async {
    final client = TestRealtimeClient();
    final controller = OnlineMatchController(client: client);
    addTearDown(() {
      if (controller.mounted) controller.dispose();
    });
    client.emit('AUTHENTICATED', {'seatIndex': 0});
    client.emit('STATE_SNAPSHOT', {
      'currentSeatIndex': 1,
      'phase': 'ROLL_REQUIRED',
      'seats': [],
    });
    client.emit('DICE_ROLLED', {'seatIndex': 1, 'value': 4});
    await tester.pump();

    expect(controller.currentState.isMyTurn, isFalse);
    expect(controller.currentState.isAnimating, isTrue);
    expect(controller.currentState.rollSequence, 0);
    controller.rollDice();
    expect(client.rollRequests, 0);

    await tester.pump(GamePacing.diceRoll);
    expect(controller.currentState.isAnimating, isFalse);
    controller.dispose();
  });

  testWidgets('yard launch keeps route progress at the server zero point', (
    tester,
  ) async {
    final client = TestRealtimeClient();
    final controller = OnlineMatchController(client: client);
    addTearDown(() {
      if (controller.mounted) controller.dispose();
    });
    client.emit('STATE_SNAPSHOT', {
      'currentSeatIndex': 0,
      'phase': 'MOVE_REQUIRED',
      'seats': [
        {
          'seatIndex': 0,
          'tokens': [
            {'id': 0, 'location': 'YARD', 'position': -1, 'stepsTaken': 0},
          ],
        },
      ],
    });
    client.emit('MOVE_APPLIED', {
      'seatIndex': 0,
      'tokenId': 0,
      'fromLocation': 'YARD',
      'fromPosition': -1,
      'toLocation': 'TRACK',
      'toPosition': 0,
      'stepsTaken': 1,
    });
    await tester.pump();

    expect(
      controller.currentState.seats.single['tokens'].single['stepsTaken'],
      0,
    );
    controller.dispose();
  });

  testWidgets(
    'online turn remains with roller through dice and token animations',
    (tester) async {
      final client = TestRealtimeClient();
      final controller = OnlineMatchController(client: client);
      addTearDown(() {
        if (controller.mounted) controller.dispose();
      });
      client.emit('AUTHENTICATED', {'seatIndex': 0});
      client.emit('STATE_SNAPSHOT', {
        'currentSeatIndex': 0,
        'phase': 'ROLL_REQUIRED',
        'seats': [
          {
            'seatIndex': 0,
            'tokens': [
              {'id': 0, 'location': 'TRACK', 'position': 0, 'stepsTaken': 0},
            ],
          },
        ],
      });
      client.emit('DICE_ROLLED', {'seatIndex': 0, 'value': 2});
      client.emit('LEGAL_MOVES', {
        'moves': [
          {'tokenId': 0, 'fromLocation': 'TRACK'},
        ],
      });
      await tester.pump();
      expect(controller.currentState.isAnimating, isTrue);
      expect(controller.currentState.currentSeatIndex, 0);
      await tester.pump(GamePacing.diceRoll);
      expect(controller.currentState.phase, 'MOVE_REQUIRED');
      expect(client.moves, isEmpty);
      await tester.pump(GamePacing.autoMovePause);
      expect(client.moves, [0]);
      controller.moveToken(0);
      expect(client.moves, [0]);
      client.emit('MOVE_APPLIED', {
        'seatIndex': 0,
        'tokenId': 0,
        'toLocation': 'TRACK',
        'toPosition': 2,
        'stepsTaken': 2,
      });
      client.emit('TURN_STARTED', {
        'currentSeatIndex': 1,
        'timeoutSeconds': 15,
      });
      await tester.pump();
      expect(controller.currentState.isAnimating, isTrue);
      expect(controller.currentState.currentSeatIndex, 0);
      expect(controller.currentState.diceValue, 2);
      await tester.pump(GamePacing.tokenMove);
      expect(controller.currentState.currentSeatIndex, 1);
      expect(controller.currentState.diceValue, isNull);
      controller.dispose();
    },
  );

  testWidgets(
    'snapshot cancels queued turns and old auto moves; multiple yard choices stay manual',
    (tester) async {
      final client = TestRealtimeClient();
      final controller = OnlineMatchController(client: client);
      addTearDown(() {
        if (controller.mounted) controller.dispose();
      });
      client.emit('AUTHENTICATED', {'seatIndex': 0});
      client.emit('DICE_ROLLED', {'value': 6});
      client.emit('LEGAL_MOVES', {
        'moves': [
          {'tokenId': 0},
        ],
      });
      client.emit('TURN_STARTED', {'currentSeatIndex': 1});
      await tester.pump();
      client.emit('STATE_SNAPSHOT', {
        'currentSeatIndex': 0,
        'phase': 'MOVE_REQUIRED',
        'diceValue': 6,
        'legalMoves': [
          {'tokenId': 2, 'fromLocation': 'YARD'},
          {'tokenId': 3, 'fromLocation': 'YARD'},
        ],
      });
      await tester.pump(const Duration(seconds: 3));
      expect(controller.currentState.currentSeatIndex, 0);
      expect(controller.currentState.legalMoves.length, 2);
      expect(client.moves, isEmpty);
      client.emit('STATE_SNAPSHOT', {
        'currentSeatIndex': 0,
        'phase': 'MOVE_REQUIRED',
        'legalMoves': [
          {'tokenId': 2},
        ],
      });
      client.emit('STATE_SNAPSHOT', {
        'currentSeatIndex': 1,
        'phase': 'ROLL_REQUIRED',
      });
      await tester.pump(const Duration(seconds: 2));
      expect(client.moves, isEmpty);
      expect(controller.currentState.diceValue, isNull);
      controller.dispose();
    },
  );
}
