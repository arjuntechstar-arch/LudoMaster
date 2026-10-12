import 'api_client.dart';

/// Cosmetic selections granted by the server inventory.
class CosmeticSelection {
  static String boardTheme = 'theme_classic_wood';
  static String diceSkin = 'dice_classic_ivory';
  static String frame = 'frame_standard';

  static void applyInventory(List<CatalogItemModel> inventory) {
    boardTheme = 'theme_classic_wood';
    diceSkin = 'dice_classic_ivory';
    frame = 'frame_standard';
    for (final item in inventory.where((item) => item.isEquipped)) {
      switch (item.category) {
        case 'BOARD_THEME':
          boardTheme = item.id;
          break;
        case 'DICE_SKIN':
          diceSkin = item.assetKey == 'dice_ivory'
              ? 'dice_classic_ivory'
              : item.assetKey;
          break;
        case 'FRAME':
          frame = item.assetKey;
          break;
      }
    }
  }

  static Future<void> refresh(ApiClient apiClient) async {
    applyInventory(await apiClient.getInventory());
  }
}
