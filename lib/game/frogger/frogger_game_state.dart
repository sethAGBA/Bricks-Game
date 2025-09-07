import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bricks/audio/sfx.dart';

class FroggerGameState with ChangeNotifier {
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
  bool _soundOn = true;
  int _volume = 2; // 0..3 like other games

  // Entities
  Point<int> _player = const Point<int>(cols ~/ 2, rows - 2);
  final List<_Car> _cars = <_Car>[];
  final List<_Log> _logs = <_Log>[];
  final Set<int> _filledGoals = <int>{};
  final List<_Bonus> _bonuses = <_Bonus>[];
  final List<_Crash> _crashes = <_Crash>[];

  // Timers
  Timer? _loopTimer;
  Timer? _secondsTimer;
  int _tick = 0;
  Timer? _gameOverAnimTimer;
  int _gameOverAnimFrame = 0;

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
  Point<int> get player => _player;
  List<_Car> get cars => List.unmodifiable(_cars);
  List<_Log> get logs => List.unmodifiable(_logs);
  Set<int> get filledGoals => Set.unmodifiable(_filledGoals);
  List<_Bonus> get bonuses => List.unmodifiable(_bonuses);
  List<_Crash> get crashes => List.unmodifiable(_crashes);

  void applyMenuSettings({required int level, required int speed}) {
    _initialLevel = level.clamp(1, 12);
    _level = _initialLevel;
    _speedSetting = speed.clamp(1, 10);
    notifyListeners();
  }

  Future<void> loadHighScore() async {
    final p = await SharedPreferences.getInstance();
    _highScore = p.getInt('froggerHighScore') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('froggerHighScore', _highScore);
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
    _gameOverAnimTimer?.cancel();
    _gameOverAnimFrame = 0;
    _player = const Point<int>(cols ~/ 2, rows - 2);
    _cars.clear();
    _logs.clear();
    _filledGoals.clear();
    _bonuses.clear();
    _spawnInitialCars();
    _spawnInitialLogs();
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

  void toggleSound() {
    _volume = (_volume + 1) % 4;
    _soundOn = _volume > 0;
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

  void _resetLoop() {
    _loopTimer?.cancel();
    if (!_playing || _gameOver) return;
    final int base = (360 - _speedSetting * 12 - _level * 8).clamp(90, 1000);
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
    // Move cars/logs on separate cadence for smoother progression
    if (_tick % _carStepDiv() == 0) {
      _advanceCars();
      _maybeSpawnCar();
    }
    if (_tick % _logStepDiv() == 0) {
      _advanceLogsAndCarryPlayer();
      _maybeSpawnLog();
    }
    _advanceBonuses();
    _maybeSpawnBonuses();
    _advanceCrashes();
    _checkCollisions();
    if (_score > _highScore) {
      _highScore = _score;
      _saveHighScore();
    }
    notifyListeners();
  }

  // Layout bands
  List<int> get _roadRows => const [13, 15, 17];
  List<int> get _waterRows => const [3, 5, 7, 9, 11];
  int get _goalRow => 0;
  List<int> get _goalXs => const [0, 2, 4, 6, 8];

  void _spawnInitialCars() {
    final rnd = Random();
    _cars.clear();
    for (final r in _roadRows) {
      final dir = (r % 4 == 0) ? -1 : 1;
      final count = 1 + (_level ~/ 4);
      for (int i = 0; i < count; i++) {
        final x = rnd.nextInt(cols);
        final bool truck = rnd.nextDouble() < 0.35; // some trucks
        final int len = truck ? (rnd.nextBool() ? 2 : 3) : 1;
        _cars.add(_Car(Point<int>(x, r), dir, len));
      }
    }
  }

  void _spawnInitialLogs() {
    final rnd = Random();
    _logs.clear();
    for (final r in _waterRows) {
      final dir = (r % 4 == 1) ? -1 : 1;
      final count = 1 + (_level ~/ 5);
      for (int i = 0; i < count; i++) {
        final x = rnd.nextInt(cols);
        final len = 3 + rnd.nextInt(2); // 3..4
        _logs.add(_Log(Point<int>(x, r), dir, len));
      }
    }
  }

  void _advanceCars() {
    final List<_Car> moved = [];
    for (final c in _cars) {
      int nx = c.pos.x + c.dir;
      // wrap considering length
      if (nx < -c.len) nx = cols - 1;
      if (nx >= cols) nx = -c.len + 1;
      moved.add(_Car(Point<int>(nx, c.pos.y), c.dir, c.len));
    }
    _cars
      ..clear()
      ..addAll(moved);
  }

  void _advanceLogsAndCarryPlayer() {
    final List<_Log> moved = [];
    for (final l in _logs) {
      int nx = l.pos.x + l.dir;
      if (nx < -l.len) nx = cols - 1;
      if (nx >= cols) nx = -l.len + 1;
      moved.add(_Log(Point<int>(nx, l.pos.y), l.dir, l.len));
    }
    _logs
      ..clear()
      ..addAll(moved);
    // Carry player if on a log; otherwise drown on water rows
    if (_waterRows.contains(_player.y)) {
      if (_isOnLog(_player)) {
        final int dir = _logDirAt(_player);
        final int nx = _player.x + dir;
        if (nx < 0 || nx >= cols) {
          _onLifeLost(CrashKind.edge, _player);
        } else {
          _player = Point<int>(nx, _player.y);
        }
      } else {
        _onLifeLost(CrashKind.water, _player);
      }
    }
  }

  void _maybeSpawnCar() {
    final rnd = Random();
    if (_tick % 6 != 0) return;
    for (final r in _roadRows) {
      final dir = (r % 4 == 0) ? -1 : 1;
      final p = (0.10 + 0.02 * (_level - 1)).clamp(0.10, 0.30);
      if (rnd.nextDouble() < p) {
        final bool truck = rnd.nextDouble() < (0.25 + 0.02 * _level).clamp(0.25, 0.55);
        final int len = truck ? (rnd.nextBool() ? 2 : 3) : 1;
        final int x = dir < 0 ? cols - 1 : 0;
        // Avoid immediate overlap across length
        bool blocked = false;
        for (int i = 0; i < len; i++) {
          final int cx = x + i * (dir > 0 ? 1 : -1);
          if (_carCells().any((pt) => pt.y == r && pt.x == cx)) { blocked = true; break; }
        }
        if (!blocked) {
          _cars.add(_Car(Point<int>(x, r), dir, len));
        }
      }
    }
  }

  void _maybeSpawnLog() {
    final rnd = Random();
    if (_tick % 10 != 0) return;
    for (final r in _waterRows) {
      final dir = (r % 4 == 1) ? -1 : 1;
      final p = (0.08 + 0.02 * (_level - 1)).clamp(0.08, 0.25);
      if (rnd.nextDouble() < p) {
        final x = dir < 0 ? cols - 1 : 0;
        final len = 3 + rnd.nextInt(2);
        final bool occupied = _logCells().any((pt) => pt.y == r && pt.x == x);
        if (!occupied) {
          _logs.add(_Log(Point<int>(x, r), dir, len));
        }
      }
    }
  }

  void _checkCollisions() {
    // Hit vehicle (car/truck)?
    if (_carCells().any((c) => c == _player)) {
      _onLifeLost(CrashKind.vehicle, _player);
      return;
    }
    // Goal check: must land exactly on a goal slot on top row
    if (_player.y == _goalRow) {
      final int? slot = _nearestGoalSlot(_player.x);
      if (slot != null && !_filledGoals.contains(slot)) {
        _filledGoals.add(slot);
        _score += 200;
        if (_filledGoals.length >= _goalXs.length) {
          _level = (_level + 1).clamp(1, 12);
          _filledGoals.clear();
          if (_soundOn) Sfx.play('sounds/cartoon_16-74046.mp3', volume: _volume / 3);
        }
        _player = const Point<int>(cols ~/ 2, rows - 2);
        _cars.clear();
        _logs.clear();
        _bonuses.clear();
        _spawnInitialCars();
        _spawnInitialLogs();
        _resetLoop();
        return;
      } else {
        _onLifeLost(CrashKind.water, _player);
      }
    }
    // Collect bonus
    final idx = _bonuses.indexWhere((b) => b.pos == _player);
    if (idx >= 0) {
      final b = _bonuses.removeAt(idx);
      if (b.kind == BonusKind.life) {
        _life = (_life + 1).clamp(0, 9);
        _score += 100;
      } else {
        _score += 200;
      }
    }
  }

  void _onLifeLost([CrashKind kind = CrashKind.vehicle, Point<int>? at]) {
    // Add crash visual at current or given position
    final p = at ?? _player;
    _crashes.add(_Crash(p, kind, 0, 10));
    _life--;
    if (_life <= 0) {
      _endGame();
    } else {
      _player = const Point<int>(cols ~/ 2, rows - 2);
      if (_soundOn) Sfx.play('sounds/8bit-ringtone-free-to-use-loopable-44702.mp3', volume: _volume / 3);
    }
    notifyListeners();
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

  // Controls
  void moveLeft() {
    if (!_playing || _gameOver) return;
    if (_player.x > 0) { _player = Point<int>(_player.x - 1, _player.y); _score += 1; if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265.mp3', volume: _volume / 3); }
    _checkCollisions();
    notifyListeners();
  }
  void moveRight() {
    if (!_playing || _gameOver) return;
    if (_player.x < cols - 1) { _player = Point<int>(_player.x + 1, _player.y); _score += 1; if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265.mp3', volume: _volume / 3); }
    _checkCollisions();
    notifyListeners();
  }
  void moveUp() {
    if (!_playing || _gameOver) return;
    if (_player.y > 0) { _player = Point<int>(_player.x, _player.y - 1); _score += 2; if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265.mp3', volume: _volume / 3); }
    _checkCollisions();
    notifyListeners();
  }
  void moveDown() {
    if (!_playing || _gameOver) return;
    if (_player.y < rows - 1) { _player = Point<int>(_player.x, _player.y + 1); if (_soundOn) Sfx.play('sounds/gameboy-pluck-41265.mp3', volume: _volume / 3); }
    _checkCollisions();
    notifyListeners();
  }

  // Helpers
  int _carStepDiv() {
    final int L = _level.clamp(1, 12);
    return (6 - (L ~/ 3)).clamp(3, 6);
  }

  int _logStepDiv() {
    final int L = _level.clamp(1, 12);
    return (8 - (L ~/ 2)).clamp(3, 8);
  }

  bool _isOnLog(Point<int> p) => _logCells().any((c) => c == p);
  int _logDirAt(Point<int> p) {
    for (final l in _logs) {
      for (int i = 0; i < l.len; i++) {
        if (Point<int>(l.pos.x + i, l.pos.y) == p) return l.dir;
      }
    }
    return 0;
  }

  Iterable<Point<int>> _logCells() sync* {
    for (final l in _logs) {
      for (int i = 0; i < l.len; i++) {
        yield Point<int>(l.pos.x + i, l.pos.y);
      }
    }
  }

  int? _nearestGoalSlot(int x) {
    int bestIdx = -1; int bestD = 1 << 30;
    for (int i = 0; i < _goalXs.length; i++) {
      final int d = (_goalXs[i] - x).abs();
      if (d < bestD) { bestD = d; bestIdx = i; }
    }
    return bestD == 0 ? bestIdx : null; // must be exactly on slot
  }

  Iterable<Point<int>> _carCells() sync* {
    for (final v in _cars) {
      for (int i = 0; i < v.len; i++) {
        yield Point<int>(v.pos.x + i * (v.dir > 0 ? 1 : -1), v.pos.y);
      }
    }
  }

  void _advanceBonuses() {
    if (_bonuses.isEmpty) return;
    final List<_Bonus> moved = [];
    for (final b in _bonuses) {
      // Goal bonuses stay fixed; log bonuses follow log motion if still on a log cell
      if (b.kindSource == BonusSource.goal) {
        moved.add(b);
        continue;
      }
      if (_isOnLog(b.pos)) {
        final int dir = _logDirAt(b.pos);
        final int nx = b.pos.x + dir;
        if (nx >= 0 && nx < cols) {
          moved.add(_Bonus(Point<int>(nx, b.pos.y), b.kind, b.kindSource));
        }
      } else {
        // fell in water; remove
      }
    }
    _bonuses
      ..clear()
      ..addAll(moved);
  }

  void _maybeSpawnBonuses() {
    final rnd = Random();
    // Log bonuses: small chance per water row if none exists on that row
    if (_tick % 30 == 0) {
      for (final r in _waterRows) {
        if (_bonuses.any((b) => b.pos.y == r && b.kindSource == BonusSource.log)) continue;
        if (rnd.nextDouble() < 0.10) {
          // choose a random log cell on row r
          final cells = _logCells().where((p) => p.y == r).toList();
          if (cells.isNotEmpty) {
            final p = cells[rnd.nextInt(cells.length)];
            final kind = rnd.nextDouble() < 0.3 ? BonusKind.life : BonusKind.score;
            _bonuses.add(_Bonus(p, kind, BonusSource.log));
          }
        }
      }
    }
    // Goal bonuses: occasionally place a bonus on an unfilled goal slot
    if (_tick % 50 == 0) {
      final available = <int>[];
      for (int i = 0; i < _goalXs.length; i++) {
        if (!_filledGoals.contains(i) && !_bonuses.any((b) => b.pos == Point<int>(_goalXs[i], _goalRow))) {
          available.add(i);
        }
      }
      if (available.isNotEmpty && rnd.nextDouble() < 0.15) {
        final idx = available[rnd.nextInt(available.length)];
        _bonuses.add(_Bonus(Point<int>(_goalXs[idx], _goalRow), BonusKind.score, BonusSource.goal));
      }
    }
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _secondsTimer?.cancel();
    _gameOverAnimTimer?.cancel();
    super.dispose();
  }

}

enum CrashKind { vehicle, water, edge }

class _Crash {
  final Point<int> pos;
  final CrashKind kind;
  int frame;
  final int maxFrames;
  _Crash(this.pos, this.kind, this.frame, this.maxFrames);
}

class _Car {
  final Point<int> pos;
  final int dir; // -1 left, 1 right
  final int len; // 1 for car, 2-3 for trucks
  _Car(this.pos, this.dir, this.len);
}

class _Log {
  final Point<int> pos;
  final int dir; // -1 left, 1 right
  final int len;
  _Log(this.pos, this.dir, this.len);
}

enum BonusKind { score, life }
enum BonusSource { log, goal }

class _Bonus {
  final Point<int> pos;
  final BonusKind kind;
  final BonusSource kindSource;
  _Bonus(this.pos, this.kind, this.kindSource);
}
