import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Lightweight helper to play short, overlapping sound effects reliably.
/// Creates a transient AudioPlayer per play and disposes it on completion.
class Sfx {
  static Future<void> play(String assetPath, {double volume = 1.0}) async {
    final player = AudioPlayer();
    bool cleaned = false;
    StreamSubscription<void>? sub;
    Timer? fallback;

    Future<void> cleanup() async {
      if (cleaned) return;
      cleaned = true;
      try { await sub?.cancel(); } catch (_) {}
      try { fallback?.cancel(); } catch (_) {}
      try { await player.stop(); } catch (_) {}
      try { await player.release(); } catch (_) {}
      try { await player.dispose(); } catch (_) {}
    }
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.play(AssetSource(assetPath));
      // Dispose when done to free resources
      sub = player.onPlayerComplete.listen((_) async {
        await cleanup();
      });
      // Fallback delayed cleanup (if completion isn't fired)
      fallback = Timer(const Duration(seconds: 6), () {
        cleanup();
      });
    } catch (_) {
      await cleanup();
    }
  }
}
