import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

/// Royal blue and gold palette inspired by the supplied game references.
class AppColors {
  const AppColors._();

  // Royal blue backgrounds and glossy panel surfaces.
  static const Color background = Color(0xFF0B2247);
  static const Color surface = Color(0xFF10488E);
  static const Color surfaceCard = Color(0xFF1765B7);
  static const Color surfaceElevated = Color(0xFF2588D8);

  // Gold highlights primary actions; green and cyan identify rewards and gems.
  static const Color primary = Color(0xFFFFC928);
  static const Color primaryLight = Color(0xFFFFE680);
  static const Color primaryDark = Color(0xFFD58A08);
  static const Color mint = Color(0xFF8FE33E);
  static const Color coral = Color(0xFFFF6B81);

  // Accents & Metallics - Luminous Cyber Gold & Cyan
  static const Color gold = Color(0xFFFFD166);
  static const Color goldLight = Color(0xFFFFE4A3);
  static const Color goldDark = Color(0xFFD9A62E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color cyan = Color(0xFF36D1DC);
  static const Color neonPink = Color(0xFFFF4D8D);

  // Player Colors - Ultra-vibrant, high-contrast jewel tones
  static const Color red = Color(0xFFFF4D6D);
  static const Color redLight = Color(0xFFFF8FA3);
  static const Color redDark = Color(0xFFC92A4B);

  static const Color green = Color(0xFF2DD4BF);
  static const Color greenLight = Color(0xFF5EEAD4);
  static const Color greenDark = Color(0xFF0F766E);

  static const Color yellow = Color(0xFFFBBF24);
  static const Color yellowLight = Color(0xFFFDE68A);
  static const Color yellowDark = Color(0xFFD97706);

  static const Color blue = Color(0xFF38BDF8);
  static const Color blueLight = Color(0xFF7DD3FC);
  static const Color blueDark = Color(0xFF0284C7);

  static const Color orange = Color(0xFFFF8A3D);
  static const Color orangeLight = Color(0xFFFFB27A);
  static const Color orangeDark = Color(0xFFC65D15);

  static const Color purple = Color(0xFF9B7BFF);
  static const Color purpleLight = Color(0xFFC4B5FD);
  static const Color purpleDark = Color(0xFF6D4AFF);

  // Card Background Aliases
  static const Color cardBackground = surfaceCard;
  static const Color cardBackgroundLight = surfaceElevated;

  // Board Specific
  static const Color boardBackground = Color(0xFF0D1728);
  static const Color trackCellBorder = Color(0xFF2E466B);
  static const Color trackCellFill = Color(0xFF142238);
  static const Color starSafe = Color(0xFFFFD166);

  // Text
  static const Color textPrimary = Color(0xFFF7F9FC);
  static const Color textSecondary = Color(0xFFD5E9FF);
  static const Color textMuted = Color(0xFFA9CCF2);

  static Color getPlayerColor(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return red;
      case PlayerColor.green:
        return green;
      case PlayerColor.yellow:
        return yellow;
      case PlayerColor.blue:
        return blue;
      case PlayerColor.orange:
        return orange;
      case PlayerColor.purple:
        return purple;
    }
  }

  static Color getPlayerLightColor(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return redLight;
      case PlayerColor.green:
        return greenLight;
      case PlayerColor.yellow:
        return yellowLight;
      case PlayerColor.blue:
        return blueLight;
      case PlayerColor.orange:
        return orangeLight;
      case PlayerColor.purple:
        return purpleLight;
    }
  }

  static Color getPlayerDarkColor(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return redDark;
      case PlayerColor.green:
        return greenDark;
      case PlayerColor.yellow:
        return yellowDark;
      case PlayerColor.blue:
        return blueDark;
      case PlayerColor.orange:
        return orangeDark;
      case PlayerColor.purple:
        return purpleDark;
    }
  }
}
