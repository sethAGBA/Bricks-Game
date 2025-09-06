import 'dart:async';
import 'dart:math';
import 'package:bricks/game/piece.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:bricks/audio/sfx.dart';

class RaceGameState with ChangeNotifier {
  // Game state
  int _score = 0;
  int _highScore = 0;
  int _level = 1;
  int _initialLevel = 1;
  int _life = 4;
  bool _playing = false;
  bool _gameOver = false;
  bool _isCrashing = false;
  int _crashAnimationFrame = 0;
  VoidCallback? onGameOver;
  int _elapsedSeconds = 0;
  bool _isStartingGame = false;
  Timer? _timer;
  Timer? _gameSecondsTimer;
  int _speedSetting = 1;
  bool _isAccelerating = false; // New flag
  bool _isDecelerating = false; // New flag
  bool _enemyAccelerating = false; // When true, enemies move faster
  bool _testModeNoRoadMove = false; // New flag for testing
  bool _trailBlinkOn = true; // Blink flag for visual trails/centers
  Timer? _trailBlinkTimer;
  Timer? _gameOverAnimTimer;
  int _gameOverAnimFrame = 0;

  late Car playerCar;
  late List<Car> otherCars;
  late Road road;

  // Game grid dimensions (same as other games)
  static const int rows = 20;
  static const int cols = 11;

  // Audio state
  bool _soundOn = true;
  int _volume = 2;
  // Audio players
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // Getters
  int get score => _score;
  int get level => _level;
  int get life => _life;
  bool get playing => _playing;
  bool get gameOver => _gameOver;
  bool get isCrashing => _isCrashing;
  int get crashAnimationFrame => _crashAnimationFrame;
  bool get soundOn => _soundOn;
  int get volume => _volume;
  int get elapsedSeconds => _elapsedSeconds;
  int get highScore => _highScore;
  bool get isStartingGame => _isStartingGame;
  int get speedSetting => _speedSetting;
  bool get isAccelerating => _isAccelerating; // New getter
  bool get isDecelerating => _isDecelerating; // New getter
  bool get enemyAccelerating => _enemyAccelerating;
  bool get trailBlinkOn => _trailBlinkOn;
  int get gameOverAnimFrame => _gameOverAnimFrame;

  RaceGameState() {
    loadHighScore();
    playerCar = Car.init();
    otherCars = [];
    road = Road.init();
  }

  void applyMenuSettings({required int level, required int speed}) {
    _initialLevel = level.clamp(1, 10);
    _level = _initialLevel;
    _speedSetting = speed.clamp(1, 10);
    notifyListeners();
  }

  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('raceHighScore') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('raceHighScore', _highScore);
  }

  void startGame() {
    _playing = true;
    _gameOver = false;
    _isCrashing = false;
    _crashAnimationFrame = 0;
    _score = 0;
    _life = 4;
    _elapsedSeconds = 0;
    _level = _initialLevel;
    _timer?.cancel();
    _gameSecondsTimer?.cancel();

    playerCar = Car.init();
    otherCars = [Car.generate()];
    road = Road.init();

    _resetTimer();
    _startElapsedTimer();
  // Start background engine music if sound enabled
  _startEngineMusic();
    _startTrailBlink();
    notifyListeners();
  }

  void _resetTimer() {
    _resetTimerInternal();
  }

  int _computeBaseSpeed() {
    // base interval in milliseconds: decreases with higher speedSetting and level
    final int base = 300 - _speedSetting * 18 - _level * 10;
    return base.clamp(40, 1000);
  }

  // Compute how many steps enemies will move in the next tick.
  int _computeEnemyMultiplier() {
    final int baseEnemySteps = 1 + (_level ~/ 2);
    if (_enemyAccelerating) {
      final int maxEnemyMultiplier = 40;
      int enemyMultiplier = baseEnemySteps * (1 + _level);
      enemyMultiplier *= (1 + (_speedSetting ~/ 3));
      if (enemyMultiplier > maxEnemyMultiplier) enemyMultiplier = maxEnemyMultiplier;
      return enemyMultiplier;
    }
    return baseEnemySteps;
  }

  void _resetTimerInternal({bool forceAccelerated = false}) {
    // Adjust the global tick when enemy acceleration is engaged to make the
    // DROP button effect immediately visible. When accelerated, shorten the
    // interval aggressively (about 35% of base), with sane clamps.
    _timer?.cancel();
    if (_playing && !_gameOver && !_isCrashing) {
      final int baseSpeed = _computeBaseSpeed();
      int interval = baseSpeed;
      if (forceAccelerated || _enemyAccelerating) {
        // Acceleration effect scales with level and speedSetting.
        // Lower ratio => faster ticks. Example (level,speed)->ratio approx:
        // (1,1)=0.50, (5,5)=~0.33, (10,10)=~0.18
        final double baseRatio = 0.50;
        final double perLevelDrop = 0.025; // 2.5% per level above 1
        final double perSpeedDrop = 0.02;  // 2% per speed step above 1
        final double rawRatio = baseRatio
            - perLevelDrop * (_level - 1)
            - perSpeedDrop * (_speedSetting - 1);
        final double ratio = rawRatio.clamp(0.12, 0.50);
        final int accelerated = (baseSpeed * ratio).round();
        interval = accelerated.clamp(15, 1000);
      }
      _timer = Timer.periodic(Duration(milliseconds: interval), (timer) {
        gameLoop();
      });
    }
  }

  void gameLoop() {
    if (!_playing || _gameOver || _isCrashing) return;

    // Capture previous positions so we can detect crossing collisions
    final prevPlayerPoints = List<Point<int>>.from(playerCar.points);
    final prevOtherPointsList = otherCars.map((c) => List<Point<int>>.from(c.points)).toList();
    final prevRoadPoints = List<Point<int>>.from(road.points);

    // Move other cars and road first
    // If enemy acceleration is active, move them multiple times per tick
    // Enemy movement scales with level. At higher levels enemies step more per tick.
    final int baseEnemySteps = 1 + (_level ~/ 2); // increases over levels
    // When player holds enemy-accel, scale multiplier proportionally to level
    // so acceleration becomes stronger at higher levels. Cap to avoid extreme values.
    final int maxEnemyMultiplier = 40;
    int enemyMultiplier;
    if (_enemyAccelerating) {
      // Proportional to level: base * (1 + level)
      enemyMultiplier = baseEnemySteps * (1 + _level);
      // Apply additional factor from speedSetting for finer control
      enemyMultiplier *= (1 + (_speedSetting ~/ 3));
      if (enemyMultiplier > maxEnemyMultiplier) enemyMultiplier = maxEnemyMultiplier;
    } else {
      enemyMultiplier = baseEnemySteps;
    }
    for (var car in otherCars) {
      for (int m = 0; m < enemyMultiplier; m++) {
        car.moveDown(allowOverflow: true);
      }
    }
    if (!_testModeNoRoadMove) { // Only move road if not in test mode
      road.moveDown();
    }

  // Remove cars that moved fully off-screen (all points beyond bottom)
  otherCars.removeWhere((car) => car.points.every((p) => p.y >= RaceGameState.rows));

    // Move player according to accelerate/decelerate flags.
    // When accelerating/decelerating, perform multiple small moves per tick
    // so the vehicle effectively moves faster while the flag is active.
  // Make vertical acceleration more noticeable: multiplier depends on speedSetting and level
  final int accelMultiplier = (1 + ((_speedSetting + _level) ~/ 3)).clamp(1, 6);
    bool collidedDuringMove = false;
    if (_isAccelerating) {
      for (int i = 0; i < accelMultiplier; i++) {
        playerCar.moveUp(); // Move player car up when accelerating
        // After each micro-move, check immediate collision to avoid skipping
        if (playerCar.isCrashed(otherCars) || playerCar.isCrashedWithRoad(road)) {
          collidedDuringMove = true;
          break;
        }
      }
    } else if (_isDecelerating) {
      for (int i = 0; i < accelMultiplier; i++) {
        playerCar.moveDown(); // Move player car down when decelerating
        if (playerCar.isCrashed(otherCars) || playerCar.isCrashedWithRoad(road)) {
          collidedDuringMove = true;
          break;
        }
      }
    }

    // Collision detection: direct overlap OR crossing (swapped positions during move)
    bool collided = false;
    if (playerCar.isCrashed(otherCars) || playerCar.isCrashedWithRoad(road)) {
      collided = true;
    } else {
      // Check crossing with other cars: player previous == other current && player current == other previous
      for (int ci = 0; ci < otherCars.length && !collided; ci++) {
        final prevOther = prevOtherPointsList.length > ci ? prevOtherPointsList[ci] : <Point<int>>[];
        final currOther = otherCars[ci].points;
        for (final pPrev in prevPlayerPoints) {
          for (final qCurr in currOther) {
            if (pPrev.x == qCurr.x && pPrev.y == qCurr.y) {
              // find corresponding current player point and prev other point to see if they swapped
              for (final pCurr in playerCar.points) {
                for (final qPrev in prevOther) {
                  if (pCurr.x == qPrev.x && pCurr.y == qPrev.y) {
                    collided = true;
                    break;
                  }
                }
                if (collided) break;
              }
            }
            if (collided) break;
          }
          if (collided) break;
        }
      }

      // Check crossing with road
      if (!collided) {
        for (final pPrev in prevPlayerPoints) {
          for (final rCurr in road.points) {
            if (pPrev.x == rCurr.x && pPrev.y == rCurr.y) {
              for (final pCurr in playerCar.points) {
                for (final rPrev in prevRoadPoints) {
                  if (pCurr.x == rPrev.x && pCurr.y == rPrev.y) {
                    collided = true;
                    break;
                  }
                }
                if (collided) break;
              }
            }
            if (collided) break;
          }
          if (collided) break;
        }
      }
    }

    if (collided || collidedDuringMove) {
      // print('Collision detected (post-move or crossing)');
      _isCrashing = true;
      _timer?.cancel();
      _gameSecondsTimer?.cancel();
      _startCrashAnimation();
      return;
    }

    // Spawn frequency and max concurrent cars scale with level so the road
    // becomes busier at higher levels.
  final int spawnInterval = max(2, 9 - _level); // lower interval at higher levels
  final int maxConcurrent = 2 + (_level ~/ 2); // allow more cars as level increases (base 2)
    if (road.traffic % spawnInterval == 0) {
  // Increase spawn count with level so higher levels produce more enemies
  // while still capping to avoid overwhelming the player.
  int computedSpawn = 1 + (_level ~/ 2); // grows every two levels
  const int maxSpawnPerTick = 4;
  final int spawnCount = computedSpawn > maxSpawnPerTick ? maxSpawnPerTick : computedSpawn;
  // per-row cap: allow up to 2 enemies per initial row (side-by-side)
  const int perRowCap = 2;
  // Track lanes used this tick and counts of how many cars were placed on each row
  final usedLanes = <int>{};
  final Map<int, int> rowCount = <int, int>{};
      final random = Random();
      for (int s = 0; s < spawnCount; s++) {
        if (otherCars.length >= maxConcurrent) break;
        // pick a lane not used already this tick if possible
        List<int> lanes = [0, 1, 2];
        lanes.removeWhere((l) => usedLanes.contains(l));
        int lane;
        if (lanes.isEmpty) {
          // all lanes already used; pick any lane at random
          lane = random.nextInt(3);
        } else {
          lane = lanes[random.nextInt(lanes.length)];
        }
        final candidate = Car.generateInLane(lane);

        // Keep the candidate at the default initial Y so multiple spawned
        // this tick align on the same initial line.
        final int candidateRow = candidate.points.map((p) => p.y).reduce((a, b) => a < b ? a : b);

        // Enforce per-row cap among cars spawned this tick
        final int existingOnRow = rowCount[candidateRow] ?? 0;
        if (existingOnRow >= perRowCap) {
          // row already reached cap this tick; try next iteration
          continue;
        }

        // Add candidate and update tracking
        otherCars.add(candidate);
        usedLanes.add(lane);
        rowCount[candidateRow] = existingOnRow + 1;

        // Optionally spawn a side-by-side pair for higher levels by placing
        // the second enemy in an adjacent lane (if available and row count allows).
        const int pairLevel = 3; // starting level for side-by-side pairs
        if (_level >= pairLevel && otherCars.length < maxConcurrent) {
          // try neighboring lanes (left, then right)
          final neighbors = <int>[];
          if (lane - 1 >= 0) neighbors.add(lane - 1);
          if (lane + 1 <= 2) neighbors.add(lane + 1);
          for (final n in neighbors) {
            if (otherCars.length >= maxConcurrent) break;
            if (usedLanes.contains(n)) continue; // lane already used this tick
            final pairCandidate = Car.generateInLane(n);
            final int pairRow = pairCandidate.points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
            final int existingOnPairRow = rowCount[pairRow] ?? 0;
            if (pairRow == candidateRow && existingOnPairRow < perRowCap) {
              // place the side-by-side enemy on the same row
              otherCars.add(pairCandidate);
              usedLanes.add(n);
              rowCount[pairRow] = existingOnPairRow + 1;
              break;
            }
          }
        }
      }
    }

    _score += 10;

    // Level up logic
    final newLevel = (_score ~/ 1000) + 1; // Level up every 1000 points
    if (newLevel > _level) {
      _level = newLevel;
      _resetTimer(); // Apply new speed
    }

    // Collision check is now handled in _checkCollisionAndHandleCrash()
    // which is called when playerCar moves.

    notifyListeners();
  }

  void _startCrashAnimation() {
    const int animationFrames = 12; // tighter, more expressive explosion
    const Duration frameDuration = Duration(milliseconds: 60);

    Timer.periodic(frameDuration, (timer) {
      _crashAnimationFrame++;
      if (_crashAnimationFrame >= animationFrames) {
        timer.cancel();
        _isCrashing = false;
        _crashAnimationFrame = 0;
        handleCrash(); // Perform crash logic after animation
      } else {
        notifyListeners();
      }
    });
    // Play crash sound effect
    if (_soundOn) {
      Sfx.play('sounds/bit_bomber1-89534.mp3', volume: _volume / 3);
    }
  }

  void handleCrash() {
    _life--;
    if (_life <= 0) {
      _gameOver = true;
      _playing = false;
      _timer?.cancel();
      _gameSecondsTimer?.cancel();
  // Reset level to 1 on game over to return the player to the initial difficulty
  _level = 1;
      _startGameOverAnim();
      if (_score > _highScore) {
        _highScore = _score;
        _saveHighScore();
      }
    } else {
      // Reset car positions after a crash
      playerCar = Car.init();
      otherCars = [Car.generate()];
      _resetTimer(); // Resume game after crash
      _startElapsedTimer();
    }
    notifyListeners();
  }

  void _startEngineMusic() {
    if (!_soundOn) return;
    // loop engine music
  _musicPlayer.setReleaseMode(ReleaseMode.loop);
  _musicPlayer.play(AssetSource('sounds/bllrr-text-loop-82399.mp3'));
  }

  void _stopEngineMusic() {
    _musicPlayer.stop();
  }

  void moveLeft() {
    if (_gameOver || !_playing || _isCrashing) return;
  final prev = List<Point<int>>.from(playerCar.points);
  playerCar.moveLeft();
  _checkCollisionAndHandleCrash(prev);
    notifyListeners();
  }

  void moveRight() {
    if (_gameOver || !_playing || _isCrashing) return;
  final prev = List<Point<int>>.from(playerCar.points);
  playerCar.moveRight();
  _checkCollisionAndHandleCrash(prev);
    notifyListeners();
  }

  void moveUp() {
    if (_gameOver || !_playing || _isCrashing) return;
    _isAccelerating = true;
    _isDecelerating = false; // Ensure only one is active
    // Immediate burst so a single press produces noticeable upward movement
    final int burst = 1 + (_speedSetting ~/ 2);
    for (int i = 0; i < burst; i++) {
      final prev = List<Point<int>>.from(playerCar.points);
      playerCar.moveUp();
      _checkCollisionAndHandleCrash(prev);
      if (_isCrashing) break;
    }
    notifyListeners();
  }

  // Backwards-compatible aliases
  void accelerate() => moveUp();


  void moveDown() {
    if (_gameOver || !_playing || _isCrashing) return;
    _isDecelerating = true;
    _isAccelerating = false; // Ensure only one is active
    // Immediate burst so a single press produces noticeable downward movement
    final int burst = 1 + (_speedSetting ~/ 2);
    for (int i = 0; i < burst; i++) {
      final prev = List<Point<int>>.from(playerCar.points);
      playerCar.moveDown();
      _checkCollisionAndHandleCrash(prev);
      if (_isCrashing) break;
    }
    notifyListeners();
  }

  void decelerate() => moveDown();

  // Enemy acceleration control
  void startEnemyAcceleration() {
    _enemyAccelerating = true;
    notifyListeners();
  // shorten timer interval to speed up the loop when enemies are accelerated
  _resetTimerInternal(forceAccelerated: true);
  }

  void stopEnemyAcceleration() {
    _enemyAccelerating = false;
    notifyListeners();
  _resetTimerInternal();
  }

  void stopAccelerating() {
    _isAccelerating = false;
    notifyListeners();
  }

  void stopDecelerating() {
    _isDecelerating = false;
    notifyListeners();
  }

  // Enhanced collision checker. If [prevPlayerPoints] is provided, we also
  // detect "crossing" collisions that happen between a player micro-move
  // and the next automatic move of other cars/road (i.e. swapping positions).
  void _checkCollisionAndHandleCrash([List<Point<int>>? prevPlayerPoints]) {
    // Direct overlap check
    if (playerCar.isCrashed(otherCars) || playerCar.isCrashedWithRoad(road)) {
      _isCrashing = true;
      _timer?.cancel();
      _gameSecondsTimer?.cancel();
      _startCrashAnimation();
      return;
    }

    if (prevPlayerPoints == null) return;

    // Compute enemy movement path (multiple steps) for the next tick.
    final int enemySteps = _computeEnemyMultiplier();

    // Check each other car: build the set of positions it will occupy during
    // the next enemySteps steps, and detect overlaps or crossing with the
    // player's previous/current positions.
    for (final other in otherCars) {
      final prevOther = other.points;
      final Set<String> prevOtherSet = prevOther.map((p) => '${p.x},${p.y}').toSet();

      // Build path positions for steps 1..enemySteps
      final Set<String> otherPath = <String>{};
      for (int s = 1; s <= enemySteps; s++) {
        for (final q in prevOther) {
          otherPath.add('${q.x},${q.y + s}');
        }
      }

      // If player's current position intersects otherPath => collision
      for (final pCurr in playerCar.points) {
        if (otherPath.contains('${pCurr.x},${pCurr.y}')) {
          _isCrashing = true;
          _timer?.cancel();
          _gameSecondsTimer?.cancel();
          _startCrashAnimation();
          return;
        }
      }

      // If player's previous position is in otherPath and player's current
      // position was the car's previous position => crossing swap
      for (final pPrev in prevPlayerPoints) {
        if (otherPath.contains('${pPrev.x},${pPrev.y}')) {
          for (final pCurr in playerCar.points) {
            if (prevOtherSet.contains('${pCurr.x},${pCurr.y}')) {
              _isCrashing = true;
              _timer?.cancel();
              _gameSecondsTimer?.cancel();
              _startCrashAnimation();
              return;
            }
          }
        }
      }
    }

    // Road moves only once per tick in the main loop; simulate one-step road move
    final prevRoadPoints = road.points;
    final Set<String> roadNext = prevRoadPoints.map((p) => '${p.x},${p.y + 1}').toSet();
    for (final pCurr in playerCar.points) {
      if (roadNext.contains('${pCurr.x},${pCurr.y}')) {
        _isCrashing = true;
        _timer?.cancel();
        _gameSecondsTimer?.cancel();
        _startCrashAnimation();
        return;
      }
    }
    for (final pPrev in prevPlayerPoints) {
      if (roadNext.contains('${pPrev.x},${pPrev.y}')) {
        for (final pCurr in playerCar.points) {
          if (prevRoadPoints.any((r) => r.x == pCurr.x && r.y == pCurr.y)) {
            _isCrashing = true;
            _timer?.cancel();
            _gameSecondsTimer?.cancel();
            _startCrashAnimation();
            return;
          }
        }
      }
    }
  }

  

  

  void togglePlaying() {
    if (_gameOver) return;
    _playing = !_playing;
    if (_playing) {
      _resetTimer();
      _startElapsedTimer();
      _startTrailBlink();
    } else {
      _timer?.cancel();
      _stopElapsedTimer();
      _stopTrailBlink();
      _stopEngineMusic();
      Sfx.stopAll();
    }
    notifyListeners();
  }

  void toggleSound() {
    _volume = (_volume + 1) % 4;
    _soundOn = _volume > 0;
    notifyListeners();
    if (_soundOn) {
      _startEngineMusic();
    } else {
      _stopEngineMusic();
    }
  }

  void stop() {
    _playing = false;
    _gameOver = false;
    _isCrashing = false;
    _crashAnimationFrame = 0;
    _timer?.cancel();
    _gameSecondsTimer?.cancel();
    _stopEngineMusic();
    Sfx.stopAll();
    _score = 0;
    _life = 4;
    _elapsedSeconds = 0;
    _level = _initialLevel;
    playerCar = Car.init();
    otherCars = [Car.generate()];
    road = Road.init();
    notifyListeners();
  }

  void setTestModeNoRoadMove(bool value) {
    _testModeNoRoadMove = value;
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
  }

  void _startGameOverAnim() {
    _gameOverAnimTimer?.cancel();
    _gameOverAnimFrame = 0;
    _gameOverAnimTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!_gameOver) { t.cancel(); return; }
      _gameOverAnimFrame++;
      if (_gameOverAnimFrame > 24) {
        t.cancel();
      }
      notifyListeners();
    });
  }

  void _startTrailBlink() {
    _trailBlinkTimer?.cancel();
    _trailBlinkTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (_playing && !_gameOver && !_isCrashing) {
        _trailBlinkOn = !_trailBlinkOn;
        notifyListeners();
      }
    });
  }

  void _stopTrailBlink() {
    _trailBlinkTimer?.cancel();
    _trailBlinkTimer = null;
    _trailBlinkOn = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gameSecondsTimer?.cancel();
  _musicPlayer.dispose();
  _sfxPlayer.dispose();
    _stopTrailBlink();
    _gameOverAnimTimer?.cancel();
    super.dispose();
  }
}

class Car {
  List<Point<int>> points;

  Car(this.points);

  static final _carShape = [
    Point(1, 0),
    Point(0, 1), Point(1, 1), Point(2, 1),
    Point(1, 2),
    Point(0, 3), Point(2, 3),
  ];

  static Car init() {
    final carPoints = _carShape.map((p) => Point(p.x + 4, p.y + 16)).toList();
    return Car(carPoints);
  }

  static Car generate() {
    final random = Random();
    final lane = random.nextInt(3); // 0, 1, or 2
    final x = 1 + (lane * 3); // 1, 4, or 7
    final carPoints = _carShape.map((p) => Point(p.x + x, p.y - 4)).toList();
    return Car(carPoints);
  }

  // Generate a car in a specific lane (0..2)
  static Car generateInLane(int lane) {
    final l = lane.clamp(0, 2);
    final x = 1 + (l * 3);
    final carPoints = _carShape.map((p) => Point(p.x + x, p.y - 4)).toList();
    return Car(carPoints);
  }

  void moveDown({bool allowOverflow = false}) {
    // print('Before moveDown: ${points.map((p) => p.y).toList()}');
    if (!allowOverflow && points.any((p) => p.y >= RaceGameState.rows - 1)) return;
    for (var i = 0; i < points.length; i++) {
      points[i] = Point(points[i].x, points[i].y + 1);
    }
    // print('After moveDown: ${points.map((p) => p.y).toList()}');
  }

  void moveUp() {
    // print('Before moveUp: ${points.map((p) => p.y).toList()}');
    if (points.any((p) => p.y <= 0)) return;
    for (var i = 0; i < points.length; i++) {
      points[i] = Point(points[i].x, points[i].y - 1);
    }
    // print('After moveUp: ${points.map((p) => p.y).toList()}');
  }

  void moveLeft() {
    if (points.any((p) => p.x <= 1)) return;
    for (var i = 0; i < points.length; i++) {
      points[i] = Point(points[i].x - 3, points[i].y);
    }
  }

  void moveRight() {
    if (points.any((p) => p.x >= 7)) return;
    for (var i = 0; i < points.length; i++) {
      points[i] = Point(points[i].x + 3, points[i].y);
    }
  }

  bool isCrashed(List<Car> otherCars) {
    for (final otherCar in otherCars) {
      for (final p1 in points) {
        for (final p2 in otherCar.points) {
          if (p1.x == p2.x && p1.y == p2.y) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool isCrashedWithRoad(Road road) {
    // print('isCrashedWithRoad: Player points: ${points}, Road points: ${road.points}');
    for (final p1 in points) {
      for (final p2 in road.points) {
        if (p1.x == p2.x && p1.y == p2.y) {
          // print('Overlap at: (${p1.x}, ${p1.y})');
          return true;
        }
      }
    }
    return false;
  }
}

class Road {
  List<Point<int>> points;
  int traffic = 0;

  Road(this.points);

  static Road init() {
    final roadPoints = <Point<int>>[];
    for (var i = 0; i < RaceGameState.rows; i++) {
      if (i % 4 != 0) { // Dashed pattern from Java
        roadPoints.add(Point(0, i));
        roadPoints.add(Point(RaceGameState.cols - 1, i));
      }
    }
    return Road(roadPoints);
  }

  void moveDown() {
    for (var i = 0; i < points.length; i++) {
      points[i] = Point(points[i].x, (points[i].y + 1) % RaceGameState.rows);
    }
    traffic++;
  }
}
