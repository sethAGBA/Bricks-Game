import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Lightweight helper to play short, overlapping sound effects reliably.
/// Creates a transient AudioPlayer per play and disposes it on completion.
class Sfx {
  static final Set<AudioPlayer> _active = <AudioPlayer>{};
  static final Map<String, int> _lastPlayMs = <String, int>{};
  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static Future<void> play(String assetPath, {double volume = 1.0, int throttleMs = 150, int maxConcurrent = 3}) async {
    // Global throttle per asset to avoid rapid-fire spamming
    final int now = _now();
    final int last = _lastPlayMs[assetPath] ?? 0;
    if (now - last < throttleMs) {
      return;
    }
    _lastPlayMs[assetPath] = now;

    // Cap concurrent lightweight players to avoid OS churn
    if (_active.length >= maxConcurrent) {
      return;
    }
    final player = AudioPlayer();
    _active.add(player);
    bool cleaned = false;
    StreamSubscription<void>? sub;
    Timer? fallback;

    Future<void> cleanup() async {
      if (cleaned) return;
      cleaned = true;
      try { await sub?.cancel(); } catch (_) {}
      try { fallback?.cancel(); } catch (_) {}
      try { await player.stop(); } catch (_) {}
      try { await player.dispose(); } catch (_) {}
      _active.remove(player);
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

  static Future<void> stopAll() async {
    final players = List<AudioPlayer>.from(_active);
    _active.clear();
    for (final p in players) {
      try { await p.stop(); } catch (_) {}
      try { await p.dispose(); } catch (_) {}
    }
  }
}
