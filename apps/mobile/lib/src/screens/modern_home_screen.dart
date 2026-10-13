import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';

import '../controllers/game_controller.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../widgets/app_loader.dart';
import '../widgets/auth_dialog.dart';
import '../widgets/play_with_friends_dialog.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/watch_ad_reward_dialog.dart';
import 'achievements_screen.dart';
import 'clubs_screen.dart';
import 'daily_rewards_dialog.dart';
import 'friends_screen.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'match_history_screen.dart';
import 'matchmaking_screen.dart';
import 'missions_screen.dart';
import 'notifications_dialog.dart';
import 'online_room_screen.dart';
import 'profile_editor_screen.dart';
import 'season_screen.dart';
import 'setup_screen.dart';
import 'store_inventory_screen.dart';
import 'tournament_screen.dart';

/// Game-first lobby inspired by successful casual board-game menus.
///
/// The screen deliberately avoids standard app-shell patterns such as tab bars,
/// list dashboards and equal-weight navigation. The player HUD, game identity and
/// four primary play modes own the visual hierarchy; progression/social systems
/// sit around them as secondary game controls.
class ModernHomeScreen extends ConsumerStatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  ConsumerState<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends ConsumerState<ModernHomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = ApiClient();
  UserMeModel? _account;
  DailyRewardStatusModel? _dailyReward;
  GameState? _savedGame;
  int _unreadNotifications = 0;
  int _roomInvites = 0;
  bool _loading = true;
  Timer? _refreshTimer;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _bootstrap();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshBadges(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([_loadAccount(), _loadSavedGame()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _ensureSession() async {
    final hasSession =
        _apiClient.accessToken != null || await _apiClient.restoreSession();
    if (!hasSession) await _apiClient.loginGuest();
  }

  Future<void> _loadAccount() async {
    try {
      await _ensureSession();
      final account = await _apiClient.getMyAccount();
      DailyRewardStatusModel? reward;
      try {
        reward = await _apiClient.getDailyRewardStatus();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _account = account;
        _dailyReward = reward;
      });
      await _refreshBadges();
    } catch (_) {
      // The lobby stays playable for local modes while the network is offline.
    }
  }

  Future<void> _refreshBadges() async {
    try {
      await _ensureSession();
      final notifications = await _apiClient.getNotifications();
      final invites = await _apiClient.getMyRoomInvites();
      if (!mounted) return;
      setState(() {
        _unreadNotifications = notifications.where((n) => !n.isRead).length;
        _roomInvites = invites.length;
      });
    } catch (_) {}
  }

  Future<void> _loadSavedGame() async {
    final game = await StorageService.loadActiveGame();
    if (mounted) setState(() => _savedGame = game);
  }

  Future<void> _openAuthenticated(Widget Function(ApiClient) builder) async {
    try {
      await _ensureSession();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => builder(_apiClient)),
      );
      await _loadAccount();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to connect: $error')),
      );
    }
  }

  void _openStore({int initialTab = 0}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => StoreInventoryScreen(
              apiClient: _apiClient,
              onInventoryChanged: _loadAccount,
              initialTabIndex: initialTab,
            ),
          ),
        )
        .then((_) => _loadAccount());
  }

  Future<void> _openProfile() async {
    final account = _account;
    if (account == null || account.profile.isGuest) {
      await showDialog<void>(
        context: context,
        builder: (_) => AuthDialog(
          apiClient: _apiClient,
          onAuthenticated: _loadAccount,
        ),
      );
      await _loadAccount();
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditorScreen(
          apiClient: _apiClient,
          profile: account.profile,
        ),
      ),
    );
    if (changed == true) await _loadAccount();
  }

  Future<void> _playOnline() =>
      _openAuthenticated((api) => MatchmakingScreen(apiClient: api));

  Future<void> _openRoom() =>
      _openAuthenticated((api) => OnlineRoomScreen(apiClient: api));

  void _playFriends() {
    final username = _account?.profile.username ?? '';
    showDialog<void>(
      context: context,
      builder: (_) => PlayWithFriendsDialog(
        apiClient: _apiClient,
        myUsername: username,
        onRefresh: _loadAccount,
      ),
    ).then((_) => _loadAccount());
  }

  void _resumeGame() {
    final game = _savedGame;
    if (game == null) return;
    ref.read(gameControllerProvider.notifier).resumeSavedGame(game);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const GameScreen()))
        .then((_) => _loadSavedGame());
  }

  Future<void> _claimDailyReward() async {
    await _ensureSession();
    if (!mounted) return;
    await DailyRewardsDialog.show(
      context,
      _apiClient,
      onRewardClaimed: _loadAccount,
    );
    await _loadAccount();
  }

  void _showNotifications() {
    showDialog<void>(
      context: context,
      builder: (_) => NotificationsDialog(
        apiClient: _apiClient,
        onRefreshHome: _loadAccount,
      ),
    ).then((_) => _refreshBadges());
  }

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _GameMenuSheet(
        roomInvites: _roomInvites,
        onMissions: () {
          Navigator.pop(sheetContext);
          _openAuthenticated((api) => MissionsScreen(apiClient: api));
        },
        onAchievements: () {
          Navigator.pop(sheetContext);
          _openAuthenticated((api) => AchievementsScreen(apiClient: api));
        },
        onSeason: () {
          Navigator.pop(sheetContext);
          _openAuthenticated((api) => SeasonScreen(apiClient: api));
        },
        onTournament: () {
          Navigator.pop(sheetContext);
          _openAuthenticated((api) => TournamentScreen(apiClient: api));
        },
        onLeaderboard: () {
          Navigator.pop(sheetContext);
          _openAuthenticated((api) => LeaderboardScreen(apiClient: api));
        },
        onFriends: () {
          Navigator.pop(sheetContext);
          _openAuthenticated((api) => FriendsScreen(apiClient: api));
        },
        onClubs: () {
          Navigator.pop(sheetContext);
          _openAuthenticated((api) => ClubsScreen(apiClient: api));
        },
        onHistory: () {
          Navigator.pop(sheetContext);
          _openAuthenticated((api) => MatchHistoryScreen(apiClient: api));
        },
        onRewardPack: () {
          Navigator.pop(sheetContext);
          showDialog<void>(
            context: context,
            builder: (_) => WatchAdRewardDialog(
              apiClient: _apiClient,
              onRewardClaimed: _loadAccount,
            ),
          ).then((_) => _loadAccount());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _account == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF071D55),
        body: AppLoader(message: 'Opening game lobby...'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF06194B),
      body: Stack(
        children: [
          const Positioned.fill(child: _GameLobbyBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 720;
                return Column(
                  children: [
                    _PlayerHud(
                      account: _account,
                      notifications: _unreadNotifications,
                      onProfile: _openProfile,
                      onCoins: () => _openStore(initialTab: 1),
                      onNotifications: _showNotifications,
                      onMore: _showMoreMenu,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          compact ? 4 : 10,
                          16,
                          14,
                        ),
                        child: Column(
                          children: [
                            _GameIdentity(compact: compact),
                            SizedBox(height: compact ? 8 : 14),
                            if (_savedGame != null) ...[
                              _ContinueRibbon(
                                playerCount: _savedGame!.players.length,
                                turn: _savedGame!.sequence,
                                onTap: _resumeGame,
                              ),
                              SizedBox(height: compact ? 8 : 12),
                            ],
                            _ModeGrid(
                              compact: compact,
                              pulse: _pulseController,
                              onOnline: _playOnline,
                              onFriends: _playFriends,
                              onComputer: () => Navigator.of(context)
                                  .push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SetupScreen(
                                        isVsComputer: true,
                                      ),
                                    ),
                                  )
                                  .then((_) => _loadSavedGame()),
                              onLocal: () => Navigator.of(context)
                                  .push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SetupScreen(
                                        isVsComputer: false,
                                      ),
                                    ),
                                  )
                                  .then((_) => _loadSavedGame()),
                            ),
                            SizedBox(height: compact ? 10 : 16),
                            _EventRail(
                              canClaimReward: _dailyReward?.canClaim ?? false,
                              inviteCount: _roomInvites,
                              onReward: _claimDailyReward,
                              onTournament: () => _openAuthenticated(
                                (api) => TournamentScreen(apiClient: api),
                              ),
                              onSeason: () => _openAuthenticated(
                                (api) => SeasonScreen(apiClient: api),
                              ),
                              onFriends: () => _openAuthenticated(
                                (api) => FriendsScreen(apiClient: api),
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 16),
                            _UtilityDock(
                              onStore: () => _openStore(initialTab: 0),
                              onLeaderboard: () => _openAuthenticated(
                                (api) => LeaderboardScreen(apiClient: api),
                              ),
                              onRoom: _openRoom,
                              onClub: () => _openAuthenticated(
                                (api) => ClubsScreen(apiClient: api),
                              ),
                              onMore: _showMoreMenu,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GameLobbyBackground extends StatelessWidget {
  const _GameLobbyBackground();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _LobbyPainter(),
        child: const SizedBox.expand(),
      );
}

class _LobbyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF123A91), Color(0xFF0A2870), Color(0xFF04143F)],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2E74FF).withValues(alpha: 0.36),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.38),
          radius: size.width * 0.72,
        ),
      );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.38),
      size.width * 0.72,
      glow,
    );

    final tilePaint = Paint()..color = Colors.white.withValues(alpha: 0.025);
    const tile = 54.0;
    for (double y = 110; y < size.height; y += tile) {
      for (double x = -tile; x < size.width + tile; x += tile) {
        final shifted = ((y / tile).round().isEven) ? x : x + tile / 2;
        canvas.save();
        canvas.translate(shifted + tile / 2, y + tile / 2);
        canvas.rotate(0.785398);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: 24,
              height: 24,
            ),
            const Radius.circular(5),
          ),
          tilePaint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlayerHud extends StatelessWidget {
  const _PlayerHud({
    required this.account,
    required this.notifications,
    required this.onProfile,
    required this.onCoins,
    required this.onNotifications,
    required this.onMore,
  });

  final UserMeModel? account;
  final int notifications;
  final VoidCallback onProfile;
  final VoidCallback onCoins;
  final VoidCallback onNotifications;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final profile = account?.profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF163D91), Color(0xFF0B2B75)],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF68B8FF), width: 1.4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProfileAvatar(
                        avatarId: profile?.avatarId ?? 'avatar_0',
                        radius: 21,
                      ),
                      Positioned(
                        right: -4,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC928),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Text(
                            '${profile?.level ?? 1}',
                            style: const TextStyle(
                              color: Color(0xFF4A2A00),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 84),
                    child: Text(
                      profile?.displayName ?? 'Player',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _CurrencyHud(
            icon: Icons.monetization_on_rounded,
            value: account?.wallet.coins ?? 1000,
            color: const Color(0xFFFFC928),
            onTap: onCoins,
          ),
          const SizedBox(width: 6),
          _CurrencyHud(
            icon: Icons.diamond_rounded,
            value: account?.wallet.gems ?? 50,
            color: const Color(0xFF65E9FF),
            onTap: onCoins,
          ),
          const SizedBox(width: 6),
          _HudIcon(
            icon: Icons.notifications_rounded,
            badge: notifications,
            onTap: onNotifications,
          ),
          const SizedBox(width: 4),
          _HudIcon(icon: Icons.menu_rounded, onTap: onMore),
        ],
      ),
    );
  }
}

class _CurrencyHud extends StatelessWidget {
  const _CurrencyHud({
    required this.icon,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 34,
          padding: const EdgeInsets.fromLTRB(4, 3, 7, 3),
          decoration: BoxDecoration(
            color: const Color(0xFF071B4A).withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 5),
              Text(
                value > 9999 ? '${(value / 1000).toStringAsFixed(1)}k' : '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.add_circle, color: Color(0xFF56E978), size: 14),
            ],
          ),
        ),
      );
}

class _HudIcon extends StatelessWidget {
  const _HudIcon({required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => Badge(
        isLabelVisible: badge > 0,
        label: Text('$badge'),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A62C0), Color(0xFF164492)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF72C9FF), width: 1.2),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 5, offset: Offset(0, 3)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
      );
}

class _GameIdentity extends StatelessWidget {
  const _GameIdentity({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: compact ? 122 : 146,
                height: compact ? 72 : 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF53B5FF).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: compact ? -4 : -8,
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: const Color(0xFFFFD447),
                  size: compact ? 30 : 38,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 6)],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: compact ? 14 : 18),
                child: const AppLogo(size: 62),
              ),
            ],
          ),
          Transform.translate(
            offset: const Offset(0, -5),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD744), Color(0xFFFF8A1D)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
              child: Text(
                'LUDO MASTER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 24 : 29,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  shadows: const [
                    Shadow(color: Color(0xFF7B2E00), offset: Offset(0, 3), blurRadius: 1),
                    Shadow(color: Colors.black54, offset: Offset(0, 5), blurRadius: 7),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

class _ContinueRibbon extends StatelessWidget {
  const _ContinueRibbon({
    required this.playerCount,
    required this.turn,
    required this.onTap,
  });

  final int playerCount;
  final int turn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0CBF76), Color(0xFF087E51)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF7FFFC6), width: 1.3),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 7, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONTINUE GAME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$playerCount players • turn $turn',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      );
}

class _ModeGrid extends StatelessWidget {
  const _ModeGrid({
    required this.compact,
    required this.pulse,
    required this.onOnline,
    required this.onFriends,
    required this.onComputer,
    required this.onLocal,
  });

  final bool compact;
  final Animation<double> pulse;
  final VoidCallback onOnline;
  final VoidCallback onFriends;
  final VoidCallback onComputer;
  final VoidCallback onLocal;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (context, child) => Transform.scale(
                    scale: 1 + pulse.value * 0.008,
                    child: child,
                  ),
                  child: _GameModeButton(
                    key: const Key('mode-online'),
                    height: compact ? 112 : 132,
                    title: 'ONLINE',
                    subtitle: 'Quick Match',
                    icon: Icons.public_rounded,
                    topColor: const Color(0xFF55E36E),
                    bottomColor: const Color(0xFF12A84E),
                    badge: 'LIVE',
                    onTap: onOnline,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GameModeButton(
                  key: const Key('mode-friends'),
                  height: compact ? 112 : 132,
                  title: 'FRIENDS',
                  subtitle: 'Play Together',
                  icon: Icons.group_rounded,
                  topColor: const Color(0xFFFF765E),
                  bottomColor: const Color(0xFFE53D42),
                  onTap: onFriends,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GameModeButton(
                  key: const Key('mode-computer'),
                  height: compact ? 100 : 118,
                  title: 'VS COMPUTER',
                  subtitle: 'Offline Practice',
                  icon: Icons.smart_toy_rounded,
                  topColor: const Color(0xFF61B9FF),
                  bottomColor: const Color(0xFF2571D8),
                  onTap: onComputer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GameModeButton(
                  key: const Key('mode-local'),
                  height: compact ? 100 : 118,
                  title: 'PASS & PLAY',
                  subtitle: 'Local Multiplayer',
                  icon: Icons.people_alt_rounded,
                  topColor: const Color(0xFFFFD34D),
                  bottomColor: const Color(0xFFF29B17),
                  darkText: true,
                  onTap: onLocal,
                ),
              ),
            ],
          ),
        ],
      );
}

class _GameModeButton extends StatelessWidget {
  const _GameModeButton({
    super.key,
    required this.height,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.topColor,
    required this.bottomColor,
    required this.onTap,
    this.badge,
    this.darkText = false,
  });

  final double height;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color topColor;
  final Color bottomColor;
  final VoidCallback onTap;
  final String? badge;
  final bool darkText;

  @override
  Widget build(BuildContext context) {
    final textColor = darkText ? const Color(0xFF5B3500) : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [topColor, bottomColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78), width: 2),
          boxShadow: [
            BoxShadow(
              color: bottomColor.withValues(alpha: 0.72),
              offset: const Offset(0, 7),
              blurRadius: 0,
            ),
            const BoxShadow(
              color: Color(0x66000000),
              offset: Offset(0, 10),
              blurRadius: 10,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 7,
              left: 9,
              right: 9,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: -7,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE82136),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.19),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Icon(icon, color: textColor, size: 29),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                      shadows: darkText
                          ? null
                          : const [Shadow(color: Colors.black38, offset: Offset(0, 2), blurRadius: 2)],
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.84),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRail extends StatelessWidget {
  const _EventRail({
    required this.canClaimReward,
    required this.inviteCount,
    required this.onReward,
    required this.onTournament,
    required this.onSeason,
    required this.onFriends,
  });

  final bool canClaimReward;
  final int inviteCount;
  final VoidCallback onReward;
  final VoidCallback onTournament;
  final VoidCallback onSeason;
  final VoidCallback onFriends;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 72,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          children: [
            _EventBadge(
              icon: Icons.card_giftcard_rounded,
              label: 'DAILY',
              color: const Color(0xFFFFC532),
              marker: canClaimReward ? 'FREE' : null,
              onTap: onReward,
            ),
            _EventBadge(
              icon: Icons.emoji_events_rounded,
              label: 'CUP',
              color: const Color(0xFFFF7D45),
              marker: '8P',
              onTap: onTournament,
            ),
            _EventBadge(
              icon: Icons.workspace_premium_rounded,
              label: 'SEASON',
              color: const Color(0xFFB771FF),
              onTap: onSeason,
            ),
            _EventBadge(
              icon: Icons.mail_rounded,
              label: 'INVITES',
              color: const Color(0xFF48D9BE),
              marker: inviteCount > 0 ? '$inviteCount' : null,
              onTap: onFriends,
            ),
          ],
        ),
      );
}

class _EventBadge extends StatelessWidget {
  const _EventBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.marker,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? marker;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 78,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF173E8A), Color(0xFF0A285F)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.72), width: 1.4),
                  boxShadow: const [
                    BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 28),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (marker != null)
                Positioned(
                  right: -3,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE83245),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Text(
                      marker!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _UtilityDock extends StatelessWidget {
  const _UtilityDock({
    required this.onStore,
    required this.onLeaderboard,
    required this.onRoom,
    required this.onClub,
    required this.onMore,
  });

  final VoidCallback onStore;
  final VoidCallback onLeaderboard;
  final VoidCallback onRoom;
  final VoidCallback onClub;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF06173E).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF3C72BC)),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DockButton(icon: Icons.storefront_rounded, label: 'SHOP', onTap: onStore),
            _DockButton(icon: Icons.leaderboard_rounded, label: 'RANK', onTap: onLeaderboard),
            _DockButton(icon: Icons.key_rounded, label: 'ROOM', onTap: onRoom),
            _DockButton(icon: Icons.shield_rounded, label: 'CLUB', onTap: onClub),
            _DockButton(icon: Icons.grid_view_rounded, label: 'MORE', onTap: onMore),
          ],
        ),
      );
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF9ED4FF), size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
}

class _GameMenuSheet extends StatelessWidget {
  const _GameMenuSheet({
    required this.roomInvites,
    required this.onMissions,
    required this.onAchievements,
    required this.onSeason,
    required this.onTournament,
    required this.onLeaderboard,
    required this.onFriends,
    required this.onClubs,
    required this.onHistory,
    required this.onRewardPack,
  });

  final int roomInvites;
  final VoidCallback onMissions;
  final VoidCallback onAchievements;
  final VoidCallback onSeason;
  final VoidCallback onTournament;
  final VoidCallback onLeaderboard;
  final VoidCallback onFriends;
  final VoidCallback onClubs;
  final VoidCallback onHistory;
  final VoidCallback onRewardPack;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF12347B), Color(0xFF071C4B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF68B8FF), width: 1.4),
            boxShadow: const [
              BoxShadow(color: Color(0x88000000), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.casino_rounded, color: Color(0xFFFFC928)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'GAME MENU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.12,
                children: [
                  _MenuTile(icon: Icons.flag_rounded, label: 'Missions', onTap: onMissions),
                  _MenuTile(icon: Icons.emoji_events_rounded, label: 'Badges', onTap: onAchievements),
                  _MenuTile(icon: Icons.workspace_premium_rounded, label: 'Season', onTap: onSeason),
                  _MenuTile(icon: Icons.account_tree_rounded, label: 'Cup', onTap: onTournament),
                  _MenuTile(icon: Icons.leaderboard_rounded, label: 'Ranking', onTap: onLeaderboard),
                  _MenuTile(
                    icon: Icons.people_alt_rounded,
                    label: roomInvites > 0 ? 'Friends ($roomInvites)' : 'Friends',
                    onTap: onFriends,
                  ),
                  _MenuTile(icon: Icons.shield_rounded, label: 'Clubs', onTap: onClubs),
                  _MenuTile(icon: Icons.history_rounded, label: 'History', onTap: onHistory),
                  _MenuTile(icon: Icons.play_circle_fill_rounded, label: 'Free Coins', onTap: onRewardPack),
                ],
              ),
            ],
          ),
        ),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF255FB8), Color(0xFF123E88)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFFFD34D), size: 28),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
