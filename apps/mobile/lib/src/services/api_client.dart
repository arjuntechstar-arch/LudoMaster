import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'runtime_config.dart';

class RoomMemberModel {
  final String id;
  final String userId;
  final int seatIndex;
  final bool isReady;
  final bool isHost;
  final String displayName;
  final String avatarId;
  final int level;

  RoomMemberModel({
    required this.id,
    required this.userId,
    required this.seatIndex,
    required this.isReady,
    required this.isHost,
    required this.displayName,
    required this.avatarId,
    required this.level,
  });

  factory RoomMemberModel.fromJson(Map<String, dynamic> json) {
    return RoomMemberModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      seatIndex: json['seat_index'] as int,
      isReady: json['is_ready'] as bool,
      isHost: json['is_host'] as bool,
      displayName: json['display_name'] as String? ?? 'Player',
      avatarId: json['avatar_id'] as String? ?? 'avatar_0',
      level: json['level'] as int? ?? 1,
    );
  }
}

class RoomModel {
  final String id;
  final String code;
  final String hostUserId;
  final String mode;
  final int maxPlayers;
  final bool fillWithBots;
  final String status;
  final int betCoins;
  final List<RoomMemberModel> members;
  final String? matchId;

  RoomModel({
    required this.id,
    required this.code,
    required this.hostUserId,
    required this.mode,
    required this.maxPlayers,
    required this.fillWithBots,
    required this.status,
    required this.betCoins,
    required this.members,
    this.matchId,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    final membersList =
        (json['members'] as List<dynamic>?)
            ?.map((m) => RoomMemberModel.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];
    return RoomModel(
      id: json['id'] as String,
      code: json['code'] as String,
      hostUserId: json['host_user_id'] as String,
      mode: json['mode'] as String,
      maxPlayers: json['max_players'] as int,
      fillWithBots: json['fill_with_bots'] as bool? ?? true,
      status: json['status'] as String,
      betCoins: json['bet_coins'] as int? ?? 0,
      members: membersList,
      matchId: json['match_id'] as String?,
    );
  }
}

class ApiClient {
  String baseUrl;
  String? _accessToken;
  String? _userId;
  bool? _isGuest;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? RuntimeConfig.apiBaseUrl;

  String? get accessToken => _accessToken;
  String? get userId => _userId;
  bool? get isGuest => _isGuest;

  void setAuth(String token, String userId) {
    _accessToken = token;
    _userId = userId;
    _isGuest = null;
  }

  Future<bool>? _restoring;
  int _sessionVersion = 0;
  Future<bool> restoreSession() =>
      _restoring ??= _restoreSession().whenComplete(() => _restoring = null);

  Future<bool> _restoreSession() async {
    final version = _sessionVersion;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _userId = prefs.getString('user_id');
    _isGuest = prefs.getBool('is_guest');
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      return _accessToken != null;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (_sessionVersion != version) return _accessToken != null;
      if (response.statusCode == 200) {
        await _storeSession(jsonDecode(response.body) as Map<String, dynamic>);
        return true;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        return false;
      }
    } catch (_) {
      // Keep the saved access token for offline use if refresh is unreachable.
    }
    return _accessToken != null;
  }

  Future<String> _resolveDeviceId(String? deviceId) async {
    if (deviceId != null && deviceId.trim().isNotEmpty) return deviceId.trim();

    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('installation_id');
    if (savedId != null && savedId.isNotEmpty) return savedId;

    final random = Random.secure();
    final generatedId =
        'device_${List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join()}';
    await prefs.setString('installation_id', generatedId);
    return generatedId;
  }

  Future<void> _storeSession(Map<String, dynamic> data) async {
    _sessionVersion++;
    _accessToken = data['access_token'] as String;
    _userId = data['user_id'] as String;
    _isGuest = data['is_guest'] as bool?;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', _accessToken!);
    await prefs.setString('user_id', _userId!);
    if (_isGuest != null) await prefs.setBool('is_guest', _isGuest!);
    final refreshToken = data['refresh_token'] as String?;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<Map<String, dynamic>> getAuthProviders() async {
    final response = await http.get(Uri.parse('$baseUrl/auth/providers'));
    if (response.statusCode != 200) {
      throw Exception('Account connections are temporarily unavailable');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signInWithGoogleToken(
    String token, {
    bool link = false,
    String? displayName,
    String? username,
    String? avatarId,
  }) async {
    final payload = <String, dynamic>{
      'id_token': token,
      'link_to_current_user': link,
      'display_name': ?displayName?.trim(),
      'username': ?username?.trim(),
      'avatar_id': ?avatarId,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception(_responseMessage(response, 'Google sign-in failed'));
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    await _storeSession(result);
    return result;
  }

  Future<Map<String, dynamic>> signInWithPlayGamesCode(
    String code, {
    bool link = false,
    String? displayName,
    String? username,
    String? avatarId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/play-games'),
      headers: _headers,
      body: jsonEncode({
        'server_auth_code': code,
        'link_to_current_user': link,
        'display_name': ?displayName?.trim(),
        'username': ?username?.trim(),
        'avatar_id': ?avatarId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_responseMessage(response, 'Play Games sign-in failed'));
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    await _storeSession(result);
    return result;
  }

  String _responseMessage(http.Response response, String fallback) {
    try {
      final details = jsonDecode(response.body) as Map<String, dynamic>;
      return details['detail'] is String
          ? details['detail'] as String
          : fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<Map<String, dynamic>> getPurchaseConfiguration() async {
    final response = await http.get(
      Uri.parse('$baseUrl/purchases/config'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Purchases are temporarily unavailable');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAdRewardStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/economy/watch-ad/status'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Ad rewards are temporarily unavailable');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> loginGuest({
    String? deviceId,
    String platform = 'ANDROID',
  }) async {
    final resolvedDeviceId = await _resolveDeviceId(deviceId);
    final url = Uri.parse('$baseUrl/auth/guest');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_id': resolvedDeviceId,
        'platform': platform,
        'app_version': '1.0.1',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storeSession(data);
    } else {
      throw Exception('Guest login failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    final resolvedDeviceId = await _resolveDeviceId(deviceId);
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
        'device_id': resolvedDeviceId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storeSession(data);
      return data;
    } else {
      final body = jsonDecode(response.body);
      final msg = body is Map
          ? (body['detail'] ?? response.body)
          : response.body;
      throw Exception('$msg');
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
    required String username,
    required String avatarId,
    String? deviceId,
  }) async {
    final resolvedDeviceId = await _resolveDeviceId(deviceId);
    final url = Uri.parse('$baseUrl/auth/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
        'display_name': displayName.trim(),
        'username': username
            .trim()
            .replaceFirst(RegExp(r'^@'), '')
            .toLowerCase(),
        'avatar_id': avatarId,
        'device_id': resolvedDeviceId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storeSession(data);
      return data;
    } else {
      final body = jsonDecode(response.body);
      final msg = body is Map
          ? (body['detail'] ?? response.body)
          : response.body;
      throw Exception('$msg');
    }
  }

  Future<Map<String, dynamic>> upgradeGuest({
    required String email,
    required String password,
    required String displayName,
    required String username,
    required String avatarId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/upgrade'),
      headers: _headers,
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
        'display_name': displayName.trim(),
        'username': username
            .trim()
            .replaceFirst(RegExp(r'^@'), '')
            .toLowerCase(),
        'avatar_id': avatarId,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storeSession(data);
      return data;
    }

    final body = jsonDecode(response.body);
    final message = body is Map
        ? (body['detail'] ?? response.body)
        : response.body;
    throw Exception('$message');
  }

  Future<void> logout() async {
    _sessionVersion++;
    _accessToken = null;
    _userId = null;
    _isGuest = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('user_id');
      await prefs.remove('refresh_token');
      await prefs.remove('is_guest');
      await prefs.remove('display_name');
      await prefs.remove('avatar_id');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> claimWatchAdReward() async {
    final url = Uri.parse('$baseUrl/economy/watch-ad/claim');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to claim ad reward: ${response.body}');
    }
  }

  Future<RoomModel> createRoom({
    String mode = 'CLASSIC',
    int maxPlayers = 4,
    bool fillWithBots = true,
    int betCoins = 0,
  }) async {
    final url = Uri.parse('$baseUrl/rooms');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'mode': mode,
        'max_players': maxPlayers,
        'fill_with_bots': fillWithBots,
        'bet_coins': betCoins,
      }),
    );

    if (response.statusCode == 201) {
      return RoomModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Create room failed: ${response.body}');
    }
  }

  Future<RoomModel> joinRoom(String code) async {
    final url = Uri.parse('$baseUrl/rooms/join');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'code': code.trim().toUpperCase()}),
    );

    if (response.statusCode == 200) {
      return RoomModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Join room failed: ${response.body}');
    }
  }

  Future<RoomModel> getRoom(String roomId) async {
    final url = Uri.parse('$baseUrl/rooms/$roomId');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      return RoomModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Get room failed: ${response.body}');
    }
  }

  Future<RoomModel> toggleReady(String roomId, bool isReady) async {
    final url = Uri.parse('$baseUrl/rooms/$roomId/ready');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'is_ready': isReady}),
    );

    if (response.statusCode == 200) {
      return RoomModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Toggle ready failed: ${response.body}');
    }
  }

  Future<void> leaveRoom(String roomId) async {
    final url = Uri.parse('$baseUrl/rooms/$roomId/leave');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Leave room failed: ${response.body}');
    }
  }

  Future<RoomModel> startRoomMatch(String roomId) async {
    final url = Uri.parse('$baseUrl/rooms/$roomId/start');
    final response = await http.post(url, headers: _headers);

    if (response.statusCode == 200) {
      return RoomModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Start match failed: ${response.body}');
    }
  }

  Future<MatchmakingTicketModel> enqueueMatchmaking({
    String mode = 'CLASSIC',
    int playerCount = 4,
    int betCoins = 100,
    String region = 'GLOBAL',
  }) async {
    final url = Uri.parse('$baseUrl/matchmaking/enqueue');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'mode': mode,
        'player_count': playerCount,
        'bet_coins': betCoins,
        'region': region,
      }),
    );

    if (response.statusCode == 201) {
      return MatchmakingTicketModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Enqueue failed: ${response.body}');
    }
  }

  Future<MatchmakingTicketModel> getMatchmakingTicket(String ticketId) async {
    final url = Uri.parse('$baseUrl/matchmaking/ticket/$ticketId');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      return MatchmakingTicketModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Get ticket failed: ${response.body}');
    }
  }

  Future<void> cancelMatchmakingTicket(String ticketId) async {
    final url = Uri.parse('$baseUrl/matchmaking/ticket/$ticketId/cancel');
    final response = await http.post(url, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Cancel matchmaking failed: ${response.body}');
    }
  }

  Future<List<MatchHistoryModel>> getMyMatchHistory({int limit = 20}) async {
    final url = Uri.parse('$baseUrl/matches/my-history?limit=$limit');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list =
          (data['matches'] as List<dynamic>?)
              ?.map(
                (m) => MatchHistoryModel.fromJson(m as Map<String, dynamic>),
              )
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Get match history failed: ${response.body}');
    }
  }

  Future<List<RecentPlayerModel>> getRecentPlayers({int limit = 20}) async {
    final url = Uri.parse('$baseUrl/players/recent?limit=$limit');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final list =
          (jsonDecode(response.body) as List<dynamic>?)
              ?.map(
                (p) => RecentPlayerModel.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Get recent players failed: ${response.body}');
    }
  }

  // --- Social & Friends Methods ---

  Future<void> sendFriendRequest({
    String? targetUserId,
    String? playerId,
    String? username,
  }) async {
    final url = Uri.parse('$baseUrl/friends/request');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'target_user_id': ?targetUserId,
        'player_id': ?playerId,
        'username': ?username,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Send friend request failed: ${response.body}');
    }
  }

  Future<Map<String, List<FriendRequestModel>>> getFriendRequests() async {
    final url = Uri.parse('$baseUrl/friends/requests');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final inc =
          (data['incoming'] as List<dynamic>?)
              ?.map(
                (r) => FriendRequestModel.fromJson(r as Map<String, dynamic>),
              )
              .toList() ??
          [];
      final out =
          (data['outgoing'] as List<dynamic>?)
              ?.map(
                (r) => FriendRequestModel.fromJson(r as Map<String, dynamic>),
              )
              .toList() ??
          [];
      return {'incoming': inc, 'outgoing': out};
    } else {
      throw Exception('Get friend requests failed: ${response.body}');
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final url = Uri.parse('$baseUrl/friends/requests/$requestId/accept');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Accept request failed: ${response.body}');
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    final url = Uri.parse('$baseUrl/friends/requests/$requestId/decline');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Decline request failed: ${response.body}');
    }
  }

  Future<List<FriendModel>> getFriends() async {
    final url = Uri.parse('$baseUrl/friends');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final list =
          (jsonDecode(response.body) as List<dynamic>?)
              ?.map((f) => FriendModel.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Get friends failed: ${response.body}');
    }
  }

  Future<void> removeFriend(String friendUserId) async {
    final url = Uri.parse('$baseUrl/friends/$friendUserId');
    final response = await http.delete(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Remove friend failed: ${response.body}');
    }
  }

  Future<void> blockUser(String blockedUserId, {String? reason}) async {
    final url = Uri.parse('$baseUrl/blocks');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'blocked_user_id': blockedUserId, 'reason': ?reason}),
    );
    if (response.statusCode != 201) {
      throw Exception('Block user failed: ${response.body}');
    }
  }

  Future<List<BlockedUserModel>> getBlockedUsers() async {
    final url = Uri.parse('$baseUrl/blocks');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final list =
          (jsonDecode(response.body) as List<dynamic>?)
              ?.map((b) => BlockedUserModel.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Get blocked users failed: ${response.body}');
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final url = Uri.parse('$baseUrl/blocks/$blockedUserId');
    final response = await http.delete(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Unblock user failed: ${response.body}');
    }
  }

  Future<void> submitReport({
    required String reportedUserId,
    required String category,
    String? description,
    String? matchId,
  }) async {
    final url = Uri.parse('$baseUrl/reports');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'reported_user_id': reportedUserId,
        'category': category,
        'description': ?description,
        'match_id': ?matchId,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Submit report failed: ${response.body}');
    }
  }

  Future<RoomInviteModel> inviteToRoom(
    String roomId,
    String recipientId,
  ) async {
    final url = Uri.parse('$baseUrl/rooms/$roomId/invite');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'recipient_id': recipientId}),
    );
    if (response.statusCode == 201) {
      return RoomInviteModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Invite to room failed: ${response.body}');
    }
  }

  Future<List<RoomInviteModel>> getMyRoomInvites() async {
    final url = Uri.parse('$baseUrl/rooms/invites/my-invites');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final list =
          (jsonDecode(response.body) as List<dynamic>?)
              ?.map((i) => RoomInviteModel.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Get room invites failed: ${response.body}');
    }
  }

  Future<void> respondToRoomInvite(String inviteId, bool accept) async {
    final url = Uri.parse(
      '$baseUrl/rooms/invites/$inviteId/respond?accept=$accept',
    );
    final response = await http.post(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Respond to invite failed: ${response.body}');
    }
  }

  // --- Economy & Progression Methods ---

  Future<DailyRewardStatusModel> getDailyRewardStatus() async {
    final url = Uri.parse('$baseUrl/economy/daily-reward');
    final response = await _authenticated(
      () => http.get(url, headers: _headers),
    );
    if (response.statusCode == 200) {
      return DailyRewardStatusModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception(
        _responseMessage(
          response,
          'Rewards are temporarily unavailable. Please retry.',
        ),
      );
    }
  }

  Future<ClaimDailyRewardModel> claimDailyReward() async {
    final url = Uri.parse('$baseUrl/economy/daily-reward/claim');
    final response = await _authenticated(
      () => http.post(url, headers: _headers),
    );
    if (response.statusCode == 200) {
      return ClaimDailyRewardModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception(
        _responseMessage(response, 'Could not claim rewards. Please retry.'),
      );
    }
  }

  Future<List<CatalogItemModel>> getCatalog() async {
    final url = Uri.parse('$baseUrl/economy/catalog');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final list =
          (jsonDecode(response.body) as List<dynamic>?)
              ?.map(
                (item) =>
                    CatalogItemModel.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Get catalog failed: ${response.body}');
    }
  }

  Future<void> purchaseStoreItem(
    String itemId, {
    String currency = 'COINS',
  }) async {
    final url = Uri.parse('$baseUrl/economy/purchase');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'item_id': itemId, 'currency': currency}),
    );
    if (response.statusCode != 200) {
      throw Exception('Purchase item failed: ${response.body}');
    }
  }

  Future<List<CatalogItemModel>> getInventory() async {
    final url = Uri.parse('$baseUrl/inventory');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final list =
          (jsonDecode(response.body) as List<dynamic>?)
              ?.map(
                (item) =>
                    CatalogItemModel.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Get inventory failed: ${response.body}');
    }
  }

  Future<void> equipCosmeticItem(String itemId) async {
    final url = Uri.parse('$baseUrl/inventory/equip');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'item_id': itemId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Equip item failed: ${response.body}');
    }
  }

  Future<List<MissionModel>> getMissions() async {
    final url = Uri.parse('$baseUrl/missions');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final list =
          (jsonDecode(response.body) as List<dynamic>?)
              ?.map((m) => MissionModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Get missions failed: ${response.body}');
    }
  }

  Future<ClaimMissionModel> claimMission(String missionId) async {
    final url = Uri.parse('$baseUrl/missions/$missionId/claim');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode == 200) {
      return ClaimMissionModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Claim mission failed: ${response.body}');
    }
  }

  Future<List<AchievementModel>> getAchievements() async {
    final url = Uri.parse('$baseUrl/achievements');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final list =
          (jsonDecode(response.body) as List<dynamic>?)
              ?.map((a) => AchievementModel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Get achievements failed: ${response.body}');
    }
  }

  Future<ClaimAchievementModel> claimAchievement(String achievementId) async {
    final url = Uri.parse('$baseUrl/achievements/$achievementId/claim');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode == 200) {
      return ClaimAchievementModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Claim achievement failed: ${response.body}');
    }
  }

  Future<http.Response> _authenticated(
    Future<http.Response> Function() request,
  ) async {
    var response = await request();
    if (response.statusCode == 401 && await restoreSession()) {
      response = await request();
    }
    return response;
  }

  Future<void> _rememberProfile(UserProfileModel profile) async {
    _isGuest = profile.isGuest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', profile.isGuest);
    await prefs.setString('display_name', profile.displayName);
    await prefs.setString('avatar_id', profile.avatarId);
  }

  Future<UserMeModel> getMyAccount() async {
    final response = await _authenticated(
      () => http.get(Uri.parse('$baseUrl/me'), headers: _headers),
    );
    if (response.statusCode != 200) {
      throw Exception(
        _responseMessage(response, 'Could not load your profile. Try again.'),
      );
    }
    final account = UserMeModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await _rememberProfile(account.profile);
    return account;
  }

  Future<Map<String, dynamic>> checkUsernameAvailability(
    String username,
  ) async {
    final url = Uri.parse('$baseUrl/me/username-availability')
        .replace(queryParameters: {'username': username});
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Could not check username availability.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<UserProfileModel> updateProfile({required String avatarId}) async {
    final response = await _authenticated(
      () => http.patch(
        Uri.parse('$baseUrl/me/profile'),
        headers: _headers,
        body: jsonEncode({'avatar_id': avatarId}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception(
        _responseMessage(response, 'Could not save your profile. Try again.'),
      );
    }
    final profile = UserProfileModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await _rememberProfile(profile);
    return profile;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _authenticated(
      () => http.patch(
        Uri.parse('$baseUrl/me/password'),
        headers: _headers,
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception(
        _responseMessage(
          response,
          'Could not update your password. Try again.',
        ),
      );
    }
  }

  Future<List<TournamentModel>> getTournaments() async {
    final url = Uri.parse('$baseUrl/tournaments');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final list =
          (jsonDecode(response.body) as List<dynamic>?)
              ?.map((t) => TournamentModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Get tournaments failed: ${response.body}');
    }
  }

  Future<TournamentDetailModel> getTournamentDetails(
    String tournamentId,
  ) async {
    final url = Uri.parse('$baseUrl/tournaments/$tournamentId');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return TournamentDetailModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Get tournament details failed: ${response.body}');
    }
  }

  Future<TournamentJoinModel> joinTournament(String tournamentId) async {
    final url = Uri.parse('$baseUrl/tournaments/$tournamentId/join');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode == 200) {
      return TournamentJoinModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Join tournament failed: ${response.body}');
    }
  }

  Future<SeasonDetailModel> getCurrentSeason() async {
    final url = Uri.parse('$baseUrl/seasons/current');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return SeasonDetailModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Get season failed: ${response.body}');
    }
  }

  Future<void> unlockPremiumPass() async {
    final url = Uri.parse('$baseUrl/seasons/premium-pass');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Unlock Royal Pass failed: ${response.body}');
    }
  }

  Future<ClaimSeasonRewardModel> claimSeasonReward(
    int tierNumber, {
    bool isPremium = false,
  }) async {
    final url = Uri.parse('$baseUrl/seasons/claim');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'tier_number': tierNumber, 'is_premium': isPremium}),
    );
    if (response.statusCode == 200) {
      return ClaimSeasonRewardModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Claim season reward failed: ${response.body}');
    }
  }

  Future<LeaderboardModel> getLeaderboard({
    String scope = 'ALL_TIME',
    int limit = 50,
    int offset = 0,
  }) async {
    final url = Uri.parse(
      '$baseUrl/leaderboards?scope=$scope&limit=$limit&offset=$offset',
    );
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return LeaderboardModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Get leaderboard failed: ${response.body}');
    }
  }

  Future<MyLeaderboardRankModel> getMyLeaderboardRank({
    String scope = 'ALL_TIME',
  }) async {
    final url = Uri.parse('$baseUrl/leaderboards/my-rank?scope=$scope');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return MyLeaderboardRankModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Get my rank failed: ${response.body}');
    }
  }

  Future<List<IapProductModel>> getIapProducts() async {
    final url = Uri.parse('$baseUrl/purchases/products');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final list = (jsonDecode(response.body) as List<dynamic>)
          .map((e) => IapProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } else {
      throw Exception('Get IAP products failed: ${response.body}');
    }
  }

  Future<IapOrderModel> createIapOrder({
    required String productId,
    String platform = 'ANDROID',
  }) async {
    final url = Uri.parse('$baseUrl/purchases/create-order');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'product_id': productId, 'platform': platform}),
    );
    if (response.statusCode == 200) {
      return IapOrderModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Create IAP order failed: ${response.body}');
    }
  }

  Future<VerifyReceiptResultModel> verifyIapReceipt({
    required String productId,
    required String transactionId,
    required String rawReceipt,
    String platform = 'ANDROID',
    String? orderId,
  }) async {
    final url = Uri.parse('$baseUrl/purchases/verify-receipt');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'product_id': productId,
        'transaction_id': transactionId,
        'raw_receipt': rawReceipt,
        'platform': platform,
        'order_id': orderId,
      }),
    );
    if (response.statusCode == 200) {
      return VerifyReceiptResultModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Verify receipt failed: ${response.body}');
    }
  }

  Future<List<NotificationItemModel>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final url = Uri.parse('$baseUrl/notifications?limit=$limit&offset=$offset');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>)
          .map((e) => NotificationItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Get notifications failed: ${response.body}');
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final url = Uri.parse('$baseUrl/notifications/$notificationId/read');
    await http.post(url, headers: _headers);
  }

  Future<void> markAllNotificationsRead() async {
    final url = Uri.parse('$baseUrl/notifications/read-all');
    await http.post(url, headers: _headers);
  }

  Future<VersionCheckModel> checkAppVersion({
    String platform = 'ANDROID',
    String appVersion = '1.0.1',
  }) async {
    final url = Uri.parse(
      '$baseUrl/config/version-check?platform=$platform&app_version=$appVersion',
    );
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return VersionCheckModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Version check failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> exportMyData() async {
    final url = Uri.parse('$baseUrl/auth/export-data');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Export data failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> deleteMyAccount() async {
    final url = Uri.parse('$baseUrl/auth/delete-account');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode == 200) {
      await logout();
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Delete account failed: ${response.body}');
    }
  }

  Future<ClubModel> createClub({
    required String name,
    required String tag,
    String description = 'Welcome to our club!',
    String badgeIcon = 'shield_gold',
    int minLevel = 1,
    bool isOpen = true,
  }) async {
    final url = Uri.parse('$baseUrl/clubs');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'name': name.trim(),
        'tag': tag.trim().toUpperCase(),
        'description': description.trim(),
        'badge_icon': badgeIcon,
        'min_level': minLevel,
        'is_open': isOpen,
      }),
    );
    if (response.statusCode == 201) {
      return ClubModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Create club failed: ${response.body}');
    }
  }

  Future<List<ClubModel>> getClubs({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParam = query != null && query.isNotEmpty
        ? '&query=${Uri.encodeComponent(query)}'
        : '';
    final url = Uri.parse(
      '$baseUrl/clubs?limit=$limit&offset=$offset$queryParam',
    );
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>)
          .map((e) => ClubModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Get clubs failed: ${response.body}');
    }
  }

  Future<ClubDetailModel?> getMyClub() async {
    final url = Uri.parse('$baseUrl/clubs/my-club');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded == null) return null;
      return ClubDetailModel.fromJson(decoded as Map<String, dynamic>);
    } else {
      throw Exception('Get my club failed: ${response.body}');
    }
  }

  Future<ClubDetailModel> getClubDetails(String clubId) async {
    final url = Uri.parse('$baseUrl/clubs/$clubId');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return ClubDetailModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Get club details failed: ${response.body}');
    }
  }

  Future<ClubDetailModel> joinClub(String clubId) async {
    final url = Uri.parse('$baseUrl/clubs/$clubId/join');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode == 200) {
      return ClubDetailModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Join club failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> leaveClub(String clubId) async {
    final url = Uri.parse('$baseUrl/clubs/$clubId/leave');
    final response = await http.post(url, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Leave club failed: ${response.body}');
    }
  }

  Future<VoiceTokenModel> getVoiceToken({
    required String roomId,
    bool enableMic = true,
    bool privacyConsent = true,
  }) async {
    final url = Uri.parse('$baseUrl/rooms/$roomId/voice/token');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'enable_mic': enableMic,
        'privacy_consent': privacyConsent,
      }),
    );
    if (response.statusCode == 200) {
      return VoiceTokenModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Get voice token failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> setVoiceMute({
    required String roomId,
    String? targetUserId,
    required bool isMuted,
  }) async {
    final url = Uri.parse('$baseUrl/rooms/$roomId/voice/mute');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'target_user_id': ?targetUserId, 'is_muted': isMuted}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Set voice mute failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> reportVoiceAbuse({
    required String roomId,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    final url = Uri.parse('$baseUrl/rooms/$roomId/voice/report');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'reported_user_id': reportedUserId,
        'reason': reason,
        'details': ?details,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Report voice abuse failed: ${response.body}');
    }
  }
}

class VersionCheckModel {
  final bool upgradeRequired;
  final bool maintenanceMode;
  final String latestVersion;
  final String minVersion;
  final String? message;

  VersionCheckModel({
    required this.upgradeRequired,
    required this.maintenanceMode,
    required this.latestVersion,
    required this.minVersion,
    this.message,
  });

  factory VersionCheckModel.fromJson(Map<String, dynamic> json) {
    return VersionCheckModel(
      upgradeRequired: json['upgrade_required'] as bool? ?? false,
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      latestVersion: json['latest_version'] as String? ?? '1.0.0',
      minVersion: json['min_version'] as String? ?? '1.0.0',
      message: json['message'] as String?,
    );
  }
}

class MatchmakingTicketModel {
  final String ticketId;
  final String status;
  final String? matchedMatchId;
  final int playerCount;
  final int rating;
  final int queueTimeSeconds;

  MatchmakingTicketModel({
    required this.ticketId,
    required this.status,
    this.matchedMatchId,
    required this.playerCount,
    required this.rating,
    required this.queueTimeSeconds,
  });

  factory MatchmakingTicketModel.fromJson(Map<String, dynamic> json) {
    return MatchmakingTicketModel(
      ticketId: json['ticket_id'] as String,
      status: json['status'] as String,
      matchedMatchId: json['matched_match_id'] as String?,
      playerCount: json['player_count'] as int? ?? 4,
      rating: json['rating'] as int? ?? 1000,
      queueTimeSeconds: json['queue_time_seconds'] as int? ?? 0,
    );
  }
}

class MatchPlayerHistoryModel {
  final String? userId;
  final int seatIndex;
  final String displayName;
  final String avatarId;
  final String color;
  final int? placement;
  final bool isBot;

  MatchPlayerHistoryModel({
    this.userId,
    required this.seatIndex,
    required this.displayName,
    required this.avatarId,
    required this.color,
    this.placement,
    required this.isBot,
  });

  factory MatchPlayerHistoryModel.fromJson(Map<String, dynamic> json) {
    return MatchPlayerHistoryModel(
      userId: json['user_id'] as String?,
      seatIndex: json['seat_index'] as int,
      displayName: json['display_name'] as String? ?? 'Player',
      avatarId: json['avatar_id'] as String? ?? 'avatar_0',
      color: json['color'] as String? ?? 'RED',
      placement: json['placement'] as int?,
      isBot: json['is_bot'] as bool? ?? false,
    );
  }
}

class MatchHistoryModel {
  final String id;
  final String mode;
  final String status;
  final int? myPlacement;
  final String myColor;
  final int coinsDelta;
  final int xpGained;
  final String startedAt;
  final String? finishedAt;
  final List<MatchPlayerHistoryModel> players;

  MatchHistoryModel({
    required this.id,
    required this.mode,
    required this.status,
    this.myPlacement,
    required this.myColor,
    required this.coinsDelta,
    required this.xpGained,
    required this.startedAt,
    this.finishedAt,
    required this.players,
  });

  factory MatchHistoryModel.fromJson(Map<String, dynamic> json) {
    final playerList =
        (json['players'] as List<dynamic>?)
            ?.map(
              (p) =>
                  MatchPlayerHistoryModel.fromJson(p as Map<String, dynamic>),
            )
            .toList() ??
        [];
    return MatchHistoryModel(
      id: json['id'] as String,
      mode: json['mode'] as String? ?? 'CLASSIC',
      status: json['status'] as String? ?? 'ACTIVE',
      myPlacement: json['my_placement'] as int?,
      myColor: json['my_color'] as String? ?? 'RED',
      coinsDelta: json['coins_delta'] as int? ?? 0,
      xpGained: json['xp_gained'] as int? ?? 0,
      startedAt: json['started_at'] as String? ?? '',
      finishedAt: json['finished_at'] as String?,
      players: playerList,
    );
  }
}

class RecentPlayerModel {
  final String userId;
  final String playerId;
  final String? username;
  final String displayName;
  final String avatarId;
  final int level;
  final String countryCode;

  RecentPlayerModel({
    required this.userId,
    required this.playerId,
    this.username,
    required this.displayName,
    required this.avatarId,
    required this.level,
    required this.countryCode,
  });

  factory RecentPlayerModel.fromJson(Map<String, dynamic> json) {
    return RecentPlayerModel(
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      playerId: json['player_id'] as String? ?? 'LM-00000',
      displayName: json['display_name'] as String? ?? 'Player',
      avatarId: json['avatar_id'] as String? ?? 'avatar_0',
      level: json['level'] as int? ?? 1,
      countryCode: json['country_code'] as String? ?? 'GLB',
    );
  }
}

class FriendModel {
  final String userId;
  final String playerId;
  final String? username;
  final String displayName;
  final String avatarId;
  final int level;
  final String countryCode;
  final bool isOnline;

  FriendModel({
    required this.userId,
    required this.playerId,
    this.username,
    required this.displayName,
    required this.avatarId,
    required this.level,
    required this.countryCode,
    this.isOnline = true,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      playerId: json['player_id'] as String? ?? 'LM-00000',
      displayName: json['display_name'] as String? ?? 'Friend',
      avatarId: json['avatar_id'] as String? ?? 'avatar_0',
      level: json['level'] as int? ?? 1,
      countryCode: json['country_code'] as String? ?? 'GLB',
      isOnline: json['is_online'] as bool? ?? true,
    );
  }
}

class FriendRequestModel {
  final String id;
  final String userId;
  final String displayName;
  final String avatarId;
  final String playerId;
  final String? username;
  final String createdAt;

  FriendRequestModel({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.avatarId,
    required this.playerId,
    this.username,
    required this.createdAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] as String,
      userId: (json['user_id'] ?? json['friend_user_id']) as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Player',
      avatarId: json['avatar_id'] as String? ?? 'avatar_0',
      username: json['username'] as String?,
      playerId: json['player_id'] as String? ?? 'LM-00000',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class BlockedUserModel {
  final String id;
  final String blockedId;
  final String blockedDisplayName;
  final String createdAt;

  BlockedUserModel({
    required this.id,
    required this.blockedId,
    required this.blockedDisplayName,
    required this.createdAt,
  });

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    return BlockedUserModel(
      id: json['id'] as String,
      blockedId: json['blocked_id'] as String,
      blockedDisplayName: json['blocked_display_name'] as String? ?? 'Player',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class RoomInviteModel {
  final String id;
  final String roomId;
  final String? roomCode;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String status;
  final String createdAt;

  RoomInviteModel({
    required this.id,
    required this.roomId,
    this.roomCode,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.status,
    required this.createdAt,
  });

  factory RoomInviteModel.fromJson(Map<String, dynamic> json) {
    return RoomInviteModel(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      roomCode: json['room_code'] as String?,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? 'Friend',
      recipientId: json['recipient_id'] as String,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class DailyRewardDayModel {
  final int day;
  final int coins;
  final int gems;
  final int xp;
  final bool isClaimed;
  final bool isToday;

  DailyRewardDayModel({
    required this.day,
    required this.coins,
    required this.gems,
    required this.xp,
    required this.isClaimed,
    required this.isToday,
  });

  factory DailyRewardDayModel.fromJson(Map<String, dynamic> json) {
    return DailyRewardDayModel(
      day: json['day'] as int,
      coins: json['coins'] as int,
      gems: json['gems'] as int,
      xp: json['xp'] as int,
      isClaimed: json['is_claimed'] as bool? ?? false,
      isToday: json['is_today'] as bool? ?? false,
    );
  }
}

class DailyRewardStatusModel {
  final int currentStreak;
  final bool canClaim;
  final String? lastClaimDate;
  final List<DailyRewardDayModel> days;

  DailyRewardStatusModel({
    required this.currentStreak,
    required this.canClaim,
    this.lastClaimDate,
    required this.days,
  });

  factory DailyRewardStatusModel.fromJson(Map<String, dynamic> json) {
    return DailyRewardStatusModel(
      currentStreak: json['current_streak'] as int? ?? 0,
      canClaim: json['can_claim'] as bool? ?? false,
      lastClaimDate: json['last_claim_date'] as String?,
      days:
          (json['days'] as List<dynamic>?)
              ?.map(
                (d) => DailyRewardDayModel.fromJson(d as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

class ClaimDailyRewardModel {
  final String message;
  final int day;
  final int coinsAwarded;
  final int gemsAwarded;
  final int xpAwarded;
  final int newBalanceCoins;
  final int newBalanceGems;
  final int newLevel;
  final int newXp;

  ClaimDailyRewardModel({
    required this.message,
    required this.day,
    required this.coinsAwarded,
    required this.gemsAwarded,
    required this.xpAwarded,
    required this.newBalanceCoins,
    required this.newBalanceGems,
    required this.newLevel,
    required this.newXp,
  });

  factory ClaimDailyRewardModel.fromJson(Map<String, dynamic> json) {
    return ClaimDailyRewardModel(
      message: json['message'] as String? ?? 'Reward claimed!',
      day: json['day'] as int? ?? 1,
      coinsAwarded: json['coins_awarded'] as int? ?? 0,
      gemsAwarded: json['gems_awarded'] as int? ?? 0,
      xpAwarded: json['xp_awarded'] as int? ?? 0,
      newBalanceCoins: json['new_balance_coins'] as int? ?? 0,
      newBalanceGems: json['new_balance_gems'] as int? ?? 0,
      newLevel: json['new_level'] as int? ?? 1,
      newXp: json['new_xp'] as int? ?? 0,
    );
  }
}

class MissionModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String actionType;
  final int currentCount;
  final int targetCount;
  final int rewardCoins;
  final int rewardGems;
  final int rewardXp;
  final String icon;
  final bool isCompleted;
  final bool isClaimed;

  MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.actionType,
    required this.currentCount,
    required this.targetCount,
    required this.rewardCoins,
    required this.rewardGems,
    required this.rewardXp,
    required this.icon,
    required this.isCompleted,
    required this.isClaimed,
  });

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    return MissionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String? ?? 'DAILY',
      actionType: json['action_type'] as String? ?? 'MATCH_PLAY',
      currentCount: json['current_count'] as int? ?? 0,
      targetCount: json['target_count'] as int? ?? 1,
      rewardCoins: json['reward_coins'] as int? ?? 0,
      rewardGems: json['reward_gems'] as int? ?? 0,
      rewardXp: json['reward_xp'] as int? ?? 0,
      icon: json['icon'] as String? ?? 'sports_esports',
      isCompleted: json['is_completed'] as bool? ?? false,
      isClaimed: json['is_claimed'] as bool? ?? false,
    );
  }
}

class ClaimMissionModel {
  final String missionId;
  final int coinsAwarded;
  final int gemsAwarded;
  final int xpAwarded;
  final int newBalanceCoins;
  final int newBalanceGems;
  final int newLevel;
  final int newXp;

  ClaimMissionModel({
    required this.missionId,
    required this.coinsAwarded,
    required this.gemsAwarded,
    required this.xpAwarded,
    required this.newBalanceCoins,
    required this.newBalanceGems,
    required this.newLevel,
    required this.newXp,
  });

  factory ClaimMissionModel.fromJson(Map<String, dynamic> json) {
    return ClaimMissionModel(
      missionId: json['mission_id'] as String,
      coinsAwarded: json['coins_awarded'] as int? ?? 0,
      gemsAwarded: json['gems_awarded'] as int? ?? 0,
      xpAwarded: json['xp_awarded'] as int? ?? 0,
      newBalanceCoins: json['new_balance_coins'] as int? ?? 0,
      newBalanceGems: json['new_balance_gems'] as int? ?? 0,
      newLevel: json['new_level'] as int? ?? 1,
      newXp: json['new_xp'] as int? ?? 0,
    );
  }
}

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final String actionType;
  final int currentCount;
  final int targetCount;
  final int rewardCoins;
  final int rewardGems;
  final int rewardXp;
  final String badgeKey;
  final bool isUnlocked;
  final bool isClaimed;

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.actionType,
    required this.currentCount,
    required this.targetCount,
    required this.rewardCoins,
    required this.rewardGems,
    required this.rewardXp,
    required this.badgeKey,
    required this.isUnlocked,
    required this.isClaimed,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      actionType: json['action_type'] as String? ?? 'MATCH_WIN',
      currentCount: json['current_count'] as int? ?? 0,
      targetCount: json['target_count'] as int? ?? 1,
      rewardCoins: json['reward_coins'] as int? ?? 0,
      rewardGems: json['reward_gems'] as int? ?? 0,
      rewardXp: json['reward_xp'] as int? ?? 0,
      badgeKey: json['badge_key'] as String? ?? 'badge_bronze',
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      isClaimed: json['is_claimed'] as bool? ?? false,
    );
  }
}

class ClaimAchievementModel {
  final String achievementId;
  final int coinsAwarded;
  final int gemsAwarded;
  final int xpAwarded;
  final int newBalanceCoins;
  final int newBalanceGems;
  final int newLevel;
  final int newXp;

  ClaimAchievementModel({
    required this.achievementId,
    required this.coinsAwarded,
    required this.gemsAwarded,
    required this.xpAwarded,
    required this.newBalanceCoins,
    required this.newBalanceGems,
    required this.newLevel,
    required this.newXp,
  });

  factory ClaimAchievementModel.fromJson(Map<String, dynamic> json) {
    return ClaimAchievementModel(
      achievementId: json['achievement_id'] as String,
      coinsAwarded: json['coins_awarded'] as int? ?? 0,
      gemsAwarded: json['gems_awarded'] as int? ?? 0,
      xpAwarded: json['xp_awarded'] as int? ?? 0,
      newBalanceCoins: json['new_balance_coins'] as int? ?? 0,
      newBalanceGems: json['new_balance_gems'] as int? ?? 0,
      newLevel: json['new_level'] as int? ?? 1,
      newXp: json['new_xp'] as int? ?? 0,
    );
  }
}

class CatalogItemModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final String rarity;
  final int priceCoins;
  final int priceGems;
  final String assetKey;
  final bool isDefault;
  final bool isOwned;
  final bool isEquipped;

  CatalogItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.rarity,
    required this.priceCoins,
    required this.priceGems,
    required this.assetKey,
    required this.isDefault,
    required this.isOwned,
    required this.isEquipped,
  });

  factory CatalogItemModel.fromJson(Map<String, dynamic> json) {
    return CatalogItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String? ?? '',
      rarity: json['rarity'] as String? ?? 'COMMON',
      priceCoins: json['price_coins'] as int? ?? 0,
      priceGems: json['price_gems'] as int? ?? 0,
      assetKey: json['asset_key'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
      isOwned: json['is_owned'] as bool? ?? false,
      isEquipped: json['is_equipped'] as bool? ?? false,
    );
  }
}

class UserProfileModel {
  final String userId;
  final String playerId;
  final String? username;
  final String displayName;
  final String avatarId;
  final int level;
  final int xp;
  final String countryCode;
  final bool isGuest;
  final bool isVerified;

  UserProfileModel({
    required this.userId,
    required this.playerId,
    this.username,
    required this.displayName,
    required this.avatarId,
    required this.level,
    required this.xp,
    required this.countryCode,
    required this.isGuest,
    required this.isVerified,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String?,
      playerId: json['player_id'] as String? ?? 'LM-00000',
      displayName: json['display_name'] as String? ?? 'Player',
      avatarId: json['avatar_id'] as String? ?? 'avatar_0',
      level: json['level'] as int? ?? 1,
      xp: json['xp'] as int? ?? 0,
      countryCode: json['country_code'] as String? ?? 'GLB',
      isGuest: json['is_guest'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

class UserStatsModel {
  final String userId;
  final int matchesPlayed;
  final int matchesWon;
  final double winRatePercent;
  final int winStreak;
  final int bestStreak;
  final int totalCaptures;
  final int totalTokensHome;

  UserStatsModel({
    required this.userId,
    required this.matchesPlayed,
    required this.matchesWon,
    required this.winRatePercent,
    required this.winStreak,
    required this.bestStreak,
    required this.totalCaptures,
    required this.totalTokensHome,
  });

  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      userId: json['user_id'] as String? ?? '',
      matchesPlayed: json['matches_played'] as int? ?? 0,
      matchesWon: json['matches_won'] as int? ?? 0,
      winRatePercent: (json['win_rate_percent'] as num?)?.toDouble() ?? 0.0,
      winStreak: json['win_streak'] as int? ?? 0,
      bestStreak: json['best_streak'] as int? ?? 0,
      totalCaptures: json['total_captures'] as int? ?? 0,
      totalTokensHome: json['total_tokens_home'] as int? ?? 0,
    );
  }
}

class UserWalletModel {
  final String userId;
  final int coins;
  final int gems;

  UserWalletModel({
    required this.userId,
    required this.coins,
    required this.gems,
  });

  factory UserWalletModel.fromJson(Map<String, dynamic> json) {
    return UserWalletModel(
      userId: json['user_id'] as String? ?? '',
      coins: json['coins'] as int? ?? 0,
      gems: json['gems'] as int? ?? 0,
    );
  }
}

class UserMeModel {
  final String id;
  final bool isGuest;
  final bool isVerified;
  final UserProfileModel profile;
  final UserStatsModel stats;
  final UserWalletModel wallet;

  UserMeModel({
    required this.id,
    required this.isGuest,
    required this.isVerified,
    required this.profile,
    required this.stats,
    required this.wallet,
  });

  factory UserMeModel.fromJson(Map<String, dynamic> json) {
    return UserMeModel(
      id: json['id'] as String,
      isGuest: json['is_guest'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      profile: UserProfileModel.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
      stats: UserStatsModel.fromJson(json['stats'] as Map<String, dynamic>),
      wallet: UserWalletModel.fromJson(json['wallet'] as Map<String, dynamic>),
    );
  }
}

class TournamentModel {
  final String id;
  final String title;
  final String description;
  final int entryFeeCoins;
  final int prizePoolCoins;
  final int prizePoolGems;
  final int maxParticipants;
  final int currentParticipants;
  final String status;
  final String? winnerUserId;
  final bool isJoined;

  TournamentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.entryFeeCoins,
    required this.prizePoolCoins,
    required this.prizePoolGems,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.status,
    this.winnerUserId,
    required this.isJoined,
  });

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    return TournamentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      entryFeeCoins: json['entry_fee_coins'] as int? ?? 0,
      prizePoolCoins: json['prize_pool_coins'] as int? ?? 0,
      prizePoolGems: json['prize_pool_gems'] as int? ?? 0,
      maxParticipants: json['max_participants'] as int? ?? 8,
      currentParticipants: json['current_participants'] as int? ?? 0,
      status: json['status'] as String? ?? 'REGISTRATION',
      winnerUserId: json['winner_user_id'] as String?,
      isJoined: json['is_joined'] as bool? ?? false,
    );
  }
}

class TournamentParticipantModel {
  final String id;
  final String userId;
  final String displayName;
  final String avatarId;
  final int seed;
  final int? placement;
  final int prizeCoins;
  final int prizeGems;
  final int? eliminatedRound;

  TournamentParticipantModel({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.avatarId,
    required this.seed,
    this.placement,
    required this.prizeCoins,
    required this.prizeGems,
    this.eliminatedRound,
  });

  factory TournamentParticipantModel.fromJson(Map<String, dynamic> json) {
    return TournamentParticipantModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? 'Player',
      avatarId: json['avatar_id'] as String? ?? 'avatar_0',
      seed: json['seed'] as int? ?? 1,
      placement: json['placement'] as int?,
      prizeCoins: json['prize_coins'] as int? ?? 0,
      prizeGems: json['prize_gems'] as int? ?? 0,
      eliminatedRound: json['eliminated_round'] as int?,
    );
  }
}

class TournamentMatchModel {
  final String id;
  final int roundNumber;
  final int matchIndex;
  final String status;
  final String? matchId;
  final List<String> participantIds;
  final List<String> winnerIds;

  TournamentMatchModel({
    required this.id,
    required this.roundNumber,
    required this.matchIndex,
    required this.status,
    this.matchId,
    required this.participantIds,
    required this.winnerIds,
  });

  factory TournamentMatchModel.fromJson(Map<String, dynamic> json) {
    return TournamentMatchModel(
      id: json['id'] as String,
      roundNumber: json['round_number'] as int? ?? 1,
      matchIndex: json['match_index'] as int? ?? 0,
      status: json['status'] as String? ?? 'PENDING',
      matchId: json['match_id'] as String?,
      participantIds:
          (json['participant_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      winnerIds:
          (json['winner_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class TournamentDetailModel {
  final TournamentModel tournament;
  final List<TournamentParticipantModel> participants;
  final List<TournamentMatchModel> matches;

  TournamentDetailModel({
    required this.tournament,
    required this.participants,
    required this.matches,
  });

  factory TournamentDetailModel.fromJson(Map<String, dynamic> json) {
    return TournamentDetailModel(
      tournament: TournamentModel.fromJson(
        json['tournament'] as Map<String, dynamic>,
      ),
      participants:
          (json['participants'] as List<dynamic>?)
              ?.map(
                (p) => TournamentParticipantModel.fromJson(
                  p as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      matches:
          (json['matches'] as List<dynamic>?)
              ?.map(
                (m) => TournamentMatchModel.fromJson(m as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

class TournamentJoinModel {
  final String message;
  final String tournamentId;
  final int currentParticipants;
  final String status;
  final int seed;

  TournamentJoinModel({
    required this.message,
    required this.tournamentId,
    required this.currentParticipants,
    required this.status,
    required this.seed,
  });

  factory TournamentJoinModel.fromJson(Map<String, dynamic> json) {
    return TournamentJoinModel(
      message: json['message'] as String? ?? '',
      tournamentId: json['tournament_id'] as String,
      currentParticipants: json['current_participants'] as int? ?? 1,
      status: json['status'] as String? ?? 'REGISTRATION',
      seed: json['seed'] as int? ?? 1,
    );
  }
}

class SeasonTierModel {
  final String id;
  final int tierNumber;
  final int xpRequired;
  final int freeRewardCoins;
  final int freeRewardGems;
  final String? freeRewardItemId;
  final String? freeRewardItemName;
  final int premiumRewardCoins;
  final int premiumRewardGems;
  final String? premiumRewardItemId;
  final String? premiumRewardItemName;
  final bool isUnlocked;
  final bool isFreeClaimed;
  final bool isPremiumClaimed;

  SeasonTierModel({
    required this.id,
    required this.tierNumber,
    required this.xpRequired,
    required this.freeRewardCoins,
    required this.freeRewardGems,
    this.freeRewardItemId,
    this.freeRewardItemName,
    required this.premiumRewardCoins,
    required this.premiumRewardGems,
    this.premiumRewardItemId,
    this.premiumRewardItemName,
    required this.isUnlocked,
    required this.isFreeClaimed,
    required this.isPremiumClaimed,
  });

  factory SeasonTierModel.fromJson(Map<String, dynamic> json) {
    return SeasonTierModel(
      id: json['id'] as String,
      tierNumber: json['tier_number'] as int,
      xpRequired: json['xp_required'] as int,
      freeRewardCoins: json['free_reward_coins'] as int? ?? 0,
      freeRewardGems: json['free_reward_gems'] as int? ?? 0,
      freeRewardItemId: json['free_reward_item_id'] as String?,
      freeRewardItemName: json['free_reward_item_name'] as String?,
      premiumRewardCoins: json['premium_reward_coins'] as int? ?? 0,
      premiumRewardGems: json['premium_reward_gems'] as int? ?? 0,
      premiumRewardItemId: json['premium_reward_item_id'] as String?,
      premiumRewardItemName: json['premium_reward_item_name'] as String?,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      isFreeClaimed: json['is_free_claimed'] as bool? ?? false,
      isPremiumClaimed: json['is_premium_claimed'] as bool? ?? false,
    );
  }
}

class SeasonDetailModel {
  final String id;
  final int seasonNumber;
  final String title;
  final String themeName;
  final String startsAt;
  final String endsAt;
  final bool isActive;
  final int currentXp;
  final int currentTier;
  final bool hasPremiumPass;
  final int premiumPassCostGems;
  final List<SeasonTierModel> tiers;

  SeasonDetailModel({
    required this.id,
    required this.seasonNumber,
    required this.title,
    required this.themeName,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    required this.currentXp,
    required this.currentTier,
    required this.hasPremiumPass,
    this.premiumPassCostGems = 100,
    required this.tiers,
  });

  factory SeasonDetailModel.fromJson(Map<String, dynamic> json) {
    return SeasonDetailModel(
      id: json['id'] as String,
      seasonNumber: json['season_number'] as int? ?? 1,
      title: json['title'] as String? ?? 'Season 1',
      themeName: json['theme_name'] as String? ?? 'Classic',
      startsAt: json['starts_at'] as String? ?? '',
      endsAt: json['ends_at'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      currentXp: json['current_xp'] as int? ?? 0,
      currentTier: json['current_tier'] as int? ?? 1,
      hasPremiumPass: json['has_premium_pass'] as bool? ?? false,
      premiumPassCostGems: json['premium_pass_cost_gems'] as int? ?? 100,
      tiers:
          (json['tiers'] as List<dynamic>?)
              ?.map((t) => SeasonTierModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ClaimSeasonRewardModel {
  final int tierNumber;
  final int coinsAwarded;
  final int gemsAwarded;
  final String? itemAwarded;
  final int newBalanceCoins;
  final int newBalanceGems;

  ClaimSeasonRewardModel({
    required this.tierNumber,
    required this.coinsAwarded,
    required this.gemsAwarded,
    this.itemAwarded,
    required this.newBalanceCoins,
    required this.newBalanceGems,
  });

  factory ClaimSeasonRewardModel.fromJson(Map<String, dynamic> json) {
    return ClaimSeasonRewardModel(
      tierNumber: json['tier_number'] as int,
      coinsAwarded: json['coins_awarded'] as int? ?? 0,
      gemsAwarded: json['gems_awarded'] as int? ?? 0,
      itemAwarded: json['item_awarded'] as String?,
      newBalanceCoins: json['new_balance_coins'] as int? ?? 0,
      newBalanceGems: json['new_balance_gems'] as int? ?? 0,
    );
  }
}

class LeaderboardEntryModel {
  final int rank;
  final String userId;
  final String playerId;
  final String displayName;
  final String avatarId;
  final String countryCode;
  final int level;
  final int score;
  final int matchesPlayed;
  final int matchesWon;
  final double winRate;

  LeaderboardEntryModel({
    required this.rank,
    required this.userId,
    required this.playerId,
    required this.displayName,
    required this.avatarId,
    required this.countryCode,
    required this.level,
    required this.score,
    required this.matchesPlayed,
    required this.matchesWon,
    required this.winRate,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      rank: json['rank'] as int? ?? 1,
      userId: json['user_id'] as String? ?? '',
      playerId: json['player_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Player',
      avatarId: json['avatar_id'] as String? ?? 'avatar_0',
      countryCode: json['country_code'] as String? ?? 'IN',
      level: json['level'] as int? ?? 1,
      score: json['score'] as int? ?? 0,
      matchesPlayed: json['matches_played'] as int? ?? 0,
      matchesWon: json['matches_won'] as int? ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LeaderboardModel {
  final String scope;
  final int totalPlayers;
  final List<LeaderboardEntryModel> entries;

  LeaderboardModel({
    required this.scope,
    required this.totalPlayers,
    required this.entries,
  });

  factory LeaderboardModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardModel(
      scope: json['scope'] as String? ?? 'ALL_TIME',
      totalPlayers: json['total_players'] as int? ?? 0,
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map(
                (e) =>
                    LeaderboardEntryModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

class MyLeaderboardRankModel {
  final String scope;
  final int rank;
  final int score;
  final int matchesPlayed;
  final int matchesWon;

  MyLeaderboardRankModel({
    required this.scope,
    required this.rank,
    required this.score,
    required this.matchesPlayed,
    required this.matchesWon,
  });

  factory MyLeaderboardRankModel.fromJson(Map<String, dynamic> json) {
    return MyLeaderboardRankModel(
      scope: json['scope'] as String? ?? 'ALL_TIME',
      rank: json['rank'] as int? ?? 999,
      score: json['score'] as int? ?? 0,
      matchesPlayed: json['matches_played'] as int? ?? 0,
      matchesWon: json['matches_won'] as int? ?? 0,
    );
  }
}

class IapProductModel {
  final String id;
  final String name;
  final String description;
  final int priceCents;
  final String currencyCode;
  final int coins;
  final int gems;
  final String? badge;
  final String icon;
  final String? itemId;
  final bool consumable;

  IapProductModel({
    String? id,
    String? productId,
    String? name,
    String? title,
    this.description = '',
    int? priceCents,
    double? price,
    String? currencyCode,
    String? currency,
    int? coins,
    int? grantCoins,
    int? gems,
    int? grantGems,
    this.badge,
    this.icon = 'coins',
    this.itemId,
    this.consumable = true,
  }) : id = id ?? productId ?? '',
       name = name ?? title ?? '',
       priceCents = priceCents ?? (price != null ? (price * 100).round() : 0),
       currencyCode = currencyCode ?? currency ?? 'USD',
       coins = coins ?? grantCoins ?? 0,
       gems = gems ?? grantGems ?? 0;

  String get productId => id;
  String get title => name;
  double get price => priceCents / 100.0;
  String get currency => currencyCode;
  int get grantCoins => coins;
  int get grantGems => gems;

  factory IapProductModel.fromJson(Map<String, dynamic> json) {
    return IapProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      priceCents: json['price_cents'] as int? ?? 0,
      currencyCode: json['currency_code'] as String? ?? 'USD',
      coins: json['coins'] as int? ?? 0,
      gems: json['gems'] as int? ?? 0,
      badge: json['badge'] as String?,
      icon: json['icon'] as String? ?? 'coins',
      itemId: json['item_id'] as String?,
      consumable: json['consumable'] as bool? ?? true,
    );
  }
}

class IapOrderModel {
  final String orderId;
  final String productId;
  final String platform;
  final int priceCents;
  final String currencyCode;
  final String status;
  final String createdAt;

  IapOrderModel({
    required this.orderId,
    required this.productId,
    required this.platform,
    int? priceCents,
    double? price,
    String? currencyCode,
    String? currency,
    required this.status,
    this.createdAt = '',
  }) : priceCents = priceCents ?? (price != null ? (price * 100).round() : 0),
       currencyCode = currencyCode ?? currency ?? 'USD';

  double get price => priceCents / 100.0;
  String get currency => currencyCode;

  factory IapOrderModel.fromJson(Map<String, dynamic> json) {
    return IapOrderModel(
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      platform: json['platform'] as String,
      priceCents: json['price_cents'] as int? ?? 0,
      currencyCode: json['currency_code'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class VerifyReceiptResultModel {
  final String status;
  final String transactionId;
  final String productId;
  final int grantedCoins;
  final int grantedGems;
  final int newCoinsBalance;
  final int newGemsBalance;
  final String message;

  VerifyReceiptResultModel({
    required this.status,
    String? transactionId,
    String? orderId,
    String? productId,
    int? grantedCoins,
    int? grantedGems,
    int? newCoinsBalance,
    int? newGemsBalance,
    Map<String, dynamic>? walletBalance,
    String? message,
  }) : transactionId = transactionId ?? orderId ?? '',
       productId = productId ?? '',
       grantedCoins = grantedCoins ?? 0,
       grantedGems = grantedGems ?? 0,
       newCoinsBalance =
           newCoinsBalance ?? (walletBalance?['coins'] as int? ?? 0),
       newGemsBalance = newGemsBalance ?? (walletBalance?['gems'] as int? ?? 0),
       message = message ?? '';

  Map<String, int> get walletBalance => {
    'coins': newCoinsBalance,
    'gems': newGemsBalance,
  };
  String get orderId => transactionId;

  factory VerifyReceiptResultModel.fromJson(Map<String, dynamic> json) {
    return VerifyReceiptResultModel(
      status: json['status'] as String,
      transactionId: json['transaction_id'] as String,
      productId: json['product_id'] as String,
      grantedCoins: json['granted_coins'] as int? ?? 0,
      grantedGems: json['granted_gems'] as int? ?? 0,
      newCoinsBalance: json['new_coins_balance'] as int? ?? 0,
      newGemsBalance: json['new_gems_balance'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

class NotificationItemModel {
  final String id;
  final String title;
  final String body;
  final String category;
  final String? dataPayload;
  final bool isRead;
  final String createdAt;

  NotificationItemModel({
    required this.id,
    required this.title,
    String? body,
    String? message,
    required this.category,
    String? dataPayload,
    String? data,
    required this.isRead,
    required this.createdAt,
  }) : body = body ?? message ?? '',
       dataPayload = dataPayload ?? data;

  String get message => body;
  String? get data => dataPayload;

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String? ?? 'ANNOUNCEMENT',
      dataPayload: json['data_payload'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class ClubModel {
  final String id;
  final String name;
  final String tag;
  final String description;
  final String badgeIcon;
  final String leaderUserId;
  final int minLevel;
  final bool isOpen;
  final int memberCount;
  final int maxMembers;
  final String createdAt;

  ClubModel({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.badgeIcon,
    required this.leaderUserId,
    required this.minLevel,
    required this.isOpen,
    required this.memberCount,
    required this.maxMembers,
    required this.createdAt,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'] as String,
      name: json['name'] as String,
      tag: json['tag'] as String,
      description: json['description'] as String? ?? '',
      badgeIcon: json['badge_icon'] as String? ?? 'shield_gold',
      leaderUserId: json['leader_user_id'] as String,
      minLevel: json['min_level'] as int? ?? 1,
      isOpen: json['is_open'] as bool? ?? true,
      memberCount: json['member_count'] as int? ?? 1,
      maxMembers: json['max_members'] as int? ?? 30,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class ClubMemberModel {
  final String id;
  final String userId;
  final String role;
  final String joinedAt;
  final String displayName;
  final String avatarId;
  final int level;

  ClubMemberModel({
    required this.id,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.displayName,
    required this.avatarId,
    required this.level,
  });

  factory ClubMemberModel.fromJson(Map<String, dynamic> json) {
    return ClubMemberModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'MEMBER',
      joinedAt: json['joined_at'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Player',
      avatarId: json['avatar_id'] as String? ?? 'avatar_0',
      level: json['level'] as int? ?? 1,
    );
  }
}

class ClubDetailModel extends ClubModel {
  final List<ClubMemberModel> members;

  ClubDetailModel({
    required super.id,
    required super.name,
    required super.tag,
    required super.description,
    required super.badgeIcon,
    required super.leaderUserId,
    required super.minLevel,
    required super.isOpen,
    required super.memberCount,
    required super.maxMembers,
    required super.createdAt,
    required this.members,
  });

  factory ClubDetailModel.fromJson(Map<String, dynamic> json) {
    final membersList =
        (json['members'] as List<dynamic>?)
            ?.map((e) => ClubMemberModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ClubDetailModel(
      id: json['id'] as String,
      name: json['name'] as String,
      tag: json['tag'] as String,
      description: json['description'] as String? ?? '',
      badgeIcon: json['badge_icon'] as String? ?? 'shield_gold',
      leaderUserId: json['leader_user_id'] as String,
      minLevel: json['min_level'] as int? ?? 1,
      isOpen: json['is_open'] as bool? ?? true,
      memberCount: json['member_count'] as int? ?? 1,
      maxMembers: json['max_members'] as int? ?? 30,
      createdAt: json['created_at'] as String? ?? '',
      members: membersList,
    );
  }
}

class VoiceTokenModel {
  final String roomId;
  final String userId;
  final String voiceSessionId;
  final String token;
  final bool micEnabled;

  VoiceTokenModel({
    required this.roomId,
    required this.userId,
    required this.voiceSessionId,
    required this.token,
    required this.micEnabled,
  });

  factory VoiceTokenModel.fromJson(Map<String, dynamic> json) {
    return VoiceTokenModel(
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      voiceSessionId: json['voice_session_id'] as String,
      token: json['token'] as String,
      micEnabled: json['mic_enabled'] as bool? ?? false,
    );
  }
}
