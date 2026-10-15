import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/notifications_dialog.dart';
import 'package:mobile/src/screens/store_inventory_screen.dart';
import 'package:mobile/src/services/api_client.dart';

class MockPurchasesNotificationsApiClient extends ApiClient {
  bool orderCreated = false;
  bool receiptVerified = false;
  String? lastPurchasedProductId;
  String? lastVerifiedOrderId;
  bool markReadCalled = false;
  bool markAllReadCalled = false;

  final List<NotificationItemModel> notifications = [
    NotificationItemModel(
      id: 'notif_1',
      title: 'Welcome Gift!',
      body: 'Claim 500 bonus coins on your first day.',
      category: 'REWARD',
      isRead: false,
      createdAt: '2026-10-02T12:00:00Z',
    ),
    NotificationItemModel(
      id: 'notif_2',
      title: 'Tournament Starting',
      body: 'Weekend Master Tournament begins in 1 hour.',
      category: 'EVENT',
      isRead: true,
      createdAt: '2026-10-01T10:00:00Z',
    ),
    NotificationItemModel(
      id: 'notif_3',
      title: 'Daily Streak Bonus',
      body: 'Keep your streak alive!',
      category: 'REWARD',
      isRead: false,
      createdAt: '2026-10-02T13:00:00Z',
    ),
  ];

  @override
  Future<List<NotificationItemModel>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    return List.from(notifications);
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    markReadCalled = true;
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final old = notifications[index];
      notifications[index] = NotificationItemModel(
        id: old.id,
        title: old.title,
        body: old.body,
        category: old.category,
        isRead: true,
        dataPayload: old.dataPayload,
        createdAt: old.createdAt,
      );
    }
  }

  @override
  Future<void> markAllNotificationsRead() async {
    markAllReadCalled = true;
    for (int i = 0; i < notifications.length; i++) {
      final old = notifications[i];
      notifications[i] = NotificationItemModel(
        id: old.id,
        title: old.title,
        body: old.body,
        category: old.category,
        isRead: true,
        dataPayload: old.dataPayload,
        createdAt: old.createdAt,
      );
    }
  }

  @override
  Future<List<IapProductModel>> getIapProducts() async {
    return [
      IapProductModel(
        productId: 'coin_pouch_5k',
        title: 'Pouch of Coins',
        description: 'Instantly grants 5,000 Coins',
        currency: 'USD',
        price: 0.99,
        grantCoins: 5000,
        grantGems: 0,
        icon: 'monetization_on',
      ),
      IapProductModel(
        productId: 'gem_bag_300',
        title: 'Bag of Gems',
        description: 'Instantly grants 300 Gems',
        currency: 'USD',
        price: 4.99,
        grantCoins: 0,
        grantGems: 300,
        icon: 'diamond',
      ),
    ];
  }

  @override
  Future<IapOrderModel> createIapOrder({
    required String productId,
    String platform = 'ANDROID',
  }) async {
    orderCreated = true;
    lastPurchasedProductId = productId;
    return IapOrderModel(
      orderId: 'ord_mock_123',
      productId: productId,
      platform: platform,
      price: 0.99,
      currency: 'USD',
      status: 'PENDING',
      createdAt: '2026-10-02T12:00:00Z',
    );
  }

  @override
  Future<VerifyReceiptResultModel> verifyIapReceipt({
    String? productId,
    String? transactionId,
    String? rawReceipt,
    String? receiptPayload,
    String platform = 'ANDROID',
    String? orderId,
  }) async {
    receiptVerified = true;
    lastVerifiedOrderId = orderId ?? transactionId;
    return VerifyReceiptResultModel(
      orderId: orderId,
      status: 'COMPLETED',
      productId: 'coin_pouch_5k',
      grantedCoins: 5000,
      grantedGems: 0,
      walletBalance: {'coins': 6000, 'gems': 100},
    );
  }

  @override
  Future<UserMeModel> getMyAccount() async {
    return UserMeModel(
      id: 'usr_mock_1',
      isGuest: true,
      isVerified: false,
      profile: UserProfileModel(
        userId: 'usr_mock_1',
        playerId: 'LM-00001',
        displayName: 'TestPlayer',
        avatarId: 'avatar_0',
        level: 3,
        xp: 350,
        countryCode: 'GLB',
        isGuest: true,
        isVerified: false,
      ),
      stats: UserStatsModel(
        userId: 'usr_mock_1',
        matchesPlayed: 10,
        matchesWon: 5,
        winRatePercent: 50.0,
        winStreak: 2,
        bestStreak: 4,
        totalCaptures: 15,
        totalTokensHome: 12,
      ),
      wallet: UserWalletModel(userId: 'usr_mock_1', coins: 1000, gems: 100),
    );
  }

  @override
  Future<List<CatalogItemModel>> getCatalog() async {
    return [
      CatalogItemModel(
        id: 'cat_board_neon',
        name: 'Neon Board',
        category: 'BOARD_THEME',
        description: 'Neon theme',
        rarity: 'EPIC',
        priceCoins: 5000,
        priceGems: 50,
        assetKey: 'neon',
        isDefault: false,
        isOwned: false,
        isEquipped: false,
      ),
    ];
  }

  @override
  Future<List<CatalogItemModel>> getInventory() async {
    return [
      CatalogItemModel(
        id: 'cat_board_classic',
        name: 'Classic Board',
        category: 'BOARD_THEME',
        description: 'Classic theme',
        rarity: 'COMMON',
        priceCoins: 0,
        priceGems: 0,
        assetKey: 'classic',
        isDefault: true,
        isOwned: true,
        isEquipped: true,
      ),
    ];
  }
}

void main() {
  testWidgets('NotificationsDialog displays items and marks read/all-read', (
    tester,
  ) async {
    final mockClient = MockPurchasesNotificationsApiClient();
    bool refreshHomeCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsDialog(
            apiClient: mockClient,
            onRefreshHome: () {
              refreshHomeCalled = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dialog title and notifications list
    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('Welcome Gift!'), findsOneWidget);
    expect(
      find.text('Claim 500 bonus coins on your first day.'),
      findsOneWidget,
    );
    expect(find.text('Tournament Starting'), findsOneWidget);
    expect(
      find.text('Weekend Master Tournament begins in 1 hour.'),
      findsOneWidget,
    );

    // Tap on the unread notification to mark as read
    await tester.tap(find.text('Welcome Gift!'));
    await tester.pumpAndSettle();

    expect(mockClient.markReadCalled, isTrue);
    expect(refreshHomeCalled, isTrue);

    // The compact action keeps its accessible label on narrow dialogs.
    expect(find.byTooltip('Mark all as read'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();

    expect(mockClient.markAllReadCalled, isTrue);
  });

  testWidgets(
    'StoreInventoryScreen disables money purchases without a configured store',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockPurchasesNotificationsApiClient();
      bool inventoryChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreInventoryScreen(
            apiClient: mockClient,
            onInventoryChanged: () {
              inventoryChanged = true;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify 3 tabs exist
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Coins & Gems'), findsOneWidget);
      expect(find.text('My Inventory'), findsOneWidget);

      // Switch to Coins & Gems tab
      await tester.tap(find.text('Coins & Gems'));
      await tester.pumpAndSettle();

      // Verify IAP packages render
      expect(find.text('Pouch of Coins'), findsOneWidget);
      expect(find.text('+5000 Coins'), findsOneWidget);

      expect(find.text('Bag of Gems'), findsOneWidget);
      expect(find.text('+300 Gems'), findsOneWidget);

      // Only real store prices may enable a money purchase.
      expect(find.text('UNAVAILABLE'), findsNWidgets(2));
      for (final text in find.text('UNAVAILABLE').evaluate()) {
        final button = find.ancestor(
          of: find.byWidget(text.widget),
          matching: find.byType(ElevatedButton),
        );
        expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      }
      expect(mockClient.orderCreated, isFalse);
      expect(mockClient.receiptVerified, isFalse);
      expect(inventoryChanged, isFalse);
    },
  );
}
