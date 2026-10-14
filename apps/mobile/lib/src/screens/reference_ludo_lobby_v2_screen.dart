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

/// Reference-first lobby that always preserves the original portrait aspect
/// ratio. On wide/short screens the complete game canvas is letterboxed instead
/// of being enlarged by width and vertically cropped.
class ReferenceLudoLobbyV2Screen extends ConsumerStatefulWidget {
  const ReferenceLudoLobbyV2Screen({super.key});

  @override
  ConsumerState<ReferenceLudoLobbyV2Screen> createState() =>
      _ReferenceLudoLobbyV2ScreenState();
}

class _ReferenceLudoLobbyV2ScreenState
    extends ConsumerState<ReferenceLudoLobbyV2Screen> {
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
      // Local modes remain playable while offline.
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

  void _showNotifications() {
    showDialog<void>(
      context: context,
      builder: (_) => NotificationsDialog(
        apiClient: _apiClient,
        onRefreshHome: _loadAccount,
      ),
    ).then((_) => _refreshBadges());
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
        backgroundColor: Color(0xFF08132D),
        body: AppLoader(message: 'Opening game lobby...'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF08132D),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // BoxFit.contain is the key fix for the desktop/web glitch. The
            // 706x1600 reference is scaled using BOTH available dimensions.
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: _designWidth,
                  height: _designHeight,
                  child: _buildCanvas(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    final profile = _account?.profile;
    final wallet = _account?.wallet;

    return Stack(
      children: [
        const Positioned.fill(child: _DotBackground()),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: 112,
          child: _TopBar(
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

        Positioned(
          left: 18,
          top: 180,
          child: _CirclePromo(
            label: '₹25',
            subLabel: 'ONLY',
            onTap: () => _openStore(initialTab: 1),
          ),
        ),
        Positioned(
          left: 20,
          top: 284,
          child: _RoundLetter(onTap: () => _openStore(initialTab: 0)),
        ),
        Positioned(
          left: 18,
          top: 360,
          child: _PlayPromo(
            hasResume: _savedGame != null,
            onTap: _savedGame == null
                ? () => _openStore(initialTab: 0)
                : _resumeGame,
          ),
        ),

        Positioned(
          right: 18,
          top: 180,
          child: _FreePromo(onTap: _claimDailyReward),
        ),
        Positioned(
          right: 22,
          top: 282,
          child: _RoundAction(
            icon: Icons.gps_fixed_rounded,
            fill: const Color(0xFFE93438),
            onTap: () => _openAuthenticated(
              (api) => TournamentScreen(apiClient: api),
            ),
          ),
        ),
        Positioned(
          right: 22,
          top: 352,
          child: _RoundAction(
            icon: Icons.sentiment_satisfied_alt_rounded,
            fill: const Color(0xFFFFC83B),
            iconColor: const Color(0xFF573100),
            onTap: () => _openAuthenticated(
              (api) => FriendsScreen(apiClient: api),
            ),
          ),
        ),
        Positioned(
          right: 28,
          top: 430,
          child: _HelpButton(onTap: () => _showComingSoon('Help')),
        ),

        const Positioned(
          left: 145,
          top: 235,
          width: 416,
          height: 370,
          child: _Hero(),
        ),

        Positioned(
          left: 18,
          top: 680,
          width: 216,
          height: 190,
          child: _ModeCard(
            key: const Key('mode-online'),
            icon: Icons.public_rounded,
            iconColor: const Color(0xFF91DEFF),
            title: 'ONLINE',
            players: '274K',
            onTap: () => _openAuthenticated(
              (api) => MatchmakingScreen(apiClient: api),
            ),
          ),
        ),
        Positioned(
          left: 245,
          top: 680,
          width: 216,
          height: 190,
          child: _ModeCard(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFFFFD83C),
            title: 'TEAM UP',
            players: '5K',
            onTap: () => _openAuthenticated(
              (api) => OnlineRoomScreen(apiClient: api),
            ),
          ),
        ),
        Positioned(
          left: 472,
          top: 680,
          width: 216,
          height: 190,
          child: _ModeCard(
            key: const Key('mode-friends'),
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFFFF5968),
            title: 'FRIENDS',
            players: '24K',
            onTap: _playFriends,
          ),
        ),

        Positioned(
          left: 18,
          top: 892,
          width: 327,
          height: 142,
          child: _LocalModeCard(
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
          top: 892,
          width: 328,
          height: 142,
          child: _LocalModeCard(
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

        Positioned(
          left: 18,
          top: 1085,
          width: 116,
          height: 82,
          child: _SmallEvent(
            top: '7',
            bottom: 'UP DOWN',
            fill: const Color(0xFF173AC5),
            onTap: () => _showComingSoon('Up Down'),
          ),
        ),
        Positioned(
          left: 145,
          top: 1085,
          width: 416,
          height: 82,
          child: _TournamentButton(
            onTap: () => _openAuthenticated(
              (api) => TournamentScreen(apiClient: api),
            ),
          ),
        ),
        Positioned(
          right: 18,
          top: 1085,
          width: 116,
          height: 82,
          child: _SmallEvent(
            top: '₹',
            bottom: 'SNAKES',
            fill: const Color(0xFF08713A),
            onTap: () => _showComingSoon('Snakes'),
          ),
        ),

        Positioned(
          left: 18,
          top: 1192,
          width: 670,
          height: 82,
          child: _ClaimBanner(
            canClaim: _dailyReward?.canClaim ?? false,
            onTap: _claimDailyReward,
          ),
        ),

        Positioned(
          left: 22,
          top: 1352,
          child: _FreeAd(onTap: () => _openStore(initialTab: 1)),
        ),
        Positioned(
          right: 24,
          top: 1340,
          child: _Spin(onTap: () => _openAuthenticated(
            (api) => SeasonScreen(apiClient: api),
          )),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 104,
          child: _BottomNav(
            inviteCount: _roomInvites,
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

class _DotBackground extends StatelessWidget {
  const _DotBackground();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DotPainter(),
        child: const SizedBox.expand(),
      );
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0C1733));
    final paint = Paint()..color = const Color(0xFF17223E);
    for (double y = 160; y < size.height; y += 92) {
      for (double x = 0; x < size.width + 50; x += 92) {
        final shift = ((y / 92).round().isEven) ? 0.0 : 46.0;
        canvas.drawCircle(Offset(x + shift, y), 9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
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
          color: Color(0xFF0D1938),
          border: Border(bottom: BorderSide(color: Color(0xFF1E3E6C), width: 2)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 18,
              top: 18,
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
                        color: const Color(0xFFFFD33A),
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
                      top: -5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF18C85B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -7,
                      bottom: -9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC62E),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF6A4000)),
                        ),
                        child: Text(
                          '★$level',
                          style: const TextStyle(
                            color: Color(0xFF563200),
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
            Positioned(left: 101, top: 30, child: _HeaderSquare(icon: Icons.settings_rounded, fill: const Color(0xFF2C6DD9), onTap: onSettings)),
            Positioned(
              left: 163,
              top: 30,
              child: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: _HeaderSquare(icon: Icons.mail_rounded, fill: const Color(0xFFFFAA0A), onTap: onMail),
              ),
            ),
            Positioned(left: 355, top: 31, child: _CurrencyPill(icon: Icons.diamond_rounded, iconColor: const Color(0xFF67EBFF), value: gems, width: 120, onTap: onCurrency)),
            Positioned(left: 483, top: 31, child: _CurrencyPill(icon: Icons.monetization_on_rounded, iconColor: const Color(0xFFFFD42A), value: coins, width: 144, onTap: onCurrency)),
            Positioned(right: 18, top: 30, child: _HeaderSquare(icon: Icons.shopping_cart_rounded, fill: const Color(0xFFFFA708), onTap: onStore)),
          ],
        ),
      );
}

class _HeaderSquare extends StatelessWidget {
  const _HeaderSquare({required this.icon, required this.fill, required this.onTap});
  final IconData icon;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 51,
          height: 51,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white70, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 3), blurRadius: 3)],
          ),
          child: Icon(icon, color: Colors.white, size: 29),
        ),
      );
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.icon, required this.iconColor, required this.value, required this.width, required this.onTap});
  final IconData icon;
  final Color iconColor;
  final int value;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: width,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF071125),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF28CEF3), width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 5),
              Expanded(child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
              const CircleAvatar(radius: 15, backgroundColor: Color(0xFF19C95C), child: Icon(Icons.add_rounded, color: Colors.white, size: 22)),
            ],
          ),
        ),
      );
}

class _CirclePromo extends StatelessWidget {
  const _CirclePromo({required this.label, required this.subLabel, required this.onTap});
  final String label;
  final String subLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFFFC940), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: Text(label, style: const TextStyle(color: Color(0xFF593200), fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 5),
            Text(subLabel, style: const TextStyle(color: Color(0xFFFFE134), fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _RoundLetter extends StatelessWidget {
  const _RoundLetter({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE8890C), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          child: const Text('K', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
        ),
      );
}

class _PlayPromo extends StatelessWidget {
  const _PlayPromo({required this.hasResume, required this.onTap});
  final bool hasResume;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 65,
          height: 70,
          decoration: BoxDecoration(color: const Color(0xFFFFD027), border: Border.all(color: Colors.white, width: 1.5)),
          child: Column(
            children: [
              Container(height: 25, color: const Color(0xFFE5212C), alignment: Alignment.center, child: Text(hasResume ? 'PLAY' : 'NEW', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))),
              const Expanded(child: Icon(Icons.play_arrow_rounded, color: Color(0xFFE52D34), size: 29)),
            ],
          ),
        ),
      );
}

class _FreePromo extends StatelessWidget {
  const _FreePromo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(width: 57, height: 57, decoration: BoxDecoration(color: const Color(0xFFFFBC18), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 30)),
            const SizedBox(height: 3),
            const Text('FREE', style: TextStyle(color: Color(0xFFFFE032), fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.fill, required this.onTap, this.iconColor = Colors.white});
  final IconData icon;
  final Color fill;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(width: 54, height: 54, decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: Icon(icon, color: iconColor, size: 28)),
      );
}

class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF1A50B2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1AC8F0), width: 2)), child: const Text('?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 23))),
      );
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(top: 0, child: _AdPill()),
          const Positioned(top: 54, child: _Logo()),
          const Positioned(top: 184, left: 18, right: 18, child: _Board()),
        ],
      );
}

class _AdPill extends StatelessWidget {
  const _AdPill();

  @override
  Widget build(BuildContext context) => Container(
        width: 90,
        height: 37,
        decoration: BoxDecoration(color: const Color(0xFF111828), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF50566A), width: 2)),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 11, backgroundColor: Color(0xFFE83D82), child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13)), SizedBox(width: 6), Text('AD', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))]),
      );
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    const letters = ['L', 'U', 'D', 'O'];
    const colors = [Color(0xFF2781ED), Color(0xFFE83844), Color(0xFF25B85A), Color(0xFFFFB510)];
    return SizedBox(
      width: 245,
      height: 125,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const Positioned(top: 0, child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD23E), size: 76, shadows: [Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 4))])),
          Positioned(top: 40, child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(4, (i) => Container(width: 56, height: 70, margin: const EdgeInsets.symmetric(horizontal: 2), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: colors[i], width: 4), boxShadow: [BoxShadow(color: colors[i].withValues(alpha: .8), offset: const Offset(0, 8))]), child: Text(letters[i], style: TextStyle(color: colors[i], fontSize: 40, fontWeight: FontWeight.w900))))),
          const Positioned(bottom: 0, child: Text('KING', style: TextStyle(color: Color(0xFFFFC832), fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 5, shadows: [Shadow(color: Color(0xFF5F3900), offset: Offset(0, 3))]))),
          const Opacity(opacity: 0, child: Text('LUDO KING')),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(left: 36, right: 36, bottom: 22, height: 70, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: const Color(0xFFD8F4FF), border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 7, offset: Offset(0, 7))]), child: const Row(children: [Expanded(child: ColoredBox(color: Color(0xFFE63C42))), SizedBox(width: 6), Expanded(child: ColoredBox(color: Color(0xFF25A851)))]))),
            const Positioned(left: 8, bottom: 12, child: _Pawn(fill: Color(0xFF286DE0), big: true)),
            const Positioned(left: 110, top: 0, child: _Pawn(fill: Color(0xFFE93E48))),
            const Positioned(right: 108, top: 2, child: _Pawn(fill: Color(0xFF26B657))),
            const Positioned(right: 8, bottom: 12, child: _Pawn(fill: Color(0xFFFFB917), big: true)),
            const Positioned(top: 40, child: _Dice()),
          ],
        ),
      );
}

class _Pawn extends StatelessWidget {
  const _Pawn({required this.fill, this.big = false});
  final Color fill;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final scale = big ? 1.0 : .72;
    return Transform.scale(
      scale: scale,
      alignment: Alignment.topCenter,
      child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: fill.withValues(alpha: .88), shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 2))), Transform.translate(offset: const Offset(0, -5), child: Container(width: 56, height: 78, decoration: BoxDecoration(color: fill, borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)))))]),
    );
  }
}

class _Dice extends StatelessWidget {
  const _Dice();

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: .08,
        child: Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Color(0xFF94A5B7), offset: Offset(0, 10)), BoxShadow(color: Colors.black45, blurRadius: 9, offset: Offset(0, 12))]),
          child: const Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_Pip(), _Pip()]), Row(mainAxisAlignment: MainAxisAlignment.center, children: [_Pip(fill: Color(0xFFE72C37))]), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_Pip(), _Pip()])]),
        ),
      );
}

class _Pip extends StatelessWidget {
  const _Pip({this.fill = Colors.black});
  final Color fill;

  @override
  Widget build(BuildContext context) => Container(width: 11, height: 11, decoration: BoxDecoration(color: fill, shape: BoxShape.circle));
}

BoxDecoration _panelDecoration() => BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1596CB), Color(0xFF0475A8)]),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF63E2FF), width: 3),
      boxShadow: const [BoxShadow(color: Color(0xFF032840), offset: Offset(0, 7))],
    );

class _ModeCard extends StatelessWidget {
  const _ModeCard({super.key, required this.icon, required this.iconColor, required this.title, required this.players, required this.onTap});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String players;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          decoration: _panelDecoration(),
          child: Column(
            children: [
              Expanded(child: Center(child: Icon(icon, color: iconColor, size: 52))),
              Container(margin: const EdgeInsets.fromLTRB(7, 0, 7, 8), height: 48, alignment: Alignment.center, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFC23A), Color(0xFFF19700)]), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Color(0xFFB34B00), offset: Offset(0, 7))]), child: Text(title, style: const TextStyle(color: Color(0xFF351B00), fontSize: 20, fontWeight: FontWeight.w900))),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: const BoxDecoration(color: Color(0xFF142B68), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10))),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 5, backgroundColor: Color(0xFF25DD73)),
                    const SizedBox(width: 5),
                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Players: $players', maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _LocalModeCard extends StatelessWidget {
  const _LocalModeCard({super.key, required this.title, required this.icon, required this.onTap});
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          decoration: _panelDecoration(),
          child: Column(
            children: [
              Expanded(child: Center(child: Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFFFC632), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: const Color(0xFF5B3400), size: 32)))),
              Container(margin: const EdgeInsets.fromLTRB(12, 0, 12, 10), height: 46, alignment: Alignment.center, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFC43C), Color(0xFFF19700)]), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Color(0xFFAD4A00), offset: Offset(0, 7))]), child: Text(title, style: const TextStyle(color: Color(0xFF351B00), fontSize: 20, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
      );
}

class _SmallEvent extends StatelessWidget {
  const _SmallEvent({required this.top, required this.bottom, required this.fill, required this.onTap});
  final String top;
  final String bottom;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFFFC51F), width: 3)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(top, style: const TextStyle(color: Color(0xFFFFD43B), fontSize: 23, fontWeight: FontWeight.w900)), Text(bottom, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))]),
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFFE48A00), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFFFE95C), width: 4), boxShadow: const [BoxShadow(color: Color(0xFF7D3C00), offset: Offset(0, 7))]),
          child: const Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Colors.white, size: 31),
              SizedBox(width: 8),
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text('TOURNAMENT', maxLines: 1, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)))),
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
          decoration: BoxDecoration(color: const Color(0xFFFFC42A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0xFF9C4B00), offset: Offset(0, 7))]),
          child: Stack(
            children: [
              Positioned(left: 18, top: 10, bottom: 10, width: 90, child: Container(alignment: Alignment.center, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B25E8), Color(0xFF3322A6)]), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFFFFE328), width: 2)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('SEASON', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)), Text('27', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900))]))),
              Center(child: Text(canClaim ? 'CLAIM' : 'CLAIM', style: const TextStyle(color: Color(0xFF9A4E14), fontSize: 35, fontWeight: FontWeight.w900))),
              const Positioned(right: 24, top: 20, child: Icon(Icons.keyboard_double_arrow_right_rounded, color: Color(0xFFB96E00), size: 40)),
            ],
          ),
        ),
      );
}

class _FreeAd extends StatelessWidget {
  const _FreeAd({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Row(children: [Container(width: 68, height: 68, decoration: BoxDecoration(color: const Color(0xFF2138BA), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFC929), width: 2)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.video_collection_rounded, color: Color(0xFFFFCE28), size: 25), Text('x5', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))])), const SizedBox(width: 10), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('FREE AD', style: TextStyle(color: Color(0xFFFFDA2B), fontSize: 15, fontWeight: FontWeight.w900)), Text('🪙 1000', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))])]),
      );
}

class _Spin extends StatelessWidget {
  const _Spin({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 82,
          height: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: const Color(0xFFFFC02A), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: const Icon(Icons.casino_rounded, color: Color(0xFF4F2B00), size: 32)),
              const SizedBox(height: 3),
              const Text('SPIN', style: TextStyle(color: Color(0xFFFFD638), fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.inviteCount, required this.onEvent, required this.onAdda, required this.onInventory, required this.onSocial});
  final int inviteCount;
  final VoidCallback onEvent;
  final VoidCallback onAdda;
  final VoidCallback onInventory;
  final VoidCallback onSocial;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Color(0xFF233FA4), border: Border(top: BorderSide(color: Color(0xFF1A8EC9), width: 4))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          const _NavItem(icon: Icons.home_rounded, label: 'HOME', active: true),
          _NavItem(icon: Icons.emoji_events_rounded, label: 'EVENT', onTap: onEvent),
          _NavItem(icon: Icons.mic_rounded, label: 'ADDA', raised: true, onTap: onAdda),
          _NavItem(icon: Icons.inventory_2_rounded, label: 'INVENTORY', onTap: onInventory),
          _NavItem(icon: Icons.forum_rounded, label: 'SOCIAL', dot: inviteCount > 0, onTap: onSocial),
        ]),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.active = false, this.raised = false, this.dot = false, this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final bool raised;
  final bool dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 112,
          height: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(clipBehavior: Clip.none, children: [Container(width: 54, height: 54, decoration: BoxDecoration(color: active || raised ? const Color(0xFFFFC12D) : Colors.transparent, borderRadius: BorderRadius.circular(16), border: active || raised ? Border.all(color: Colors.white, width: 2) : null), child: Icon(icon, color: active || raised ? const Color(0xFF5A3100) : const Color(0xFFB9D9F2), size: 29)), if (dot) const Positioned(right: 0, top: 0, child: CircleAvatar(radius: 6, backgroundColor: Color(0xFFFFD124)))]),
              const SizedBox(height: 2),
              FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(color: active || raised ? const Color(0xFFFFE13C) : Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
      );
}
