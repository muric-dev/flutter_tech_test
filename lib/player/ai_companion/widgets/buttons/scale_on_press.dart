import 'package:flutter/material.dart';

/// Shrinks [child] slightly while a finger is down on it, as Spotify's
/// buttons do. Stays still when the system asks to reduce motion.
class ScaleOnPress extends StatefulWidget {
  const ScaleOnPress({required this.child, super.key});

  /// The scale while pressed.
  static const pressedScale = 0.96;

  final Widget child;

  @override
  State<ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends State<ScaleOnPress> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? ScaleOnPress.pressedScale : 1,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
