import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bricks/audio/sfx.dart';

class _Spark {
  final Point<int> pos;
  int frame;
  final int max;
  _Spark(this.pos, this.frame, this.max);
}

class PongGameState with ChangeNotifier {
  static const int rows = 20;
  static const int cols = 10;

  // Game state
  int _score = 0; // player points
  int _aiScore = 0;
  int _highScore = 0;
  int _level = 1;
  int _initialLevel = 1;
  int _life = 4;
  int _elapsedSeconds = 0;
  bool _playing = false;
  bool _gameOver = false;
  Timer? _gameOverAnimTimer;
  int _gameOverAnimFrame = 0;
  int _speedSetting = 1;

  // Sound
  bool _soundOn = true;
  int _volume = 2; // 0..3

  // Entities
  int _paddleY = rows ~/ 2; // center of 3-cell paddle
  int _aiPaddleY = rows ~/ 2;
  Point<int> _ball = const Point<int>(cols ~/ 2, rows ~/ 2);
  int _dx = -1; // left/right
  int _dy = -1; // up/down

  // Timers
  Timer? _loopTimer;
  Timer? _secondsTimer;
  int _tick = 0;
  int _baseMs = 300;

  // Getters
  int get score => _score;
  int get highScore => _highScore;
  int get aiScore => _aiScore;
  int get level => _level;
  int get life => _life;
  int get elapsedSeconds => _elapsedSeconds;
  bool get playing => _playing;
  bool get gameOver => _gameOver;
  int get gameOverAnimFrame => _gameOverAnimFrame;
  bool get soundOn => _soundOn;
  int get volume => _volume;
  int get paddleY => _paddleY;
  int get aiPaddleY => _aiPaddleY;
  Point<int> get ball => _ball;

  void applyMenuSettings({required int level, required int speed}) {
    _initialLevel = level.clamp(1, 12);
    _level = _initialLevel;
    _speedSetting = speed.clamp(1, 10);
    notifyListeners();
}

  Future<void> loadHighScore() async {
    final p = await SharedPreferences.getInstance();
    _highScore = p.getInt('pongHighScore') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('pongHighScore', _highScore);
  }

  void startGame() {
    Sfx.stopAll();
    _score = 0;
    _aiScore = 0;
    _life = 4;
    _elapsedSeconds = 0;
    _level = _initialLevel;
    _playing = true;
    _gameOver = false;
    _gameOverAnimTimer?.cancel();
    _gameOverAnimFrame = 0;
    _tick = 0;
    _paddleY = rows ~/ 2;
    _aiPaddleY = rows ~/ 2;
    _ball = const Point<int>(cols ~/ 2, rows ~/ 2);
    _dx = Random().nextBool() ? -1 : 1;
    _dy = Random().nextBool() ? -1 : 1;
    _resetLoop();
    _startSeconds();
    notifyListeners();
  }

  void stop() {
    _playing = false;
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
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

  void moveUp() {
    if (!_playing || _gameOver) return;
    _paddleY = max(_paddleY - 1, 1);
    notifyListeners();
  }

  void moveDown() {
    if (!_playing || _gameOver) return;
    _paddleY = min(_paddleY + 1, rows - 2);
    notifyListeners();
  }

  void _resetLoop() {
    _loopTimer?.cancel();
    if (!_playing || _gameOver) return;
    _baseMs = (300 - _speedSetting * 16 - _level * 8).clamp(80, 1000);
    _loopTimer = Timer.periodic(Duration(milliseconds: _baseMs), (_) => _tickLoop());
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
    _advanceAI();
    _advanceBall();
    _advanceSparks();
    if (_score > _highScore) { _highScore = _score; _saveHighScore(); }
    notifyListeners();
  }

  void _advanceAI() {
    // Simple AI with level-dependent latency
    if (_tick % _aiEvery() != 0) return;
    final targetY = ball.y;
    if (_aiPaddleY < targetY) _aiPaddleY++;
    else if (_aiPaddleY > targetY) _aiPaddleY--;
    _aiPaddleY = _aiPaddleY.clamp(1, rows - 2);
  }

  int _aiEvery() {
    // Level 1: slower reaction (every 3 ticks) → Level 12: faster (every 1)
    final int L = _level.clamp(1, 12);
    return (3 - (L ~/ 6)).clamp(1, 3);
  }

  void _advanceBall() {
    int nx = _ball.x + _dx;
    int ny = _ball.y + _dy;

    // wall collisions
    if (ny <= 0) { ny = 0; _dy = 1; _playBounce(); _addSpark(Point(nx, ny)); }
    if (ny >= rows - 1) { ny = rows - 1; _dy = -1; _playBounce(); _addSpark(Point(nx, ny)); }

    // paddle collisions
    // player paddle at column 1 spanning [paddleY-1, paddleY, paddleY+1]
    if (nx == 1 && (ny >= _paddleY - 1 && ny <= _paddleY + 1) && _dx < 0) {
      _dx = 1; _tweakAngle(ny, _paddleY); _speedUp(); _playBounce(); _addSpark(Point(nx, ny));
    }
    // AI paddle at column cols-2
    final int aiCol = cols - 2;
    if (nx == aiCol && (ny >= _aiPaddleY - 1 && ny <= _aiPaddleY + 1) && _dx > 0) {
      _dx = -1; _tweakAngle(ny, _aiPaddleY); _speedUp(); _playBounce(); _addSpark(Point(nx, ny));
    }

    // scoring: ball goes out left or right
    if (nx < 0) {
      _onPointScored(false); // AI scores
      return;
    }
    if (nx >= cols) {
      _onPointScored(true); // player scores
      return;
    }

    _ball = Point<int>(nx, ny);
  }

  void _tweakAngle(int ny, int py) {
    // Hit above or below paddle center tilts dy
    if (ny < py) _dy = -1; else if (ny > py) _dy = 1; // keep dy
  }

  void _speedUp() {
    // Speed up by lowering timer interval slightly (min cap)
    _baseMs = max(50, _baseMs - 6);
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(Duration(milliseconds: _baseMs), (_) => _tickLoop());
  }

  void _onPointScored(bool player) {
    if (player) {
      _score += 1;
      if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265 (1).mp3', volume: _volume / 3);
    }
    // lose a life when AI scores; end game if no lives
    if (!player) {
      _aiScore += 1;
      _life--;
      if (_life <= 0) { _endGame(); return; }
    }
    // reset positions
    _paddleY = rows ~/ 2;
    _aiPaddleY = rows ~/ 2;
    _ball = Point<int>(cols ~/ 2, rows ~/ 2);
    _dx = player ? -1 : 1; _dy = Random().nextBool() ? -1 : 1;
    _resetLoop();
    notifyListeners();
  }

  void _playBounce() { if (_soundOn) Sfx.play('sounds/bit_bomber1-89534.mp3', volume: _volume / 3); }

  void _endGame() {
    _gameOver = true; _playing = false;
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

  // Sparks
  final List<_Spark> _sparks = <_Spark>[];
  List<_Spark> get sparks => List.unmodifiable(_sparks);
  void _addSpark(Point<int> at) { _sparks.add(_Spark(at, 0, 8)); }
  void _advanceSparks() { if (_sparks.isEmpty) return; _sparks.removeWhere((s) => ++s.frame > s.max); }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    _gameOverAnimTimer?.cancel();
    super.dispose();
  }
}
