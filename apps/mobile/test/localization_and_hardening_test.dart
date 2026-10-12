import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/controllers/settings_controller.dart';
import 'package:mobile/src/localization/app_localizations.dart';
import 'package:mobile/src/services/crash_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Localization Tests (Phase 12 Polish)', () {
    test('English dictionary contains required keys', () {
      final l10n = AppLocalizations('en');
      expect(l10n.text('app_title'), equals('LUDO PLAY'));
      expect(l10n.text('play_vs_computer'), equals('Play vs Computer'));
      expect(l10n.text('rewards'), equals('Rewards'));
      expect(l10n.text('settings_title'), equals('SETTINGS & ACCESSIBILITY'));
    });

    test('Hindi dictionary translates strings accurately', () {
      final l10n = AppLocalizations('hi');
      expect(l10n.text('app_title'), equals('लूडो प्ले'));
      expect(l10n.text('play_vs_computer'), equals('कंप्यूटर से खेलें'));
      expect(l10n.text('rewards'), equals('इनाम'));
      expect(l10n.text('roll_dice'), equals('पासा फेंकें'));
    });

    test('Spanish dictionary translates strings accurately', () {
      final l10n = AppLocalizations('es');
      expect(l10n.text('play_vs_computer'), equals('Jugar vs Ordenador'));
      expect(l10n.text('roll_dice'), equals('Lanzar Dado'));
    });

    test('French and German dictionaries translate strings accurately', () {
      final l10nFr = AppLocalizations('fr');
      expect(l10nFr.text('play_vs_computer'), equals('Jouer contre l\'Ordi'));

      final l10nDe = AppLocalizations('de');
      expect(l10nDe.text('play_vs_computer'), equals('Gegen Computer spielen'));
    });

    test('Unknown language falls back to English dictionary', () {
      final l10nUnknown = AppLocalizations('xx');
      expect(l10nUnknown.text('app_title'), equals('LUDO PLAY'));
      expect(l10nUnknown.text('play_vs_computer'), equals('Play vs Computer'));
    });

    test('Missing key falls back to key itself', () {
      final l10n = AppLocalizations('en');
      expect(l10n.text('non_existent_key_xyz'), equals('non_existent_key_xyz'));
    });
  });

  group('Crash Reporting & Diagnostics Service Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Logs unhandled exceptions into in-memory ring buffer', () {
      CrashReportingService.logError(
        'Simulated NullReferenceException in DiceRoller',
        context: 'Test Context',
      );

      final logs = CrashReportingService.inMemoryLogs;
      expect(logs.isNotEmpty, isTrue);
      expect(logs.first.message, contains('Simulated NullReferenceException'));
      expect(logs.first.context, equals('Test Context'));
    });

    test('Clear logs wipes stored diagnostics', () async {
      CrashReportingService.logError('Temporary error to be cleared');
      expect(CrashReportingService.inMemoryLogs.isNotEmpty, isTrue);

      await CrashReportingService.clearLogs();
      expect(CrashReportingService.inMemoryLogs.isEmpty, isTrue);
    });
  });

  group('Accessibility & Settings Controller Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('SettingsController manages language, high contrast, and large text', () async {
      final controller = SettingsController();

      // Initial defaults
      expect(controller.state.languageCode, equals('en'));
      expect(controller.state.highContrast, isFalse);
      expect(controller.state.largeText, isFalse);

      // Change language
      await controller.setLanguage('hi');
      expect(controller.state.languageCode, equals('hi'));

      // Toggle high contrast
      await controller.toggleHighContrast();
      expect(controller.state.highContrast, isTrue);

      // Toggle large text
      await controller.toggleLargeText();
      expect(controller.state.largeText, isTrue);
    });
  });
}
