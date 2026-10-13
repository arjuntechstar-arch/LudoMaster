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

/// Arcade-style Ludo lobby based on the supplied visual reference.
class KingLobbyScreen extends ConsumerStatefulWidget {
  const KingLobbyScreen({super.key});

  @override
  ConsumerState<KingLobbyScreen> createState() => _KingLobbyScreenState();
}

class _KingLobbyScreenState extends ConsumerState<KingLobbyScreen> {
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
      // Local play remains available when offline.
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

  void _showNotifications() {
    showDialog<void>(
      context: context,
      builder: (_) => NotificationsDialog(
        apiClient: _apiClient,
        onRefreshHome: _loadAccount,
      ),
    ).then((_) => _refreshBadges());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _account == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF071632),
        body: AppLoader(message: 'Opening game lobby...'),
      );
    }

    final compact = MediaQuery.sizeOf(context).height < 760;
    return Scaffold(
      backgroundColor: const Color(0xFF071632),
      body: Stack(
        children: [
          const Positioned.fill(child: _GameBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopHud(
                  account: _account,
                  notifications: _unreadNotifications,
                  onProfile: _openProfile,
                  onNotifications: _showNotifications,
                  onStore: () => _openStore(initialTab: 0),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          compact ? 8 : 14,
                          16,
                          compact ? 92 : 104,
                        ),
                        child: Column(
                          children: [
                            _Hero(compact: compact),
                            SizedBox(height: compact ? 8 : 14),
                            if (_savedGame != null) ...[
                              _YellowButton(
                                label: 'CONTINUE GAME',
                                icon: Icons.play_circle_fill_rounded,
                                onTap: _resumeGame,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: _ArcadeCard(
                                    key: const Key('mode-online'),
                                    icon: Icons.public_rounded,
                                    title: 'ONLINE',
                                    players: '274,182',
                                    accent: const Color(0xFF72D7FF),
                                    onTap: _playOnline,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ArcadeCard(
                                    icon: Icons.shield_rounded,
                                    title: 'TEAM UP',
                                    players: '5,024',
                                    accent: const Color(0xFFFFD13D),
                                    onTap: () => _openAuthenticated(
                                      (api) => OnlineRoomScreen(apiClient: api),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ArcadeCard(
                                    key: const Key('mode-friends'),
                                    icon: Icons.favorite_rounded,
                                    title: 'FRIENDS',
                                    players: '24,473',
                                    accent: const Color(0xFFFF6675),
                                    onTap: _playFriends,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _WideCard(
                                    key: const Key('mode-computer'),
                                    icon: Icons.smart_toy_rounded,
                                    title: 'COMPUTER',
                                    onTap: () => Navigator.of(context)
                                        .push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => const SetupScreen(
                                              isVsComputer: true,
                                            ),
                                          ),
                                        )
                                        .then((_) => _loadSavedGame()),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _WideCard(
                                    key: const Key('mode-local'),
                                    icon: Icons.people_alt_rounded,
                                    title: 'PASS N PLAY',
                                    onTap: () => Navigator.of(context)
                                        .push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => const SetupScreen(
                                              isVsComputer: false,
                                            ),
                                          ),
                                        )
                                        .then((_) => _loadSavedGame()),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _TournamentRow(
                              onTournament: () => _openAuthenticated(
                                (api) => TournamentScreen(apiClient: api),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ClaimRow(
                              canClaim: _dailyReward?.canClaim ?? false,
                              onTap: _claimDailyReward,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _FreeAd(onTap: () => _openStore(initialTab: 1)),
                                _Spin(
                                  onTap: () => _openAuthenticated(
                                    (api) => SeasonScreen(apiClient: api),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _LeftPromos(onStore: () => _openStore(initialTab: 1)),
                      _RightPromos(
                        onReward: _claimDailyReward,
                        onTournament: () => _openAuthenticated(
                          (api) => TournamentScreen(apiClient: api),
                        ),
                        onSocial: () => _openAuthenticated(
                          (api) => FriendsScreen(apiClient: api),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
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
      ),
    );
  }
}

class _GameBackground extends StatelessWidget {
  const _GameBackground();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _GameBackgroundPainter(),
        child: const SizedBox.expand(),
      );
}

class _GameBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.4),
          radius: 1.25,
          colors: [Color(0xFF173B83), Color(0xFF0D2452), Color(0xFF071632)],
        ).createShader(rect),
    );
    final dot = Paint()..color = Colors.white.withValues(alpha: .055);
    for (double y = 18; y < size.height; y += 52) {
      for (double x = 6; x < size.width + 30; x += 52) {
        final shift = ((y / 52).round().isEven) ? 0.0 : 25.0;
        canvas.drawCircle(Offset(x + shift, y), 6, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.account,
    required this.notifications,
    required this.onProfile,
    required this.onNotifications,
    required this.onStore,
  });

  final UserMeModel? account;
  final int notifications;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final VoidCallback onStore;

  @override
  Widget build(BuildContext context) {
    final profile = account?.profile;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF071A3F).withValues(alpha: .86),
        border: const Border(bottom: BorderSide(color: Color(0xFF234B82))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onProfile,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD23C), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ProfileAvatar(
                      avatarId: profile?.avatarId ?? 'avatar_0',
                      radius: 22,
                    ),
                  ),
                ),
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF24C768),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
                Positioned(
                  left: -4,
                  bottom: -7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD23C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '★ ${profile?.level ?? 1}',
                      style: const TextStyle(
                        color: Color(0xFF6C3C00),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _HudSquare(icon: Icons.settings_rounded, onTap: onProfile),
          const SizedBox(width: 6),
          Badge(
            isLabelVisible: notifications > 0,
            label: Text('$notifications'),
            child: _HudSquare(
              icon: Icons.mail_rounded,
              color: const Color(0xFFFFB000),
              onTap: onNotifications,
            ),
          ),
          const Spacer(),
          _Currency(
            icon: Icons.diamond_rounded,
            value: account?.wallet.gems ?? 150,
            iconColor: const Color(0xFF4BE0FF),
            onTap: onStore,
          ),
          const SizedBox(width: 6),
          _Currency(
            icon: Icons.monetization_on_rounded,
            value: account?.wallet.coins ?? 2930,
            iconColor: const Color(0xFFFFD225),
            onTap: onStore,
          ),
          const SizedBox(width: 6),
          _HudSquare(
            icon: Icons.shopping_cart_rounded,
            color: const Color(0xFFFFB000),
            onTap: onStore,
          ),
        ],
      ),
    );
  }
}

class _HudSquare extends StatelessWidget {
  const _HudSquare({
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF3475D4),
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: .72)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white54),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 3))],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}

class _Currency extends StatelessWidget {
  const _Currency({
    required this.icon,
    required this.value,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final int value;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.fromLTRB(9, 5, 5, 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0A224D), Color(0xFF030A18)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF3BC6F7), width: 1.4),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 17),
              const SizedBox(width: 4),
              Text(
                '$value',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 5),
              const CircleAvatar(
                radius: 10,
                backgroundColor: Color(0xFF24C768),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 15),
              ),
            ],
          ),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF4E81), size: 15),
                SizedBox(width: 4),
                Text('AD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
          const _LudoLogo(),
          SizedBox(height: compact ? 8 : 12),
          SizedBox(height: compact ? 118 : 142, child: const _BoardStage()),
        ],
      );
}

class _LudoLogo extends StatelessWidget {
  const _LudoLogo();

  @override
  Widget build(BuildContext context) {
    const letters = ['L', 'U', 'D', 'O'];
    const colors = [Color(0xFF2E7BEF), Color(0xFFE7333E), Color(0xFF22B95A), Color(0xFFFFB315)];
    return Column(
      children: [
        Transform.translate(
          offset: const Offset(0, 6),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFFFD43B),
            size: 56,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            4,
            (index) => Container(
              width: 50,
              height: 54,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors[index], width: 3),
                boxShadow: [
                  BoxShadow(color: colors[index].withValues(alpha: .75), offset: const Offset(0, 6)),
                  const BoxShadow(color: Colors.black38, blurRadius: 7, offset: Offset(0, 8)),
                ],
              ),
              child: Text(
                letters[index],
                style: TextStyle(color: colors[index], fontSize: 31, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'MASTER',
          style: TextStyle(
            color: Color(0xFFFFD43B),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const Opacity(opacity: 0, child: Text('LUDO MASTER')),
      ],
    );
  }
}

class _BoardStage extends StatelessWidget {
  const _BoardStage();

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 270,
          height: 128,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 22,
                right: 22,
                bottom: 18,
                height: 66,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFEFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 9))],
                  ),
                  child: const Row(
                    children: [
                      Expanded(child: _BoardHalf(color: Color(0xFFE83441))),
                      SizedBox(width: 5),
                      Expanded(child: _BoardHalf(color: Color(0xFF24AA55))),
                    ],
                  ),
                ),
              ),
              const Positioned(left: 3, bottom: 16, child: _Pawn(color: Color(0xFF2475E8), scale: 1)),
              const Positioned(left: 82, top: 2, child: _Pawn(color: Color(0xFFE93B48), scale: .78)),
              const Positioned(right: 75, top: 5, child: _Pawn(color: Color(0xFF27B75B), scale: .82)),
              const Positioned(right: 3, bottom: 16, child: _Pawn(color: Color(0xFFFFC51F), scale: 1)),
              const Positioned(top: 18, child: _Dice()),
            ],
          ),
        ),
      );
}

class _BoardHalf extends StatelessWidget {
  const _BoardHalf({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54),
            ),
          ),
        ),
      );
}

class _Pawn extends StatelessWidget {
  const _Pawn({required this.color, required this.scale});
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) => Transform.scale(
        scale: scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .5), blurRadius: 8)],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: Container(
                width: 40,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: .7)]),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                    bottomLeft: Radius.circular(5),
                    bottomRight: Radius.circular(5),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Dice extends StatelessWidget {
  const _Dice();

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: .08,
        child: Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(color: Color(0xFF8FA3B9), offset: Offset(0, 8)),
              BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 12)),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_Pip(), _Pip()]),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [_Pip(color: Color(0xFFE82936))]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_Pip(), _Pip()]),
            ],
          ),
        ),
      );
}

class _Pip extends StatelessWidget {
  const _Pip({this.color = Colors.black});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _ArcadeCard extends StatelessWidget {
  const _ArcadeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.players,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String players;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 150,
          padding: const EdgeInsets.fromLTRB(7, 10, 7, 8),
          decoration: _cyanPanel(),
          child: Column(
            children: [
              Expanded(child: Icon(icon, color: accent, size: 42)),
              _YellowButton(label: title, onTap: onTap),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.circle, color: Color(0xFF32DE78), size: 10),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Players: $players',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _WideCard extends StatelessWidget {
  const _WideCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 118,
          padding: const EdgeInsets.all(10),
          decoration: _cyanPanel(),
          child: Column(
            children: [
              Expanded(child: Icon(icon, color: const Color(0xFFFFD43B), size: 34)),
              _YellowButton(label: title, onTap: onTap),
            ],
          ),
        ),
      );
}

BoxDecoration _cyanPanel() => BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF159AD4), Color(0xFF0673AB)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF58D3FF), width: 2),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 6))],
    );

class _YellowButton extends StatelessWidget {
  const _YellowButton({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 39,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE267), Color(0xFFF8A70E), Color(0xFFDD7800)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFF0A0)),
            boxShadow: const [
              BoxShadow(color: Color(0xFF843C00), offset: Offset(0, 5)),
              BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: const Color(0xFF5D2D00), size: 20),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4B2400),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _TournamentRow extends StatelessWidget {
  const _TournamentRow({required this.onTournament});
  final VoidCallback onTournament;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const _PromoBlock(label: '7', caption: 'UP DOWN', color: Color(0xFF234DD2)),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTournament,
              child: Container(
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFA600), Color(0xFFE47A00)]),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFFFE58B), width: 2),
                  boxShadow: const [BoxShadow(color: Color(0xFF713000), offset: Offset(0, 5))],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text('TOURNAMENT', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const _PromoBlock(label: '⌁', caption: 'SNAKES', color: Color(0xFF07924D)),
        ],
      );
}

class _PromoBlock extends StatelessWidget {
  const _PromoBlock({required this.label, required this.caption, required this.color});
  final String label;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 78,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFFFD229), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFFFE251), fontSize: 21, fontWeight: FontWeight.w900)),
            Text(caption, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({required this.canClaim, required this.onTap});
  final bool canClaim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFE051), Color(0xFFFFBC19)]),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFFFF0A8), width: 2),
            boxShadow: const [BoxShadow(color: Color(0xFF873C00), offset: Offset(0, 5))],
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6636D6), Color(0xFF3C1B9B)]),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('SEASON', style: TextStyle(color: Color(0xFFFFF17A), fontSize: 9, fontWeight: FontWeight.w900)),
                    Text('27', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  canClaim ? 'CLAIM' : 'REWARDS',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8C3800), fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              const Icon(Icons.double_arrow_rounded, color: Color(0xFFB45A00), size: 29),
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
        child: const Row(
          children: [
            _PromoIcon(icon: Icons.smart_display_rounded, label: 'x5'),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FREE AD', style: TextStyle(color: Color(0xFFFFE657), fontSize: 11, fontWeight: FontWeight.w900)),
                Text('1000 COINS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      );
}

class _PromoIcon extends StatelessWidget {
  const _PromoIcon({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF183BC0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD229), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFFD229), size: 24),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _Spin extends StatelessWidget {
  const _Spin({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: const Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Color(0xFFFFC32A),
              child: Icon(Icons.settings_suggest_rounded, color: Color(0xFF693300), size: 30),
            ),
            SizedBox(height: 3),
            Text('SPIN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _LeftPromos extends StatelessWidget {
  const _LeftPromos({required this.onStore});
  final VoidCallback onStore;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 8,
        top: 18,
        child: Column(
          children: [
            _RoundPromo(label: '₹25', caption: 'ONLY', color: const Color(0xFFFFC83D), onTap: onStore),
            const SizedBox(height: 12),
            _RoundPromo(label: 'K', caption: 'VIP', color: const Color(0xFFE29400), onTap: onStore),
          ],
        ),
      );
}

class _RightPromos extends StatelessWidget {
  const _RightPromos({
    required this.onReward,
    required this.onTournament,
    required this.onSocial,
  });

  final VoidCallback onReward;
  final VoidCallback onTournament;
  final VoidCallback onSocial;

  @override
  Widget build(BuildContext context) => Positioned(
        right: 8,
        top: 18,
        child: Column(
          children: [
            _RoundPromo(icon: Icons.card_giftcard_rounded, caption: 'FREE', color: const Color(0xFFFFB000), onTap: onReward),
            const SizedBox(height: 12),
            _RoundPromo(icon: Icons.track_changes_rounded, color: const Color(0xFFE9303E), onTap: onTournament),
            const SizedBox(height: 12),
            _RoundPromo(icon: Icons.emoji_emotions_rounded, color: const Color(0xFFFFC43D), onTap: onSocial),
          ],
        ),
      );
}

class _RoundPromo extends StatelessWidget {
  const _RoundPromo({
    required this.color,
    required this.onTap,
    this.label,
    this.caption,
    this.icon,
  });

  final Color color;
  final VoidCallback onTap;
  final String? label;
  final String? caption;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: .7)]),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 7, offset: Offset(0, 4))],
              ),
              child: icon != null
                  ? Icon(icon, color: Colors.white, size: 24)
                  : Text(
                      label ?? '',
                      style: const TextStyle(color: Color(0xFF633200), fontSize: 15, fontWeight: FontWeight.w900),
                    ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 3),
              Text(
                caption!,
                style: const TextStyle(
                  color: Color(0xFFFFE45A),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 2)],
                ),
              ),
            ],
          ],
        ),
      );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.inviteCount,
    required this.onEvent,
    required this.onAdda,
    required this.onInventory,
    required this.onSocial,
  });

  final int inviteCount;
  final VoidCallback onEvent;
  final VoidCallback onAdda;
  final VoidCallback onInventory;
  final VoidCallback onSocial;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          height: 78,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2851C0), Color(0xFF17358F)]),
            border: Border(top: BorderSide(color: Color(0xFF3EB9F5), width: 2)),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const _NavItem(icon: Icons.home_rounded, label: 'HOME', selected: true),
              _NavItem(icon: Icons.emoji_events_rounded, label: 'EVENT', onTap: onEvent),
              _NavItem(icon: Icons.mic_rounded, label: 'ADDA', badge: 'NEW', onTap: onAdda),
              _NavItem(icon: Icons.inventory_2_rounded, label: 'INVENTORY', onTap: onInventory),
              _NavItem(
                icon: Icons.forum_rounded,
                label: 'SOCIAL',
                badge: inviteCount > 0 ? '$inviteCount' : null,
                onTap: onSocial,
              ),
            ],
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final String? badge;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: selected ? 42 : 34,
                    height: selected ? 42 : 34,
                    decoration: selected
                        ? BoxDecoration(
                            color: const Color(0xFFFFC02B),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: const Color(0xFFFFF09A), width: 1.5),
                          )
                        : null,
                    child: Icon(
                      icon,
                      color: selected ? const Color(0xFF603000) : const Color(0xFFCFE3FF),
                      size: selected ? 25 : 23,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF13643),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFFFE769) : Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
}
