import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:bricks/audio/sfx.dart';

enum Direction { up, down, left, right }

class SnakeGameState with ChangeNotifier {
  static const int rows = 20;
  static const int cols = 10;
  static const int _initialSnakeLength = 3;
  static const int _initialSpeed = 300; // milliseconds per tick
  static const int _acceleratedSpeed = 120; // Reduced acceleration speed (slower than before)
  static const int _speedIncreaseInterval = 5; // Increase speed every 5 points
  static const int _speedIncreaseAmount = 10; // Decrease speed by 10ms
  static const int _foodLifespan = 5; // Seconds before food disappears
  static const int _lengthPenaltyAmount = 2; // Number of segments lost on collision
  static const int _maxObstacles = 5; // Maximum number of random obstacles

  int _currentSpeed = _initialSpeed; // Current speed of the snake
  int _speedSetting = 1; // 1..10 from menu

  List<Point<int>> snake = [];
  List<Point<int>> obstacles = []; // New list for obstacles
  Point<int>? food;
  Direction direction = Direction.right;
  bool isGameOver = false;
  bool isPlaying = false;
  bool _isStartingGame = false; // New state for start animation
  Color _startBlinkColor = Colors.transparent; // Color for start blinking text
  bool _isAccelerating = false; // New state for acceleration
  int score = 0;
  int highScore = 0;
  int level = 1;
  int life = 4; // Initial life
  int elapsedSeconds = 0;
  Timer? _timer;
  Timer? _gameTimer; // For tracking elapsed time
  Timer? _foodTimer; // New timer for food lifespan
  Timer? _startBlinkTimer; // Start text blinking timer
  int _foodRemainingSeconds = _foodLifespan;
  final AudioPlayer _soundEffectsPlayer = AudioPlayer();
  late AudioCache _audioCache;
  bool _soundOn = true;
  int _volume = 2;
  bool _isDisposed = false; // Guard against post-dispose callbacks
  int _lastSoundPlayMs = 0; // Debounce for sound plays

  // Getters
  bool get soundOn => _soundOn;
  int get volume => _volume;
  bool get isAccelerating => _isAccelerating;
  bool get isStartingGame => _isStartingGame;
  Color get startBlinkColor => _startBlinkColor;

  SnakeGameState() {
    _initializeGame();
    loadHighScore();
    _audioCache = AudioCache(prefix: 'assets/sounds/');
    _audioCache.loadAll([
      'gameboy-pluck-41265.mp3',
      'gameboy-pluck-41265 (1).mp3',
      'bit_bomber1-89534.mp3',
      'cartoon_16-74046.mp3',
      '8bit-ringtone-free-to-use-loopable-44702.mp3',
    ]);
  }

  void applyMenuSettings({required int level, required int speed}) {
    final int clampedLevel = level.clamp(1, 15); // support up to 15 maps
    _speedSetting = speed.clamp(1, 10);
    this.level = clampedLevel; // store level for map selection
    _currentSpeed = _applySpeedSetting(_initialSpeed, _speedSetting);
    notifyListeners();
  }

  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('snakeHighScore') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('snakeHighScore', highScore);
  }

  void _initializeGame() {
    print('SnakeGameState: _initializeGame called');
    snake = [];
    // Start snake in the middle
    for (int i = 0; i < _initialSnakeLength; i++) {
      snake.add(Point<int>(cols ~/ 2 - i, rows ~/ 2));
    }
    direction = Direction.right;
    isGameOver = false; // Ensure game is not over
    isPlaying = false; // Ensure game is not playing initially
    _isAccelerating = false; // Reset acceleration
    score = 0;
    level = 1;
    life = 4;
    elapsedSeconds = 0;
    _currentSpeed = _initialSpeed; // Initialize current speed
    obstacles = []; // Initialize obstacles list; will be replaced by map if available
    _foodTimer?.cancel(); // Cancel any existing food timer
    _startBlinkTimer?.cancel(); // Cancel any existing start blink timer
    _generateFood();
    // Try to load level-based map asynchronously; fallback keeps random-free board
    _loadMapObstaclesForLevel(level).then((loaded) {
      if (_isDisposed) return;
      if (loaded != null) {
        obstacles = loaded;
        // If current food overlaps obstacles, re-generate
        if (food != null && obstacles.contains(food)) {
          _generateFood();
        }
        notifyListeners();
      } else {
        // Optional: generate a few random obstacles if no map
        _generateObstacles();
        notifyListeners();
      }
    });
    print('SnakeGameState: _initializeGame - isGameOver: $isGameOver, isPlaying: $isPlaying');
    notifyListeners();
  }

  Future<List<Point<int>>?> _loadMapObstaclesForLevel(int lvl) async {
    try {
      final int idx = ((lvl - 1).clamp(0, 15)).toInt();
      final String path = 'assets/snake/${idx.toString().padLeft(2, '0')}.map';
      final String data = await rootBundle.loadString(path);
      final lines = data.split('\n').where((e) => e.isNotEmpty).toList();
      if (lines.length != rows) return null;
      final List<Point<int>> points = [];
      for (int y = 0; y < rows; y++) {
        final row = lines[y];
        if (row.length < cols) return null;
        for (int x = 0; x < cols; x++) {
          if (row[x] == '1') {
            points.add(Point<int>(x, y));
          }
        }
      }
      return points;
    } catch (_) {
      return null;
    }
  }

  void startGame() {
    print('SnakeGameState: startGame called');
    if (isPlaying || _isStartingGame) {
      print('SnakeGameState: startGame - already playing or starting, returning.');
      return;
    }
    stopAllSounds(); // Stop any lingering sounds before starting
    isPlaying = false; // Ensure game is not playing during animation
    _initializeGame(); // Reset game state for a new game
    _isStartingGame = true; // Set starting game flag AFTER reset
    playSound('cartoon_16-74046.mp3'); // Play start game sound

    int blinkCount = 0;
    _startBlinkTimer?.cancel();
    _startBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isDisposed) {
        timer.cancel();
        _startBlinkTimer = null;
        return;
      }
      blinkCount++;
      _startBlinkColor = (blinkCount % 2 == 1) ? Colors.green : Colors.transparent;
      print('SnakeGameState: _startBlinkColor: $_startBlinkColor, blinkCount: $blinkCount');
      notifyListeners();
      if (blinkCount >= 6) { // 3 blinks (on/off is 2 blinks)
        timer.cancel();
        _startBlinkTimer = null;
        _isStartingGame = false; // Reset starting game flag
        print('SnakeGameState: _isStartingGame set to false');
        isPlaying = true; // Start playing
        _resetTimer(); // Start game timer
        _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_isDisposed) {
            timer.cancel();
            return;
          }
          elapsedSeconds++;
          notifyListeners();
        });
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void _resetTimer() {
    print('SnakeGameState: _resetTimer called');
    _timer?.cancel();
    final base = _isAccelerating ? _acceleratedSpeed : _currentSpeed;
    final speed = base;
    _timer = Timer.periodic(Duration(milliseconds: speed), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _moveSnake();
    });
  }

  int _applySpeedSetting(int baseMs, int setting) {
    final double factor = (11 - setting) / 10.0; // 1..10 -> 1.0..0.1
    final int ms = (baseMs * factor).round();
    return ms.clamp(60, 800);
  }

  void toggleAcceleration() {
    _isAccelerating = !_isAccelerating;
    _resetTimer(); // Reset timer with new speed
    notifyListeners();
  }

  void togglePlaying() {
    print('SnakeGameState: togglePlaying called');
    isPlaying = !isPlaying;
    if (isPlaying) {
      _resetTimer(); // Resume game
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        elapsedSeconds++;
        notifyListeners();
      });
    } else {
      _timer?.cancel(); // Pause game
      _gameTimer?.cancel();
      stopAllSounds(); // Ensure any playing sounds are stopped when pausing
    }
    notifyListeners();
  }

  void toggleSound() {
    _volume = (_volume + 1) % 4;
    _soundOn = _volume > 0;
    if (!_soundOn) {
      stopAllSounds();
    }
    notifyListeners();
  }

  void playSound(String soundPath) {
    if (!_soundOn || _isDisposed) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSoundPlayMs < 80) return; // debounce audio spam
    _lastSoundPlayMs = now;
    Sfx.play('sounds/$soundPath', volume: _volume / 3);
  }

  void stopAllSounds() {
    try { _soundEffectsPlayer.stop(); } catch (_) {}
  }

  void _generateFood() {
    _foodTimer?.cancel(); // Cancel previous food timer
    final random = Random();
    Point<int> newFood;
    do {
      newFood = Point<int>(random.nextInt(cols), random.nextInt(rows));
    } while (snake.contains(newFood) || obstacles.contains(newFood)); // Ensure food doesn't spawn on snake or obstacles
    food = newFood;
    _foodRemainingSeconds = _foodLifespan;
    notifyListeners();

    // Use a periodic timer so we can pause/resume with isPlaying
    _foodTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isGameOver) {
        timer.cancel();
        return;
      }
      if (!isPlaying) {
        return; // paused: do not count down
      }
      _foodRemainingSeconds--;
      if (_foodRemainingSeconds <= 0) {
        print('SnakeGameState: Food expired!');
        food = null; // Food disappears
        if (life > 0) {
          playSound('8bit-ringtone-free-to-use-loopable-44702.mp3'); // lose life sound or notify
          // regenerate a new food and reset counter
          _foodTimer?.cancel();
          _generateFood();
        } else {
          _gameOver();
        }
        notifyListeners();
      }
    });
  }

  void _generateObstacles() {
    obstacles.clear();
    final random = Random();
    int numObstacles = random.nextInt(_maxObstacles) + 1; // Generate 1 to _maxObstacles

    for (int i = 0; i < numObstacles; i++) {
      Point<int> newObstacle;
      do {
        newObstacle = Point<int>(random.nextInt(cols), random.nextInt(rows));
      } while (snake.contains(newObstacle) || newObstacle == food || obstacles.contains(newObstacle));
      obstacles.add(newObstacle);
    }
  }

  void _moveSnake() {
    print('SnakeGameState: _moveSnake called'); // Ensure this print always fires
    if (isGameOver || !isPlaying) {
      print('SnakeGameState: _moveSnake - game over or not playing');
      return;
    }

    final head = snake.first;
    Point<int> newHead;

    switch (direction) {
      case Direction.up:
        newHead = Point<int>(head.x, head.y - 1);
        break;
      case Direction.down:
        newHead = Point<int>(head.x, head.y + 1);
        break;
      case Direction.left:
        newHead = Point<int>(head.x - 1, head.y);
        break;
      case Direction.right:
        newHead = Point<int>(head.x + 1, head.y);
        break;
    }

    // Check for collisions
    if (newHead.x < 0 || newHead.x >= cols ||
        newHead.y < 0 || newHead.y >= rows ||
        snake.contains(newHead) ||
        obstacles.contains(newHead)) {
      print('SnakeGameState: Collision detected!');
      life--;
      if (life > 0) {
        playSound('8bit-ringtone-free-to-use-loopable-44702.mp3'); // Sound for losing a life
        _resetSnakeAndFood();
      } else {
        _gameOver();
      }
      return;
    }

    snake.insert(0, newHead); // Add new head

    if (newHead == food) {
      score++;
      _foodTimer?.cancel(); // Cancel food timer when eaten
      _generateFood();
      playSound('gameboy-pluck-41265.mp3'); // Sound for eating food
      // Increase speed based on score
      if (score % _speedIncreaseInterval == 0) {
        _currentSpeed = max(_acceleratedSpeed, _currentSpeed - _speedIncreaseAmount);
        _resetTimer(); // Apply new speed
      }
    } else {
      snake.removeLast(); // Remove tail if no food eaten
    }
    print('Snake head: ${snake.first}, Food: $food, Snake body: $snake'); // Detailed debug print
    notifyListeners();
  }

  void _gameOver() {
    print('SnakeGameState: _gameOver called'); // Debug print for game over
    isGameOver = true;
    isPlaying = false;
    _timer?.cancel();
    _gameTimer?.cancel();
    _foodTimer?.cancel(); // Cancel food timer on game over
    stopAllSounds();
    if (score > highScore) {
      highScore = score;
      _saveHighScore();
    }
    notifyListeners();
  }

  void _resetSnakeAndFood() {
    snake = [];
    for (int i = 0; i < _initialSnakeLength; i++) {
      snake.add(Point<int>(cols ~/ 2 - i, rows ~/ 2));
    }
    direction = Direction.right;
    _generateFood();
    notifyListeners();
  }

  void changeDirection(Direction newDirection) {
    if (isPlaying) {
      // Prevent immediate reversal
      if ((newDirection == Direction.up && direction == Direction.down) ||
          (newDirection == Direction.down && direction == Direction.up) ||
          (newDirection == Direction.left && direction == Direction.right) ||
          (newDirection == Direction.right && direction == Direction.left)) {
        return;
      }
      direction = newDirection;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _gameTimer?.cancel();
    _foodTimer?.cancel(); // Cancel food timer on dispose
    _startBlinkTimer?.cancel();
    _soundEffectsPlayer.dispose();
    super.dispose();
  }
}
