import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../theme/app_colors.dart';

/// Interactive, animated 3D token with pulsing legal move highlight.
class TokenWidget extends StatefulWidget {
  const TokenWidget({
    super.key,
    required this.token,
    required this.size,
    required this.isLegalMove,
    this.onTap,
  });

  final Token token;
  final double size;
  final bool isLegalMove;
  final VoidCallback? onTap;

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _hopController;
  late Animation<double> _hopAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _hopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _hopAnimation = CurvedAnimation(
      parent: _hopController,
      curve: Curves.easeInOut,
    );

    if (widget.isLegalMove) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant TokenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLegalMove != oldWidget.isLegalMove) {
      if (widget.isLegalMove) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    // Trigger lively coin hopping animation whenever position changes
    if (widget.token.trackCell != oldWidget.token.trackCell ||
        widget.token.laneStep != oldWidget.token.laneStep ||
        widget.token.state != oldWidget.token.state) {
      _hopController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _hopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getPlayerColor(widget.token.color);
    final lightColor = AppColors.getPlayerLightColor(widget.token.color);
    final darkColor = AppColors.getPlayerDarkColor(widget.token.color);

    return GestureDetector(
      onTap: widget.isLegalMove ? widget.onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _hopAnimation]),
        builder: (context, child) {
          final isHopping = _hopController.isAnimating;
          final hopProgress = _hopAnimation.value;
          final hopY = isHopping ? -12.0 * sin(hopProgress * pi) : 0.0;
          final hopScale = isHopping
              ? (1.0 + 0.28 * sin(hopProgress * pi))
              : 1.0;
          final pulseScale = widget.isLegalMove ? _pulseAnimation.value : 1.0;

          return Transform.translate(
            offset: Offset(0, hopY),
            child: Transform.scale(
              scale: pulseScale * hopScale,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing aura ring if legal move
                    if (widget.isLegalMove)
                      Container(
                        width: widget.size * 1.35,
                        height: widget.size * 1.35,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),

                    // Token Base Drop Shadow (elevates and softens during hop)
                    Container(
                      width: widget.size * (isHopping ? 0.85 : 1.0),
                      height: widget.size * (isHopping ? 0.85 : 1.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isHopping ? 0.25 : 0.5,
                            ),
                            blurRadius: isHopping ? 10 : 4,
                            spreadRadius: isHopping ? -2 : 0,
                            offset: Offset(1, isHopping ? 12 : 3),
                          ),
                        ],
                      ),
                    ),

                    // Outer Token Ring (3D bevel)
                    Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [lightColor, darkColor],
                          center: const Alignment(-0.3, -0.4),
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                    ),

                    // Inner Crown/Emblem Ring
                    Container(
                      width: widget.size * 0.55,
                      height: widget.size * 0.55,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.9),
                        boxShadow: [
                          BoxShadow(
                            color: darkColor.withValues(alpha: 0.8),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: widget.size * 0.28,
                          height: widget.size * 0.28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
