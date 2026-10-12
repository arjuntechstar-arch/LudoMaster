import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../theme/app_colors.dart';
import '../services/game_pacing.dart';

/// Animated 3D dice widget with pip dots and thumb-friendly interactive area.
class DiceWidget extends StatefulWidget {
  const DiceWidget({
    super.key,
    required this.diceValue,
    required this.canRoll,
    required this.playerColor,
    required this.onRoll,
    this.size = 68.0,
    this.diceSkinAssetKey = 'dice_classic_ivory',
    this.rollSequence,
    this.onDisabledTap,
    this.remainingSeconds,
  });

  final int? diceValue;
  final bool canRoll;
  final PlayerColor playerColor;
  final VoidCallback onRoll;
  final double size;
  final String diceSkinAssetKey;
  final int? rollSequence;
  final VoidCallback? onDisabledTap;
  final int? remainingSeconds;

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> with TickerProviderStateMixin {
  late AnimationController _rollController;
  late AnimationController _idleController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _idleAnimation;
  late PlayerColor _displayPlayerColor;
  int _displayValue = 1;
  Timer? _faceCycleTimer;
  Timer? _playerColorTimer;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.diceValue ?? 1;
    _displayPlayerColor = widget.playerColor;
    _rollController = AnimationController(
      vsync: this,
      duration: GamePacing.diceRoll,
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _idleAnimation = CurvedAnimation(
      parent: _idleController,
      curve: Curves.easeInOut,
    );
    if (widget.canRoll) _idleController.repeat(reverse: true);

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _rollController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.14,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.14,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
    ]).animate(_rollController);

    _rollController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _faceCycleTimer?.cancel();
        setState(() {
          _displayValue = widget.diceValue ?? _displayValue;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.canRoll != oldWidget.canRoll) {
      if (widget.canRoll) {
        _idleController.repeat(reverse: true);
      } else {
        _idleController.stop();
        _idleController.reset();
      }
    }
    final isNewRoll = widget.rollSequence != null
        ? widget.rollSequence != oldWidget.rollSequence &&
              widget.diceValue != null
        : widget.diceValue != oldWidget.diceValue && widget.diceValue != null;

    if (isNewRoll) {
      _playerColorTimer?.cancel();
      _displayPlayerColor = widget.playerColor;
      _faceCycleTimer?.cancel();
      _faceCycleTimer = Timer.periodic(const Duration(milliseconds: 135), (_) {
        if (mounted && _rollController.isAnimating) {
          setState(() {
            _displayValue = Random().nextInt(6) + 1;
          });
        }
      });
      _rollController.forward(from: 0).then((_) {
        _faceCycleTimer?.cancel();
        if (mounted && widget.diceValue != null) {
          setState(() {
            _displayValue = widget.diceValue!;
          });
        }
      });
    } else if (widget.diceValue != oldWidget.diceValue &&
        widget.diceValue != null) {
      // Opponents' results update without starting this player's roll animation.
      _playerColorTimer?.cancel();
      _displayPlayerColor = widget.playerColor;
      if (!_rollController.isAnimating) _displayValue = widget.diceValue!;
    } else if (widget.playerColor != oldWidget.playerColor) {
      _schedulePlayerColorChange(widget.playerColor);
    } else if (widget.diceValue != null &&
        widget.diceValue != _displayValue &&
        !_rollController.isAnimating) {
      setState(() {
        _displayValue = widget.diceValue!;
      });
    }
  }

  void _schedulePlayerColorChange(PlayerColor color) {
    _playerColorTimer?.cancel();
    if (_displayPlayerColor == color) return;
    _playerColorTimer = Timer(GamePacing.diceColorHold, () {
      if (!mounted || widget.playerColor != color) return;
      if (_rollController.isAnimating) {
        _schedulePlayerColorChange(color);
        return;
      }
      setState(() => _displayPlayerColor = color);
    });
  }

  @override
  void dispose() {
    _faceCycleTimer?.cancel();
    _playerColorTimer?.cancel();
    _idleController.dispose();
    _rollController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.canRoll && !_rollController.isAnimating) {
      widget.onRoll();
    } else {
      widget.onDisabledTap?.call();
    }
  }

  List<Color> get _skinGradientColors {
    switch (widget.diceSkinAssetKey) {
      case 'dice_gold':
        return const [Color(0xFFFFE066), Color(0xFFD4AF37)];
      case 'dice_crystal':
        return const [Color(0xFFE0F2FE), Color(0xFF38BDF8)];
      case 'dice_classic_ivory':
      default:
        return const [Colors.white, Color(0xFFE2E8F0)];
    }
  }

  Color _getPipColor(Color defaultPlayerColor) {
    switch (widget.diceSkinAssetKey) {
      case 'dice_gold':
        return const Color(0xFF452202);
      case 'dice_crystal':
        return const Color(0xFF0369A1);
      case 'dice_classic_ivory':
      default:
        return defaultPlayerColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getPlayerColor(_displayPlayerColor);
    final pipColor = _getPipColor(color);

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        enabled: widget.canRoll,
        label: _rollController.isAnimating
            ? 'Rolling dice'
            : 'Dice, ${widget.diceValue ?? _displayValue}',
        hint: widget.canRoll ? 'Tap to roll' : 'Wait for your turn to roll',
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _rotationAnimation,
            _scaleAnimation,
            _idleAnimation,
          ]),
          builder: (context, child) {
            final isRolling = _rollController.isAnimating;
            final angle = isRolling ? _rotationAnimation.value : 0.0;
            final scale = isRolling
                ? _scaleAnimation.value
                : 1.0 + (_idleAnimation.value * 0.035);
            final jitterX = isRolling
                ? sin(_rollController.value * pi * 6) * 2.0
                : 0.0;
            final jitterY = isRolling
                ? sin(_rollController.value * pi * 4) * 4.0
                : 0.0;

            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..multiply(Matrix4.translationValues(jitterX, jitterY, 0.0))
              ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0))
              ..rotateZ(angle)
              ..rotateX(isRolling ? sin(angle) * 0.35 : 0.0)
              ..rotateY(isRolling ? cos(angle) * 0.35 : 0.0);

            return SizedBox(
              width: widget.size + 18,
              height: widget.size + 18,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (widget.remainingSeconds != null)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        end:
                            (widget.remainingSeconds!.clamp(
                                      0,
                                      GamePacing.turnDurationSeconds,
                                    ) /
                                    GamePacing.turnDurationSeconds)
                                .toDouble(),
                      ),
                      duration: const Duration(milliseconds: 350),
                      builder: (context, progress, _) => SizedBox(
                        width: widget.size + 14,
                        height: widget.size + 14,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          backgroundColor: AppColors.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.remainingSeconds! <= 5
                                ? const Color(0xFFEF4444)
                                : AppColors.gold,
                          ),
                        ),
                      ),
                    ),
                  Transform(
                    alignment: Alignment.center,
                    transform: transform,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.size * 0.24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _skinGradientColors,
                        ),
                        border: Border.all(
                          color: widget.canRoll ? AppColors.gold : color,
                          width: widget.canRoll ? 3.0 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.canRoll
                                ? AppColors.gold.withValues(
                                    alpha: 0.45 + _idleAnimation.value * 0.2,
                                  )
                                : Colors.black.withValues(alpha: 0.4),
                            blurRadius: widget.canRoll
                                ? 12 + _idleAnimation.value * 4
                                : 6,
                            spreadRadius: widget.canRoll ? 2 : 0,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _buildDiceFace(_displayValue, pipColor),
                      ),
                    ),
                  ),
                  if (widget.remainingSeconds != null)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.remainingSeconds! <= 5
                              ? const Color(0xFF7F1D1D)
                              : AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.remainingSeconds! <= 5
                                ? const Color(0xFFEF4444)
                                : AppColors.gold,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '${widget.remainingSeconds}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDiceFace(int value, Color pipColor) {
    final dotSize = widget.size * 0.16;

    Widget dot() => Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pipColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 1.5,
            offset: const Offset(0.5, 1),
          ),
        ],
      ),
    );

    final empty = SizedBox(width: dotSize, height: dotSize);

    List<Widget> rows;
    switch (value) {
      case 1:
        return Center(child: dot());
      case 2:
        rows = [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), empty],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [empty, dot()],
          ),
        ];
        break;
      case 3:
        rows = [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), empty, empty],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [empty, dot(), empty],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [empty, empty, dot()],
          ),
        ];
        break;
      case 4:
        rows = [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
        ];
        break;
      case 5:
        rows = [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [dot()]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
        ];
        break;
      case 6:
      default:
        rows = [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
        ];
        break;
    }

    return Padding(
      padding: EdgeInsets.all(widget.size * 0.16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: rows,
      ),
    );
  }
}
