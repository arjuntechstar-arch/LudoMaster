import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

/// Curated, premium color palette for LudoMaster.
class AppColors {
  const AppColors._();

  // Background & Surface - Deep Midnight Obsidian & Space Cadet
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF131B2E);
  static const Color surfaceCard = Color(0xFF1C2640);
  static const Color surfaceElevated = Color(0xFF283656);

  // Accents & Metallics - Luminous Cyber Gold & Cyan
  static const Color gold = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFE66D);
  static const Color goldDark = Color(0xFFD4AF37);
  static const Color amber = Color(0xFFF59E0B);
  static const Color cyan = Color(0xFF00F0FF);
  static const Color neonPink = Color(0xFFFF2D55);

  // Player Colors - Ultra-vibrant, high-contrast jewel tones
  static const Color red = Color(0xFFFF3366);
  static const Color redLight = Color(0xFFFF6B8B);
  static const Color redDark = Color(0xFFBE123C);

  static const Color green = Color(0xFF10B981);
  static const Color greenLight = Color(0xFF34D399);
  static const Color greenDark = Color(0xFF047857);

  static const Color yellow = Color(0xFFFBBF24);
  static const Color yellowLight = Color(0xFFFDE68A);
  static const Color yellowDark = Color(0xFFD97706);

  static const Color blue = Color(0xFF0EA5E9);
  static const Color blueLight = Color(0xFF38BDF8);
  static const Color blueDark = Color(0xFF0369A1);

  static const Color orange = Color(0xFFFF6B00);
  static const Color orangeLight = Color(0xFFFB923C);
  static const Color orangeDark = Color(0xFFC2410C);

  static const Color purple = Color(0xFFA855F7);
  static const Color purpleLight = Color(0xFFC084FC);
  static const Color purpleDark = Color(0xFF7E22CE);

  // Card Background Aliases
  static const Color cardBackground = surfaceCard;
  static const Color cardBackgroundLight = surfaceElevated;

  // Board Specific
  static const Color boardBackground = Color(0xFF0F172A);
  static const Color trackCellBorder = Color(0xFF2E3E63);
  static const Color trackCellFill = Color(0xFF172036);
  static const Color starSafe = Color(0xFFFFD700);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

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
