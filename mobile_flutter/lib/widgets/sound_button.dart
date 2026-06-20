import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import 'interactive_scale_button.dart';

enum SoundButtonType { click, navigate, purchase, success, edit }

/// Botón con escala animada + sonido de feedback.
class SoundButton extends StatelessWidget {
  const SoundButton({
    super.key,
    required this.child,
    this.onPressed,
    this.sound = SoundButtonType.click,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final SoundButtonType sound;
  final BorderRadius? borderRadius;

  void _play() {
    switch (sound) {
      case SoundButtonType.click:
        SoundService.playClick();
      case SoundButtonType.navigate:
        SoundService.playNavigate();
      case SoundButtonType.purchase:
        SoundService.playPurchase();
      case SoundButtonType.success:
        SoundService.playSuccess();
      case SoundButtonType.edit:
        SoundService.playEdit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveScaleButton(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      onTap: onPressed == null
          ? null
          : () {
              _play();
              onPressed!();
            },
      child: child,
    );
  }
}
