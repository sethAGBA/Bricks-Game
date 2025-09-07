import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bricks/audio/sfx.dart';

class TanksGameState with ChangeNotifier {
  static const int rows = 20;
  static const int cols = 10;
  static const int maxLevel = 12;

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
  Tank _player = Tank(Point<int>(cols ~/ 2 - 1, rows ~/ 2 - 1), Dir.up);
  final List<Tank> _enemies = <Tank>[];
  final List<_Bullet> _bullets = <_Bullet>[]; // player bullets with dir
  final List<_Bullet> _enemyBullets = <_Bullet>[];
  final List<TankPowerUp> _powerUps = <TankPowerUp>[];
  final Set<Point<int>> _walls = <Point<int>>{};
  final List<_Impact> _impacts = <_Impact>[]; // short-lived explosion visuals

  // Timers
  Timer? _loopTimer;
  Timer? _secondsTimer;
  Timer? _gameOverAnimTimer;
  int _gameOverAnimFrame = 0;
  int _tick = 0;
  int _tickMs = 320;
  int _lastFireTick = -9999;
  int _killsThisLevel = 0; // still tracked for stats if needed
  int _remainingEnemies = 0; // enemies left to spawn this level
  Boss? _boss; // active boss when present
  int _bossHDir = 1; // boss horizontal direction: 1=right, -1=left
  int _nextSpawnTick = 0;
  int _lastKillTick = 0; // tick of last enemy kill (for spawn pressure)

  // Audio
  bool _soundOn = true;
  int _volume = 2;
  // Effects
  bool _shieldActive = false;
  int _shieldUntilTick = 0;
  bool _rapidActive = false;
  int _rapidUntilTick = 0;

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
  Tank get player => _player;
  List<Tank> get enemies => List.unmodifiable(_enemies);
  List<_Bullet> get bullets => List.unmodifiable(_bullets);
  List<_Bullet> get enemyBullets => List.unmodifiable(_enemyBullets);
  Set<Point<int>> get walls => _walls;
  int get gameOverAnimFrame => _gameOverAnimFrame;
  List<TankPowerUp> get powerUps => List.unmodifiable(_powerUps);
  bool get shieldActive => _shieldActive;
  bool get rapidActive => _rapidActive;
  int get shieldRemainingSeconds => _shieldActive ? ((_shieldUntilTick - _tick) * _tickMs / 1000).ceil() : 0;
  int get rapidRemainingSeconds => _rapidActive ? ((_rapidUntilTick - _tick) * _tickMs / 1000).ceil() : 0;
  List<_Impact> get impacts => List.unmodifiable(_impacts);
  Boss? get boss => _boss;
  bool get bossActive => _boss != null;

  void applyMenuSettings({required int level, required int speed}) {
    _initialLevel = level.clamp(1, maxLevel);
    _level = _initialLevel;
    _speedSetting = speed.clamp(1, 10);
    notifyListeners();
  }

  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('tanksHighScore') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tanksHighScore', _highScore);
  }

  void startGame() {
    Sfx.stopAll();
    _score = 0;
    _life = 4;
    _elapsedSeconds = 0;
    _level = 1; // start at 1
    _playing = true;
    _gameOver = false;
    _gameOverAnimTimer?.cancel();
    _gameOverAnimFrame = 0;
    // Wave start: player appears at the middle, facing up
    _player = Tank(Point<int>(cols ~/ 2 - 1, rows ~/ 2 - 1), Dir.up);
    _enemies.clear();
    _bullets.clear();
    _enemyBullets.clear();
    _walls.clear();
    _powerUps.clear();
    _shieldActive = false; _shieldUntilTick = 0;
    _rapidActive = false; _rapidUntilTick = 0;
    _tick = 0;
    _lastKillTick = 0;
    _nextSpawnTick = 0;
    _spawnWalls();
    _startLevel();
    _resetLoop();
    _startSeconds();
    notifyListeners();
  }

  void _startLevel() {
    if (_level > maxLevel) _level = maxLevel;
    _enemies.clear();
    _bullets.clear();
    _enemyBullets.clear();
    _impacts.clear();
    _boss = null;
    _remainingEnemies = _enemiesForLevel();
    _killsThisLevel = 0;
    _lastKillTick = _tick;
    _spawnEnemies(initial: true);
  }

  void _spawnWalls() {
    // Clear and generate a pattern depending on level
    // Base: side pillars every other row
    for (int r = 2; r < rows - 4; r++) {
      if (r % 2 == 0) {
        _walls.add(Point<int>(2, r));
        _walls.add(Point<int>(cols - 3, r));
      }
    }
    // Add a central zig-zag that grows with level
    final int span = (2 + (_level % 3)); // 2..4 zig segments
    for (int i = 0; i < span; i++) {
      final int r = 3 + i * 2;
      if (r >= rows - 5) break;
      final int c = (i % 2 == 0) ? (cols ~/ 2 - 2) : (cols ~/ 2 + 1);
      if (c >= 0 && c < cols) _walls.add(Point<int>(c, r));
    }
    // Ensure the center 3x3 area is clear for the player spawn
    final int cx = cols ~/ 2 - 1;
    final int cy = rows ~/ 2 - 1;
    for (int dy = 0; dy < 3; dy++) {
      for (int dx = 0; dx < 3; dx++) {
        _walls.remove(Point<int>(cx + dx, cy + dy));
      }
    }
  }

  void _spawnEnemies({bool initial = false}) {
    final rnd = Random();
    final int maxConcurrent = _maxConcurrentEnemies();
    if (_remainingEnemies <= 0 || bossActive) { _nextSpawnTick = _tick + _computeSpawnInterval(); return; }
    int target = initial ? min(4, maxConcurrent) : 1;
    int placed = 0;
    int attempts = 0;
    while (placed < target && attempts < 200 && _enemies.length < maxConcurrent) {
      attempts++;
      // Try one per side first for initial placement
      if (initial) {
        final List<int> sides = [0, 1, 2, 3]..shuffle(rnd);
        for (final s in sides) {
          if (placed >= target || _enemies.length >= maxConcurrent || _remainingEnemies <= 0) break;
          if (_trySpawnOnSide(s, rnd)) { placed++; _remainingEnemies--; }
        }
        if (placed >= target || _enemies.length >= maxConcurrent || _remainingEnemies <= 0) break;
      }
      if (_remainingEnemies > 0 && _trySpawnOnSide(rnd.nextInt(4), rnd)) { placed++; _remainingEnemies--; }
    }
    // schedule next spawn opportunity
    _nextSpawnTick = _tick + _computeSpawnInterval();
  }

  bool _trySpawnOnSide(int side, Random rnd) {
    // Attempt a few times per side to find a valid slot
    for (int i = 0; i < 30; i++) {
      late final Point<int> p;
      late final Dir d;
      switch (side) {
        case 0: // top -> move down
          p = Point<int>(rnd.nextInt(cols - 2), 0);
          d = Dir.down;
          break;
        case 1: // bottom -> move up
          p = Point<int>(rnd.nextInt(cols - 2), rows - 3);
          d = Dir.up;
          break;
        case 2: // left -> move right
          p = Point<int>(0, rnd.nextInt(rows - 2));
          d = Dir.right;
          break;
        default: // right -> move left
          p = Point<int>(cols - 3, rnd.nextInt(rows - 2));
          d = Dir.left;
      }
      if (_canPlaceTankAt(p, d)) {
        _enemies.add(Tank(p, d));
        return true;
      }
    }
    return false;
  }

  void _resetLoop() {
    _loopTimer?.cancel();
    final int base = (320 - _speedSetting * 18 - _level * 10).clamp(60, 1000);
    _tickMs = base;
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

  void stop() {
    _playing = false;
    _gameOver = false;
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    _gameOverAnimTimer?.cancel();
    _gameOverAnimFrame = 0;
    Sfx.stopAll();
    _score = 0; _life = 4; _elapsedSeconds = 0; _level = _initialLevel;
    _player = Tank(Point<int>(cols ~/ 2 - 1, rows ~/ 2 - 1), Dir.up);
    _enemies.clear(); _bullets.clear(); _enemyBullets.clear(); _walls.clear();
    notifyListeners();
  }

  void _tickLoop() {
    if (_gameOver || !_playing) return;
    _tick++;

    // effects expiry
    if (_shieldActive && _tick >= _shieldUntilTick) { _shieldActive = false; }
    if (_rapidActive && _tick >= _rapidUntilTick) { _rapidActive = false; }

    // advance impacts
    if (_impacts.isNotEmpty) {
      _impacts.removeWhere((im) => ++im.frame > im.maxFrames);
    }

    // Move enemy tanks; frequency increases with level
    final int moveEvery = _enemyMoveEvery();
    if (_tick % moveEvery == 0) {
      final rnd = Random();
      for (final e in _enemies) {
        // Occasional random turn; decreases with level (becomes more purposeful)
        final double turnProb = (0.5 - 0.03 * _level).clamp(0.1, 0.5).toDouble();
        if (rnd.nextDouble() < turnProb) {
          e.dir = Dir.values[rnd.nextInt(4)];
        }
        // Try to move; if blocked, choose a better direction (bias towards the player / LOS)
        Dir dir = e.dir;
        Point<int> np = _step(e.pos, dir);
        if (_canPlaceTankAt(np, dir, ignore: e)) {
          e.pos = np;
        } else {
          dir = _chooseEnemyDirection(e);
          np = _step(e.pos, dir);
          if (_canPlaceTankAt(np, dir, ignore: e)) {
            e.dir = dir;
            e.pos = np;
          }
        }
        // Enemy fire: LOS fire probability and random fire scale with level
        final Dir? los = _lineOfSightDir(e.pos, _player.pos);
        final double pLos = _enemyLosFireProb();
        final double pRnd = _enemyRandomFireProb();
        if (los != null && rnd.nextDouble() < pLos) {
          final start = _barrelStart(e.pos, los);
          if (_inBounds(start) && !_walls.contains(start)) {
            _enemyBullets.add(_Bullet(start, los));
            if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265.mp3', volume: _volume / 3);
          }
        } else if (rnd.nextDouble() < pRnd) {
          final start = _barrelStart(e.pos, e.dir);
          if (_inBounds(start) && !_walls.contains(start)) {
            _enemyBullets.add(_Bullet(start, e.dir));
            if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265.mp3', volume: _volume / 3);
          }
        }
      }
    }

    // Boss movement and firing
    if (bossActive) {
      // Horizontal patrol only; speed depends on level
      final int every = _bossMoveEvery();
      if (_tick % every == 0) {
        final Dir horiz = _bossHDir < 0 ? Dir.left : Dir.right;
        // Desired next X
        int nextX = _step(_boss!.pos, horiz).x;
        // Clamp to board so the 7x5 boss stays inside horizontally
        final int minX = 0;
        final int maxX = cols - 7;
        if (nextX < minX || nextX > maxX) {
          // reverse at edges
          _bossHDir = -_bossHDir;
          final Dir rev = _bossHDir < 0 ? Dir.left : Dir.right;
          nextX = _step(_boss!.pos, rev).x;
          nextX = nextX.clamp(minX, maxX);
        } else {
          nextX = nextX.clamp(minX, maxX);
        }
        final Point<int> np = Point<int>(nextX, 1);
        // With clamped X and fixed Y, ensure no collision
        if (_canPlaceBossAt(np, Dir.down)) {
          _boss!.pos = np;
        }
      }
      // Fire straight down from top boss
      if (_tick % 3 == 0) {
        final Point<int> start = _bossBarrelStart(_boss!.pos, Dir.down);
        if (_inBounds(start)) {
          _enemyBullets.add(_Bullet(start, Dir.down));
          if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265.mp3', volume: _volume / 3);
        }
      }
    }

    // Move bullets
    _advanceBullets();
    _advanceEnemyBullets();
    _movePowerUps();

    // Spawning/wave progression
    if (!bossActive) {
      final int maxConcurrent = _effectiveMaxConcurrentEnemies();
      // Ensure at least one enemy: if empty and still enemies remaining, spawn immediately
      if (_remainingEnemies > 0 && _enemies.isEmpty) {
        _spawnEnemies();
      } else if (_remainingEnemies > 0 && _tick >= _nextSpawnTick && _enemies.length < maxConcurrent) {
        _spawnEnemies();
      }
      // If wave cleared, spawn boss
      if (_remainingEnemies <= 0 && _enemies.isEmpty) {
        _spawnBoss();
      }
    }

    if (_score > _highScore) {
      _highScore = _score;
      _saveHighScore();
    }

    notifyListeners();
  }

  void moveLeft() => _movePlayer(Dir.left);
  void moveRight() => _movePlayer(Dir.right);
  void moveUp() => _movePlayer(Dir.up);
  void moveDown() => _movePlayer(Dir.down);

  void _movePlayer(Dir d) {
    if (!_playing || _gameOver) return;
    if (bossActive) {
      // Limit to horizontal movement; keep cannon up
      if (d != Dir.left && d != Dir.right) return;
      _player.dir = Dir.up;
      final np = _step(_player.pos, d);
      if (_canPlaceTankAt(np, Dir.up, ignore: _player)) {
        _player.pos = np;
        notifyListeners();
      }
      return;
    }
    _player.dir = d;
    final np = _step(_player.pos, d);
    if (_canPlaceTankAt(np, d, ignore: _player)) { _player.pos = np; notifyListeners(); }
  }

  void fire() {
    if (!_playing || _gameOver) return;
    // Allow multiple shots when tapping quickly; only block multiple within the same tick
    if (_lastFireTick == _tick && !_rapidActive) {
      return;
    }
    _lastFireTick = _tick;
    final p = _barrelStart(_player.pos, _player.dir);
    if (_inBounds(p)) {
      // Destructible wall at barrel? clear it and don't spawn bullet
      if (_walls.remove(p)) {
        if (_soundOn) Sfx.play('sounds/bit_bomber1-89534.mp3', volume: _volume / 3);
      } else {
        _bullets.add(_Bullet(p, _player.dir));
        if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265 (1).mp3', volume: _volume / 3);
      }
    }
    notifyListeners();
  }

  void _advanceBullets() {
    final remove = <_Bullet>[];
    final add = <_Bullet>[];
    for (final b in _bullets) {
      final nb = _step(b.pos, b.dir);
      if (!_inBounds(nb)) { remove.add(b); continue; }
      // Hit wall: destroy wall and bullet
      if (_walls.remove(nb)) { remove.add(b); _impacts.add(_Impact(nb, 0, 4)); if (_soundOn) Sfx.play('sounds/bit_bomber1-89534.mp3', volume: _volume / 3); continue; }
      // hit enemy? (use 3x3 tank shape)
      final hit = _enemies.indexWhere((e) => _bulletHitsTank(nb, e));
      if (hit >= 0) {
        _score += 20;
        final enemy = _enemies.removeAt(hit);
        _maybeSpawnPowerUp(enemy.pos);
        _impacts.add(_Impact(enemy.pos, 0, 6));
        // Track kill and immediately respawn from a corner near the kill
        _onEnemyKilled(enemy.pos);
        remove.add(b);
        if (_soundOn) Sfx.play('sounds/bit_bomber1-89534.mp3', volume: _volume / 3);
        continue;
      }
      // hit boss? Only shots that enter the cannon count; body hits are ignored (absorbed)
      if (_boss != null) {
        final Point<int> cannon = _bossCannonCell(_boss!);
        if (nb == cannon) {
          _boss!.hp -= 1;
          _impacts.add(_Impact(nb, 0, 4));
          remove.add(b);
          if (_soundOn) Sfx.play('sounds/bit_bomber1-89534.mp3', volume: _volume / 3);
          if (_boss!.hp <= 0) {
            _score += 100; // boss defeated bonus
            _boss = null;
            _onBossDefeated();
          }
          continue;
        } else {
          // If bullet hits boss body, absorb without damage
          bool bodyHit = false;
          for (final cell in _bossCells(_boss!)) { if (cell == nb) { bodyHit = true; break; } }
          if (bodyHit) { remove.add(b); continue; }
        }
      }
      add.add(_Bullet(nb, b.dir)); remove.add(b);
    }
    _bullets..removeWhere((x) => remove.contains(x))..addAll(add);
    // Bullet-vs-bullet: remove pairs at same positions
    if (_enemyBullets.isNotEmpty && _bullets.isNotEmpty) {
      final toRemovePlayer = <_Bullet>[];
      final toRemoveEnemy = <_Bullet>[];
      for (final pb in _bullets) {
        final idx = _enemyBullets.indexWhere((eb) => eb.pos == pb.pos);
        if (idx >= 0) { toRemovePlayer.add(pb); toRemoveEnemy.add(_enemyBullets[idx]); }
      }
      _bullets.removeWhere((b) => toRemovePlayer.contains(b));
      _enemyBullets.removeWhere((b) => toRemoveEnemy.contains(b));
    }
  }

  void _advanceEnemyBullets() {
    final remove = <_Bullet>[];
    final add = <_Bullet>[];
    for (final b in _enemyBullets) {
      final nb = _step(b.pos, b.dir);
      if (!_inBounds(nb)) { remove.add(b); continue; }
      // Hit wall: destroy wall and bullet
      if (_walls.remove(nb)) { remove.add(b); _impacts.add(_Impact(nb, 0, 4)); continue; }
      if (_bulletHitsTank(nb, _player)) {
        remove.add(b);
        if (_shieldActive) {
          _shieldActive = false; // absorb shot
        } else {
          _onLifeLost();
          return;
        }
      }
      add.add(_Bullet(nb, b.dir)); remove.add(b);
    }
    _enemyBullets..removeWhere((x) => remove.contains(x))..addAll(add);
    // Bullet-vs-bullet collision
    if (_enemyBullets.isNotEmpty && _bullets.isNotEmpty) {
      final toRemovePlayer = <_Bullet>[];
      final toRemoveEnemy = <_Bullet>[];
      for (final eb in _enemyBullets) {
        final idx = _bullets.indexWhere((pb) => pb.pos == eb.pos);
        if (idx >= 0) { toRemovePlayer.add(_bullets[idx]); toRemoveEnemy.add(eb); }
      }
      _bullets.removeWhere((b) => toRemovePlayer.contains(b));
      _enemyBullets.removeWhere((b) => toRemoveEnemy.contains(b));
    }
  }

  // Enemy AI helpers: scale movement and firing with level
  int _enemyMoveEvery() {
    // Progressive speed: start slow at low levels and ramp up.
    // Map level 1..maxLevel to period ~6..2 (ticks per step).
    final int L = _level.clamp(1, maxLevel);
    final double period = 6 - 4 * ((L - 1) / (maxLevel - 1));
    return period.round().clamp(2, 6);
  }

  double _enemyLosFireProb() {
    // Line-of-sight fire probability grows with level [0.3 .. 0.85]
    final double p = 0.30 + 0.05 * (_level - 1);
    return p.clamp(0.30, 0.85);
  }

  double _enemyRandomFireProb() {
    // Occasional random fire probability grows with level [0.03 .. 0.20]
    final double p = 0.03 + 0.01 * (_level - 1);
    return p.clamp(0.03, 0.20);
  }

  Dir _chooseEnemyDirection(Tank e) {
    // Prefer LOS direction if available (with increasing bias by level),
    // otherwise choose a valid direction that reduces distance to player.
    final rnd = Random();
    final List<Dir> candidates = [];
    for (final d in Dir.values) {
      final np = _step(e.pos, d);
      if (_canPlaceTankAt(np, d, ignore: e)) candidates.add(d);
    }
    if (candidates.isEmpty) return e.dir;

    final Dir? los = _lineOfSightDir(e.pos, _player.pos);
    if (los != null && candidates.contains(los)) {
      final double losBias = (0.40 + 0.06 * _level).clamp(0.40, 0.90);
      if (rnd.nextDouble() < losBias) return los;
    }

    // Choose direction that minimizes Manhattan distance from (future center) to player's center
    final Point<int> playerCenter = Point<int>(_player.pos.x + 1, _player.pos.y + 1);
    Dir best = candidates.first;
    int bestDist = 1 << 30;
    for (final d in candidates) {
      final np = _step(e.pos, d);
      final Point<int> center = Point<int>(np.x + 1, np.y + 1);
      final int dist = (playerCenter.x - center.x).abs() + (playerCenter.y - center.y).abs();
      if (dist < bestDist) { bestDist = dist; best = d; }
    }
    return best;
  }

  void _onLifeLost() {
    _life--;
    if (_life <= 0) {
      _endGame();
    } else {
      // Impact ring on player hit (center of tank)
      final hitCenter = Point<int>(_player.pos.x + 1, _player.pos.y + 1);
      _impacts.add(_Impact(hitCenter, 0, 6));
      // Respawn depends on phase: boss -> bottom center; wave -> middle center
      if (bossActive) {
        _player = Tank(Point<int>(cols ~/ 2 - 1, rows - 4), Dir.up);
      } else {
        _player = Tank(Point<int>(cols ~/ 2 - 1, rows ~/ 2 - 1), Dir.up);
      }
      _bullets.clear(); _enemyBullets.clear();
      if (_soundOn) Sfx.play('sounds/8bit-ringtone-free-to-use-loopable-44702.mp3', volume: _volume / 3);
    }
    notifyListeners();
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

  Point<int> _step(Point<int> p, Dir d) {
    switch (d) {
      case Dir.up: return Point<int>(p.x, p.y - 1);
      case Dir.down: return Point<int>(p.x, p.y + 1);
      case Dir.left: return Point<int>(p.x - 1, p.y);
      case Dir.right: return Point<int>(p.x + 1, p.y);
    }
  }

  // Returns the starting cell for a bullet fired from the tank's barrel.
  // Tanks occupy a 3x3 area with `pos` as the top-left; the barrel start is
  // the cell immediately outside the center of the corresponding edge.
  Point<int> _barrelStart(Point<int> p, Dir d) {
    switch (d) {
      case Dir.up:
        return Point<int>(p.x + 1, p.y - 1);
      case Dir.down:
        return Point<int>(p.x + 1, p.y + 3);
      case Dir.left:
        return Point<int>(p.x - 1, p.y + 1);
      case Dir.right:
        return Point<int>(p.x + 3, p.y + 1);
    }
  }

  bool _isEmpty(Point<int> p) => _inBounds(p) && !_walls.contains(p) && _enemies.every((e) => e.pos != p) && _player.pos != p;
  bool _inBounds(Point<int> p) => p.x >= 0 && p.x < cols && p.y >= 0 && p.y < rows;

  bool _bulletHitsTank(Point<int> bullet, Tank tank) {
    for (final cell in _tankCells(tank)) {
      if (cell == bullet) return true;
    }
    return false;
  }

  Iterable<Point<int>> _tankCells(Tank t) sync* {
    // 3x3 masks from Java Tank.STATES
    List<int> rowsMask;
    switch (t.dir) {
      case Dir.up: rowsMask = [0x2, 0x7, 0x5]; break;     // 010,111,101
      case Dir.right: rowsMask = [0x6, 0x3, 0x6]; break;  // 110,011,110
      case Dir.down: rowsMask = [0x5, 0x7, 0x2]; break;   // 101,111,010
      case Dir.left: rowsMask = [0x3, 0x6, 0x3]; break;   // 011,110,011
    }
    for (int ry = 0; ry < 3; ry++) {
      for (int rx = 0; rx < 3; rx++) {
        if (((rowsMask[ry] >> (2 - rx)) & 1) == 1) {
          final int cx = t.pos.x + rx;
          final int cy = t.pos.y + ry;
          if (_inBounds(Point<int>(cx, cy))) yield Point<int>(cx, cy);
        }
      }
    }
  }

  Iterable<Point<int>> _tankCellsAt(Point<int> topLeft, Dir dir) sync* {
    List<int> rowsMask;
    switch (dir) {
      case Dir.up: rowsMask = [0x2, 0x7, 0x5]; break;
      case Dir.right: rowsMask = [0x6, 0x3, 0x6]; break;
      case Dir.down: rowsMask = [0x5, 0x7, 0x2]; break;
      case Dir.left: rowsMask = [0x3, 0x6, 0x3]; break;
    }
    for (int ry = 0; ry < 3; ry++) {
      for (int rx = 0; rx < 3; rx++) {
        if (((rowsMask[ry] >> (2 - rx)) & 1) == 1) {
          yield Point<int>(topLeft.x + rx, topLeft.y + ry);
        }
      }
    }
  }

  bool _canPlaceTankAt(Point<int> topLeft, Dir dir, {Tank? ignore}) {
    for (final cell in _tankCellsAt(topLeft, dir)) {
      if (!_inBounds(cell) || _walls.contains(cell)) return false;
      // collide with player
      for (final pc in _tankCells(_player)) {
        if ((ignore == null || !identical(ignore, _player)) && pc == cell) return false;
      }
      // collide with enemies
      for (final e in _enemies) {
        if (ignore != null && identical(e, ignore)) continue;
        for (final ec in _tankCells(e)) { if (ec == cell) return false; }
      }
      // collide with boss (5x5)
      if (_boss != null) {
        for (final bc in _bossCells(_boss!)) { if (bc == cell) return false; }
      }
    }
    return true;
  }

  Dir? _lineOfSightDir(Point<int> from, Point<int> to) {
    if (from.x == to.x) {
      final int step = (to.y > from.y) ? 1 : -1;
      for (int y = from.y + step; y != to.y; y += step) {
        if (_walls.contains(Point<int>(from.x, y))) return null;
      }
      return to.y > from.y ? Dir.down : Dir.up;
    } else if (from.y == to.y) {
      final int step = (to.x > from.x) ? 1 : -1;
      for (int x = from.x + step; x != to.x; x += step) {
        if (_walls.contains(Point<int>(x, from.y))) return null;
      }
      return to.x > from.x ? Dir.right : Dir.left;
    }
    return null;
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    _gameOverAnimTimer?.cancel();
    super.dispose();
  }

  // Power-ups
  void _maybeSpawnPowerUp(Point<int> at) {
    final rnd = Random();
    if (rnd.nextDouble() > 0.25) return; // 25% drop
    final kind = rnd.nextBool() ? TankPowerUpKind.shield : TankPowerUpKind.rapid;
    _powerUps.add(TankPowerUp(Point<int>(at.x, at.y), kind));
  }

  void _movePowerUps() {
    if (_powerUps.isEmpty) return;
    final removed = <TankPowerUp>[];
    for (final p in _powerUps) {
      final ny = p.pos.y + 1;
      if (ny >= rows) { removed.add(p); continue; }
      p.pos = Point<int>(p.pos.x, ny);
      if (p.pos == _player.pos) {
        _applyPowerUp(p.kind);
        removed.add(p);
      }
    }
    _powerUps.removeWhere((x) => removed.contains(x));
  }

  void _applyPowerUp(TankPowerUpKind kind) {
    switch (kind) {
      case TankPowerUpKind.shield:
        _shieldActive = true;
        _shieldUntilTick = _tick + 200;
        break;
      case TankPowerUpKind.rapid:
        _rapidActive = true;
        _rapidUntilTick = _tick + 200;
        break;
    }
    if (_soundOn) Sfx.play('sounds/cartoon_16-74046.mp3', volume: _volume / 3);
  }

  // Kill/level progression during wave
  void _onEnemyKilled(Point<int> at) {
    _killsThisLevel++;
    _lastKillTick = _tick;
    // Visual impact already added by caller; next enemy spawns on schedule if any remaining
  }

  void _onBossDefeated() {
    // Advance level until maxLevel; at maxLevel, end the game (victory)
    if (_level >= maxLevel) {
      _endGame();
    } else {
      _level++;
      _startLevel();
      _resetLoop();
    }
  }

  int _computeSpawnInterval() {
    // Base interval decreases as level and speed increase
    final int base = (38 - 2 * _level - (_speedSetting ~/ 2)).clamp(10, 40);
    return base;
  }

  int _maxConcurrentEnemies() {
    // Start with 4 (classic simultaneous enemies), increases to 6
    final int maxC = 4 + (_level ~/ 3);
    return maxC.clamp(4, 6);
  }

  int _effectiveMaxConcurrentEnemies() {
    final int base = _maxConcurrentEnemies();
    return _spawnPressureActive() ? 6 : base;
  }

  bool _spawnPressureActive() {
    // If no kills for a while, push more enemies up to 6
    final int threshold = _noKillThresholdTicks();
    return (_tick - _lastKillTick) > threshold;
  }

  int _noKillThresholdTicks() {
    // Shorter threshold at higher levels; base ~180 ticks down to ~80
    final int L = _level.clamp(1, maxLevel);
    final int t = 180 - (L - 1) * 10;
    return t.clamp(80, 180);
  }

  int _enemiesForLevel() {
    // Total enemies per wave grows with level, capped for pacing
    final int base = 6 + (_level * 2);
    return base.clamp(6, 24);
  }

  void _spawnBoss() {
    // Boss phase: only player and boss — clear walls, enemies, powerups, enemy bullets
    _walls.clear();
    _enemies.clear();
    _powerUps.clear();
    _enemyBullets.clear();
    // Ensure player bottom center
    _player = Tank(Point<int>(cols ~/ 2 - 1, rows - 3), Dir.up);

    // Boss is 7x5; place at row 1 (one line below top) moving horizontally (dir fixed down for cannon)
    final int width = 7;
    final int y = 1; // one row below top
    final int startX = ((cols - width) / 2).floor().clamp(0, cols - width);
    final Point<int> start = Point<int>(startX, y);
    if (_canPlaceBossAt(start, Dir.down)) {
      _boss = Boss(start, Dir.down, _bossHpForLevel()); _bossHDir = 1; return;
    }
    for (int x = 0; x <= cols - width; x++) {
      final p = Point<int>(x, y);
      if (_canPlaceBossAt(p, Dir.down)) { _boss = Boss(p, Dir.down, _bossHpForLevel()); _bossHDir = 1; return; }
    }
    _boss = Boss(Point<int>(0, y), Dir.down, _bossHpForLevel()); _bossHDir = 1;
  }

  int _bossHpForLevel() => (6 + _level).clamp(6, 24);

  int _bossMoveEvery() {
    // Progressive boss speed: start slower and ramp toward fast.
    // Map level 1..maxLevel to period ~7..2.
    final int L = _level.clamp(1, maxLevel);
    final double period = 7 - 5 * ((L - 1) / (maxLevel - 1));
    return period.round().clamp(2, 7);
  }
  
  // Boss geometry (5x5) and helpers (instance methods to access state)
  Iterable<Point<int>> _bossCells(Boss b) => _bossCellsAt(b.pos, b.dir);
  
  Iterable<Point<int>> _bossCellsAt(Point<int> topLeft, Dir dir) sync* {
    // 7x5 boss shape masks (width=7, height=5)
    List<int> rowsMask;
    switch (dir) {
      case Dir.up:
        rowsMask = [
          0x08, // 0001000 barrel tip
          0x1C, // 0011100
          0x7F, // 1111111
          0x55, // 1010101
          0x7F, // 1111111
        ];
        break;
      case Dir.right:
        rowsMask = [
          0x3F, // 0111111
          0x11, // 0010001
          0x7F, // 1111111
          0x11, // 0010001
          0x3F, // 0111111
        ];
        break;
      case Dir.down:
        rowsMask = [
          0x7F, // 1111111
          0x55, // 1010101
          0x7F, // 1111111
          0x1C, // 0011100
          0x08, // 0001000 barrel tip
        ];
        break;
      case Dir.left:
        rowsMask = [
          0x7C, // 1111100
          0x44, // 1000100
          0x7F, // 1111111
          0x44, // 1000100
          0x7C, // 1111100
        ];
        break;
    }
    for (int ry = 0; ry < 5; ry++) {
      for (int rx = 0; rx < 7; rx++) {
        if (((rowsMask[ry] >> (6 - rx)) & 1) == 1) {
          yield Point<int>(topLeft.x + rx, topLeft.y + ry);
        }
      }
    }
  }

  bool _canPlaceBossAt(Point<int> topLeft, Dir dir) {
    for (final cell in _bossCellsAt(topLeft, dir)) {
      if (!_inBounds(cell) || _walls.contains(cell)) return false;
      for (final pc in _tankCells(_player)) { if (pc == cell) return false; }
      for (final e in _enemies) { for (final ec in _tankCells(e)) { if (ec == cell) return false; } }
    }
    return true;
  }

  // Centers used for LOS aiming
  Point<int> playerCenter() => Point<int>(_player.pos.x + 1, _player.pos.y + 1);
  Point<int> bossCenter() => Point<int>(_boss!.pos.x + 3, _boss!.pos.y + 2);

  // Boss barrel start (5x5 geometry)
  Point<int> _bossBarrelStart(Point<int> p, Dir d) {
    switch (d) {
      case Dir.up: return Point<int>(p.x + 3, p.y - 1);
      case Dir.down: return Point<int>(p.x + 3, p.y + 5);
      case Dir.left: return Point<int>(p.x - 1, p.y + 2);
      case Dir.right: return Point<int>(p.x + 7, p.y + 2);
    }
  }

  // Temporary shim to reuse direction helper for boss
  Tank _bossAsTank() => Tank(_boss!.pos, _boss!.dir);

  // Boss vulnerable point: cannon intake (center of boss mask)
  Point<int> _bossCannonCell(Boss b) => Point<int>(b.pos.x + 3, b.pos.y + 2);
}

class Boss {
  Point<int> pos;
  Dir dir;
  int hp;
  Boss(this.pos, this.dir, this.hp);
}

class _Bullet {
  Point<int> pos;
  Dir dir;
  _Bullet(this.pos, this.dir);
}

class _Impact {
  Point<int> pos;
  int frame;
  final int maxFrames;
  _Impact(this.pos, this.frame, this.maxFrames);
}

class TankPowerUp {
  Point<int> pos;
  final TankPowerUpKind kind;
  TankPowerUp(this.pos, this.kind);
}

enum TankPowerUpKind { shield, rapid }

class Tank {
  Point<int> pos;
  Dir dir;
  Tank(this.pos, this.dir);
}

enum Dir { up, down, left, right }
