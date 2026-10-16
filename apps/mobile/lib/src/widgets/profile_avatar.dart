import 'package:flutter/material.dart';

import 'game_symbol.dart';

class FreeAvatar {
  const FreeAvatar(this.id, this.name, this.icon, this.color);
  final String id;
  final String name;
  final IconData icon;
  final Color color;
}

const freeAvatars = [
  FreeAvatar('avatar_0', 'Player', Icons.person_rounded, Color(0xFF6366F1)),
  FreeAvatar(
    'avatar_1',
    'Rocket',
    Icons.rocket_launch_rounded,
    Color(0xFFEC4899),
  ),
  FreeAvatar('avatar_2', 'Paw', Icons.pets_rounded, Color(0xFF14B8A6)),
  FreeAvatar('avatar_3', 'Knight', Icons.shield_rounded, Color(0xFF3B82F6)),
  FreeAvatar('avatar_4', 'Star', Icons.auto_awesome_rounded, Color(0xFFF59E0B)),
  FreeAvatar('avatar_5', 'Dice', Icons.casino_rounded, Color(0xFFEF4444)),
  FreeAvatar(
    'avatar_6',
    'Smile',
    Icons.emoji_emotions_rounded,
    Color(0xFF22C55E),
  ),
  FreeAvatar(
    'avatar_7',
    'Gamer',
    Icons.sports_esports_rounded,
    Color(0xFF8B5CF6),
  ),
];

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.avatarId, this.radius = 24});
  final String avatarId;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final avatar =
        freeAvatars.where((item) => item.id == avatarId).firstOrNull ??
        freeAvatars.first;
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatar.color.withValues(alpha: 0.22),
      child: GameSymbol(avatar.icon, color: avatar.color, size: radius * 1.25),
    );
  }
}
