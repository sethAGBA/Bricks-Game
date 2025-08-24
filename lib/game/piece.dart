

enum Tetromino { L, J, I, O, S, Z, T }

// A simple Point class
class Point<T extends num> {
  final T x;
  final T y;

  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is Point<T> && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)'; // Added for better debugging output
}

class Piece {
  final Tetromino type;
  final Point<int> position;
  final int _rotationState;
  final List<List<int>> shape;

  // All rotation states for each piece
  static final Map<Tetromino, List<List<List<int>>>> _allShapes = {
    Tetromino.L: [
      [ [0, 1, 0], [0, 1, 0], [0, 1, 1] ],
      [ [0, 0, 0], [1, 1, 1], [1, 0, 0] ],
      [ [1, 1, 0], [0, 1, 0], [0, 1, 0] ],
      [ [0, 0, 1], [1, 1, 1], [0, 0, 0] ]
    ],
    Tetromino.J: [
      [ [0, 1, 0], [0, 1, 0], [1, 1, 0] ],
      [ [1, 0, 0], [1, 1, 1], [0, 0, 0] ],
      [ [0, 1, 1], [0, 1, 0], [0, 1, 0] ],
      [ [0, 0, 0], [1, 1, 1], [0, 0, 1] ]
    ],
    Tetromino.I: [
      [ [0, 0, 1, 0], [0, 0, 1, 0], [0, 0, 1, 0], [0, 0, 1, 0] ],
      [ [0, 0, 0, 0], [1, 1, 1, 1], [0, 0, 0, 0], [0, 0, 0, 0] ]
    ],
    Tetromino.O: [
      [ [1, 1], [1, 1] ]
    ],
    Tetromino.S: [
      [ [0, 1, 1], [1, 1, 0], [0, 0, 0] ],
      [ [0, 1, 0], [0, 1, 1], [0, 0, 1] ]
    ],
    Tetromino.Z: [
      [ [1, 1, 0], [0, 1, 1], [0, 0, 0] ],
      [ [0, 0, 1], [0, 1, 1], [0, 1, 0] ]
    ],
    Tetromino.T: [
      [ [0, 1, 0], [1, 1, 1], [0, 0, 0] ],
      [ [0, 1, 0], [0, 1, 1], [0, 1, 0] ],
      [ [0, 0, 0], [1, 1, 1], [0, 1, 0] ],
      [ [0, 1, 0], [1, 1, 0], [0, 1, 0] ]
    ]
  };

  Piece({required this.type, this.position = const Point(0, 0), int rotationState = 0})
      : _rotationState = rotationState,
        shape = _allShapes[type]![rotationState];

  List<List<List<int>>> get _rotations => _allShapes[type]!;

  Piece copyWith({Point<int>? position, int? rotationState}) {
    final newRotationState = rotationState ?? _rotationState;
    return Piece(
      type: type,
      position: position ?? this.position,
      rotationState: newRotationState,
    );
  }

  Piece rotate() {
    final newRotationState = (_rotationState + 1) % _rotations.length;
    return copyWith(rotationState: newRotationState);
  }

  Piece rotateBack() {
    final newRotationState = (_rotationState - 1 + _rotations.length) % _rotations.length;
    return copyWith(rotationState: newRotationState);
  }
}