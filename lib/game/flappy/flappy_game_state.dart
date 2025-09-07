import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bricks/audio/sfx.dart';

class FlappyGameState with ChangeNotifier {
  static const int rows = 20;
  static const int cols = 10;

  // Game
  int _score = 0;
  int _highScore = 0;
  int _level = 1;
  int _initialLevel = 1;
  int _life = 4;
  int _elapsedSeconds = 0;
  bool _playing = false;
  bool _gameOver = false;
  int _speedSetting = 1;

  // Sound
  bool _soundOn = true;
  int _volume = 2; // 0..3

  // Physics
  double _y = rows / 2; // bird center in grid units
  double _vy = 0.0;
  final double _gravity = 0.15;
  final double _flapImpulse = -2.2;
  bool _upHeld = false;
  bool _downHeld = false;
  int _lastUpMs = 0;
  int _lastDownMs = 0;

  // Pipes
  final List<_Pipe> _pipes = <_Pipe>[];
  int _tick = 0;
  Timer? _loopTimer;
  Timer? _secondsTimer;
  Timer? _gameOverAnimTimer;

  int _gameOverAnimFrame = 0;
  final List<_Crash> _crashes = <_Crash>[];
  // Getters
  int get score => _score;
  int get highScore => _highScore;
  int get level => _level;
  int get life => _life;
  int get elapsedSeconds => _elapsedSeconds;
  bool get playing => _playing;
  bool get gameOver => _gameOver;
  int get gameOverAnimFrame => _gameOverAnimFrame;
  List<_Crash> get crashes => List.unmodifiable(_crashes);
  bool get soundOn => _soundOn;
  int get volume => _volume;
  int get birdX => 3; // fixed column
  int get birdY => _y.clamp(0, rows - 1).round();
  List<_Pipe> get pipes => List.unmodifiable(_pipes);

  // Settings
  void applyMenuSettings({required int level, required int speed}) {
    _initialLevel = level.clamp(1, 12);
    _level = _initialLevel;
    _speedSetting = speed.clamp(1, 10);
    notifyListeners();
  }

  Future<void> loadHighScore() async {
    final p = await SharedPreferences.getInstance();
    _highScore = p.getInt('flappyHighScore') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('flappyHighScore', _highScore);
  }

  void startGame() {
    Sfx.stopAll();
    _score = 0;
    _life = 4;
    _elapsedSeconds = 0;
    _level = _initialLevel;
    _playing = true;
    _gameOver = false;
    _tick = 0;
    _vy = 0;
    _y = rows / 2;
    _gameOverAnimTimer?.cancel();
    _gameOverAnimFrame = 0;
    _pipes.clear();
    _spawnInitialPipes();
    _resetLoop();
    _startSeconds();
    notifyListeners();
  }

  void stop() {
    _playing = false;
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    _gameOverAnimTimer?.cancel();
    notifyListeners();
  }

  void togglePlaying() {
    if (_gameOver) return;
    _playing = !_playing;
    if (_playing) {
      _resetLoop();
      _startSeconds();
    } else {
      _loopTimer?.cancel();
      _secondsTimer?.cancel();
    }
    notifyListeners();
  }

  void toggleSound() {
    _volume = (_volume + 1) % 4;
    _soundOn = _volume > 0;
    notifyListeners();
  }

  void flap() {
    if (!_playing || _gameOver) return;
    _vy = _flapImpulse;
    if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265.mp3', volume: _volume / 3);
  }

  void moveUp() {
    if (!_playing || _gameOver) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final bool spam = now - _lastUpMs < 200;
    _lastUpMs = now;
    _y = (_y - 1).clamp(0, rows - 1);
    _vy = spam ? -1.2 : -0.5; // boost on spam
    _checkScoreAndCollisions();
    notifyListeners();
  }

  void moveDown() {
    if (!_playing || _gameOver) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final bool spam = now - _lastDownMs < 200;
    _lastDownMs = now;
    _y = (_y + 1).clamp(0, rows - 1);
    _vy = spam ? 1.2 : 0.5; // boost on spam
    _checkScoreAndCollisions();
    notifyListeners();
  }

  void holdUp(bool held) { _upHeld = held; }
  void holdDown(bool held) { _downHeld = held; }

  void _resetLoop() {
    _loopTimer?.cancel();
    if (!_playing || _gameOver) return;
    final int base = (320 - _speedSetting * 16 - _level * 8).clamp(90, 1000);
    _loopTimer = Timer.periodic(Duration(milliseconds: base), (_) => _tickLoop());
  }

  void _startSeconds() {
    _secondsTimer?.cancel();
    _secondsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_playing && !_gameOver) {
        _elapsedSeconds++;
        notifyListeners();
      }
    });
  }

  void _tickLoop() {
    if (_gameOver || !_playing) return;
    _tick++;
    // Physics
    _vy += _gravity * _speedFactor();
    if (_upHeld) _vy -= 0.15 * _speedFactor();
    if (_downHeld) _vy += 0.15 * _speedFactor();
    // clamp velocity
    _vy = _vy.clamp(-3.5, 3.5);
    _y += _vy * 0.5; // integrate

    // Pipes move left
    _advancePipes();
    _maybeSpawnPipe();
    _advanceCrashes();
    _checkScoreAndCollisions();

    if (_score > _highScore) { _highScore = _score; _saveHighScore(); }
    notifyListeners();
  }

  double _speedFactor() => 1.0 + (_level - 1) * 0.08 + (_speedSetting - 1) * 0.05;

  void _spawnInitialPipes() {
    _pipes.clear();
    for (int i = 0; i < 3; i++) {
      final x = cols + i * 5;
      _pipes.add(_generatePipe(x));
    }
  }

  _Pipe _generatePipe(int x) {
    final gap = _gapForLevel(); // tiles
    final rng = Random();
    final minY = 2;
    final maxY = rows - gap - 2;
    final gy = rng.nextInt(maxY - minY + 1) + minY;
    return _Pipe(x: x, gapY: gy, gapH: gap, width: 1, scored: false);
  }

  void _advancePipes() {
    final List<_Pipe> moved = [];
    for (final p in _pipes) {
      int nx = p.x - 1;
      moved.add(p.copyWith(x: nx));
    }
    _pipes
      ..clear()
      ..addAll(moved.where((p) => p.x + p.width >= 0));
  }

  void _maybeSpawnPipe() {
    if (_tick % 6 != 0) return;
    if (_pipes.isEmpty || (_pipes.last.x < cols - 5)) {
      _pipes.add(_generatePipe(cols + 2));
    }
  }

  void _checkScoreAndCollisions() {
    // Collisions with ground/ceiling
    if (_y < 0 || _y >= rows) {
      _onLifeLost(FlappyCrashKind.ground, Point<int>(birdX, birdY));
      return;
    }
    // Pipe collision & scoring
    for (int i = 0; i < _pipes.length; i++) {
      final p = _pipes[i];
      // scoring when bird passes the pipe's trailing edge
      if (!p.scored && birdX > p.x + p.width - 1) {
        _pipes[i] = p.copyWith(scored: true);
        _score += 10;
        if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265 (1).mp3', volume: _volume / 3);
        if (_score % 50 == 0) {
          _level = (_level + 1).clamp(1, 12);
          if (_soundOn) Sfx.play('sounds/cartoon_16-74046.mp3', volume: _volume / 3);
        }
      }
      // collision: any tile at birdX except gap
      if (birdX >= p.x && birdX < p.x + p.width) {
        final int by = birdY;
        if (by < p.gapY || by >= p.gapY + p.gapH) {
          _onLifeLost(FlappyCrashKind.pipe, Point<int>(birdX, by));
          return;
        }
      }
    }
  }

  void _onLifeLost([FlappyCrashKind kind = FlappyCrashKind.pipe, Point<int>? at]) {
    if (at != null) {
      _crashes.add(_Crash(at, kind, 0, 10));
    }
    _life--;
    if (_life <= 0) {
      _endGame();
    } else {
      // Reset bird and pipes lightly
      _vy = 0;
      _y = rows / 2;
      _pipes.clear();
      _spawnInitialPipes();
      if (_soundOn) Sfx.play('sounds/8bit-ringtone-free-to-use-loopable-44702.mp3', volume: _volume / 3);
    }
  }

  void _advanceCrashes() {
    if (_crashes.isEmpty) return;
    _crashes.removeWhere((c) => ++c.frame > c.maxFrames);
  }

  void _endGame() {
    _gameOver = true;
    _playing = false;
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    Sfx.stopAll();
    _gameOverAnimFrame = 0;
    _gameOverAnimTimer?.cancel();
    _gameOverAnimTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      _gameOverAnimFrame++;
      if (_gameOverAnimFrame > 24) { t.cancel(); }
      notifyListeners();
    });
  }

  int _gapForLevel() {
    // Wider at low levels, tighter at high levels
    final int L = _level.clamp(1, 12);
    // Map 1..12 -> gap 6..3
    final double gap = 6 - 3 * ((L - 1) / (12 - 1));
    return gap.round().clamp(3, 6);
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    _gameOverAnimTimer?.cancel();
    super.dispose();
  }
}

class _Pipe {
  final int x;
  final int gapY;
  final int gapH;
  final int width;
  final bool scored;
  _Pipe({required this.x, required this.gapY, required this.gapH, required this.width, required this.scored});
  _Pipe copyWith({int? x, int? gapY, int? gapH, int? width, bool? scored}) =>
      _Pipe(x: x ?? this.x, gapY: gapY ?? this.gapY, gapH: gapH ?? this.gapH, width: width ?? this.width, scored: scored ?? this.scored);
}

enum FlappyCrashKind { pipe, ground }

class _Crash {
  final Point<int> pos;
  final FlappyCrashKind kind;
  int frame;
  final int maxFrames;
  _Crash(this.pos, this.kind, this.frame, this.maxFrames);
}
