import 'dart:math' as math;
import 'package:bricks/game/game_state.dart';
import 'package:bricks/game/race/race_game_state.dart';
import 'package:bricks/game/snake/snake_game_state.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:bricks/screens/race_game_screen.dart';
import 'package:bricks/screens/tetris_game_screen.dart';
import 'package:bricks/screens/snake_game_screen.dart';
import 'package:bricks/screens/coming_soon_game_screen.dart';
import 'package:bricks/style/app_style.dart';
import 'package:bricks/game/game_grid_painter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/game/piece.dart';

class MenuGameScreen extends StatefulWidget {
  const MenuGameScreen({super.key});

  @override
  State<MenuGameScreen> createState() => _MenuGameScreenState();
}

enum GameKind { tetris, snake, racing, brick, shoot }

class GameDef {
  final String title;
  final GameKind kind;
  const GameDef(this.title, this.kind);
}

const List<GameDef> kGames = <GameDef>[
  GameDef('TETRIS', GameKind.tetris),
  GameDef('SNAKE', GameKind.snake),
  GameDef('RACING', GameKind.racing),
  GameDef('BRICK', GameKind.brick),
  GameDef('SHOOT', GameKind.shoot),
];

class _MenuGameScreenState extends State<MenuGameScreen> {
  // Menu value 0..9999
  int _value = 0;
  int _level = 1; // difficulty level (1..10)
  int _speed = 1; // speed setting (1..10)

  void _inc() => setState(() => _value = (_value + 1) % 10000);
  void _dec() => setState(() => _value = (_value - 1 + 10000) % 10000);

  void _selectGame(BuildContext context) {
    final int idx = _value % kGames.length;
    final GameDef def = kGames[idx];
    if (def.kind == GameKind.tetris) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) {
              final gs = GameState();
              gs.applyMenuSettings(level: _level, speed: _speed);
              return gs;
            },
            child: const TetrisGameScreen(),
          ),
        ),
      );
    } else if (def.kind == GameKind.snake) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) {
              final ss = SnakeGameState();
              ss.applyMenuSettings(level: _level, speed: _speed);
              return ss;
            },
            child: const SnakeGameScreen(),
          ),
        ),
      );
    } else if (def.kind == GameKind.racing) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) {
              final rs = RaceGameState();
              rs.applyMenuSettings(level: _level, speed: _speed);
              return rs;
            },
            child: const RaceGameScreen(),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComingSoonGameScreen(title: def.title),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, GameButtonCallback> buttonCallbacks = {
      GameBoyScreen.btnLeft: _dec,
      GameBoyScreen.btnRight: _inc,
      GameBoyScreen.btnUp: () => setState(() => _speed = (_speed % 10) + 1),
      GameBoyScreen.btnDown: () => setState(() => _level = (_level % 10) + 1),
      GameBoyScreen.btnRotate: () => _selectGame(context),
      GameBoyScreen.btnStart: () => _selectGame(context),
      GameBoyScreen.btnSettings: () => Navigator.popUntil(context, (r) => r.isFirst),
    };

    return GameBoyScreen(
      gameContent: _MenuContent(value: _value, level: _level, speed: _speed),
      onButtonPressed: buttonCallbacks,
    );
  }
}

// No-op helper screens needed; we navigate directly to existing screens with providers

class _MenuPainter extends CustomPainter {
  final int value;
  _MenuPainter(this.value);

  // DIGITS shapes 4x5 as in Java
  static final List<List<List<int>>> digits = [
    [
      [0, 1, 1, 0],
      [1, 0, 0, 1],
      [1, 0, 0, 1],
      [1, 0, 0, 1],
      [0, 1, 1, 0],
    ],
    [
      [0, 0, 1, 0],
      [0, 1, 1, 0],
      [0, 0, 1, 0],
      [0, 0, 1, 0],
      [0, 1, 1, 1],
    ],
    [
      [0, 1, 1, 1],
      [0, 0, 0, 1],
      [0, 1, 1, 1],
      [0, 1, 0, 0],
      [0, 1, 1, 1],
    ],
    [
      [0, 1, 1, 1],
      [0, 0, 0, 1],
      [0, 1, 1, 1],
      [0, 0, 0, 1],
      [0, 1, 1, 1],
    ],
    [
      [0, 1, 0, 1],
      [0, 1, 0, 1],
      [0, 1, 1, 1],
      [0, 0, 0, 1],
      [0, 0, 0, 1],
    ],
    [
      [0, 1, 1, 1],
      [0, 1, 0, 0],
      [0, 1, 1, 1],
      [0, 0, 0, 1],
      [0, 1, 1, 1],
    ],
    [
      [0, 1, 1, 1],
      [0, 1, 0, 0],
      [0, 1, 1, 1],
      [0, 1, 0, 1],
      [0, 1, 1, 1],
    ],
    [
      [0, 1, 1, 1],
      [0, 0, 0, 1],
      [0, 0, 0, 1],
      [0, 0, 0, 1],
      [0, 0, 0, 1],
    ],
    [
      [0, 1, 1, 1],
      [0, 1, 0, 1],
      [0, 1, 1, 1],
      [0, 1, 0, 1],
      [0, 1, 1, 1],
    ],
    [
      [0, 1, 1, 1],
      [0, 1, 0, 1],
      [0, 1, 1, 1],
      [0, 0, 0, 1],
      [0, 1, 1, 1],
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Use same orientation as Tetris: 10 cols x 20 rows
    final int cols = GameState.cols; // 10
    final int rows = GameState.rows; // 20
    final double cellWidth = size.width / cols;
    final double cellHeight = size.height / rows;

    // Background
    final Paint bg = Paint()..color = LcdColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Styles
    // Match Tetris painter style
    const double gapPx = GameGridPainter.gapPx;
    const double outerStrokeWidth = GameGridPainter.outerStrokeWidth;
    const double innerSizeFactor = GameGridPainter.innerSizeFactor;

    final Paint onPaint = Paint()..color = LcdColors.pixelOn;
    final Paint offPaint = Paint()..color = LcdColors.pixelOff;
    final Paint borderPaintOn = Paint()
      ..color = LcdColors.pixelOn
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStrokeWidth;
    final Paint borderPaintOff = Paint()
      ..color = LcdColors.pixelOff
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStrokeWidth;

  // helper Rects
    Rect contentRect(int c, int r) => Rect.fromLTWH(
        c * cellWidth + gapPx / 2, r * cellHeight + gapPx / 2, cellWidth - gapPx, cellHeight - gapPx);

    void drawCell(int c, int r, bool on) {
      final Rect outer = contentRect(c, r);
      canvas.drawRect(outer, on ? borderPaintOn : borderPaintOff);
      final double innerW = outer.width * innerSizeFactor;
      final double innerH = outer.height * innerSizeFactor;
      final double innerOffset = (1.0 - innerSizeFactor) / 2.0;
      final Rect inner = Rect.fromLTWH(
        outer.left + outer.width * innerOffset,
        outer.top + outer.height * innerOffset,
        innerW,
        innerH,
      );
      canvas.drawRect(inner, on ? onPaint : offPaint);
    }

    // Draw all OFF covering full painter size (10x20)
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        drawCell(c, r, false);
      }
    }

    // Compute digits
    final List<int> values = List.generate(4, (i) => (value ~/ math.pow(10, i)) % 10);
    // Place digits in a 2x2 grid within 10x20
    final List<Offset> positions = [
      const Offset(1, 3),  // thousands top-left
      const Offset(5, 3),  // hundreds top-right
      const Offset(1, 11), // tens bottom-left
      const Offset(5, 11), // ones bottom-right
    ];
    for (int i = 0; i < 4; i++) {
      final shape = digits[values[i]];
      final int baseX = positions[i].dx.toInt();
      final int baseY = positions[i].dy.toInt();
      for (int ry = 0; ry < shape.length; ry++) {
        for (int rx = 0; rx < shape[ry].length; rx++) {
          if (shape[ry][rx] == 1) {
            final int cx = baseX + rx;
            final int cy = baseY + ry;
            if (cx >= 0 && cx < cols && cy >= 0 && cy < rows) {
              drawCell(cx, cy, true);
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MenuPainter oldDelegate) => oldDelegate.value != value;
}

class _MenuContent extends StatelessWidget {
  final int value;
  final int level;
  final int speed;
  const _MenuContent({required this.value, required this.level, required this.speed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: LcdColors.pixelOn, width: 3),
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: LcdColors.pixelOff, width: 2),
          color: LcdColors.background,
        ),
        child: Row(
          children: [
            // Left: 20x10 menu board as before
            Expanded(
              flex: 1,
              child: SizedBox.expand(
                child: CustomPaint(painter: _MenuPainter(value)),
              ),
            ),
            // Divider (center)
            Container(width: 2, color: LcdColors.pixelOn, margin: const EdgeInsets.symmetric(horizontal: 8)),
            // Right: preview fills the remaining LCD area, full ON/OFF cells
            Expanded(
              flex: 1,
              child: Container(
                color: LcdColors.background,
                child: Stack(
                  children: [
                    // Full-size preview grid retains its proportions
                    Positioned.fill(
                      child: _PreviewBoard(kind: kGames[value % kGames.length].kind),
                    ),
                    // Title overlay at top, drawn over the grid (does not shrink it)
                    Positioned(
                      top: 4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          kGames[value % kGames.length].title,
                          style: const TextStyle(
                            color: LcdColors.pixelOn,
                            fontFamily: 'Digital7',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    // Bottom overlays: level/speed + hints
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _lcdStat(label: 'LEVEL', value: level),
                              _lcdStat(label: 'SPEED', value: speed),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'SELECT: START/ROTATE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: LcdColors.pixelOn,
                              fontFamily: 'Digital7',
                              fontSize: 10,
                            ),
                          ),
                          const Text(
                            '← → CHANGE  ↑ SPEED  ↓ LEVEL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: LcdColors.pixelOn,
                              fontFamily: 'Digital7',
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lcdStat({required String label, required int value}) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: LcdColors.pixelOn, fontFamily: 'Digital7', fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value.toString().padLeft(2, '0'),
            style: const TextStyle(
                color: LcdColors.pixelOn, fontFamily: 'Digital7', fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _PreviewBoard extends StatelessWidget {
  final GameKind kind;
  const _PreviewBoard({required this.kind});

  @override
  Widget build(BuildContext context) {
    final int rows = GameState.rows;
    final int cols = GameState.cols;
    final List<List<Tetromino?>> grid = List.generate(rows, (_) => List.filled(cols, null));

    Piece piece = Piece(type: Tetromino.T, position: const Point(4, 2));
    bool hidePiece = false;

  // old demo patterns removed; draw content below in a single centered pass
    // Keep the preview grid full-size (fills the panel). Only center the
    // demo content (pieces / demo blocks) inside the grid so overlays
    // (title / hints) are not masked.

  // Define a safe vertical band inside the full grid so demo content
  // never touches the top title or bottom hints. Increase margins to 25%.
  final int topMarginRows = (rows * 0.25).toInt();
  final int bottomMarginRows = rows - topMarginRows - 1;
  // Add a small downward bias so the visual center sits below the title
  final int verticalBias = 2;
  final int centerRow = math.max(topMarginRows, math.min((topMarginRows + bottomMarginRows) ~/ 2 + verticalBias, bottomMarginRows));
  final int centerCol = cols ~/ 2;

  // place the current piece roughly at the visual center of the safe band
  final int pieceHeight = piece.shape.length;
  final int pieceWidth = piece.shape[0].length;
    piece = Piece(
      type: piece.type,
      position: Point((centerCol - pieceWidth ~/ 2), (centerRow - pieceHeight ~/ 2) + 1),
    );

    switch (kind) {
      case GameKind.tetris:
        // piece already centered
        break;
      case GameKind.snake:
        hidePiece = true;
        for (int i = 0; i < 4; i++) {
          final int c = centerCol - i;
          if (centerRow >= 0 && centerRow < rows && c >= 0 && c < cols) grid[centerRow][c] = Tetromino.I;
        }
        break;
      case GameKind.racing:
        hidePiece = true;

        // Use the in-game Car shape so preview matches actual vehicle.
        // Instantiate a template car, compute its centroid, then translate
        // to the preview center within the safe band.
        final carTemplate = Car.init();
        if (carTemplate.points.isNotEmpty) {
          double sx = 0, sy = 0;
          for (final p in carTemplate.points) {
            sx += p.x;
            sy += p.y;
          }
          final double avgX = sx / carTemplate.points.length;
          final double avgY = sy / carTemplate.points.length;
          final int shiftX = centerCol - avgX.round();
          final int shiftY = centerRow - avgY.round();

          for (final p in carTemplate.points) {
            final int nx = p.x + shiftX;
            final int ny = p.y + shiftY;
            if (ny >= topMarginRows && ny <= bottomMarginRows && nx >= 0 && nx < cols) {
              grid[ny][nx] = Tetromino.O; // car body using O color
            }
          }
        }

        // Decorative elements: three small markers on the left and right of the car
        final int leftDecorCol = math.max(0, centerCol - 4);
        final int rightDecorCol = math.min(cols - 1, centerCol + 3);
        final List<int> decorRows = [centerRow - 2, centerRow, centerRow + 2];
        final List<Tetromino> decorTypes = [Tetromino.T, Tetromino.L, Tetromino.Z];

        for (int i = 0; i < decorRows.length; i++) {
          final int r = decorRows[i];
          final Tetromino t = decorTypes[i % decorTypes.length];
          if (r >= topMarginRows && r <= bottomMarginRows) {
            if (leftDecorCol >= 0 && leftDecorCol < cols) grid[r][leftDecorCol] = t;
            if (rightDecorCol >= 0 && rightDecorCol < cols) grid[r][rightDecorCol] = t;
          }
        }
        break;
      case GameKind.brick:
        hidePiece = true;
        // compact 2x2-ish brick cluster in the safe band
        final List<Offset> brickCells = [
          Offset(centerCol - 1.0, centerRow - 1.0),
          Offset(centerCol.toDouble(), centerRow - 1.0),
          Offset(centerCol - 1.0, centerRow.toDouble()),
          Offset(centerCol.toDouble(), centerRow.toDouble()),
        ];
        for (final o in brickCells) {
          final int r = o.dy.toInt();
          final int c = o.dx.toInt();
          if (r >= topMarginRows && r <= bottomMarginRows && c >= 0 && c < cols) grid[r][c] = Tetromino.Z;
        }
        // small platform under the cluster
        if (centerRow + 1 <= bottomMarginRows) {
          if (centerCol >= 1 && centerCol < cols - 1) {
            grid[centerRow + 1][centerCol - 1] = Tetromino.I;
            grid[centerRow + 1][centerCol] = Tetromino.I;
          } else if (centerCol < cols) {
            grid[centerRow + 1][centerCol] = Tetromino.I;
          }
        }
        break;
      case GameKind.shoot:
        hidePiece = true;
        // tight formation: two T rows and a single L below, inside safe band
        for (int offset = -1; offset <= 1; offset += 2) {
          final int c = centerCol + offset * 2;
          if (centerRow - 1 >= topMarginRows && centerRow - 1 <= bottomMarginRows && c >= 0 && c < cols) {
            grid[centerRow - 1][c] = Tetromino.T;
          }
          if (centerRow >= topMarginRows && centerRow <= bottomMarginRows && c >= 0 && c < cols) {
            grid[centerRow][c] = Tetromino.T;
          }
        }
        if (centerRow + 1 <= bottomMarginRows) grid[centerRow + 1][centerCol] = Tetromino.L;
        break;
    }

    // Fill the whole area and draw on top; we let the parent Stack overlays (title/hints)
    // remain positioned above the painter.
    return SizedBox.expand(
      child: CustomPaint(
        painter: GameGridPainter(grid, piece, hidePiece, false),
      ),
    );
  }
}

// ignore: unused_element
class _MenuSidePanelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill ENTIRE right panel with OFF cells using same LCD style
    const int rows = GameState.rows;
    final int cols = (GameState.cols / 2).ceil();

    final double cellWidth = size.width / cols;
    final double cellHeight = size.height / rows;

    final Paint bg = Paint()..color = LcdColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    const double gapPx = GameGridPainter.gapPx;
    const double outerStrokeWidth = GameGridPainter.outerStrokeWidth;
    const double innerSizeFactor = GameGridPainter.innerSizeFactor;

    final Paint offPaint = Paint()..color = LcdColors.pixelOff;
    final Paint borderPaintOff = Paint()
      ..color = LcdColors.pixelOff
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStrokeWidth;

    Rect contentRect(int c, int r) => Rect.fromLTWH(
          c * cellWidth + gapPx / 2,
          r * cellHeight + gapPx / 2,
          cellWidth - gapPx,
          cellHeight - gapPx,
        );

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final Rect outer = contentRect(c, r);
        canvas.drawRect(outer, borderPaintOff);
        final double innerW = outer.width * innerSizeFactor;
        final double innerH = outer.height * innerSizeFactor;
        final double innerOffset = (1.0 - innerSizeFactor) / 2.0;
        final Rect inner = Rect.fromLTWH(
          outer.left + outer.width * innerOffset,
          outer.top + outer.height * innerOffset,
          innerW,
          innerH,
        );
        canvas.drawRect(inner, offPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
