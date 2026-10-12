import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:mobile/src/board/dice_widget.dart';
import 'package:mobile/src/board/ludo_board_widget.dart';
import 'package:mobile/src/screens/achievements_screen.dart';
import 'package:mobile/src/screens/daily_rewards_dialog.dart';
import 'package:mobile/src/screens/missions_screen.dart';
import 'package:mobile/src/screens/store_inventory_screen.dart';
import 'package:mobile/src/services/api_client.dart';

class MockEconomyApiClient extends ApiClient {
  bool dailyRewardClaimed = false;
  bool missionClaimed = false;
  bool achievementClaimed = false;
  bool itemPurchased = false;
  bool itemEquipped = false;

  @override
  Future<DailyRewardStatusModel> getDailyRewardStatus() async {
    return DailyRewardStatusModel(
      currentStreak: 3,
      canClaim: !dailyRewardClaimed,
      days: List.generate(7, (i) {
        final dayNum = i + 1;
        return DailyRewardDayModel(
          day: dayNum,
          coins: dayNum * 250,
          gems: dayNum * 5,
          xp: dayNum * 50,
          isClaimed: dayNum < 3 || (dayNum == 3 && dailyRewardClaimed),
          isToday: dayNum == 3,
        );
      }),
    );
  }

  @override
  Future<ClaimDailyRewardModel> claimDailyReward() async {
    dailyRewardClaimed = true;
    return ClaimDailyRewardModel(
      message: 'Claimed Day 3 reward!',
      day: 3,
      coinsAwarded: 750,
      gemsAwarded: 15,
      xpAwarded: 150,
      newBalanceCoins: 2500,
      newBalanceGems: 65,
      newLevel: 2,
      newXp: 200,
    );
  }

  @override
  Future<List<MissionModel>> getMissions() async {
    return [
      MissionModel(
        id: 'mission_daily_1',
        title: 'Roll Three Sixes',
        description: 'Roll a 6 three times in any match',
        category: 'DAILY',
        actionType: 'ROLL_SIX',
        currentCount: 3,
        targetCount: 3,
        rewardCoins: 300,
        rewardGems: 5,
        rewardXp: 50,
        icon: 'casino',
        isCompleted: true,
        isClaimed: missionClaimed,
      ),
      MissionModel(
        id: 'mission_weekly_1',
        title: 'Weekly Champion',
        description: 'Win 5 multiplayer matches this week',
        category: 'WEEKLY',
        actionType: 'MATCH_WIN',
        currentCount: 2,
        targetCount: 5,
        rewardCoins: 1500,
        rewardGems: 25,
        rewardXp: 250,
        icon: 'emoji_events',
        isCompleted: false,
        isClaimed: false,
      ),
    ];
  }

  @override
  Future<ClaimMissionModel> claimMission(String missionId) async {
    missionClaimed = true;
    return ClaimMissionModel(
      missionId: missionId,
      coinsAwarded: 300,
      gemsAwarded: 5,
      xpAwarded: 50,
      newBalanceCoins: 2800,
      newBalanceGems: 70,
      newLevel: 2,
      newXp: 250,
    );
  }

  @override
  Future<List<AchievementModel>> getAchievements() async {
    return [
      AchievementModel(
        id: 'ach_first_blood',
        title: 'First Blood',
        description: 'Capture your first opponent token',
        actionType: 'TOKEN_CAPTURE',
        currentCount: 1,
        targetCount: 1,
        rewardCoins: 500,
        rewardGems: 10,
        rewardXp: 100,
        badgeKey: 'badge_first_blood',
        isUnlocked: true,
        isClaimed: achievementClaimed,
      ),
      AchievementModel(
        id: 'ach_century',
        title: 'Century Club',
        description: 'Play 100 total matches',
        actionType: 'MATCH_PLAY',
        currentCount: 12,
        targetCount: 100,
        rewardCoins: 5000,
        rewardGems: 100,
        rewardXp: 1000,
        badgeKey: 'badge_century',
        isUnlocked: false,
        isClaimed: false,
      ),
    ];
  }

  @override
  Future<ClaimAchievementModel> claimAchievement(String achievementId) async {
    achievementClaimed = true;
    return ClaimAchievementModel(
      achievementId: achievementId,
      coinsAwarded: 500,
      gemsAwarded: 10,
      xpAwarded: 100,
      newBalanceCoins: 3300,
      newBalanceGems: 80,
      newLevel: 2,
      newXp: 350,
    );
  }

  @override
  Future<List<CatalogItemModel>> getCatalog() async {
    return [
      CatalogItemModel(
        id: 'cat_board_neon',
        name: 'Neon Cyber Board',
        category: 'BOARD_THEME',
        description: 'Futuristic glowing neon aesthetic',
        rarity: 'EPIC',
        priceCoins: 5000,
        priceGems: 50,
        assetKey: 'theme_neon_cyber',
        isDefault: false,
        isOwned: itemPurchased,
        isEquipped: itemEquipped,
      ),
      CatalogItemModel(
        id: 'cat_dice_gold',
        name: 'Golden Emperor Dice',
        category: 'DICE_SKIN',
        description: 'Pure 24k gold dice with engraved pips',
        rarity: 'LEGENDARY',
        priceCoins: 10000,
        priceGems: 100,
        assetKey: 'dice_gold',
        isDefault: false,
        isOwned: false,
        isEquipped: false,
      ),
    ];
  }

  @override
  Future<List<CatalogItemModel>> getInventory() async {
    final list = <CatalogItemModel>[
      CatalogItemModel(
        id: 'cat_board_classic',
        name: 'Classic Wood Board',
        category: 'BOARD_THEME',
        description: 'Traditional handcrafted wooden board',
        rarity: 'COMMON',
        priceCoins: 0,
        priceGems: 0,
        assetKey: 'theme_classic_wood',
        isDefault: true,
        isOwned: true,
        isEquipped: !itemEquipped,
      ),
    ];
    if (itemPurchased) {
      list.add(
        CatalogItemModel(
          id: 'cat_board_neon',
          name: 'Neon Cyber Board',
          category: 'BOARD_THEME',
          description: 'Futuristic glowing neon aesthetic',
          rarity: 'EPIC',
          priceCoins: 5000,
          priceGems: 50,
          assetKey: 'theme_neon_cyber',
          isDefault: false,
          isOwned: true,
          isEquipped: itemEquipped,
        ),
      );
    }
    return list;
  }

  @override
  Future<void> purchaseStoreItem(String itemId, {String currency = 'COINS'}) async {
    itemPurchased = true;
  }

  @override
  Future<void> equipCosmeticItem(String itemId) async {
    itemEquipped = true;
  }

  @override
  Future<UserMeModel> getMyAccount() async {
    return UserMeModel(
      id: 'user_test_123',
      isGuest: true,
      isVerified: false,
      profile: UserProfileModel(
        userId: 'user_test_123',
        playerId: 'LM-99999',
        displayName: 'Test Champion',
        avatarId: 'avatar_1',
        level: 2,
        xp: 150,
        countryCode: 'USA',
        isGuest: true,
        isVerified: false,
      ),
      stats: UserStatsModel(
        userId: 'user_test_123',
        matchesPlayed: 10,
        matchesWon: 6,
        winRatePercent: 60.0,
        winStreak: 3,
        bestStreak: 4,
        totalCaptures: 15,
        totalTokensHome: 12,
      ),
      wallet: UserWalletModel(
        userId: 'user_test_123',
        coins: 10000,
        gems: 150,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8 Economy & Progression Widgets', () {
    testWidgets('DailyRewardsDialog renders 7-day calendar and claims reward', (tester) async {
      final mock = MockEconomyApiClient();
      bool rewardClaimedNotified = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  DailyRewardsDialog.show(
                    ctx,
                    mock,
                    onRewardClaimed: () => rewardClaimedNotified = true,
                  );
                },
                child: const Text('OPEN DIALOG'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pumpAndSettle();

      // Verify streak and titles
      expect(find.text('DAILY REWARDS'), findsOneWidget);
      expect(find.textContaining('Streak: 3 Days'), findsOneWidget);
      expect(find.text('DAY 1'), findsOneWidget);
      expect(find.text('DAY 7 BONUS'), findsOneWidget);

      // Verify claim button is active for Day 3
      final claimBtn = find.text('CLAIM DAY 3 REWARD');
      expect(claimBtn, findsOneWidget);

      await tester.tap(claimBtn);
      await tester.pumpAndSettle();

      expect(mock.dailyRewardClaimed, isTrue);
      expect(rewardClaimedNotified, isTrue);
      expect(find.text('Claimed Day 3 reward!'), findsOneWidget);
    });

    testWidgets('MissionsScreen displays daily/weekly missions and allows claiming', (tester) async {
      final mock = MockEconomyApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: MissionsScreen(apiClient: mock),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('MISSIONS & QUESTS'), findsOneWidget);
      expect(find.textContaining('DAILY ('), findsOneWidget);
      expect(find.textContaining('WEEKLY ('), findsOneWidget);

      // Daily mission
      expect(find.text('Roll Three Sixes'), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);

      final claimBtn = find.text('CLAIM');
      expect(claimBtn, findsOneWidget);

      await tester.tap(claimBtn);
      await tester.pumpAndSettle();

      expect(mock.missionClaimed, isTrue);

      // Switch to Weekly tab
      await tester.tap(find.textContaining('WEEKLY ('));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Champion'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
    });

    testWidgets('AchievementsScreen displays milestones and badges', (tester) async {
      final mock = MockEconomyApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: AchievementsScreen(apiClient: mock),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ACHIEVEMENTS & BADGES'), findsOneWidget);
      expect(find.text('First Blood'), findsOneWidget);
      expect(find.text('Capture your first opponent token'), findsOneWidget);
      expect(find.text('Century Club'), findsOneWidget);

      // Claim first blood
      final claimBtn = find.text('CLAIM');
      expect(claimBtn, findsOneWidget);

      await tester.tap(claimBtn);
      await tester.pumpAndSettle();

      expect(mock.achievementClaimed, isTrue);
    });

    testWidgets('StoreInventoryScreen filters categories, purchases and equips items', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mock = MockEconomyApiClient();
      bool inventoryChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreInventoryScreen(
            apiClient: mock,
            onInventoryChanged: () => inventoryChanged = true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top balance bar
      expect(find.text('Your Balance'), findsOneWidget);
      expect(find.text('10000'), findsNWidgets(2)); // User coins balance + Gold dice price
      expect(find.text('150'), findsOneWidget); // gems

      // Tab bar
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('My Inventory'), findsOneWidget);

      // Filter chips
      expect(find.text('All Items'), findsOneWidget);
      expect(find.text('Boards'), findsOneWidget);
      expect(find.text('Dice Skins'), findsOneWidget);
      expect(find.text('Frames'), findsOneWidget);

      // Item in shop
      expect(find.text('Neon Cyber Board'), findsOneWidget);
      expect(find.text('Golden Emperor Dice'), findsOneWidget);

      // Tap buy on Neon Cyber Board
      final buyButton = find.text('5000');
      expect(buyButton, findsOneWidget);
      await tester.tap(buyButton);
      await tester.pumpAndSettle();

      // Modal shows purchase options
      expect(find.text('Select Payment Currency:'), findsOneWidget);
      expect(find.text('5000 Coins'), findsOneWidget);

      await tester.tap(find.text('5000 Coins'));
      await tester.pumpAndSettle();

      expect(mock.itemPurchased, isTrue);
      expect(inventoryChanged, isTrue);

      // Switch to Inventory tab
      await tester.tap(find.text('My Inventory'));
      await tester.pumpAndSettle();

      expect(find.text('Neon Cyber Board'), findsOneWidget);
      final equipButton = find.text('EQUIP');
      expect(equipButton, findsOneWidget);

      await tester.tap(equipButton);
      await tester.pumpAndSettle();

      expect(mock.itemEquipped, isTrue);
    });

    testWidgets('LudoBoardPainter and DiceWidget support theme and skin customizers', (tester) async {
      final p1Tokens = List.generate(4, (i) => Token(id: 'red_$i', color: PlayerColor.red));
      final p2Tokens = List.generate(4, (i) => Token(id: 'green_$i', color: PlayerColor.green));
      final gameState = GameState(
        matchId: 'test_match',
        ruleset: const RulesetConfig(),
        status: GameStatus.inProgress,
        phase: GamePhase.rollRequired,
        currentSeat: 0,
        players: [
          PlayerState(id: 'p1', name: 'Alice', seat: 0, color: PlayerColor.red, tokens: p1Tokens),
          PlayerState(id: 'p2', name: 'Bob', seat: 1, color: PlayerColor.green, tokens: p2Tokens),
        ],
      );

      // Verify LudoBoardWidget renders with custom board theme
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LudoBoardWidget(
              gameState: gameState,
              boardThemeAssetKey: 'theme_neon_cyber',
              onTokenTapped: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(LudoBoardWidget), findsOneWidget);

      // Verify DiceWidget renders with custom gold dice skin
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiceWidget(
              diceValue: 6,
              canRoll: true,
              playerColor: PlayerColor.yellow,
              diceSkinAssetKey: 'dice_gold',
              onRoll: () {},
            ),
          ),
        ),
      );
      expect(find.byType(DiceWidget), findsOneWidget);
    });
  });
}
