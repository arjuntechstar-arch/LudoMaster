import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../widgets/mobile_ui.dart';
import '../theme/app_colors.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: MobilePageBody(
          children: [
            const MobileHeading(
              'Make yourself at home',
              subtitle: 'A few preferences for a better game.',
            ),
            const MobileSection('Game experience'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: const Text('Game sound'),
                    subtitle: const Text('Dice, moves, and celebrations'),
                    value: settings.soundEnabled,
                    onChanged: (_) => controller.toggleSound(),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_rounded),
                    title: const Text('Haptic feedback'),
                    subtitle: const Text(
                      'Feel your moves on supported devices',
                    ),
                    value: settings.hapticsEnabled,
                    onChanged: (_) => controller.toggleHaptics(),
                  ),
                ],
              ),
            ),
            const MobileSection('Accessibility'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.text_increase_rounded),
                    title: const Text('Larger text'),
                    subtitle: const Text('More comfortable reading'),
                    value: settings.largeText,
                    onChanged: (_) => controller.toggleLargeText(),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.contrast_rounded),
                    title: const Text('High contrast'),
                    subtitle: const Text('Stronger colors and clearer edges'),
                    value: settings.highContrast,
                    onChanged: (_) => controller.toggleHighContrast(),
                  ),
                ],
              ),
            ),
            const MobileSection('Language'),
            DropdownButtonFormField<String>(
              initialValue: settings.languageCode,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'App language',
                prefixIcon: Icon(Icons.translate_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'de', child: Text('Deutsch')),
              ],
              onChanged: (value) {
                if (value != null) controller.setLanguage(value);
              },
            ),
            const MobileSection('Privacy'),
            MobileAction(
              title: 'Privacy policy',
              subtitle: 'How Ludo Play handles your information',
              icon: Icons.privacy_tip_outlined,
              color: AppColors.mint,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
