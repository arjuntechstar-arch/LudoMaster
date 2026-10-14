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
import 'daily_rewards_dialog.dart';
import 'friends_screen.dart';
import 'game_screen.dart';
import 'matchmaking_screen.dart';
import 'notifications_dialog.dart';
import 'online_room_screen.dart';
import 'profile_editor_screen.dart';
import 'season_screen.dart';
import 'setup_screen.dart';
import 'store_inventory_screen.dart';
import 'tournament_screen.dart';

/// Pixel-proportioned lobby based directly on the supplied 706x1600 reference.
///
/// The design is rendered on a fixed logical canvas and scaled to device width,
/// which preserves the reference composition rather than letting responsive
/// layout rules reinterpret its spacing and proportions.
class ReferenceLudoLobbyScreen extends ConsumerStatefulWidget {
  const ReferenceLudoLobbyScreen({super.key});

  @override
  ConsumerState<ReferenceLudoLobbyScreen> createState() =>
      _ReferenceLudoLobbyScreenState();
}

class _ReferenceLudoLobbyScreenState
    extends ConsumerState<ReferenceLudoLobbyScreen> {
  static const double _designWidth = 706;
  static const double _designHeight = 1600;

  final ApiClient _apiClient = ApiClient();
  UserMeModel? _account;
  DailyRewardStatusModel? _dailyReward;
  GameState? _savedGame;
  int _unreadNotifications = 0;
  int _roomInvites = 0;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshBadges(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
      // Local play remains available while offline.
    }
  }

  Future<void> _refreshBadges() async {
    try {
      await _ensureSession();
      final notifications = await _apiClient.getNotifications();
      final invites = await _apiClient.getMyRoomInvites();
      if (!mounted) return;
      setState(() {
        _unreadNotifications = notifications.where((item) => !item.isRead).length;
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

  void _showNotifications() {
    showDialog<void>(
      context: context,
      builder: (_) => NotificationsDialog(
        apiClient: _apiClient,
        onRefreshHome: _loadAccount,
      ),
    ).then((_) => _refreshBadges());
  }

  Future<void> _playOnline() =>
      _openAuthenticated((api) => MatchmakingScreen(apiClient: api));

  void _playFriends() {
    showDialog<void>(
      context: context,
      builder: (_) => PlayWithFriendsDialog(
        apiClient: _apiClient,
        myUsername: _account?.profile.username ?? '',
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

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _account == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1733),
        body: AppLoader(message: 'Opening game lobby...'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1733),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final scale = width / _designWidth;
          final scaledHeight = _designHeight * scale;
          return SingleChildScrollView(
            child: SizedBox(
              width: width,
              height: scaledHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.scale(
                  alignment: Alignment.topCenter,
                  scale: scale,
                  child: SizedBox(
                    width: _designWidth,
                    height: _designHeight,
                    child: _buildDesignCanvas(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesignCanvas() {
    final wallet = _account?.wallet;
    final profile = _account?.profile;
    return Stack(
      children: [
        const Positioned.fill(child: _ReferenceBackground()),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 110,
          child: _ReferenceHeader(
            avatarId: profile?.avatarId ?? 'avatar_0',
            level: profile?.level ?? 1,
            gems: wallet?.gems ?? 150,
            coins: wallet?.coins ?? 2930,
            unread: _unreadNotifications,
            onProfile: _openProfile,
            onSettings: _openProfile,
            onMail: _showNotifications,
            onCurrency: () => _openStore(initialTab: 1),
            onStore: () => _openStore(initialTab: 0),
          ),
        ),

        // Left promotional rail.
        Positioned(
          left: 18,
          top: 178,
          child: _CirclePromo(
            diameter: 58,
            fill: const Color(0xFFFFC940),
            label: '₹25',
            subLabel: 'ONLY',
            labelColor: const Color(0xFF563000),
            onTap: () => _openStore(initialTab: 1),
          ),
        ),
        Positioned(
          left: 20,
          top: 276,
          child: _RoundLetterPromo(
            letter: 'K',
            onTap: () => _openStore(initialTab: 0),
          ),
        ),
        Positioned(
          left: 18,
          top: 350,
          child: _NewPromo(
            hasResume: _savedGame != null,
            onTap: _savedGame == null ? () => _openStore(initialTab: 0) : _resumeGame,
          ),
        ),

        // Right utility rail.
        Positioned(
          right: 18,
          top: 180,
          child: _RightRailButton(
            icon: Icons.inventory_2_rounded,
            fill: const Color(0xFFFFBC18),
            label: 'FREE',
            onTap: _claimDailyReward,
          ),
        ),
        Positioned(
          right: 22,
          top: 275,
          child: _RoundUtility(
            icon: Icons.gps_fixed_rounded,
            fill: const Color(0xFFE93234),
            onTap: () => _openAuthenticated(
              (api) => TournamentScreen(apiClient: api),
            ),
          ),
        ),
        Positioned(
          right: 22,
          top: 342,
          child: _RoundUtility(
            icon: Icons.sentiment_satisfied_alt_rounded,
            fill: const Color(0xFFFFC534),
            iconColor: const Color(0xFF563000),
            onTap: () => _openAuthenticated(
              (api) => FriendsScreen(apiClient: api),
            ),
          ),
        ),
        Positioned(
          right: 26,
          top: 412,
          child: _SquareHelp(
            onTap: () => _showComingSoon('Help'),
          ),
        ),

        // Hero exactly occupies the visual center above game modes.
        Positioned(
          left: 150,
          top: 245,
          width: 406,
          height: 330,
          child: const _ReferenceHero(),
        ),

        // Three primary online modes.
        Positioned(
          left: 18,
          top: 700,
          width: 216,
          height: 192,
          child: _ModePanel(
            key: const Key('mode-online'),
            icon: Icons.public_rounded,
            iconColor: const Color(0xFF8DD8FF),
            title: 'ONLINE',
            players: '274,182',
            onTap: _playOnline,
          ),
        ),
        Positioned(
          left: 245,
          top: 700,
          width: 216,
          height: 192,
          child: _ModePanel(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFFFFD83D),
            title: 'TEAM UP',
            players: '5,024',
            onTap: () => _openAuthenticated(
              (api) => OnlineRoomScreen(apiClient: api),
            ),
          ),
        ),
        Positioned(
          left: 472,
          top: 700,
          width: 216,
          height: 192,
          child: _ModePanel(
            key: const Key('mode-friends'),
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFFFF5B68),
            title: 'FRIENDS',
            players: '24,473',
            trailingMic: true,
            onTap: _playFriends,
          ),
        ),

        // Local modes.
        Positioned(
          left: 18,
          top: 910,
          width: 327,
          height: 145,
          child: _WideModePanel(
            key: const Key('mode-computer'),
            title: 'COMPUTER',
            icon: Icons.smart_toy_rounded,
            onTap: () => Navigator.of(context)
                .push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SetupScreen(isVsComputer: true),
                  ),
                )
                .then((_) => _loadSavedGame()),
          ),
        ),
        Positioned(
          left: 360,
          top: 910,
          width: 328,
          height: 145,
          child: _WideModePanel(
            key: const Key('mode-local'),
            title: 'PASS N PLAY',
            icon: Icons.people_alt_rounded,
            onTap: () => Navigator.of(context)
                .push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SetupScreen(isVsComputer: false),
                  ),
                )
                .then((_) => _loadSavedGame()),
          ),
        ),

        // Tournament row.
        Positioned(
          left: 18,
          top: 1128,
          width: 116,
          height: 85,
          child: _SideTournamentTile(
            topText: '7',
            bottomText: 'UP DOWN',
            fill: const Color(0xFF1736C6),
            icon: null,
            onTap: () => _showComingSoon('Up Down'),
          ),
        ),
        Positioned(
          left: 145,
          top: 1128,
          width: 416,
          height: 88,
          child: _TournamentButton(
            onTap: () => _openAuthenticated(
              (api) => TournamentScreen(apiClient: api),
            ),
          ),
        ),
        Positioned(
          right: 18,
          top: 1128,
          width: 116,
          height: 85,
          child: _SideTournamentTile(
            topText: '',
            bottomText: 'SNAKES',
            fill: const Color(0xFF067235),
            icon: Icons.currency_rupee_rounded,
            onTap: () => _showComingSoon('Snakes'),
          ),
        ),

        // Claim row.
        Positioned(
          left: 18,
          top: 1237,
          width: 670,
          height: 82,
          child: _ClaimBanner(
            canClaim: _dailyReward?.canClaim ?? false,
            onTap: _claimDailyReward,
          ),
        ),

        // Bottom promotions.
        Positioned(
          left: 22,
          top: 1400,
          child: _FreeAdTile(
            onTap: () => _openStore(initialTab: 1),
          ),
        ),
        Positioned(
          right: 22,
          top: 1388,
          child: _SpinTile(
            onTap: () => _openAuthenticated(
              (api) => SeasonScreen(apiClient: api),
            ),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 102,
          child: _ReferenceBottomNav(
            inviteCount: _roomInvites,
            onHome: () {},
            onEvent: () => _openAuthenticated(
              (api) => TournamentScreen(apiClient: api),
            ),
            onAdda: _playFriends,
            onInventory: () => _openStore(initialTab: 0),
            onSocial: () => _openAuthenticated(
              (api) => FriendsScreen(apiClient: api),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReferenceBackground extends StatelessWidget {
  const _ReferenceBackground();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _ReferenceBackgroundPainter(),
        child: const SizedBox.expand(),
      );
}

class _ReferenceBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0C1630),
    );
    final dotPaint = Paint()..color = const Color(0xFF16213B);
    const gapX = 90.0;
    const gapY = 90.0;
    for (double y = -6; y < size.height + 30; y += gapY) {
      for (double x = 0; x < size.width + 40; x += gapX) {
        final shifted = ((y / gapY).round().isEven) ? x : x + 45;
        canvas.drawCircle(Offset(shifted, y), 9, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReferenceHeader extends StatelessWidget {
  const _ReferenceHeader({
    required this.avatarId,
    required this.level,
    required this.gems,
    required this.coins,
    required this.unread,
    required this.onProfile,
    required this.onSettings,
    required this.onMail,
    required this.onCurrency,
    required this.onStore,
  });

  final String avatarId;
  final int level;
  final int gems;
  final int coins;
  final int unread;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onMail;
  final VoidCallback onCurrency;
  final VoidCallback onStore;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C1837),
          border: Border(bottom: BorderSide(color: Color(0xFF1B3C6B), width: 2)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 18,
              top: 22,
              child: InkWell(
                onTap: onProfile,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD332),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ProfileAvatar(avatarId: avatarId, radius: 32),
                      ),
                    ),
                    Positioned(
                      right: -3,
                      top: -6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF19C85B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -8,
                      bottom: -9,
                      child: Container(
                        width: 44,
                        height: 25,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC72A),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF6E4300), width: 1.5),
                        ),
                        child: Text(
                          '★$level',
                          style: const TextStyle(
                            color: Color(0xFF5A3300),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 101,
              top: 31,
              child: _HeaderSquare(
                icon: Icons.settings_rounded,
                fill: const Color(0xFF2A69D7),
                onTap: onSettings,
              ),
            ),
            Positioned(
              left: 163,
              top: 31,
              child: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: _HeaderSquare(
                  icon: Icons.mail_rounded,
                  fill: const Color(0xFFFFAA09),
                  onTap: onMail,
                ),
              ),
            ),
            Positioned(
              left: 355,
              top: 32,
              child: _CurrencyPill(
                icon: Icons.diamond_rounded,
                iconColor: const Color(0xFF64E9FF),
                value: gems,
                width: 120,
                onTap: onCurrency,
              ),
            ),
            Positioned(
              left: 483,
              top: 32,
              child: _CurrencyPill(
                icon: Icons.monetization_on_rounded,
                iconColor: const Color(0xFFFFD429),
                value: coins,
                width: 144,
                onTap: onCurrency,
              ),
            ),
            Positioned(
              right: 18,
              top: 32,
              child: _HeaderSquare(
                icon: Icons.shopping_cart_rounded,
                fill: const Color(0xFFFFA806),
                onTap: onStore,
              ),
            ),
          ],
        ),
      );
}

class _HeaderSquare extends StatelessWidget {
  const _HeaderSquare({
    required this.icon,
    required this.fill,
    required this.onTap,
  });

  final IconData icon;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 51,
          height: 51,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fill.withValues(alpha: .95), fill],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white70, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 3)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 29),
        ),
      );
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.width,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final int value;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: width,
          height: 50,
          padding: const EdgeInsets.fromLTRB(12, 0, 7, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF071125),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF28CFF3), width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 25),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFF18C95B),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      );
}

class _CirclePromo extends StatelessWidget {
  const _CirclePromo({
    required this.diameter,
    required this.fill,
    required this.label,
    required this.subLabel,
    required this.labelColor,
    required this.onTap,
  });

  final double diameter;
  final Color fill;
  final String label;
  final String subLabel;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: diameter,
              height: diameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 4)),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subLabel,
              style: const TextStyle(
                color: Color(0xFFFFE033),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _RoundLetterPromo extends StatelessWidget {
  const _RoundLetterPromo({required this.letter, required this.onTap});
  final String letter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFB51D), Color(0xFFC96800)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              fontSize: 26,
            ),
          ),
        ),
      );
}

class _NewPromo extends StatelessWidget {
  const _NewPromo({required this.hasResume, required this.onTap});
  final bool hasResume;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 65,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD026),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                height: 25,
                color: const Color(0xFFE51F2B),
                alignment: Alignment.center,
                child: Text(
                  hasResume ? 'PLAY' : 'NEW',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Expanded(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFFE52C32),
                  size: 29,
                ),
              ),
            ],
          ),
        ),
      );
}

class _RightRailButton extends StatelessWidget {
  const _RightRailButton({
    required this.icon,
    required this.fill,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color fill;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 57,
              height: 57,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFE032),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _RoundUtility extends StatelessWidget {
  const _RoundUtility({
    required this.icon,
    required this.fill,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final Color fill;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
      );
}

class _SquareHelp extends StatelessWidget {
  const _SquareHelp({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1A50B2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1AC8F0), width: 2),
          ),
          child: const Text(
            '?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 23,
            ),
          ),
        ),
      );
}

class _ReferenceHero extends StatelessWidget {
  const _ReferenceHero();

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(top: 4, child: _AdPill()),
          const Positioned(top: 52, child: _LogoCluster()),
          const Positioned(top: 175, left: 18, right: 18, child: _BoardCluster()),
        ],
      );
}

class _AdPill extends StatelessWidget {
  const _AdPill();

  @override
  Widget build(BuildContext context) => Container(
        width: 90,
        height: 37,
        decoration: BoxDecoration(
          color: const Color(0xFF111828),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF50566A), width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: Color(0xFFE83D82),
              child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
            ),
            SizedBox(width: 6),
            Text(
              'AD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _LogoCluster extends StatelessWidget {
  const _LogoCluster();

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF2781ED),
      Color(0xFFE83844),
      Color(0xFF25B85A),
      Color(0xFFFFB510),
    ];
    const letters = ['L', 'U', 'D', 'O'];
    return SizedBox(
      width: 245,
      height: 125,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const Positioned(
            top: 0,
            child: Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFFFD23E),
              size: 76,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 4)),
              ],
            ),
          ),
          Positioned(
            top: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                4,
                (index) => Container(
                  width: 56,
                  height: 70,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: colors[index], width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: colors[index].withValues(alpha: .8),
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    letters[index],
                    style: TextStyle(
                      color: colors[index],
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 0,
            child: Text(
              'KING',
              style: TextStyle(
                color: Color(0xFFFFC832),
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
                shadows: [
                  Shadow(color: Color(0xFF5F3900), offset: Offset(0, 3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardCluster extends StatelessWidget {
  const _BoardCluster();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 36,
              right: 36,
              bottom: 22,
              height: 70,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8F4FF),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 7, offset: Offset(0, 7)),
                  ],
                ),
                child: const Row(
                  children: [
                    Expanded(child: _BoardHalf(fill: Color(0xFFE63C42))),
                    SizedBox(width: 6),
                    Expanded(child: _BoardHalf(fill: Color(0xFF25A851))),
                  ],
                ),
              ),
            ),
            const Positioned(left: 8, bottom: 16, child: _BigPawn(fill: Color(0xFF286DE0))),
            const Positioned(left: 110, top: 0, child: _SmallPawn(fill: Color(0xFFE93E48))),
            const Positioned(right: 108, top: 2, child: _SmallPawn(fill: Color(0xFF26B657))),
            const Positioned(right: 8, bottom: 16, child: _BigPawn(fill: Color(0xFFFFB917))),
            const Positioned(top: 36, child: _ReferenceDice()),
          ],
        ),
      );
}

class _BoardHalf extends StatelessWidget {
  const _BoardHalf({required this.fill});
  final Color fill;

  @override
  Widget build(BuildContext context) => Container(
        color: fill,
        child: Center(
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
            ),
          ),
        ),
      );
}

class _BigPawn extends StatelessWidget {
  const _BigPawn({required this.fill});
  final Color fill;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: fill.withValues(alpha: .86),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 2),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -5),
            child: Container(
              width: 56,
              height: 78,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [fill, fill.withValues(alpha: .8)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(color: fill.withValues(alpha: .4), blurRadius: 12),
                ],
              ),
            ),
          ),
        ],
      );
}

class _SmallPawn extends StatelessWidget {
  const _SmallPawn({required this.fill});
  final Color fill;

  @override
  Widget build(BuildContext context) => Transform.scale(
        scale: .72,
        alignment: Alignment.topCenter,
        child: _BigPawn(fill: fill),
      );
}

class _ReferenceDice extends StatelessWidget {
  const _ReferenceDice();

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: .08,
        child: Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0xFF94A5B7), offset: Offset(0, 10)),
              BoxShadow(color: Colors.black45, blurRadius: 9, offset: Offset(0, 12)),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_Pip(), _Pip()]),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [_Pip(fill: Color(0xFFE72C37))]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_Pip(), _Pip()]),
            ],
          ),
        ),
      );
}

class _Pip extends StatelessWidget {
  const _Pip({this.fill = Colors.black});
  final Color fill;

  @override
  Widget build(BuildContext context) => Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      );
}

BoxDecoration _cyanPanelDecoration({double radius = 14}) => BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1596CB), Color(0xFF0475A8)],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFF63E2FF), width: 3),
      boxShadow: const [
        BoxShadow(color: Color(0xFF032840), blurRadius: 0, offset: Offset(0, 7)),
      ],
    );

class _ModePanel extends StatelessWidget {
  const _ModePanel({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.players,
    required this.onTap,
    this.trailingMic = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String players;
  final VoidCallback onTap;
  final bool trailingMic;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: _cyanPanelDecoration(),
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Icon(icon, color: iconColor, size: 52),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(7, 0, 7, 8),
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFC23A), Color(0xFFF19700)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFFB34B00), offset: Offset(0, 7)),
                        ],
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF351B00),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF142B68),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircleAvatar(radius: 5, backgroundColor: Color(0xFF25DD73)),
                          const SizedBox(width: 6),
                          Text(
                            'Players: $players',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingMic)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFF168DBE),
                    child: Icon(Icons.mic_rounded, color: Colors.white, size: 17),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _WideModePanel extends StatelessWidget {
  const _WideModePanel({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: _cyanPanelDecoration(radius: 15),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC632),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: const Color(0xFF5B3400), size: 32),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFC43C), Color(0xFFF19700)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFAD4A00), offset: Offset(0, 7)),
                  ],
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF351B00),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SideTournamentTile extends StatelessWidget {
  const _SideTournamentTile({
    required this.topText,
    required this.bottomText,
    required this.fill,
    required this.icon,
    required this.onTap,
  });

  final String topText;
  final String bottomText;
  final Color fill;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFFFC51F), width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black45, offset: Offset(0, 5), blurRadius: 4),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(icon, color: const Color(0xFFFFD13A), size: 27)
              else
                Text(
                  topText,
                  style: const TextStyle(
                    color: Color(0xFFFFD43B),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              Text(
                bottomText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
}

class _TournamentButton extends StatelessWidget {
  const _TournamentButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE48A00),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFFFE95C), width: 4),
            boxShadow: const [
              BoxShadow(color: Color(0xFF7D3C00), offset: Offset(0, 8)),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, color: Colors.white, size: 34),
              SizedBox(width: 9),
              Text(
                'TOURNAMENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 1, offset: Offset(0, 3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ClaimBanner extends StatelessWidget {
  const _ClaimBanner({required this.canClaim, required this.onTap});
  final bool canClaim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFC42A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0xFF9C4B00), offset: Offset(0, 7)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 18,
                top: 10,
                bottom: 10,
                width: 90,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF8B25E8), Color(0xFF3322A6)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFFFFE328), width: 2),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SEASON',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '27',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Text(
                  canClaim ? 'CLAIM' : 'CLAIM',
                  style: const TextStyle(
                    color: Color(0xFF9A4E14),
                    fontSize: 35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Positioned(
                right: 24,
                top: 22,
                child: Icon(
                  Icons.keyboard_double_arrow_right_rounded,
                  color: Color(0xFFB96E00),
                  size: 40,
                ),
              ),
            ],
          ),
        ),
      );
}

class _FreeAdTile extends StatelessWidget {
  const _FreeAdTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFF2138BA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFC929), width: 2),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_collection_rounded, color: Color(0xFFFFCE28), size: 25),
                  Text('x5', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FREE AD',
                  style: TextStyle(
                    color: Color(0xFFFFDA2B),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD022), size: 17),
                    SizedBox(width: 3),
                    Text(
                      '1000',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
}

class _SpinTile extends StatelessWidget {
  const _SpinTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC02A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, offset: Offset(0, 5), blurRadius: 5),
                ],
              ),
              child: const Icon(Icons.casino_rounded, color: Color(0xFF4F2B00), size: 35),
            ),
            const SizedBox(height: 4),
            const Text(
              'SPIN',
              style: TextStyle(
                color: Color(0xFFFFD638),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _ReferenceBottomNav extends StatelessWidget {
  const _ReferenceBottomNav({
    required this.inviteCount,
    required this.onHome,
    required this.onEvent,
    required this.onAdda,
    required this.onInventory,
    required this.onSocial,
  });

  final int inviteCount;
  final VoidCallback onHome;
  final VoidCallback onEvent;
  final VoidCallback onAdda;
  final VoidCallback onInventory;
  final VoidCallback onSocial;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF233FA4),
          border: Border(top: BorderSide(color: Color(0xFF1A8EC9), width: 4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _BottomNavItem(
              icon: Icons.home_rounded,
              label: 'HOME',
              active: true,
              onTap: onHome,
            ),
            _BottomNavItem(
              icon: Icons.emoji_events_rounded,
              label: 'EVENT',
              onTap: onEvent,
            ),
            _BottomNavItem(
              icon: Icons.mic_rounded,
              label: 'ADDA',
              raised: true,
              badge: 'NEW',
              onTap: onAdda,
            ),
            _BottomNavItem(
              icon: Icons.inventory_2_rounded,
              label: 'INVENTORY',
              onTap: onInventory,
            ),
            _BottomNavItem(
              icon: Icons.forum_rounded,
              label: 'SOCIAL',
              notificationDot: inviteCount > 0,
              onTap: onSocial,
            ),
          ],
        ),
      );
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.raised = false,
    this.badge,
    this.notificationDot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool raised;
  final String? badge;
  final bool notificationDot;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 112,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: raised ? 62 : 58,
                    height: raised ? 62 : 58,
                    decoration: BoxDecoration(
                      color: active || raised
                          ? const Color(0xFFFFC12D)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: active || raised
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: active || raised
                          ? const Color(0xFF5A3100)
                          : const Color(0xFFB9D9F2),
                      size: raised ? 32 : 30,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE92832),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  if (notificationDot)
                    const Positioned(
                      right: 2,
                      top: 0,
                      child: CircleAvatar(
                        radius: 7,
                        backgroundColor: Color(0xFFFFD124),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: active || raised
                      ? const Color(0xFFFFE13C)
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
}
