import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bundled Microsoft Fluent 3D artwork. License is included with the assets.
class GameAsset extends StatelessWidget {
  const GameAsset(this.name, {super.key, this.size = 32});
  final String name;
  final double size;
  static String? forIcon(IconData icon) {
    const groups = <String, List<IconData>>{
      'home': [Icons.home_outlined, Icons.home_rounded],
      'globe': [Icons.public_rounded],
      'shield': [Icons.shield_rounded, Icons.shield_outlined],
      'bag': [
        Icons.shopping_bag,
        Icons.shopping_bag_outlined,
        Icons.storefront,
        Icons.storefront_outlined,
      ],
      'target': [Icons.flag_outlined],
      'medal': [Icons.verified_outlined],
      'heart': [Icons.favorite_rounded, Icons.favorite_outline],
      'robot': [Icons.smart_toy_rounded, Icons.smart_toy_outlined],
      'friends': [
        Icons.groups_rounded,
        Icons.groups_outlined,
        Icons.people_outline,
        Icons.people_rounded,
        Icons.people_outline_rounded,
      ],
      'gift': [
        Icons.card_giftcard_rounded,
        Icons.card_giftcard_outlined,
        Icons.card_giftcard,
      ],
      'crown': [
        Icons.workspace_premium_rounded,
        Icons.workspace_premium_outlined,
      ],
      'trophy': [Icons.emoji_events_outlined],
      'coin': [Icons.monetization_on_outlined, Icons.monetization_on],
      'gem': [Icons.diamond_outlined, Icons.diamond],
      'event': [Icons.event_available_rounded, Icons.calendar_month],
      'dice': [
        Icons.casino_rounded,
        Icons.casino,
        Icons.inventory_2,
        Icons.inventory_2_outlined,
      ],
      'chat': [Icons.forum_rounded],
      'sparkles': [
        Icons.auto_awesome,
        Icons.auto_awesome_rounded,
        Icons.auto_awesome_outlined,
      ],
      'controller': [
        Icons.sports_esports_rounded,
        Icons.sports_esports_outlined,
      ],
    };
    for (final entry in groups.entries) {
      if (entry.value.contains(icon)) return entry.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/icons/fluent_3d/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    ),
  );
}

/// Perspective tilt and gentle floating for decorative hero props.
class GameDepth extends StatefulWidget {
  const GameDepth({
    super.key,
    required this.child,
    this.floating = false,
    this.phase = 0,
  });
  final Widget child;
  final bool floating;
  final double phase;
  @override
  State<GameDepth> createState() => _GameDepthState();
}

class _GameDepthState extends State<GameDepth>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  Offset _tilt = Offset.zero;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.floating &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onHover: (event) {
        if (reduced) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || box.size.isEmpty) return;
        setState(
          () => _tilt = Offset(
            (event.localPosition.dx / box.size.width - .5).clamp(-.5, .5),
            (event.localPosition.dy / box.size.height - .5).clamp(-.5, .5),
          ),
        );
      },
      onExit: (_) => setState(() => _tilt = Offset.zero),
      child: AnimatedBuilder(
        animation: _motion,
        child: widget.child,
        builder: (_, child) {
          final wave = reduced
              ? 0.0
              : math.sin(_motion.value * math.pi * 2 + widget.phase);
          final tilt = reduced ? Offset.zero : _tilt;
          return Transform.translate(
            offset: Offset(0, widget.floating ? wave * 5 : 0),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0015)
                ..rotateX(-tilt.dy * .3)
                ..rotateY(tilt.dx * .35)
                ..rotateZ(widget.floating ? wave * .035 : 0),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }
}
