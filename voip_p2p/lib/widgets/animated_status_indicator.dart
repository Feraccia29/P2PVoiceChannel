import 'package:flutter/material.dart';
import '../models/call_state.dart';
import '../theme/app_theme.dart';

class AnimatedStatusIndicator extends StatefulWidget {
  final CallState state;

  const AnimatedStatusIndicator({
    super.key,
    required this.state,
  });

  @override
  State<AnimatedStatusIndicator> createState() =>
      _AnimatedStatusIndicatorState();
}

class _AnimatedStatusIndicatorState extends State<AnimatedStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getColor() {
    switch (widget.state) {
      case CallState.idle:
        return AppTheme.idleGray;
      case CallState.connecting:
      case CallState.disconnecting:
        return AppTheme.connectingOrange;
      case CallState.connected:
        return AppTheme.connectedGreen;
      case CallState.error:
        return AppTheme.errorRed;
    }
  }

  IconData _getIcon() {
    switch (widget.state) {
      case CallState.idle:
        return Icons.radio_button_unchecked;
      case CallState.connecting:
      case CallState.disconnecting:
        return Icons.sync;
      case CallState.connected:
        return Icons.check_circle;
      case CallState.error:
        return Icons.error_outline;
    }
  }

  String _getText() {
    switch (widget.state) {
      case CallState.idle:
        return 'Disconnesso';
      case CallState.connecting:
        return 'In attesa...';
      case CallState.connected:
        return 'Connesso';
      case CallState.disconnecting:
        return 'Disconnessione...';
      case CallState.error:
        return 'Errore Connessione';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation,
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey(widget.state),
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(color),
          const SizedBox(height: 16),
          Text(
            _getText(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(Color color) {
    final icon = Icon(_getIcon(), size: 80, color: color);

    // Pulse animation for connecting/disconnecting
    if (widget.state == CallState.connecting ||
        widget.state == CallState.disconnecting) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: icon,
      );
    }

    // Glow effect for connected
    if (widget.state == CallState.connected) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [AppTheme.glowShadow(color)],
        ),
        child: icon,
      );
    }

    return icon;
  }
}
