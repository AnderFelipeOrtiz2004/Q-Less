import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Sonidos de interfaz (generados localmente; puedes reemplazarlos por MP3 de Pixabay).
class SoundService {
  static const _clickAsset = 'sounds/click.wav';
  static const _navigateAsset = 'sounds/navigate.wav';
  static const _purchaseAsset = 'sounds/purchase.wav';
  static const _successAsset = 'sounds/success.wav';
  static const _editAsset = 'sounds/edit.wav';

  static final AudioPlayer _clickPlayer = AudioPlayer();
  static final AudioPlayer _navigatePlayer = AudioPlayer();
  static final AudioPlayer _purchasePlayer = AudioPlayer();
  static final AudioPlayer _successPlayer = AudioPlayer();
  static final AudioPlayer _editPlayer = AudioPlayer();

  static bool _enabled = true;

  static void setEnabled(bool value) => _enabled = value;

  static Future<void> _playAsset(AudioPlayer player, String assetPath) async {
    if (kIsWeb || !_enabled) return;

    try {
      await player.stop();
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // El feedback sonoro es opcional.
    }
  }

  static Future<void> playClick() async =>
      _playAsset(_clickPlayer, _clickAsset);

  static Future<void> playNavigate() async =>
      _playAsset(_navigatePlayer, _navigateAsset);

  static Future<void> playPurchase() async =>
      _playAsset(_purchasePlayer, _purchaseAsset);

  static Future<void> playSuccess() async =>
      _playAsset(_successPlayer, _successAsset);

  static Future<void> playEdit() async =>
      _playAsset(_editPlayer, _editAsset);
}
