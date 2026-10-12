import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:web_socket_channel/web_socket_channel.dart';

import 'runtime_config.dart';

enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class RealtimeClient {
  final String wsBaseUrl;
  final String matchId;
  final String token;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  int _lastReceivedSequence = 0;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController =
      StreamController<RealtimeConnectionStatus>.broadcast();

  RealtimeConnectionStatus _status = RealtimeConnectionStatus.disconnected;

  RealtimeClient({
    String? wsBaseUrl,
    required this.matchId,
    required this.token,
  }) : wsBaseUrl = wsBaseUrl ?? RuntimeConfig.realtimeBaseUrl;

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  Stream<RealtimeConnectionStatus> get statusStream => _statusController.stream;
  RealtimeConnectionStatus get status => _status;
  int get lastReceivedSequence => _lastReceivedSequence;

  void _setStatus(RealtimeConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  void connect() {
    if (_isDisposed) return;
    _setStatus(
      _reconnectAttempts > 0
          ? RealtimeConnectionStatus.reconnecting
          : RealtimeConnectionStatus.connecting,
    );

    try {
      final uri = Uri.parse('$wsBaseUrl/ws/match/$matchId?token=$token');
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _setStatus(RealtimeConnectionStatus.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();

      // If reconnecting, send RECONNECT action with sequence
      if (_lastReceivedSequence > 0) {
        sendAction({
          'action': 'RECONNECT',
          'lastReceivedSequence': _lastReceivedSequence,
        });
      }
    } catch (e) {
      developer.log('WebSocket connection error: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final seq = map['sequence'] as int?;
      if (seq != null && seq > _lastReceivedSequence) {
        _lastReceivedSequence = seq;
      }
      _eventController.add(map);
    } catch (e) {
      developer.log('Error parsing WebSocket message: $e');
    }
  }

  void _onError(dynamic error) {
    developer.log('WebSocket error: $error');
    _setStatus(RealtimeConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _onDone() {
    developer.log('WebSocket connection closed.');
    _setStatus(RealtimeConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _stopHeartbeat();
    _subscription?.cancel();

    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts < 5 ? _reconnectAttempts * 2 : 10);
    developer.log(
      'Scheduling reconnect in $delaySeconds seconds (attempt $_reconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      sendAction({'type': 'PING'});
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void sendAction(Map<String, dynamic> action) {
    if (_channel != null && _status == RealtimeConnectionStatus.connected) {
      try {
        _channel!.sink.add(jsonEncode(action));
      } catch (e) {
        developer.log('Error sending action: $e');
      }
    }
  }

  void sendRollRequest() {
    sendAction({'action': 'ROLL_REQUEST'});
  }

  void sendMoveRequest(int tokenId) {
    sendAction({'action': 'MOVE_REQUEST', 'tokenId': tokenId});
  }

  void sendChat(String message) {
    sendAction({'action': 'CHAT', 'message': message});
  }

  void sendEmoji(String emojiId) {
    sendAction({'action': 'EMOJI', 'emojiId': emojiId});
  }

  void dispose() {
    _isDisposed = true;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _eventController.close();
    _statusController.close();
  }
}
