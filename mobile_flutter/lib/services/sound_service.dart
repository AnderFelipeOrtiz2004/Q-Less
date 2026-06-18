import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static const _clickAsset = 'sounds/click.mp3';
  static const _successAsset = 'sounds/success.mp3';

  static final AudioPlayer _clickPlayer = AudioPlayer();
  static final AudioPlayer _successPlayer = AudioPlayer();

  static Future<void> _playAsset(AudioPlayer player, String assetPath) async {
    if (kIsWeb) return;

    try {
      await player.stop();
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // Sound feedback is optional, so keep the app usable if playback fails.
    }
  }

  static Future<void> playClick() async => await _playAsset(
        _clickPlayer,
        _clickAsset,
      );

  static Future<void> playSuccess() async => await _playAsset(
        _successPlayer,
        _successAsset,
      );
}
