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
  bool _showStartText = false; // New state for start animation
  bool _blinkHead = true; // State for snake head blinking
  Timer? _blinkTimer; // Timer for game over/start text blinking
  Timer? _headBlinkTimer; // Timer for snake head blinking

  @override
  void initState() {
    super.initState();
    gameState = Provider.of<SnakeGameState>(context, listen: false);
    gameState.addListener(_handleGameOver);
    _startHeadBlinking(); // Start head blinking immediately
  }

  void _startHeadBlinking() {
    _headBlinkTimer?.cancel(); // Cancel any existing timer
    _headBlinkTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      setState(() {
        _blinkHead = !_blinkHead;
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
      _showStartText = true; // Ensure it's visible initially
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        setState(() {
          _showStartText = !_showStartText;
          print('SnakeGameWidget: _showStartText toggled: $_showStartText');
        });
      });
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
                    obstacles: gameState.obstacles, // Pass obstacles to painter
                    lcdPixelOn: LcdColors.pixelOn,
                    lcdPixelOff: LcdColors.pixelOff,
                    blinkHead: _blinkHead && gameState.isPlaying, // Pass blinking state to painter
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
                      : gameState.isStartingGame && _showStartText
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'START',
                                    style: TextStyle(
                                      color: gameState.startBlinkColor,
                                      fontSize: 24,
                                      fontFamily: 'Digital7',
                                    ),
                                  ),
                                ],
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
                child: Column(
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
                    _buildLifeDisplay(gameState.life),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLifeDisplay(int life) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(life, (index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: LcdColors.pixelOn,
            border: Border.all(color: LcdColors.background, width: 0.5),
          ),
        ),
      )),
    );
  }
}

class _SnakeGamePainter extends CustomPainter {
  final List<Point<int>> snake;
  final Point<int>? food;
  final List<Point<int>> obstacles;
  final Color lcdPixelOn;
  final Color lcdPixelOff;
  final bool blinkHead; // New property for blinking head

  _SnakeGamePainter({
    required this.snake,
    required this.food,
    required this.obstacles,
    required this.lcdPixelOn,
    required this.lcdPixelOff,
    this.blinkHead = false, // Default to false
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellSize = min(size.width / SnakeGameState.cols, size.height / SnakeGameState.rows);
    // Draw background pixels (off pixels)
    for (int i = 0; i < SnakeGameState.rows; i++) {
      for (int j = 0; j < SnakeGameState.cols; j++) {
        final Rect cellRect = Rect.fromLTWH(
          j * cellSize,
          i * cellSize,
          cellSize,
          cellSize,
        );
        canvas.drawRect(cellRect, Paint()..color = lcdPixelOff);
        canvas.drawRect(cellRect, Paint()
          ..color = LcdColors.background
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
      }
    }

    // Draw snake
    final double segmentPadding = 0.5; // Small gap between segments
    for (int i = 0; i < snake.length; i++) {
      final segment = snake[i];
      final paintColor = (i == 0 && blinkHead) ? Colors.grey : lcdPixelOn; // Head blinks grey
      canvas.drawRect(
        Rect.fromLTWH(
          segment.x * cellSize + segmentPadding,
          segment.y * cellSize + segmentPadding,
          cellSize - (2 * segmentPadding),
          cellSize - (2 * segmentPadding),
        ),
        Paint()..color = paintColor,
      );
    }

    // Draw food
    if (food != null) {
      canvas.drawRect(
        Rect.fromLTWH(
          food!.x * cellSize,
          food!.y * cellSize,
          cellSize,
          cellSize,
        ),
        Paint()..color = Colors.red,
      );
    }

    // Draw obstacles
    for (var obstacle in obstacles) {
      canvas.drawRect(
        Rect.fromLTWH(
          obstacle.x * cellSize,
          obstacle.y * cellSize,
          cellSize,
          cellSize,
        ),
        Paint()..color = Colors.blueGrey, // Or any other color for obstacles
      );
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