import 'package:flutter/material.dart';

class InteractiveScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;
  final double pressedScale;
  final double hoverScale;
  final Curve curve;
  final BorderRadius? borderRadius;
  final Color splashColor;
  final Color highlightColor;

  const InteractiveScaleButton({
    super.key,
    required this.child,
    this.onTap,
    this.duration = const Duration(milliseconds: 180),
    this.pressedScale = 0.95,
    this.hoverScale = 0.98,
    this.curve = Curves.easeOutBack,
    this.borderRadius,
    this.splashColor = const Color(0x44FFFFFF),
    this.highlightColor = const Color(0x22FFFFFF),
  });

  @override
  State<InteractiveScaleButton> createState() => _InteractiveScaleButtonState();
}

class _InteractiveScaleButtonState extends State<InteractiveScaleButton> {
  bool _hovering = false;
  bool _pressed = false;

  double get _scale {
    if (_pressed) return widget.pressedScale;
    if (_hovering) return widget.hoverScale;
    return 1.0;
  }

  void _setHover(bool value) {
    if (widget.onTap == null) return;
    setState(() => _hovering = value);
  }

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedScale(
        scale: _scale,
        duration: widget.duration,
        curve: widget.curve,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: widget.borderRadius,
            splashColor: widget.splashColor,
            highlightColor: widget.highlightColor,
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
