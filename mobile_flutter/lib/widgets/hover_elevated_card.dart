import 'package:flutter/material.dart';

class HoverElevatedCard extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double hoverElevation;
  final double normalElevation;
  final double hoverOffset;
  final BorderRadius borderRadius;
  final Color backgroundColor;

  const HoverElevatedCard({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.hoverElevation = 20,
    this.normalElevation = 10,
    this.hoverOffset = 2,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.backgroundColor = Colors.white,
  });

  @override
  State<HoverElevatedCard> createState() => _HoverElevatedCardState();
}

class _HoverElevatedCardState extends State<HoverElevatedCard> {
  bool _hovering = false;

  void _onHover(bool value) {
    setState(() {
      _hovering = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final boxShadow = BoxShadow(
      color: Colors.black.withValues(alpha: _hovering ? 0.18 : 0.08),
      blurRadius: _hovering ? widget.hoverElevation : widget.normalElevation,
      spreadRadius: _hovering ? 0.1 : 0,
      offset: Offset(0, _hovering ? 8 : 4),
    );

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovering ? -widget.hoverOffset : 0, 0),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: widget.borderRadius,
          boxShadow: [boxShadow],
        ),
        child: widget.child,
      ),
    );
  }
}
