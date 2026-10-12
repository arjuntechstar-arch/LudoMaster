import 'dart:math';

import 'package:flutter/material.dart';

/// Funny cartoon comic pop-up burst that appears when a token beats an opponent's token.
class FunnyCaptureOverlay extends StatefulWidget {
  final String capturingPlayerName;
  final String capturedPlayerName;
  final VoidCallback onDismissed;

  const FunnyCaptureOverlay({
    super.key,
    required this.capturingPlayerName,
    required this.capturedPlayerName,
    required this.onDismissed,
  });

  @override
  State<FunnyCaptureOverlay> createState() => _FunnyCaptureOverlayState();
}

class _FunnyCaptureOverlayState extends State<FunnyCaptureOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _opacityAnimation;

  static final List<String> _funnyPunchlines = [
    '💥 WHAM! BACK TO YARD!',
    '🚀 BYE BYE! SEE YA!',
    '⭐ OUCH! RETREAT!',
    '💨 K.O.! SENT PACKING!',
    '😂 GOTCHA! HAHA!',
    '🎯 BULLSEYE! KNOCKED OUT!',
  ];

  late String _punchline;

  @override
  void initState() {
    super.initState();
    _punchline = _funnyPunchlines[Random().nextInt(_funnyPunchlines.length)];

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.25,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.25,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _rotateAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.15),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.15, end: -0.08),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.08, end: 0.0),
        weight: 40,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 80),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.rotate(
            angle: _rotateAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFEF4444),
                        Color(0xFFF59E0B),
                        Color(0xFF8B5CF6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 3.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('💫', style: TextStyle(fontSize: 28)),
                          SizedBox(width: 8),
                          Text('😵', style: TextStyle(fontSize: 32)),
                          SizedBox(width: 8),
                          Text('💥', style: TextStyle(fontSize: 28)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _punchline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 6,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.capturingPlayerName} sent ${widget.capturedPlayerName} flying!',
                        style: const TextStyle(
                          color: Color(0xFFFEF3C7),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
