import 'package:bricks/game/game_state.dart';
import 'package:bricks/game/game_grid_painter.dart';
import 'package:bricks/game/piece.dart';
import 'package:bricks/game/game_grid_painter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Import for Timer
import 'package:bricks/style/app_style.dart';
import 'package:tuple/tuple.dart';
import 'dart:math' as math;
import 'package:bricks/widgets/game_stats_widgets.dart';

class BricksGameContent extends StatefulWidget {
  const BricksGameContent({super.key});
  @override
  BricksGameContentState createState() => BricksGameContentState();
}

class BricksGameContentState extends State<BricksGameContent> with TickerProviderStateMixin {
  late final GameState gameState;
  bool _showGameOverText = false;
  bool _showStartText = false;
  Timer? _blinkTimer;
  Timer? _startBlinkTimer;

  @override
  void initState() {
    super.initState();
    gameState = Provider.of<GameState>(context, listen: false);
    gameState.addListener(_handleGameOver);
  }

  void _handleGameOver() {
    if (gameState.gameOver) {
      _showGameOverText = true; // Ensure it's visible initially
      _blinkTimer?.cancel(); // Cancel any existing timer
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        setState(() {
          _showGameOverText = !_showGameOverText;
        });
      });
    } else {
      // Game is no longer over, stop blinking and ensure text is hidden
      _blinkTimer?.cancel();
      _showGameOverText = false;
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    gameState.removeListener(_handleGameOver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: LcdColors.pixelOn, width: 3),
      ),
      child: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withAlpha((255 * 0.5).round()), width: 2),
        ),
        child: Row(
          children: [
            // Zone de jeu principale
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: LcdColors.pixelOn, width: 1),
                ),
                child: Selector<GameState, Tuple4<List<List<Tetromino?>>, Piece, bool, bool>>(
                  selector: (_, gameState) => Tuple4(
                    gameState.grid,
                    gameState.currentPiece,
                    gameState.gameOver,
                    gameState.isAnimatingLineClear,
                  ),
                  builder: (context, data, child) {
                    final grid = data.item1;
                    final currentPiece = data.item2;
                    final gameOver = data.item3;
                    final isAnimatingLineClear = data.item4;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final double targetAspect = GameState.cols / GameState.rows; // 10/20
                        final double maxW = constraints.maxWidth;
                        final double maxH = constraints.maxHeight;
                        double width = maxW;
                        double height = width / targetAspect;
                        if (height > maxH) {
                          height = maxH;
                          width = height * targetAspect;
                        }

                        return Stack(
                          children: [
                            Center(
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: CustomPaint(
                                  painter: GameGridPainter(grid, currentPiece, gameOver, isAnimatingLineClear),
                                ),
                              ),
                            ),
                            if (gameState.isStartingGame && !gameOver)
                              Center(
                                child: _StartBlinkText(),
                              ),
                            if (gameOver && _showGameOverText)
                              const Center(
                                child: Text(
                                  'GAME OVER',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Ligne de séparation verticale
            Container(
              width: 2,
              color: LcdColors.pixelOn,
              margin: EdgeInsets.symmetric(horizontal: 4),
            ),

            // Panneau d'informations
                        // ...existing code...
            // Panneau d'informations
            Expanded(
              flex: 1,
              child: Selector<GameState, Map<String, dynamic>>(
                selector: (_, gameState) => {
                  'score': gameState.score,
                  'lines': gameState.lines,
                  'level': gameState.level,
                  'highScore': gameState.highScore,
                  'nextPiece': gameState.nextPiece,
                  'elapsedSeconds': gameState.elapsedSeconds,
                  'soundOn': gameState.soundOn,
                  'volume': gameState.volume,
                  'playing': gameState.playing,
                },
                builder: (context, data, child) {
                  final score = data['score'];
                  final lines = data['lines'];
                  final level = data['level'];
                  final highScore = data['highScore'];
                  final nextPiece = data['nextPiece'];
                  final elapsedSeconds = data['elapsedSeconds'];
                  final soundOn = data['soundOn'];
                  final volume = data['volume'];
                  final playing = data['playing'];

                  return Stack(
                    children: [
                      // Background grid with OFF cells to match LCD bricks
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SidePanelGridPainter(),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.zero,
                        child: _buildInfoPanel(
                          score,
                          lines,
                          level,
                          highScore,
                          nextPiece,
                          elapsedSeconds,
                          soundOn,
                          volume,
                          playing,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // ...existing code...
          ],
        ),
      ),
    );
  }

  

  Widget _buildGameGrid(List<List<Tetromino?>> grid, Piece currentPiece, bool gameOver, bool isAnimatingLineClear) {
    return Column(
      children: List.generate(GameState.rows, (row) {
        return Expanded(
          child: Row(
            children: List.generate(GameState.cols, (col) {
              final tetromino = grid[row][col];
              bool isPiecePixel = false;

              // Check if the current pixel is part of the moving piece
              if (!gameOver && !isAnimatingLineClear) {
                for (int i = 0; i < currentPiece.shape.length; i++) {
                  for (int j = 0; j < currentPiece.shape[i].length; j++) {
                    if (currentPiece.shape[i][j] == 1) {
                      if (currentPiece.position.y + i == row &&
                          currentPiece.position.x + j == col) {
                        isPiecePixel = true;
                      }
                    }
                  }
                }
              }

              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: tetromino != null
                        ? LcdColors.pixelOn
                        : isPiecePixel
                            ? LcdColors.pixelOn
                            : LcdColors.pixelOff,
                    border: Border.all(color: LcdColors.background, width: 0.5),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildInfoPanel(int score, int lines, int level, int highScore, Piece nextPiece, int elapsedSeconds, bool soundOn, int volume, bool playing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 2),
        buildStatText('Points'),
        buildStatNumber(score.toString().padLeft(5, '0')),
        SizedBox(height: 1),
        buildStatText('Cleans'),
        buildStatNumber(lines.toString().padLeft(5, '0')),
        SizedBox(height: 1),
        buildStatText('Level'),
        buildStatNumber(level.toString().padLeft(5, '0')),
        SizedBox(height: 1),
        buildStatText('HIGH SCORE'),
        buildStatNumber(highScore.toString().padLeft(5, '0')),
        SizedBox(height: 1),
        buildStatText('Next'),
        SizedBox(height: 2),
        Flexible(
          flex: 2,
          fit: FlexFit.loose,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.9; // bigger
              return Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    border: Border.all(color: LcdColors.pixelOn, width: 1),
                  ),
                  child: _buildNextPiece(nextPiece),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 6),

        // Temps de jeu
        buildStatText('TIME'),
        Padding(
          padding: EdgeInsets.only(bottom: 1),
          child: buildStatNumber('${elapsedSeconds ~/ 60}:${(elapsedSeconds % 60).toString().padLeft(2, '0')}'),
        ),

        // Icônes dynamiques
        Padding(
          padding: EdgeInsets.only(bottom: 1),
          child: Row(
            children: [
              Icon(
                soundOn ? Icons.volume_up : Icons.volume_off,
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
                    color: i < volume ? LcdColors.pixelOn : LcdColors.pixelOn.withAlpha((255 * 0.3).round()),
                    borderRadius: BorderRadius.circular(1),
                  ),
                )),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Provider.of<GameState>(context, listen: false).togglePlaying();
                },
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  size: 12,
                  color: LcdColors.pixelOn,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextPiece(Piece piece) {
    // Use the same BrickPanel-like cells as the main board and fill space
    return SizedBox.expand(
      child: CustomPaint(
        painter: _NextPiecePainter(piece),
      ),
    );
  }
}

class _StartBlinkText extends StatefulWidget {
  @override
  State<_StartBlinkText> createState() => _StartBlinkTextState();
}

class _StartBlinkTextState extends State<_StartBlinkText> {
  bool _visible = true;
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      setState(() {
        _visible = !_visible;
        _count++;
        if (_count >= 6) {
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _visible ? 1 : 0,
      child: const Text(
        'START',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.green,
          fontFamily: 'Digital7',
        ),
      ),
    );
  }
}

class _NextPiecePainter extends CustomPainter {
  final Piece piece;
  _NextPiecePainter(this.piece);

  static const int rows = 4;
  static const int cols = 4;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final Paint bg = Paint()..color = LcdColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final double cellWidth = size.width / cols;
    final double cellHeight = size.height / rows;

    // Reuse the same visual style constants as the main grid
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

    void drawCell(int c, int r, {Color? color}) {
      final Rect outer = contentRect(c, r);
      if (color == null) {
        canvas.drawRect(outer, borderPaintOff);
      } else {
        final Paint borderPaintOn = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = outerStrokeWidth;
        canvas.drawRect(outer, borderPaintOn);
      }

      final double innerW = outer.width * innerSizeFactor;
      final double innerH = outer.height * innerSizeFactor;
      final double innerOffset = (1.0 - innerSizeFactor) / 2.0;
      final Rect inner = Rect.fromLTWH(
        outer.left + outer.width * innerOffset,
        outer.top + outer.height * innerOffset,
        innerW,
        innerH,
      );
      if (color == null) {
        canvas.drawRect(inner, offPaint);
      } else {
        final Color blended = Color.alphaBlend(LcdColors.background.withOpacity(0.20), color);
        final Paint fillPaint = Paint()..color = blended;
        canvas.drawRect(inner, fillPaint);
      }
    }

    // Draw all OFF cells
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        drawCell(c, r, color: null);
      }
    }

    // Draw next piece pixels centered within 4x4 area
    for (int r = 0; r < piece.shape.length && r < rows; r++) {
      for (int c = 0; c < piece.shape[r].length && c < cols; c++) {
        if (piece.shape[r][c] == 1) {
          drawCell(c, r, color: TetrominoPalette.colorFor(piece.type));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NextPiecePainter oldDelegate) => oldDelegate.piece != piece;
}

class _SidePanelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill the entire side panel with OFF cells matching the LCD style
    const int rows = GameState.rows; // match main grid density vertically
    const int cols = GameState.cols ~/ 2; // half width panel approximates

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
  
