import 'package:bricks/game/game_state.dart';
import 'package:bricks/game/piece.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Import for Timer
import 'package:bricks/style/app_style.dart';
import 'package:tuple/tuple.dart';
import 'package:bricks/widgets/game_stats_widgets.dart';

class BricksGameContent extends StatefulWidget {
  const BricksGameContent({super.key});
  @override
  BricksGameContentState createState() => BricksGameContentState();
}

class BricksGameContentState extends State<BricksGameContent> with TickerProviderStateMixin {
  late final GameState gameState;
  bool _showGameOverText = false;
  Timer? _blinkTimer;

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

                    return Stack(
                      children: [
                        _buildGameGrid(grid, currentPiece, gameOver, isAnimatingLineClear),
                        if (gameOver && _showGameOverText) // Only show if game over and blinking allows
                          Center(
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
            
                  return _buildInfoPanel(score, lines, level, highScore, nextPiece, elapsedSeconds, soundOn, volume, playing);
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
        SizedBox(height: 1),
        Expanded(child: _buildNextPiece(nextPiece)),
        Spacer(flex: 2),

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
                  playing ? Icons.play_arrow : Icons.pause,
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
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: LcdColors.pixelOn, width: 1),
      ),
      child: Column(
        children: List.generate(4, (row) {
          return Expanded(
            child: Row(
              children: List.generate(4, (col) {
                bool isPixelOn = false;
                if (row < piece.shape.length && col < piece.shape[row].length) {
                  if (piece.shape[row][col] == 1) {
                    isPixelOn = true;
                  }
                }
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isPixelOn ? LcdColors.pixelOn : LcdColors.pixelOff,
                      border: Border.all(color: LcdColors.background, width: 0.5),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
  