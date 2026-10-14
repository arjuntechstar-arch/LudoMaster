import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_loader.dart';
import 'reference_ludo_lobby_v2_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = AudioService.init().timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {
        return const ReferenceLudoLobbyV2Screen();
      }
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: AppLoader(message: 'Getting ready to play...'),
      );
    },
  );
}
