import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VoiceActivityRing extends StatefulWidget {
  final Stream<double> audioLevelStream;
  final Widget child;
  final double maxScale;
  final Color? color;

  const VoiceActivityRing({
    super.key,
    required this.audioLevelStream,
    required this.child,
    this.maxScale = 1.15,
    this.color,
  });

  @override
  State<VoiceActivityRing> createState() => _VoiceActivityRingState();
}

class _VoiceActivityRingState extends State<VoiceActivityRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription<double>? _subscription;
  double _currentLevel = 0.0;

  static const double _smoothingFactor = 0.3;
  static const double _silenceThreshold = 0.01;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _subscription = widget.audioLevelStream.listen((level) {
      _currentLevel =
          _currentLevel * (1 - _smoothingFactor) + level * _smoothingFactor;

      if (_currentLevel > _silenceThreshold) {
        final targetValue = (_currentLevel * 2).clamp(0.0, 1.0);
        _controller.animateTo(targetValue,
            duration: const Duration(milliseconds: 80));
      } else {
        _controller.animateTo(0.0,
            duration: const Duration(milliseconds: 200));
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.color ?? AppTheme.connectedGreen;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        final opacity = (value * 0.6).clamp(0.0, 0.6);
        final scale = 1.0 + (widget.maxScale - 1.0) * value;

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: value > 0.01
                ? [
                    BoxShadow(
                      color: ringColor.withValues(alpha: opacity),
                      blurRadius: 20 * value,
                      spreadRadius: 5 * value,
                    ),
                  ]
                : null,
          ),
          child: Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: value > 0.01
                    ? Border.all(
                        color: ringColor.withValues(alpha: opacity + 0.2),
                        width: 3.0 * value,
                      )
                    : null,
              ),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
