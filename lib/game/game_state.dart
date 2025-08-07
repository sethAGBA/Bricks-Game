import 'dart:async';
import 'dart:math' as math;
import 'package:bricks/game/piece.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class GameState with ChangeNotifier {
  final AudioPlayer _soundEffectsPlayer = AudioPlayer();
  late AudioCache _audioCache;
  
  
  // Game state
  int _score = 0;
  int _highScore = 0;
  int _lines = 0;
  int _level = 1;
  bool _playing = false;
  bool _gameOver = false;
  final bool _isAnimatingLineClear = false;
  final List<int> _linesBeingCleared = [];
  VoidCallback? onGameOver;
  int _elapsedSeconds = 0;
  late Piece _currentPiece;
  late Piece _nextPiece;
  Timer? _timer; // Make timer nullable
  Timer? _moveSoundDebounceTimer;
  Timer? _gameSecondsTimer; // Tracks real elapsed seconds

  // Game speed (milliseconds per tick)
  final List<int> _levelSpeeds = [500, 450, 400, 350, 300, 250, 200, 150, 100, 80];

  // Game grid
  static const int rows = 20;
  static const int cols = 10;
  List<List<Tetromino?>> grid = List.generate(rows, (_) => List.filled(cols, null));

  // Audio state
  bool _soundOn = true;
  int _volume = 2;

  // Getters
  int get score => _score;
  int get lines => _lines;
  int get level => _level;
  bool get playing => _playing;
  bool get gameOver => _gameOver;
  bool get isAnimatingLineClear => _isAnimatingLineClear;
  List<int> get linesBeingCleared => _linesBeingCleared;
  Piece get currentPiece => _currentPiece;
  Piece get nextPiece => _nextPiece;
  bool get soundOn => _soundOn;
  int get volume => _volume;
  int get elapsedSeconds => _elapsedSeconds;
  int get highScore => _highScore;

  GameState() {
    loadHighScore();
    _currentPiece = _randomPiece();
    _nextPiece = _randomPiece();
    _audioCache = AudioCache(prefix: 'assets/sounds/');
    _audioCache.loadAll([
      'gameboy-pluck-41265.mp3',
      'gameboy-pluck-41265 (1).mp3',
      'bit_bomber1-89534.mp3',
      'cartoon_16-74046.mp3',
      '8bit-ringtone-free-to-use-loopable-44702.mp3',
    ]);
  }

  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('highScore') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', _highScore);
  }

  void startGame() {
    stopAllSounds(); // Stop any lingering sounds from previous game
    _playing = true;
    _gameOver = false;
    _score = 0;
    _lines = 0;
    _level = 1;
    _elapsedSeconds = 0;
    grid = List.generate(rows, (_) => List.filled(cols, null));
    _newPiece();
    _resetTimer(); // Use the new timer method
    _startElapsedTimer();
    notifyListeners();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null; // Explicitly nullify the timer reference

    if (_playing && !_gameOver) {
      // Use speed based on level, with a fallback for higher levels
      final speed = (_level - 1 < _levelSpeeds.length) ? _levelSpeeds[_level - 1] : 100;
      _timer = Timer.periodic(Duration(milliseconds: speed), (timer) {
        gameLoop();
      });
    }
  }

    void gameLoop() {
    if (_isAnimatingLineClear) return; // Pause game during animation
    moveDown();
    notifyListeners();
  }

  Piece _randomPiece() {
    final random = math.Random();
    final type = Tetromino.values[random.nextInt(Tetromino.values.length)];
    return Piece(type: type);
  }

  void _newPiece() {
    _currentPiece = _nextPiece;
    _nextPiece = _randomPiece();

    // Check for game over
    if (!canMove(_currentPiece, dx: 0, dy: 0)) {
      _gameOver = true;
      _playing = false;
      _timer?.cancel();
      _stopElapsedTimer();
      if (_score > _highScore) {
        _highScore = _score;
        _saveHighScore();
      }
      playGameOverSound();
      stopAllSounds();
    } else {
      // No need to calculate ghost piece position
    }
  }

  void moveDown() {
    if (_gameOver || !_playing) return;
    if (canMove(_currentPiece, dx: 0, dy: 1)) {
      _currentPiece = _currentPiece.copyWith(position: Point(_currentPiece.position.x, _currentPiece.position.y + 1));
      playMoveSound();
    } else {
      _lockPiece();
      _resetTimer(); // Reset timer after locking a piece
    }
  }

  void hardDrop() {
    if (_gameOver || !_playing || _isAnimatingLineClear) return;
    while (canMove(_currentPiece, dx: 0, dy: 1)) {
      _currentPiece = _currentPiece.copyWith(position: Point(_currentPiece.position.x, _currentPiece.position.y + 1));
    }
    _lockPiece();
    _resetTimer(); // Reset timer after locking a piece
    if (!_gameOver) { // Only recalculate and notify if game is not over
      // No need to calculate ghost piece position
    }
  }

  void moveLeft() {
    if (_gameOver || !_playing) return;
    if (canMove(_currentPiece, dx: -1, dy: 0)) {
      _currentPiece = _currentPiece.copyWith(position: Point(_currentPiece.position.x - 1, _currentPiece.position.y));
      playMoveSound();
      notifyListeners();
    }
  }

  void moveRight() {
    if (_gameOver || !_playing) return;
    if (canMove(_currentPiece, dx: 1, dy: 0)) {
      _currentPiece = _currentPiece.copyWith(position: Point(_currentPiece.position.x + 1, _currentPiece.position.y));
      playMoveSound();
      notifyListeners();
    }
  }

  void rotate() {
    if (_gameOver || !_playing) return;
    final rotatedPiece = _currentPiece.rotate();
    if (!canMove(rotatedPiece, dx: 0, dy: 0)) {
      // If rotation is not possible, do nothing (piece remains unchanged)
    } else {
      _currentPiece = rotatedPiece;
      playRotateSound();
    }
    notifyListeners();
  }

  bool canMove(Piece piece, {required int dx, required int dy}) {
    for (int i = 0; i < piece.shape.length; i++) {
      for (int j = 0; j < piece.shape[i].length; j++) {
        if (piece.shape[i][j] == 1) {
          int newX = piece.position.x + j + dx;
          int newY = piece.position.y + i + dy;

          // Check bounds
          if (newX < 0 || newX >= cols || newY >= rows) {
            return false;
          }

          // Check collision with other pieces
          // Only check if the target cell is within the grid bounds
          if (newY >= 0 && grid[newY][newX] != null) {
            return false;
          }
        }
      }
    }
    return true;
  }

  

  void _lockPiece() {
    playLockSound();
    for (int i = 0; i < _currentPiece.shape.length; i++) {
      for (int j = 0; j < _currentPiece.shape[i].length; j++) {
        if (_currentPiece.shape[i][j] == 1) {
          int row = _currentPiece.position.y + i;
          int col = _currentPiece.position.x + j;
          if (row >= 0 && row < rows && col >= 0 && col < cols) {
            grid[row][col] = _currentPiece.type;
          }
        }
      }
    }
    _clearLines();
    _newPiece();
    // notifyListeners(); // Moved to _clearLines or handled by subsequent calls
    // If _clearLines doesn't notify, we need to notify here
    // However, _newPiece() might also trigger a game over, which notifies.
    // For now, keep it here, but consider if it's truly redundant.
    notifyListeners();
  }

  void _clearLines() {
    int linesCleared = 0;
    List<List<Tetromino?>> newGrid = List.generate(rows, (_) => List.filled(cols, null));
    int newGridRow = rows - 1;

    for (int i = rows - 1; i >= 0; i--) {
      if (!grid[i].contains(null)) {
        linesCleared++;
      } else {
        newGrid[newGridRow] = grid[i];
        newGridRow--;
      }
    }
    grid = newGrid;

    if (linesCleared > 0) {
      playClearSound();
      _lines += linesCleared;
      int points = 0;
      switch (linesCleared) {
        case 1:
          points = 100;
          break;
        case 2:
          points = 300;
          break;
        case 3:
          points = 500;
          break;
        case 4:
          points = 800;
          break;
      }
      _score += points * _level;

      // Check for level up
      int newLevel = (_lines ~/ 10) + 1;
      if (newLevel > _level) {
        _level = newLevel;
        // Increase speed
        _resetTimer();
      }
    }
  }

  void togglePlaying() {
    if (_gameOver) return;
    _playing = !_playing;
    _resetTimer();
    if (_playing) {
      _startElapsedTimer();
    } else {
      _stopElapsedTimer();
    }
    notifyListeners();
  }

  void toggleSound() {
    _volume = (_volume + 1) % 4;
    _soundOn = _volume > 0;
    notifyListeners();
  }

  void playMoveSound() {
    _moveSoundDebounceTimer?.cancel();
    _moveSoundDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (_soundOn) {
        _soundEffectsPlayer.play(AssetSource('sounds/gameboy-pluck-41265.mp3'), volume: _volume / 3);
      }
    });
  }

  void playRotateSound() {
    if (_soundOn) {
      _soundEffectsPlayer.play(AssetSource('sounds/gameboy-pluck-41265 (1).mp3'), volume: _volume / 3);
    }
  }

  void playLockSound() {
    if (_soundOn) {
      _soundEffectsPlayer.play(AssetSource('sounds/bit_bomber1-89534.mp3'), volume: _volume / 3);
    }
  }

  void playClearSound() {
    if (_soundOn) {
      _soundEffectsPlayer.play(AssetSource('sounds/cartoon_16-74046.mp3'), volume: _volume / 3);
    }
  }

  void playGameOverSound() {
    if (_soundOn) {
      _soundEffectsPlayer.play(AssetSource('sounds/8bit-ringtone-free-to-use-loopable-44702.mp3'), volume: _volume / 3);
    }
  }

  void stopAllSounds() {
    _soundEffectsPlayer.stop();
  }

  void _startElapsedTimer() {
    _gameSecondsTimer?.cancel();
    _gameSecondsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_playing && !_gameOver) {
        _elapsedSeconds++;
        notifyListeners();
      }
    });
  }

  void _stopElapsedTimer() {
    _gameSecondsTimer?.cancel();
    _gameSecondsTimer = null;
  }

  @override
  void dispose() {
    _soundEffectsPlayer.dispose();
    _timer?.cancel();
    _moveSoundDebounceTimer?.cancel();
    _gameSecondsTimer?.cancel();
    super.dispose();
  }
}

  
