import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/cosmetic_selection.dart';
import '../services/billing_service.dart';
import '../widgets/auth_dialog.dart';
import '../theme/app_colors.dart';

/// Screen offering the Cosmetic Shop and Player Inventory (Boards, Dice, Frames).
class StoreInventoryScreen extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback? onInventoryChanged;
  final int initialTabIndex;

  const StoreInventoryScreen({
    super.key,
    required this.apiClient,
    this.onInventoryChanged,
    this.initialTabIndex = 0,
  });

  @override
  State<StoreInventoryScreen> createState() => _StoreInventoryScreenState();
}

class _StoreInventoryScreenState extends State<StoreInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<CatalogItemModel> _catalog = [];
  List<CatalogItemModel> _inventory = [];
  List<IapProductModel> _iapProducts = [];
  bool _isPurchasingIap = false;
  final BillingService _billing = BillingService.instance;
  int _completedPurchases = 0;
  int _userCoins = 0;
  int _userGems = 0;

  String _selectedCategory = 'ALL'; // ALL, BOARD_THEME, DICE_SKIN, FRAME

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
    _completedPurchases = _billing.completedPurchases;
    _billing.addListener(_billingChanged);
  }

  void _billingChanged() {
    if (!mounted) return;
    setState(() => _isPurchasingIap = _billing.busy);
    if (_billing.completedPurchases != _completedPurchases) {
      _completedPurchases = _billing.completedPurchases;
      widget.onInventoryChanged?.call();
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _billing.removeListener(_billingChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final catalogFuture = widget.apiClient.getCatalog();
      final inventoryFuture = widget.apiClient.getInventory();
      final meFuture = widget.apiClient.getMyAccount();
      final iapFuture = widget.apiClient.getIapProducts();

      final results = await Future.wait([
        catalogFuture,
        inventoryFuture,
        meFuture,
        iapFuture.catchError((_) => <IapProductModel>[]),
      ]);
      final catalog = results[0] as List<CatalogItemModel>;
      final inventory = results[1] as List<CatalogItemModel>;
      CosmeticSelection.applyInventory(inventory);
      final me = results[2] as UserMeModel;
      final iap = results[3] as List<IapProductModel>;
      await _billing.initialize(widget.apiClient);

      if (mounted) {
        setState(() {
          _catalog = catalog;
          _inventory = inventory;
          _iapProducts = iap;
          _userCoins = me.wallet.coins;
          _userGems = me.wallet.gems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toUpperCase()) {
      case 'LEGENDARY':
        return AppColors.gold;
      case 'EPIC':
        return const Color(0xFFA855F7);
      case 'RARE':
        return const Color(0xFF3B82F6);
      case 'COMMON':
      default:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'BOARD_THEME':
        return Icons.grid_4x4;
      case 'DICE_SKIN':
        return Icons.casino;
      case 'FRAME':
        return Icons.portrait;
      default:
        return Icons.category;
    }
  }

  Future<void> _purchaseItem(CatalogItemModel item, String currency) async {
    final cost = currency == 'GEMS' ? item.priceGems : item.priceCoins;
    final balance = currency == 'GEMS' ? _userGems : _userCoins;

    if (balance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient $currency! You have $balance but need $cost.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      await widget.apiClient.purchaseStoreItem(item.id, currency: currency);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully purchased ${item.name}!'),
          backgroundColor: AppColors.green,
        ),
      );
      widget.onInventoryChanged?.call();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchase failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showPurchaseDialog(CatalogItemModel item) {
    final cashProducts = _iapProducts.where(
      (product) => product.itemId == item.id,
    );
    final cashProduct = cashProducts.isEmpty ? null : cashProducts.first;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final rarityColor = _getRarityColor(item.rarity);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: rarityColor, width: 2),
                    ),
                    child: Icon(
                      _getCategoryIcon(item.category),
                      color: rarityColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.rarity,
                            style: TextStyle(
                              color: rarityColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                item.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Payment Currency:',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (item.priceCoins > 0)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEAB308),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.monetization_on, size: 20),
                        label: Text(
                          '${item.priceCoins} Coins',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _purchaseItem(item, 'COINS');
                        },
                      ),
                    ),
                  if (item.priceCoins > 0 && item.priceGems > 0)
                    const SizedBox(width: 12),
                  if (item.priceGems > 0)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.diamond, size: 20),
                        label: Text(
                          '${item.priceGems} Gems',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _purchaseItem(item, 'GEMS');
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (cashProduct != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.payment),
                  label: Text(
                    _billing.priceFor(cashProduct.id) == null
                        ? 'Money purchase unavailable'
                        : 'Buy for ${_billing.priceFor(cashProduct.id)}',
                  ),
                  onPressed:
                      _billing.priceFor(cashProduct.id) == null || _billing.busy
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          _purchaseIapProduct(cashProduct);
                        },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _equipItem(CatalogItemModel item) async {
    try {
      await widget.apiClient.equipCosmeticItem(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Equipped ${item.name}!'),
          backgroundColor: AppColors.green,
        ),
      );
      widget.onInventoryChanged?.call();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Equip failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('STORE & CUSTOMIZATION'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.storefront), text: 'Shop'),
            Tab(icon: Icon(Icons.shopping_bag), text: 'Coins & Gems'),
            Tab(icon: Icon(Icons.inventory_2), text: 'My Inventory'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Balance Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: AppColors.surface,
              child: Row(
                children: [
                  const Text(
                    'Your Balance',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _buildBalanceChip(
                    icon: Icons.monetization_on,
                    amount: _userCoins,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 8),
                  _buildBalanceChip(
                    icon: Icons.diamond,
                    amount: _userGems,
                    color: const Color(0xFF06B6D4),
                  ),
                ],
              ),
            ),

            // Category Filter Chips (only for Cosmetics & Inventory)
            if (_tabController.index != 1)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryFilterChip('ALL', 'All Items'),
                      const SizedBox(width: 8),
                      _buildCategoryFilterChip('BOARD_THEME', 'Boards'),
                      const SizedBox(width: 8),
                      _buildCategoryFilterChip('DICE_SKIN', 'Dice Skins'),
                      const SizedBox(width: 8),
                      _buildCategoryFilterChip('FRAME', 'Frames'),
                    ],
                  ),
                ),
              ),

            // Main Body: Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('RETRY'),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildShopGrid(),
                        _buildIapStoreGrid(),
                        _buildInventoryGrid(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceChip({
    required IconData icon,
    required int amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            amount.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.gold,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.textSecondary,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _selectedCategory = category;
        });
      },
    );
  }

  List<CatalogItemModel> _filterList(List<CatalogItemModel> list) {
    if (_selectedCategory == 'ALL') return list;
    return list.where((item) => item.category == _selectedCategory).toList();
  }

  Widget _buildShopGrid() {
    final filtered = _filterList(_catalog);

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'No items available in this category.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.gold,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildItemCard(item: item, isShop: true);
        },
      ),
    );
  }

  Widget _buildInventoryGrid() {
    final filtered = _filterList(_inventory);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textSecondary,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'No items owned in this category.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('VISIT SHOP'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.gold,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildItemCard(item: item, isShop: false);
        },
      ),
    );
  }

  Widget _buildIapStoreGrid() {
    if (_iapProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.textSecondary,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'No store packages available right now.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('REFRESH')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _billing.notice ??
                (BillingService.supportsGooglePlay
                    ? 'Pay securely with Google Play. Purchases are verified before delivery.'
                    : 'Money purchases are available in the Android app through Google Play.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        if (_billing.available)
          TextButton(
            onPressed: _billing.restorePurchases,
            child: const Text('RESTORE PURCHASES'),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.gold,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              itemCount: _iapProducts.length,
              itemBuilder: (context, index) {
                final product = _iapProducts[index];
                return _buildIapCard(product);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIapCard(IapProductModel product) {
    final isCosmetic = product.itemId != null;
    final owned =
        isCosmetic && _inventory.any((item) => item.id == product.itemId);
    final bool isGemProduct = product.grantGems > 0 && product.grantCoins == 0;
    final bool isBundle = product.grantGems > 0 && product.grantCoins > 0;
    final themeColor = isBundle
        ? AppColors.gold
        : isGemProduct
        ? const Color(0xFF06B6D4)
        : const Color(0xFFEAB308);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isCosmetic
                      ? 'COSMETIC'
                      : isBundle
                      ? 'BUNDLE'
                      : (isGemProduct ? 'GEMS' : 'COINS'),
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Visual Icon Preview
          Expanded(
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeColor.withValues(alpha: 0.1),
                  border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  isCosmetic
                      ? Icons.auto_awesome
                      : isBundle
                      ? Icons.card_giftcard
                      : isGemProduct
                      ? Icons.diamond
                      : Icons.monetization_on,
                  color: themeColor,
                  size: 34,
                ),
              ),
            ),
          ),

          // Title & Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCosmetic
                      ? 'Permanent unlock'
                      : product.grantCoins > 0 && product.grantGems > 0
                      ? '+${product.grantCoins} Coins & ${product.grantGems} Gems'
                      : product.grantCoins > 0
                      ? '+${product.grantCoins} Coins'
                      : '+${product.grantGems} Gems',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Price / Purchase button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 32,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.zero,
                ),
                onPressed:
                    owned ||
                        _isPurchasingIap ||
                        _billing.priceFor(product.id) == null
                    ? null
                    : () => _purchaseIapProduct(product),
                child: _isPurchasingIap
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        owned
                            ? 'OWNED'
                            : _billing.priceFor(product.id) ?? 'UNAVAILABLE',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseIapProduct(IapProductModel product) async {
    try {
      if (widget.apiClient.isGuest == true) {
        await showDialog<void>(
          context: context,
          builder: (_) => AuthDialog(
            apiClient: widget.apiClient,
            onAuthenticated: _loadData,
          ),
        );
        if (!mounted || widget.apiClient.isGuest == true) return;
      }
      await _billing.purchase(product);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchase failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildItemCard({
    required CatalogItemModel item,
    required bool isShop,
  }) {
    final rarityColor = _getRarityColor(item.rarity);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isEquipped
              ? AppColors.green
              : rarityColor.withValues(alpha: 0.4),
          width: item.isEquipped ? 2.0 : 1.2,
        ),
        boxShadow: [
          if (item.isEquipped)
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rarity & Equiped Header
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.rarity,
                    style: TextStyle(
                      color: rarityColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (item.isEquipped)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: AppColors.green, size: 10),
                        SizedBox(width: 2),
                        Text(
                          'EQUIPPED',
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Visual Preview
          Expanded(
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rarityColor.withValues(alpha: 0.1),
                  border: Border.all(color: rarityColor.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  _getCategoryIcon(item.category),
                  color: rarityColor,
                  size: 34,
                ),
              ),
            ),
          ),

          // Title & Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Bottom Action Button / Price
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildCardActionButton(item, isShop),
          ),
        ],
      ),
    );
  }

  Widget _buildCardActionButton(CatalogItemModel item, bool isShop) {
    if (item.isEquipped) {
      return Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'IN USE',
          style: TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }

    if (item.isOwned || !isShop) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surfaceElevated,
            foregroundColor: AppColors.gold,
            padding: EdgeInsets.zero,
            side: const BorderSide(color: AppColors.gold, width: 1),
          ),
          onPressed: () => _equipItem(item),
          child: const Text(
            'EQUIP',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // Shop purchase button
    final bool hasCoins = item.priceCoins > 0;
    final bool hasGems = item.priceGems > 0;

    return SizedBox(
      height: 32,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasGems && !hasCoins
              ? const Color(0xFF06B6D4)
              : AppColors.gold,
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
        ),
        onPressed: () => _showPurchaseDialog(item),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasGems && !hasCoins ? Icons.diamond : Icons.monetization_on,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              hasCoins ? '${item.priceCoins}' : '${item.priceGems}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
