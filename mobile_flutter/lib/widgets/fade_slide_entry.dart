import 'package:flutter/material.dart';

class FadeSlideEntry extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double verticalOffset;

  const FadeSlideEntry({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeOutCubic,
    this.verticalOffset = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, verticalOffset * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
