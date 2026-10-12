import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';

import '../services/audio_service.dart';
import '../services/storage_service.dart';

class SettingsState {
  const SettingsState({
    required this.soundEnabled,
    required this.hapticsEnabled,
    this.defaultDifficulty = BotDifficulty.hard,
    this.languageCode = 'en',
    this.highContrast = false,
    this.largeText = false,
  });

  final bool soundEnabled;
  final bool hapticsEnabled;
  final BotDifficulty defaultDifficulty;
  final String languageCode;
  final bool highContrast;
  final bool largeText;

  SettingsState copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
    BotDifficulty? defaultDifficulty,
    String? languageCode,
    bool? highContrast,
    bool? largeText,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      defaultDifficulty: defaultDifficulty ?? this.defaultDifficulty,
      languageCode: languageCode ?? this.languageCode,
      highContrast: highContrast ?? this.highContrast,
      largeText: largeText ?? this.largeText,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController()
    : super(
        const SettingsState(
          soundEnabled: true,
          hapticsEnabled: true,
          languageCode: 'en',
          highContrast: false,
          largeText: false,
        ),
      ) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sound = await StorageService.getSoundEnabled();
    final haptics = await StorageService.getHapticsEnabled();
    final lang = await StorageService.getLanguage();
    final contrast = await StorageService.getHighContrastEnabled();
    final text = await StorageService.getLargeTextEnabled();

    if (!mounted) return;
    state = state.copyWith(
      soundEnabled: _changed.contains('sound') ? state.soundEnabled : sound,
      hapticsEnabled: _changed.contains('haptics')
          ? state.hapticsEnabled
          : haptics,
      languageCode: _changed.contains('language') ? state.languageCode : lang,
      highContrast: _changed.contains('contrast')
          ? state.highContrast
          : contrast,
      largeText: _changed.contains('text') ? state.largeText : text,
    );
    AudioService.setSoundEnabled(state.soundEnabled);
    AudioService.hapticsEnabled = state.hapticsEnabled;
  }

  Future<void> toggleSound() async {
    _changed.add('sound');
    final updated = !state.soundEnabled;
    state = state.copyWith(soundEnabled: updated);
    AudioService.setSoundEnabled(updated);
    await _persist(() => StorageService.setSoundEnabled(updated));
  }

  Future<void> toggleHaptics() async {
    _changed.add('haptics');
    final updated = !state.hapticsEnabled;
    AudioService.hapticsEnabled = updated;
    state = state.copyWith(hapticsEnabled: updated);
    await _persist(() => StorageService.setHapticsEnabled(updated));
  }

  Future<void> setLanguage(String code) async {
    _changed.add('language');
    state = state.copyWith(languageCode: code);
    await _persist(() => StorageService.setLanguage(code));
  }

  Future<void> toggleHighContrast() async {
    _changed.add('contrast');
    final updated = !state.highContrast;
    state = state.copyWith(highContrast: updated);
    await _persist(() => StorageService.setHighContrastEnabled(updated));
  }

  Future<void> toggleLargeText() async {
    _changed.add('text');
    final updated = !state.largeText;
    state = state.copyWith(largeText: updated);
    await _persist(() => StorageService.setLargeTextEnabled(updated));
  }

  void setDifficulty(BotDifficulty diff) {
    state = state.copyWith(defaultDifficulty: diff);
  }

  final Set<String> _changed = {};
  Future<void> _writes = Future.value();
  Future<void> _persist(Future<void> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.catchError((Object _) {});
    return next;
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
      return SettingsController();
    });
