import 'package:bricks/game/snake/snake_game_state.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bricks/style/app_style.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:bricks/widgets/game_stats_widgets.dart';

class SnakeGameWidget extends StatefulWidget {
  const SnakeGameWidget({super.key});

  @override
  State<SnakeGameWidget> createState() => _SnakeGameWidgetState();
}

class _SnakeGameWidgetState extends State<SnakeGameWidget> with TickerProviderStateMixin {

  late final SnakeGameState gameState;
  bool _showGameOverText = false;
  bool _showStartText = false; // Deprecated for start; kept for game over only
  bool _blinkHead = true; // State for snake head blinking
  Timer? _blinkTimer; // Timer for game over/start text blinking
  Timer? _headBlinkTimer; // Timer for snake head blinking
  // Dedicated food blinking independent from head to avoid long invisibility
  Timer? _foodBlinkTimer;
  int _foodPulseTick = 0; // 0..9; duty cycle control
  bool _foodVisible = true;

  @override
  void initState() {
    super.initState();
    gameState = Provider.of<SnakeGameState>(context, listen: false);
    gameState.addListener(_handleGameOver);
    _startHeadBlinking(); // Start head blinking immediately
    _startFoodBlinking(); // Start food blinking with custom duty cycle
  }

  void _startHeadBlinking() {
    _headBlinkTimer?.cancel(); // Cancel any existing timer
    _headBlinkTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      setState(() {
        _blinkHead = !_blinkHead;
      });
    });
  }

  void _startFoodBlinking() {
    _foodBlinkTimer?.cancel();
    // 100ms tick; 70% ON, 30% OFF per 1s cycle
    _foodBlinkTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        if (gameState.isPlaying && !gameState.isGameOver) {
          _foodPulseTick = (_foodPulseTick + 1) % 10; // 0..9
          _foodVisible = _foodPulseTick < 7; // 0..6 ON, 7..9 OFF
        } else {
          // When paused or not playing, keep food visible
          _foodVisible = true;
        }
      });
    });
  }

  void _handleGameOver() {
    _blinkTimer?.cancel(); // Always cancel existing timer first
    _headBlinkTimer?.cancel(); // Stop head blinking when game state changes
    print('SnakeGameWidget: _handleGameOver called. isGameOver: ${gameState.isGameOver}, isStartingGame: ${gameState.isStartingGame}');

    if (gameState.isGameOver) {
      _showGameOverText = true; // Ensure it's visible initially
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        setState(() {
          _showGameOverText = !_showGameOverText;
          print('SnakeGameWidget: _showGameOverText toggled: $_showGameOverText');
        });
      });
    } else if (gameState.isStartingGame) {
      // Start blinking is driven by SnakeGameState (3 blinks over ~3s)
      // No local timer needed here.
    } else if (gameState.isPlaying) {
      _startHeadBlinking(); // Resume head blinking if game is playing
    } else {
      // Game is no longer over or starting, stop blinking and ensure text is hidden
      _showGameOverText = false;
      _showStartText = false;
      _blinkHead = true; // Ensure head is visible when not blinking
      print('SnakeGameWidget: Blinking stopped. _showGameOverText: $_showGameOverText, _showStartText: $_showStartText');
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _headBlinkTimer?.cancel(); // Cancel head blink timer on dispose
    _foodBlinkTimer?.cancel();
    gameState.removeListener(_handleGameOver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<SnakeGameState>(context);

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 0) {
          gameState.changeDirection(Direction.down);
        } else if (details.delta.dy < 0) {
          gameState.changeDirection(Direction.up);
        }
      },
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0) {
          gameState.changeDirection(Direction.right);
        } else if (details.delta.dx < 0) {
          gameState.changeDirection(Direction.left);
        }
      },
      child: Container(
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
              Expanded(
                flex: 2,
                child: CustomPaint(
                  painter: _SnakeGamePainter(
                    snake: gameState.snake,
                    food: gameState.food,
                    obstacles: gameState.obstacles,
                    blinkHead: _blinkHead && gameState.isPlaying,
                    // Use independent food blinking: false => visible, true => hide
                    blinkFood: !_foodVisible,
                  ),
                  child: gameState.isGameOver && _showGameOverText
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'GAME OVER',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 24,
                                  fontFamily: 'Digital7',
                                ),
                              ),
                            ],
                          ),
                        )
                      : gameState.isStartingGame
                          ? Center(
                              child: Text(
                                'START',
                                style: TextStyle(
                                  color: gameState.startBlinkColor,
                                  fontSize: 24,
                                  fontFamily: 'Digital7',
                                ),
                              ),
                            )
                          : Container(width: double.infinity, height: double.infinity),
                ),
              ),
              Container(
                width: 2,
                color: LcdColors.pixelOn,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              Expanded(
                flex: 1,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SnakeSidePanelGridPainter(),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildStatText('Score'),
                        buildStatNumber(gameState.score.toString().padLeft(5, '0')),
                        SizedBox(height: 10),
                        buildStatText('Level'),
                        buildStatNumber(gameState.level.toString()),
                        SizedBox(height: 10),
                        buildStatText('HIGH SCORE'),
                        buildStatNumber(gameState.highScore.toString().padLeft(5, '0')),
                        SizedBox(height: 10),
                    buildStatText('LIFE'),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Use width-based square cells (slightly larger for readability)
                        final double baseCell = constraints.maxWidth / SnakeGameState.cols;
                        final double cellSize = baseCell * 1.25; // scale up life cells
                        final double height = cellSize;
                        final double width = min(constraints.maxWidth, gameState.life * cellSize);
                        return SizedBox(height: height, width: width, child: _buildLifeDisplay(gameState.life));
                      },
                    ),
                        SizedBox(height: 10),
                        buildStatText('TIME'),
                        buildStatNumber('${gameState.elapsedSeconds ~/ 60}:${(gameState.elapsedSeconds % 60).toString().padLeft(2, '0')}'),
                        Spacer(),
                        Padding(
                          padding: EdgeInsets.only(bottom: 1),
                          child: Row(
                            children: [
                              Icon(
                                gameState.soundOn ? Icons.volume_up : Icons.volume_off,
                                size: 12,
                                color: LcdColors.pixelOn,
                              ),
                              SizedBox(width: 2),
                              Row(
                                children: List.generate(3, (i) => Container(
                                  width: 4,
                                  height: 8,
                                  margin: EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: i < gameState.volume ? LcdColors.pixelOn : LcdColors.pixelOn.withAlpha((255 * 0.3).round()),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                )),
                              ),
                              SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  gameState.togglePlaying();
                                },
                                child: Icon(
                                  gameState.isPlaying ? Icons.play_arrow : Icons.pause,
                                  size: 12,
                                  color: LcdColors.pixelOn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLifeDisplay(int life) {
    // Render lives using the same BrickPanel-like cell style
    return CustomPaint(
      painter: _LifeCellsPainter(lifeCount: life),
    );
  }
}

class _LifeCellsPainter extends CustomPainter {
  final int lifeCount;
  _LifeCellsPainter({required this.lifeCount});

  @override
  void paint(Canvas canvas, Size size) {
    // Render lives as a single 1-row grid with fixed cell size matching main grids
    const int rows = 1;
    final int cols = lifeCount.clamp(0, 10);

    // Make cells square-ish based on height
    final double cellHeight = size.height;
    final double cellWidth = cellHeight; // square cells for consistency

    // Colors and styles consistent with grids
    const double gapPx = 1.0;
    const double outerStrokeWidth = 1.0;
    const double innerSizeFactor = 0.6;

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

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = LcdColors.background);

    Rect contentRect(int c, int r) => Rect.fromLTWH(
          c * cellWidth + gapPx / 2,
          r * cellHeight + gapPx / 2,
          cellWidth - gapPx,
          cellHeight - gapPx,
        );

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

    // Compute how many cells fit in the available width
    final int maxCols = size.width ~/ cellWidth;
    final int toDraw = min(cols, maxCols);
    for (int c = 0; c < toDraw; c++) {
      drawCell(c, 0, c < lifeCount);
    }
  }

  @override
  bool shouldRepaint(covariant _LifeCellsPainter oldDelegate) => oldDelegate.lifeCount != lifeCount;
}

class _SnakeGamePainter extends CustomPainter {
  final List<Point<int>> snake;
  final Point<int>? food;
  final List<Point<int>> obstacles;
  final bool blinkHead;
  final bool blinkFood;

  _SnakeGamePainter({
    required this.snake,
    required this.food,
    required this.obstacles,
    this.blinkHead = false,
    this.blinkFood = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / SnakeGameState.cols;
    final double cellHeight = size.height / SnakeGameState.rows;

    final Paint backgroundPaint = Paint()..color = LcdColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Unified BrickPanel-like cell rendering
    const double gapPx = 1.0;
    const double outerStrokeWidth = 1.0;
    const double innerSizeFactor = 0.6;
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

    Rect cellContentRect(int col, int row) {
      final double x = col * cellWidth + gapPx / 2;
      final double y = row * cellHeight + gapPx / 2;
      final double w = cellWidth - gapPx;
      final double h = cellHeight - gapPx;
      return Rect.fromLTWH(x, y, w, h);
    }

    void drawCell(int col, int row, bool on) {
      final Rect outer = cellContentRect(col, row);
      canvas.drawRect(outer, on ? borderPaintOn : borderPaintOff);

      final double innerW = outer.width * innerSizeFactor;
      final double innerH = outer.height * innerSizeFactor;
      final double innerOffsetFactor = (1.0 - innerSizeFactor) / 2.0;
      final double innerX = outer.left + outer.width * innerOffsetFactor;
      final double innerY = outer.top + outer.height * innerOffsetFactor;
      final Rect inner = Rect.fromLTWH(innerX, innerY, innerW, innerH);
      canvas.drawRect(inner, on ? onPaint : offPaint);
    }

    void drawCellColored(int col, int row, Color color) {
      final Rect outer = cellContentRect(col, row);
      final Paint borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStrokeWidth;
      final Paint fillPaint = Paint()..color = color;
      canvas.drawRect(outer, borderPaint);

      final double innerW = outer.width * innerSizeFactor;
      final double innerH = outer.height * innerSizeFactor;
      final double innerOffsetFactor = (1.0 - innerSizeFactor) / 2.0;
      final double innerX = outer.left + outer.width * innerOffsetFactor;
      final double innerY = outer.top + outer.height * innerOffsetFactor;
      final Rect inner = Rect.fromLTWH(innerX, innerY, innerW, innerH);
      canvas.drawRect(inner, fillPaint);
    }

    // Draw all OFF
    for (int i = 0; i < SnakeGameState.rows; i++) {
      for (int j = 0; j < SnakeGameState.cols; j++) {
        drawCell(j, i, false);
      }
    }

    // Draw snake
    final double segmentPadding = 0.5; // Small gap between segments
    for (int i = 0; i < snake.length; i++) {
      final segment = snake[i];
      final bool isHead = i == 0;
      final bool visible = !(isHead && blinkHead);
      if (!visible) continue; // skip rendering head when blinking off
      if (isHead) {
        // Head in blue
        drawCellColored(segment.x, segment.y, Colors.blue);
      } else {
        drawCell(segment.x, segment.y, true);
      }
    }

    // Draw food with independent blink control
    if (food != null) {
      final bool showFood = !blinkFood; // visible when blink flag is false
      if (showFood) {
        // Food in red
        drawCellColored(food!.x, food!.y, Colors.red);
      }
    }

    // Draw obstacles
    for (var obstacle in obstacles) {
      drawCell(obstacle.x, obstacle.y, true);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _SnakeGamePainter) {
      return oldDelegate.snake != snake || oldDelegate.food != food || oldDelegate.obstacles != obstacles || oldDelegate.blinkHead != blinkHead;
    }
    return true;
  }
}

class _SnakeSidePanelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill the entire side panel with OFF cells to match LCD style
    const int rows = SnakeGameState.rows; // match main board rows
    final int cols = (SnakeGameState.cols / 2).ceil(); // approximate half width

    final double cellWidth = size.width / cols;
    final double cellHeight = size.height / rows;

    // Background
    final Paint bg = Paint()..color = LcdColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Cell style
    const double gapPx = 1.0;
    const double outerStrokeWidth = 1.0;
    const double innerSizeFactor = 0.6;

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
