import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio_service.dart';
import '../services/game_pacing.dart';
import '../services/realtime_client.dart';

class OnlineMatchState {
  final RealtimeConnectionStatus connectionStatus;
  final String matchId;
  final int mySeatIndex;
  final int currentSeatIndex;
  final String phase;
  final int? diceValue;
  final List<Map<String, dynamic>> legalMoves;
  final List<Map<String, dynamic>> seats;
  final int remainingSeconds;
  final List<Map<String, String>> chatMessages;
  final Map<String, dynamic>? latestEmoji;
  final Map<String, dynamic>? latestCapture;
  final String? opponentNotice;
  final List<Map<String, dynamic>>? matchResults;
  final bool isGameOver;
  final bool isAnimating;
  final bool requestPending;
  final int rollSequence;

  const OnlineMatchState({
    required this.connectionStatus,
    required this.matchId,
    required this.mySeatIndex,
    required this.currentSeatIndex,
    required this.phase,
    this.diceValue,
    this.legalMoves = const [],
    this.seats = const [],
    this.remainingSeconds = 15,
    this.chatMessages = const [],
    this.latestEmoji,
    this.latestCapture,
    this.opponentNotice,
    this.matchResults,
    this.isGameOver = false,
    this.isAnimating = false,
    this.requestPending = false,
    this.rollSequence = 0,
  });

  bool get isMyTurn => mySeatIndex == currentSeatIndex && !isGameOver;

  OnlineMatchState copyWith({
    RealtimeConnectionStatus? connectionStatus,
    String? matchId,
    int? mySeatIndex,
    int? currentSeatIndex,
    String? phase,
    int? diceValue,
    bool clearDiceValue = false,
    List<Map<String, dynamic>>? legalMoves,
    List<Map<String, dynamic>>? seats,
    int? remainingSeconds,
    List<Map<String, String>>? chatMessages,
    Map<String, dynamic>? latestEmoji,
    Map<String, dynamic>? latestCapture,
    bool clearCapture = false,
    String? opponentNotice,
    bool clearOpponentNotice = false,
    List<Map<String, dynamic>>? matchResults,
    bool? isGameOver,
    bool? isAnimating,
    bool? requestPending,
    int? rollSequence,
  }) {
    return OnlineMatchState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      matchId: matchId ?? this.matchId,
      mySeatIndex: mySeatIndex ?? this.mySeatIndex,
      currentSeatIndex: currentSeatIndex ?? this.currentSeatIndex,
      phase: phase ?? this.phase,
      diceValue: clearDiceValue ? null : (diceValue ?? this.diceValue),
      legalMoves: legalMoves ?? this.legalMoves,
      seats: seats ?? this.seats,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      chatMessages: chatMessages ?? this.chatMessages,
      latestEmoji: latestEmoji ?? this.latestEmoji,
      latestCapture: clearCapture
          ? null
          : (latestCapture ?? this.latestCapture),
      opponentNotice: clearOpponentNotice
          ? null
          : (opponentNotice ?? this.opponentNotice),
      matchResults: matchResults ?? this.matchResults,
      isGameOver: isGameOver ?? this.isGameOver,
      isAnimating: isAnimating ?? this.isAnimating,
      requestPending: requestPending ?? this.requestPending,
      rollSequence: rollSequence ?? this.rollSequence,
    );
  }
}

class OnlineMatchController extends StateNotifier<OnlineMatchState> {
  final RealtimeClient client;
  StreamSubscription? _eventSub;
  StreamSubscription? _statusSub;
  Timer? _countdownTimer;
  Timer? _autoMoveTimer;
  Timer? _requestTimer;
  Timer? _animationTimer;
  Completer<void>? _animationComplete;
  Future<void> _presentation = Future.value();
  int _generation = 0;

  OnlineMatchController({required this.client})
    : super(
        OnlineMatchState(
          connectionStatus: client.status,
          matchId: client.matchId,
          mySeatIndex: -1,
          currentSeatIndex: 0,
          phase: 'WAITING',
        ),
      ) {
    _statusSub = client.statusStream.listen((status) {
      state = state.copyWith(connectionStatus: status);
    });

    _eventSub = client.events.listen(_handleEvent);
    client.connect();
  }

  OnlineMatchState get currentState => state;

  Future<void> _waitForAnimation(Duration duration) {
    _cancelAnimation();
    final completion = Completer<void>();
    _animationComplete = completion;
    _animationTimer = Timer(duration, completion.complete);
    return completion.future;
  }

  void _cancelAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
    final completion = _animationComplete;
    _animationComplete = null;
    if (completion != null && !completion.isCompleted) completion.complete();
  }

  void _handleEvent(Map<String, dynamic> event) {
    final name = event['event'];
    if (name == 'STATE_SNAPSHOT') {
      _generation++;
      _cancelAnimation();
      _autoMoveTimer?.cancel();
      _requestTimer?.cancel();
      _presentation = Future.value();
      _applySnapshot((event['payload'] as Map<String, dynamic>?) ?? {});
      return;
    }
    if (const {
      'TURN_STARTED',
      'DICE_ROLLED',
      'LEGAL_MOVES',
      'MOVE_APPLIED',
      'TOKEN_CAPTURED',
      'MATCH_FINISHED',
    }.contains(name)) {
      final generation = _generation;
      _presentation = _presentation.then((_) async {
        if (!mounted || generation != _generation) return;
        _presentEvent(event);
        final payload = (event['payload'] as Map<String, dynamic>?) ?? {};
        final duration = name == 'DICE_ROLLED'
            ? GamePacing.diceRoll
            : name == 'MOVE_APPLIED'
            ? GamePacing.tokenMoveForSteps(
                (payload['stepsTaken'] as num?)?.toInt() ?? 1,
              )
            : null;
        if (duration != null) {
          await _waitForAnimation(duration);
          if (mounted && generation == _generation) {
            state = state.copyWith(isAnimating: false);
          }
        }
      });
      return;
    }
    _presentEvent(event);
  }

  void _presentEvent(Map<String, dynamic> event) {
    final eventName = event['event'] as String?;
    final payload = (event['payload'] as Map<String, dynamic>?) ?? {};

    switch (eventName) {
      case 'ERROR':
        _requestTimer?.cancel();
        state = state.copyWith(
          requestPending: false,
          opponentNotice: payload['message'] as String? ?? 'Please try again.',
        );
        break;

      case 'AUTHENTICATED':
        final seat = payload['seatIndex'] as int? ?? -1;
        state = state.copyWith(mySeatIndex: seat);
        break;

      case 'STATE_SNAPSHOT':
        _applySnapshot(payload);
        break;

      case 'MATCH_STARTED':
        final seatsList =
            (payload['seats'] as List<dynamic>?)
                ?.map((s) => s as Map<String, dynamic>)
                .toList() ??
            [];
        state = state.copyWith(seats: seatsList, phase: 'ROLL_REQUIRED');
        break;

      case 'TURN_STARTED':
        _autoMoveTimer?.cancel();
        _requestTimer?.cancel();
        final currSeat = payload['currentSeatIndex'] as int? ?? 0;
        final timeoutSec =
            (payload['timeoutSeconds'] as num?)?.toInt() ??
            GamePacing.turnDurationSeconds;
        _startCountdown(timeoutSec);
        state = state.copyWith(
          currentSeatIndex: currSeat,
          requestPending: false,
          isAnimating: false,
          phase: 'ROLL_REQUIRED',
          clearDiceValue: true,
          legalMoves: [],
        );
        break;

      case 'DICE_ROLLED':
        final val = payload['value'] as int?;
        _stopCountdown();
        _requestTimer?.cancel();
        state = state.copyWith(
          diceValue: val,
          // Every authoritative roll animates on the shared table.
          rollSequence: state.rollSequence + 1,
          isAnimating: true,
          requestPending: false,
          legalMoves: [],
        );
        break;

      case 'LEGAL_MOVES':
        final moves =
            (payload['moves'] as List<dynamic>?)
                ?.map((m) => m as Map<String, dynamic>)
                .toList() ??
            [];
        _startCountdown(GamePacing.turnDurationSeconds);
        state = state.copyWith(legalMoves: moves, phase: 'MOVE_REQUIRED');
        _scheduleAutoMove();
        break;

      case 'MOVE_APPLIED':
        _autoMoveTimer?.cancel();
        _requestTimer?.cancel();
        _stopCountdown();
        _applyMove(payload);
        state = state.copyWith(isAnimating: true, requestPending: false);
        break;

      case 'PLAYER_DISCONNECTED':
        final seat = payload['seatIndex'] as int?;
        state = state.copyWith(
          opponentNotice: 'Seat $seat disconnected (30s reconnect window)',
        );
        break;

      case 'PLAYER_RECONNECTED':
        state = state.copyWith(clearOpponentNotice: true);
        break;

      case 'CHAT_MESSAGE':
        final newMsgs = List<Map<String, String>>.from(state.chatMessages);
        newMsgs.add({
          'sender': payload['displayName'] as String? ?? 'Player',
          'text': payload['message'] as String? ?? '',
        });
        state = state.copyWith(chatMessages: newMsgs);
        break;

      case 'EMOJI_SENT':
        state = state.copyWith(latestEmoji: payload);
        break;

      case 'TOKEN_CAPTURED':
        AudioService.playCaptureHaptic();
        _applyCapture(payload);
        break;

      case 'MATCH_FINISHED':
        AudioService.playVictoryHaptic();
        AudioService.stopGameMusic();
        _stopCountdown();
        final results =
            (payload['results'] as List<dynamic>?)
                ?.map((r) => r as Map<String, dynamic>)
                .toList() ??
            [];
        state = state.copyWith(
          isGameOver: true,
          matchResults: results,
          phase: 'FINISHED',
        );
        break;
    }
  }

  void _applySnapshot(Map<String, dynamic> snapshot) {
    final currSeat = snapshot['currentSeatIndex'] as int? ?? 0;
    final phase = snapshot['phase'] as String? ?? 'WAITING';
    final diceVal = snapshot['diceValue'] as int?;
    final seatsList =
        (snapshot['seats'] as List<dynamic>?)
            ?.map((s) => s as Map<String, dynamic>)
            .toList() ??
        [];
    final moves =
        (snapshot['legalMoves'] as List<dynamic>?)
            ?.map((m) => m as Map<String, dynamic>)
            .toList() ??
        [];

    state = state.copyWith(
      currentSeatIndex: currSeat,
      phase: phase,
      diceValue: diceVal,
      clearDiceValue: diceVal == null,
      isAnimating: false,
      requestPending: false,
      isGameOver: phase == 'FINISHED',
      seats: seatsList,
      legalMoves: moves,
    );
    if (!state.isGameOver &&
        (phase == 'ROLL_REQUIRED' || phase == 'MOVE_REQUIRED')) {
      _startCountdown(
        (snapshot['timeoutSeconds'] as num?)?.toInt() ??
            GamePacing.turnDurationSeconds,
      );
    } else {
      _stopCountdown();
    }
    _scheduleAutoMove();
  }

  void _applyMove(Map<String, dynamic> payload) {
    final seatIdx = payload['seatIndex'] as int?;
    final tokenId = payload['tokenId'] as int?;
    final toLoc = payload['toLocation'] as String?;
    final toPos = payload['toPosition'] as int?;
    final stepsTaken = payload['stepsTaken'] as int?;

    if (seatIdx == null || tokenId == null) return;

    final updatedSeats = state.seats.map((seatMap) {
      if (seatMap['seatIndex'] == seatIdx) {
        final tokens = (seatMap['tokens'] as List<dynamic>?) ?? [];
        final updatedTokens = tokens.map((t) {
          final tokenMap = Map<String, dynamic>.from(t as Map<String, dynamic>);
          if (tokenMap['id'] == tokenId) {
            final fromLocation =
                payload['fromLocation'] as String? ??
                tokenMap['location'] as String?;
            tokenMap['location'] = toLoc;
            tokenMap['position'] = toPos;
            if (stepsTaken != null) {
              // The launch square is progress zero on the server. Leaving
              // the yard occupies that square without advancing the route.
              tokenMap['stepsTaken'] = fromLocation == 'YARD'
                  ? 0
                  : (tokenMap['stepsTaken'] as int? ?? 0) + stepsTaken;
            }
          }
          return tokenMap;
        }).toList();
        final newSeatMap = Map<String, dynamic>.from(seatMap);
        newSeatMap['tokens'] = updatedTokens;
        return newSeatMap;
      }
      return seatMap;
    }).toList();

    state = state.copyWith(seats: updatedSeats, legalMoves: []);
  }

  void _applyCapture(Map<String, dynamic> payload) {
    final captured = (payload['captured'] as List<dynamic>?) ?? [];
    final updatedSeats = state.seats.map((seatMap) {
      final seatIndex = seatMap['seatIndex'];
      final tokenIds = captured
          .whereType<Map<String, dynamic>>()
          .where((item) => item['seatIndex'] == seatIndex)
          .map((item) => item['tokenId'])
          .toSet();
      if (tokenIds.isEmpty) return seatMap;

      final updatedSeat = Map<String, dynamic>.from(seatMap);
      updatedSeat['tokens'] = (seatMap['tokens'] as List<dynamic>? ?? []).map((
        rawToken,
      ) {
        final token = Map<String, dynamic>.from(
          rawToken as Map<String, dynamic>,
        );
        if (tokenIds.contains(token['id'])) {
          token['location'] = 'YARD';
          token['position'] = -1;
          token['stepsTaken'] = 0;
        }
        return token;
      }).toList();
      return updatedSeat;
    }).toList();
    state = state.copyWith(seats: updatedSeats, latestCapture: payload);
  }

  void _startCountdown(int seconds) {
    _stopCountdown();
    var remaining = seconds;
    state = state.copyWith(remainingSeconds: remaining);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      state = state.copyWith(remainingSeconds: remaining < 0 ? 0 : remaining);
      if (remaining <= 0) {
        _stopCountdown();
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _scheduleAutoMove() {
    _autoMoveTimer?.cancel();
    if (!_canAutoMove()) {
      return;
    }
    final sequence = state.rollSequence;
    final generation = _generation;
    final seat = state.currentSeatIndex;
    final token = _tokenId(state.legalMoves.single['tokenId']);
    _autoMoveTimer = Timer(GamePacing.autoMovePause, () {
      if (mounted &&
          generation == _generation &&
          state.rollSequence == sequence &&
          state.currentSeatIndex == seat &&
          _canAutoMove() &&
          _tokenId(state.legalMoves.single['tokenId']) == token &&
          token != null) {
        moveToken(token);
      }
    });
  }

  bool _canAutoMove() {
    if (!state.isMyTurn ||
        state.phase != 'MOVE_REQUIRED' ||
        state.isAnimating ||
        state.requestPending ||
        state.legalMoves.length != 1) {
      return false;
    }
    final seat = state.seats
        .where((seat) => seat['seatIndex'] == state.currentSeatIndex)
        .firstOrNull;
    final tokens = seat?['tokens'];
    // Without a complete token snapshot, leave the decision to the player.
    if (tokens is! List || tokens.isEmpty) return false;
    final candidates = tokens
        .where(
          (token) =>
              token['location'] == 'TRACK' ||
              token['location'] == 'HOME_LANE' ||
              (token['location'] == 'YARD' && state.diceValue == 6),
        )
        .toList();
    return candidates.length == 1 &&
        _tokenId(candidates.single['id']) ==
            _tokenId(state.legalMoves.single['tokenId']);
  }

  int? _tokenId(dynamic raw) =>
      raw is int ? raw : int.tryParse('$raw'.split('_').last);

  void _markRequestPending() {
    state = state.copyWith(requestPending: true);
    _requestTimer?.cancel();
    _requestTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && state.requestPending) {
        state = state.copyWith(
          requestPending: false,
          opponentNotice: 'Connection is slow. Please try again.',
        );
      }
    });
  }

  void rollDice() {
    if (!state.isMyTurn || state.isAnimating || state.requestPending) return;
    if (state.phase == 'ROLL_REQUIRED') {
      AudioService.playRollHaptic();
      _markRequestPending();
      client.sendRollRequest();
    }
  }

  void moveToken(int tokenId) {
    if (!state.isMyTurn ||
        state.isAnimating ||
        state.requestPending ||
        state.phase != 'MOVE_REQUIRED') {
      return;
    }
    if (!state.legalMoves.any((move) => _tokenId(move['tokenId']) == tokenId)) {
      return;
    }
    AudioService.playMoveHaptic();
    _autoMoveTimer?.cancel();
    _markRequestPending();
    client.sendMoveRequest(tokenId);
  }

  void sendChat(String msg) {
    if (msg.trim().isNotEmpty) {
      client.sendChat(msg.trim());
    }
  }

  void sendEmoji(String emojiId) {
    client.sendEmoji(emojiId);
  }

  void clearCapture() {
    state = state.copyWith(clearCapture: true);
  }

  @override
  void dispose() {
    _generation++;
    _cancelAnimation();
    _autoMoveTimer?.cancel();
    _requestTimer?.cancel();
    _stopCountdown();
    _eventSub?.cancel();
    _statusSub?.cancel();
    client.dispose();
    super.dispose();
  }
}
