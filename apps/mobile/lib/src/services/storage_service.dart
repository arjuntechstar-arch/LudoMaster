import 'dart:convert';
import 'package:game_engine/game_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence service for pausing, saving, and resuming offline games.
class StorageService {
  static const String _keyActiveGame = 'ludomaster_active_game_state';
  static const String _keySound = 'ludomaster_setting_sound';
  static const String _keyHaptics = 'ludomaster_setting_haptics';

  /// Saves the active offline match state to local storage.
  static Future<void> saveActiveGame(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(state.toJson());
    await prefs.setString(_keyActiveGame, jsonStr);
  }

  /// Loads the saved match state, or returns null if no saved game exists.
  static Future<GameState?> loadActiveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyActiveGame);
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final state = GameState.fromJson(map);

      // Don't restore games that were already finished
      if (state.status == GameStatus.finished) {
        await clearActiveGame();
        return null;
      }

      return state;
    } catch (_) {
      await clearActiveGame();
      return null;
    }
  }

  /// Clears any saved game when match ends or player explicitly quits.
  static Future<void> clearActiveGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveGame);
  }

  /// Checks if a resumable saved game exists.
  static Future<bool> hasSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyActiveGame);
  }

  static const String _keyLanguage = 'ludomaster_setting_language';
  static const String _keyHighContrast = 'ludomaster_setting_high_contrast';
  static const String _keyLargeText = 'ludomaster_setting_large_text';

  /// Loads sound setting (default true).
  static Future<bool> getSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySound) ?? true;
  }

  /// Saves sound setting.
  static Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySound, enabled);
  }

  /// Loads haptics setting (default true).
  static Future<bool> getHapticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHaptics) ?? true;
  }

  /// Saves haptics setting.
  static Future<void> setHapticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHaptics, enabled);
  }

  /// Loads selected language code (default 'en').
  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'en';
  }

  /// Saves selected language code.
  static Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, code);
  }

  /// Loads high-contrast accessibility preference (default false).
  static Future<bool> getHighContrastEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHighContrast) ?? false;
  }

  /// Saves high-contrast accessibility preference.
  static Future<void> setHighContrastEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHighContrast, enabled);
  }

  /// Loads large text accessibility preference (default false).
  static Future<bool> getLargeTextEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLargeText) ?? false;
  }

  /// Saves large text accessibility preference.
  static Future<void> setLargeTextEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLargeText, enabled);
  }
}
