import 'package:flutter/material.dart';

/// Entrada escalonada para listas en móvil (máx. 8 pasos de delay).
class StaggeredFadeIn extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDuration;
  final double offsetY;

  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.baseDuration = const Duration(milliseconds: 380),
    this.offsetY = 22,
  });

  @override
  Widget build(BuildContext context) {
    final delayIndex = index.clamp(0, 8);
    return TweenAnimationBuilder<double>(
      key: ValueKey('stagger-$index-${child.hashCode}'),
      tween: Tween(begin: 0, end: 1),
      duration: baseDuration + Duration(milliseconds: delayIndex * 55),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - value)),
            child: Transform.scale(
              scale: 0.96 + (0.04 * value),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
