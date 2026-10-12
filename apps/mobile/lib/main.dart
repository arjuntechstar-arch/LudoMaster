import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/controllers/settings_controller.dart';
import 'src/screens/error_boundary_widget.dart';
import 'src/screens/startup_screen.dart';
import 'src/services/crash_reporting_service.dart';
import 'src/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CrashReportingService.initialize();

  runApp(const ProviderScope(child: LudoMasterApp()));
}

class LudoMasterApp extends ConsumerWidget {
  const LudoMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.highContrast
        ? AppTheme.highContrastTheme
        : AppTheme.darkTheme;

    return MaterialApp(
      title: 'Ludo Play',
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) {
        if (settings.largeText) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.15)),
            child: child ?? const SizedBox.shrink(),
          );
        }
        return child ?? const SizedBox.shrink();
      },
      home: const ErrorBoundaryWidget(child: StartupScreen()),
    );
  }
}
