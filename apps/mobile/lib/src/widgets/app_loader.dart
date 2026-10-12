import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.2),
    child: Image.asset(
      'assets/branding/ludo_play_logo.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: 'Ludo Play logo',
    ),
  );
}

class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.message = 'Loading your game...'});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 104),
        const SizedBox(height: 20),
        const Text(
          'Ludo Play',
          style: TextStyle(
            color: AppColors.goldLight,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: AppColors.gold,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 14),
        Text(message, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    ),
  );
}
