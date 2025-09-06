import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:bricks/audio/sfx.dart';

class ShootGameState with ChangeNotifier {
  static const int rows = 20;
  static const int cols = 10;

  // Game state
  int _score = 0;
  int _highScore = 0;
  int _level = 1;
  int _initialLevel = 1;
  int _life = 4;
  int _elapsedSeconds = 0;
  bool _playing = false;
  bool _gameOver = false;
  int _speedSetting = 1;

  // Entities
  int _gunX = cols ~/ 2; // center column
  final Set<Point<int>> _army = <Point<int>>{};
  final Set<Point<int>> _shots = <Point<int>>{}; // player shots going up
  final Set<Point<int>> _enemyShots = <Point<int>>{}; // enemy shots going down
  int _armyDir = 1; // 1:right, -1:left
  int _tickCount = 0;
  final List<ShootExplosion> _explosions = <ShootExplosion>[];

  // Timers
  Timer? _loopTimer;
  Timer? _secondsTimer;
  Timer? _gameOverAnimTimer;
  int _gameOverAnimFrame = 0;

  // Sound
  bool _soundOn = true;
  int _volume = 2;

  // Getters
  int get score => _score;
  int get highScore => _highScore;
  int get level => _level;
  int get life => _life;
  int get elapsedSeconds => _elapsedSeconds;
  bool get playing => _playing;
  bool get gameOver => _gameOver;
  int get gameOverAnimFrame => _gameOverAnimFrame;
  bool get soundOn => _soundOn;
  int get volume => _volume;
  int get gunX => _gunX;
  Set<Point<int>> get army => _army;
  Set<Point<int>> get shots => _shots;
  Set<Point<int>> get enemyShots => _enemyShots;
  List<ShootExplosion> get explosions => List.unmodifiable(_explosions);

  void applyMenuSettings({required int level, required int speed}) {
    _initialLevel = level.clamp(1, 15);
    _level = _initialLevel;
    _speedSetting = speed.clamp(1, 10);
    notifyListeners();
  }

  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('shootHighScore') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('shootHighScore', _highScore);
  }

  void startGame() {
    // Stop any lingering SFX
    Sfx.stopAll();
    _score = 0;
    _life = 4;
    _elapsedSeconds = 0;
    _playing = true;
    _gameOver = false;
    _gunX = cols ~/ 2;
    _shots.clear();
    _enemyShots.clear();
    _explosions.clear();
    _level = 1; // Start always at level 1
    _spawnArmy();
    _resetLoop();
    _startSeconds();
    notifyListeners();
  }

  void _spawnArmy() {
    _army.clear();
    // Generate 3 rows of aliens with spacing; rows 2..4, columns 1..8 step 2
    for (int r = 2; r <= 4; r++) {
      for (int c = 1; c < cols - 1; c += 2) {
        _army.add(Point<int>(c, r));
      }
    }
    _armyDir = 1;
  }

  void _resetLoop() {
    _loopTimer?.cancel();
    if (!_playing || _gameOver) return;
    final int base = (300 - _speedSetting * 18 - _level * 8).clamp(60, 1000);
    _loopTimer = Timer.periodic(Duration(milliseconds: base), (_) => _tick());
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

  void togglePlaying() {
    if (_gameOver) return;
    _playing = !_playing;
    if (_playing) {
      _resetLoop();
      _startSeconds();
    } else {
      _loopTimer?.cancel();
      _secondsTimer?.cancel();
      // Stop any currently playing SFX when pausing
      Sfx.stopAll();
    }
    notifyListeners();
  }

  void toggleSound() {
    _volume = (_volume + 1) % 4;
    _soundOn = _volume > 0;
    notifyListeners();
  }

  void moveLeft() {
    if (!_playing || _gameOver) return;
    if (_gunX > 1) {
      _gunX--;
      notifyListeners();
    }
  }

  void moveRight() {
    if (!_playing || _gameOver) return;
    if (_gunX < cols - 2) {
      _gunX++;
      notifyListeners();
    }
  }

  void fire() {
    if (!_playing || _gameOver) return;
    final shot = Point<int>(_gunX, rows - 3);
    // prevent stacking too many shots from same position
    if (!_shots.contains(shot)) {
      _shots.add(shot);
      if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265.mp3', volume: _volume / 3);
      notifyListeners();
    }
  }

  void _tick() {
    if (_gameOver || !_playing) return;
    _tickCount++;

    // 1) Move shots up
    final List<Point<int>> toRemoveShots = [];
    final List<Point<int>> movedShots = [];
    for (final s in _shots) {
      final ny = s.y - 1;
      if (ny < 0) {
        toRemoveShots.add(s);
      } else {
        movedShots.add(Point<int>(s.x, ny));
        toRemoveShots.add(s);
      }
    }
    for (final s in toRemoveShots) { _shots.remove(s); }
    _shots.addAll(movedShots);

    // 2) Shots vs army collisions
    final Set<Point<int>> deadAliens = {};
    final Set<Point<int>> consumedShots = {};
    for (final s in _shots) {
      for (final a in _army) {
        if (s.x == a.x && s.y == a.y) {
          deadAliens.add(a);
          consumedShots.add(s);
          _score += 10;
          if (_soundOn) Sfx.play('sounds/bit_bomber1-89534.mp3', volume: _volume / 3);
          _explosions.add(ShootExplosion(Point<int>(a.x, a.y), 0));
          break;
        }
      }
    }
    _army.removeAll(deadAliens);
    _shots.removeAll(consumedShots);

    // 3) Move army down and spawn new enemies on top row (Java-like)
    final Set<Point<int>> moved = {};
    for (final a in _army) { moved.add(Point<int>(a.x, a.y + 1)); }
    _army
      ..clear()
      ..addAll(moved);
    final Random rng = Random();
    for (int x = 0; x < cols; x++) {
      if (rng.nextBool()) { _army.add(Point<int>(x, 0)); }
    }

    // 4) Check lose conditions: army reached player's row
    if (_army.any((a) => a.y >= rows - 1)) {
      _onLifeLost(resetArmy: true);
      notifyListeners();
      return;
    }

    // 5) Level up based on score
    final int targetLevel = (_score ~/ 200) + 1;
    if (targetLevel > _level) { _level = targetLevel; _resetLoop(); }

    // 9) Advance explosions frames and cull
    for (final e in _explosions) {
      e.frame += 1;
    }
    _explosions.removeWhere((e) => e.frame > 6);

    // Save high score if improved
    if (_score > _highScore) {
      _highScore = _score;
      _saveHighScore();
    }

    notifyListeners();
  }

  void _maybeEnemyFire() {}

  void _onLifeLost({bool resetArmy = false}) {
    _life--;
    if (_life <= 0) {
      _endGame();
      return;
    }
    // Add a small explosion at the gun position
    final int gy = rows - 2;
    _explosions.add(ShootExplosion(Point<int>(_gunX, gy), 0));
    _gunX = cols ~/ 2;
    _shots.clear();
    _enemyShots.clear();
    if (resetArmy) {
      _spawnArmy();
    }
    if (_soundOn) {
      Sfx.play('sounds/8bit-ringtone-free-to-use-loopable-44702.mp3', volume: _volume / 3);
    }
  }

  void _endGame() {
    _gameOver = true;
    _playing = false;
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    // Ensure all SFX are stopped on game end
    Sfx.stopAll();
    // Start end-of-game animation frames
    _gameOverAnimFrame = 0;
    _gameOverAnimTimer?.cancel();
    _gameOverAnimTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      _gameOverAnimFrame++;
      notifyListeners();
      // End after sufficient frames
      if (_gameOverAnimFrame > 24) {
        t.cancel();
      }
    });
  }

  // Public stop for screen navigation: stops timers and pauses gameplay
  void stop() {
    _playing = false;
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    Sfx.stopAll();
    notifyListeners();
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    _gameOverAnimTimer?.cancel();
    super.dispose();
  }
}

class ShootExplosion {
  final Point<int> pos;
  int frame;
  ShootExplosion(this.pos, this.frame);
}
