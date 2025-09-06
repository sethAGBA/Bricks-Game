import 'package:audioplayers/audioplayers.dart';

/// Lightweight helper to play short, overlapping sound effects reliably.
/// Creates a transient AudioPlayer per play and disposes it on completion.
class Sfx {
  static Future<void> play(String assetPath, {double volume = 1.0}) async {
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume.clamp(0.0, 1.0));
      // Use AssetSource with path relative to assets/sounds/
      await player.play(AssetSource(assetPath));
      // Dispose when done to free resources (do not await)
      player.onPlayerComplete.first.then((_) => player.dispose());
      // Fallback delayed dispose safety net (in case completion isn't fired)
      Future<void>.delayed(const Duration(seconds: 5)).then((_) {
        try { player.dispose(); } catch (_) {}
      });
    } catch (_) {
      // On any error, ensure we release the player
      try { await player.dispose(); } catch (_) {}
    }
  }
}
