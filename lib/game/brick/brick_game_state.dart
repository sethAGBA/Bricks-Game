import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bricks/audio/sfx.dart';

class BrickGameState with ChangeNotifier {
  static const int rows = 20;
  static const int cols = 10;

  // Game state
  int _score = 0;
  int _highScore = 0;
  int _level = 1; // starts at 1
  int _initialLevel = 1;
  int _life = 4;
  int _elapsedSeconds = 0;
  bool _playing = false;
  bool _gameOver = false;
  int _speedSetting = 1;

  // Entities
  int _paddleX = cols ~/ 2; // center column for paddle (3-wide base)
  int _paddleHalf = 1; // half width: 1 => 3-wide, 2 => 5-wide when expanded
  Point<int> _ball = const Point<int>(cols ~/ 2, rows - 3);
  int _dx = 1; // ball direction x: -1, 0, 1
  int _dy = -1; // ball direction y: -1 (up), 1 (down)
  Point<int>? _ball2; // optional second ball
  int _dx2 = -1;
  int _dy2 = -1;
  bool _ballLaunched = false;
  final Set<Point<int>> _bricks = <Point<int>>{};
  // Bonus UFO
  Point<int>? _ufo; // when present, flies horizontally near the top
  int _ufoDir = 1;
  int _tickCounter = 0;
  // Falling power-ups
  final List<PowerUp> _powerUps = <PowerUp>[];
  bool _slowBall = false;
  int _slowUntilTick = 0;
  int _expandUntilTick = 0;
  bool _pierceBall = false;
  int _pierceUntilTick = 0;

  // Timers
  Timer? _loopTimer;
  Timer? _secondsTimer;
  Timer? _gameOverAnimTimer;
  int _gameOverAnimFrame = 0;
  int _tickMs = 350; // current loop interval ms for seconds conversion

  // Audio
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
  bool get soundOn => _soundOn;
  int get volume => _volume;
  int get paddleX => _paddleX;
  Point<int> get ball => _ball;
  Point<int>? get ball2 => _ball2;
  bool get ballLaunched => _ballLaunched;
  Set<Point<int>> get bricks => _bricks;
  int get gameOverAnimFrame => _gameOverAnimFrame;
  Point<int>? get ufo => _ufo;
  List<PowerUp> get powerUps => List.unmodifiable(_powerUps);
  int get paddleHalf => _paddleHalf;
  bool get expandActive => _paddleHalf > 1;
  bool get slowActive => _slowBall;
  bool get pierceActive => _pierceBall;
  bool get multiActive => _ball2 != null;
  int get expandRemainingTicks => _expandUntilTick > 0 ? (_expandUntilTick - _tickCounter).clamp(0, 9999) : 0;
  int get slowRemainingTicks => _slowUntilTick > 0 ? (_slowUntilTick - _tickCounter).clamp(0, 9999) : 0;
  int get pierceRemainingTicks => _pierceUntilTick > 0 ? (_pierceUntilTick - _tickCounter).clamp(0, 9999) : 0;
  int get expandRemainingSeconds => (expandRemainingTicks * _tickMs / 1000).ceil();
  int get slowRemainingSeconds => (slowRemainingTicks * _tickMs / 1000).ceil();
  int get pierceRemainingSeconds => (pierceRemainingTicks * _tickMs / 1000).ceil();

  void applyMenuSettings({required int level, required int speed}) {
    _initialLevel = level.clamp(1, 15);
    _level = _initialLevel;
    _speedSetting = speed.clamp(1, 10);
    notifyListeners();
  }

  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('brickHighScore') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('brickHighScore', _highScore);
  }

  void startGame() {
    // reset all state
    Sfx.stopAll();
    _score = 0;
    _life = 4;
    _elapsedSeconds = 0;
    _level = 1; // always start at level 1 per request
    _playing = true;
    _gameOver = false;
    _gameOverAnimTimer?.cancel();
    _gameOverAnimFrame = 0;
    _paddleX = cols ~/ 2;
    _ball = Point<int>(_paddleX, rows - 3);
    _dx = 1;
    _dy = -1;
    _ball2 = null; _dx2 = -1; _dy2 = -1;
    _ballLaunched = false;
    _ufo = null;
    _ufoDir = 1;
    _tickCounter = 0;
    _powerUps.clear();
    _slowBall = false;
    _slowUntilTick = 0;
    _expandUntilTick = 0;
    _paddleHalf = 1;
    _spawnBricks();
    _resetLoop();
    _startSeconds();
    notifyListeners();
  }

  void _spawnBricks() {
    _bricks.clear();
    // Pattern varies with level: density increases and layout alternates
    final int bands = 4 + (_level % 3); // 4..6 rows of bricks
    final int startRow = 2;
    for (int i = 0; i < bands; i++) {
      final int r = startRow + i;
      for (int c = 0; c < cols; c++) {
        final bool even = (i % 2 == 0);
        final bool place = (_level % 2 == 0)
            ? (even ? c % 2 == 0 : c % 2 == 1)
            : (even ? (c % 3 != 0) : (c % 3 != 1));
        if (place) _bricks.add(Point<int>(c, r));
      }
    }
  }

  void _resetLoop() {
    _loopTimer?.cancel();
    if (!_playing || _gameOver) return;
    // base interval: faster with speed setting and level
    final int base = (350 - _speedSetting * 18 - _level * 10).clamp(60, 1200);
    _tickMs = base;
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
    if (_paddleX > 1) {
      _paddleX--;
      if (!_ballLaunched) {
        _ball = Point<int>(_paddleX, rows - 3);
      }
      notifyListeners();
    }
  }

  void moveRight() {
    if (!_playing || _gameOver) return;
    if (_paddleX < cols - 2) {
      _paddleX++;
      if (!_ballLaunched) {
        _ball = Point<int>(_paddleX, rows - 3);
      }
      notifyListeners();
    }
  }

  void launchBall() {
    if (_gameOver || !_playing) return;
    _ballLaunched = true;
    notifyListeners();
  }

  void _tick() {
    if (_gameOver || !_playing) return;
    _tickCounter++;
    if (!_ballLaunched) {
      // stick ball to paddle before launch
      _ball = Point<int>(_paddleX, rows - 3);
      notifyListeners();
      return;
    }

    // Handle timed effects expiry
    if (_expandUntilTick > 0 && _tickCounter >= _expandUntilTick) {
      _paddleHalf = 1;
      _expandUntilTick = 0;
    }
    if (_slowUntilTick > 0 && _tickCounter >= _slowUntilTick) {
      _slowBall = false;
      _slowUntilTick = 0;
    }
    if (_pierceUntilTick > 0 && _tickCounter >= _pierceUntilTick) {
      _pierceBall = false;
      _pierceUntilTick = 0;
    }

    // If slow effect active, move ball only every other tick
    if (_slowBall && (_tickCounter % 2 == 1)) {
      // still drop power-ups and move UFO
      _moveUfo();
      _movePowerUps();
      notifyListeners();
      return;
    }

    // Move ball
    int nx = _ball.x + _dx;
    int ny = _ball.y + _dy;

    // Wall collisions
    if (nx < 0) {
      nx = 0; _dx = 1; _playBounce();
    } else if (nx >= cols) {
      nx = cols - 1; _dx = -1; _playBounce();
    }
    if (ny < 0) {
      ny = 0; _dy = 1; _playBounce();
    }

    // Paddle collision (paddle spans center +/- paddleHalf at row rows-2)
    final int py = rows - 2;
    if (ny == py && (nx >= _paddleX - _paddleHalf && nx <= _paddleX + _paddleHalf) && _dy > 0) {
      // reflect up
      _dy = -1;
      // adjust dx based on where it hit the paddle
      if (nx < _paddleX) _dx = -1; else if (nx > _paddleX) _dx = 1;
      ny = py - 1;
      _playBounce();
    }

    // Brick collision
    final hit = Point<int>(nx, ny);
    if (_bricks.contains(hit)) {
      _bricks.remove(hit);
      _score += 10;
      if (!_pierceBall) {
        _dy = -_dy; // reflect unless pierce
        ny = _ball.y + _dy;
      }
      if (_soundOn) Sfx.play('sounds/bit_bomber1-89534.mp3', volume: _volume / 3);
      _maybeSpawnPowerUp(hit);
    }

    // Update ball position
    _ball = Point<int>(nx, ny);

    // UFO collision (bonus)
    if (_ufo != null && _ufo!.x == _ball.x && _ufo!.y == _ball.y) {
      _score += 50;
      _ufo = null;
      _dy = -_dy; // bounce
      if (_soundOn) Sfx.play('sounds/cartoon_16-74046.mp3', volume: _volume / 3);
    }

    // UFO spawn/move
    _maybeSpawnUfo();
    _moveUfo();

    // Move power-ups and check pickup
    _movePowerUps();

    // Move second ball if present
    if (_ball2 != null) {
      int nx2 = _ball2!.x + _dx2;
      int ny2 = _ball2!.y + _dy2;
      if (nx2 < 0) { nx2 = 0; _dx2 = 1; _playBounce(); }
      else if (nx2 >= cols) { nx2 = cols - 1; _dx2 = -1; _playBounce(); }
      if (ny2 < 0) { ny2 = 0; _dy2 = 1; _playBounce(); }
      final int py2 = rows - 2;
      if (ny2 == py2 && (nx2 >= _paddleX - _paddleHalf && nx2 <= _paddleX + _paddleHalf) && _dy2 > 0) {
        _dy2 = -1;
        if (nx2 < _paddleX) _dx2 = -1; else if (nx2 > _paddleX) _dx2 = 1;
        ny2 = py2 - 1;
        _playBounce();
      }
      final hit2 = Point<int>(nx2, ny2);
      if (_bricks.contains(hit2)) {
        _bricks.remove(hit2);
        _score += 10;
        if (!_pierceBall) {
          _dy2 = -_dy2;
          ny2 = _ball2!.y + _dy2;
        }
        if (_soundOn) Sfx.play('sounds/bit_bomber1-89534.mp3', volume: _volume / 3);
        _maybeSpawnPowerUp(hit2);
      }
      _ball2 = Point<int>(nx2, ny2);
      if (_ufo != null && _ball2!.x == _ufo!.x && _ball2!.y == _ufo!.y) {
        _score += 50; _ufo = null; _dy2 = -_dy2; if (_soundOn) Sfx.play('sounds/cartoon_16-74046.mp3', volume: _volume / 3);
      }
      if (_ball2!.y >= rows) { _ball2 = null; }
    }

    // Lose life if ball falls below paddle
    if (_ball.y >= rows) {
      // if second ball exists, drop primary only
      if (_ball2 != null) {
        _ball = _ball2!; _dx = _dx2; _dy = _dy2; _ball2 = null;
      } else {
        _life--;
        if (_life <= 0) {
          _endGame();
        } else {
          _ballLaunched = false;
          _ball = Point<int>(_paddleX, rows - 3);
          _dx = 1; _dy = -1; _ball2 = null;
          if (_soundOn) Sfx.play('sounds/8bit-ringtone-free-to-use-loopable-44702.mp3', volume: _volume / 3);
        }
        notifyListeners();
        return;
      }
    }

    // Level up when no bricks remain
    if (_bricks.isEmpty) {
      _level++;
      _spawnBricks();
      _ballLaunched = false;
      _ball = Point<int>(_paddleX, rows - 3);
      _dx = 1; _dy = -1; _ball2 = null; _dx2 = -1; _dy2 = -1;
      _resetLoop();
    }

    if (_score > _highScore) {
      _highScore = _score;
      _saveHighScore();
    }

    notifyListeners();
  }

  void _playBounce() {
    if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265 (1).mp3', volume: _volume / 3);
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

  void _maybeSpawnUfo() {
    if (_ufo != null) return;
    // spawn chance increases with level; check every ~15 ticks
    if (_tickCounter % 15 != 0) return;
    final rnd = Random();
    final double p = (0.05 + 0.01 * (_level - 1)).clamp(0.05, 0.20);
    if (rnd.nextDouble() < p) {
      _ufoDir = rnd.nextBool() ? 1 : -1;
      final int startX = _ufoDir > 0 ? 0 : cols - 1;
      _ufo = Point<int>(startX, 1); // near the top
    }
  }

  void _moveUfo() {
    if (_ufo == null) return;
    // move every other tick for a slower pace
    if (_tickCounter % 2 != 0) return;
    int nx = _ufo!.x + _ufoDir;
    int ny = _ufo!.y;
    if (nx < 0 || nx >= cols) {
      // bounce and step down slightly to vary path
      _ufoDir *= -1;
      nx = _ufo!.x + _ufoDir;
      ny = (_ufo!.y + 1).clamp(1, 4);
    }
    _ufo = Point<int>(nx, ny);
  }

  void _maybeSpawnPowerUp(Point<int> at) {
    final rnd = Random();
    // 25% drop chance
    if (rnd.nextDouble() > 0.25) return;
    final double pick = rnd.nextDouble();
    PowerUpKind kind;
    if (pick < 0.4) {
      kind = PowerUpKind.expand;
    } else if (pick < 0.75) {
      kind = PowerUpKind.slow;
    } else {
      kind = PowerUpKind.life;
    }
    _powerUps.add(PowerUp(Point<int>(at.x, at.y), kind));
  }

  void _movePowerUps() {
    if (_powerUps.isEmpty) return;
    final int py = rows - 2;
    final removed = <PowerUp>[];
    for (final p in _powerUps) {
      final int ny = p.pos.y + 1;
      if (ny >= rows) {
        removed.add(p);
        continue;
      }
      p.pos = Point<int>(p.pos.x, ny);
      // pickup
      if (ny == py && (p.pos.x >= _paddleX - _paddleHalf && p.pos.x <= _paddleX + _paddleHalf)) {
        _applyPowerUp(p.kind);
        removed.add(p);
      }
    }
    _powerUps.removeWhere((p) => removed.contains(p));
  }

  void _applyPowerUp(PowerUpKind kind) {
    switch (kind) {
      case PowerUpKind.expand:
        _paddleHalf = 2; // 5-wide
        _expandUntilTick = _tickCounter + 200; // ~ duration based on tick
        break;
      case PowerUpKind.slow:
        _slowBall = true;
        _slowUntilTick = _tickCounter + 200;
        break;
      case PowerUpKind.life:
        _life = (_life + 1).clamp(0, 9);
        break;
      case PowerUpKind.multi:
        // spawn a second ball if none exists, mirror horizontal direction
        if (_ball2 == null) {
          _ball2 = Point<int>(_ball.x, _ball.y);
          _dx2 = (_dx == 0) ? 1 : -_dx;
          _dy2 = _dy;
        }
        break;
      case PowerUpKind.pierce:
        _pierceBall = true;
        _pierceUntilTick = _tickCounter + 200;
        break;
    }
    if (_soundOn) Sfx.play('sounds/cartoon_16-74046.mp3', volume: _volume / 3);
  }

  void stop() {
    _playing = false;
    _gameOver = false;
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    _gameOverAnimTimer?.cancel();
    _gameOverAnimFrame = 0;
    Sfx.stopAll();
    _score = 0;
    _life = 4;
    _elapsedSeconds = 0;
    _level = _initialLevel;
    _paddleX = cols ~/ 2;
    _ball = Point<int>(_paddleX, rows - 3);
    _dx = 1; _dy = -1; _ballLaunched = false;
    _powerUps.clear();
    _slowBall = false; _slowUntilTick = 0;
    _expandUntilTick = 0; _paddleHalf = 1;
    _spawnBricks();
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

enum PowerUpKind { expand, slow, life, multi, pierce }

class PowerUp {
  Point<int> pos;
  final PowerUpKind kind;
  PowerUp(this.pos, this.kind);
}
