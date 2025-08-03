import 'package:bricks/game/game_state.dart';
import 'package:bricks/game/piece.dart';
import 'package:bricks/screens/game_over_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Import for Timer
import 'package:tuple/tuple.dart';

class TetrisGameScreen extends StatefulWidget {
  const TetrisGameScreen({super.key});
  @override
  TetrisGameScreenState createState() => TetrisGameScreenState();
}

class TetrisGameScreenState extends State<TetrisGameScreen> with TickerProviderStateMixin {
  // Couleurs LCD authentiques
  static const Color lcdPixelOn = Color(0xFF3E3B39);
  static const Color lcdPixelOff = Color(0xFFC4C0B3);
  static const Color lcdBackground = Color(0xFFD3CDBF);

  bool _showGameOverText = false;
  Timer? _blinkTimer;
  int _blinkCount = 0;

  @override
  void initState() {
    super.initState();
    final gameState = Provider.of<GameState>(context, listen: false);
    gameState.addListener(_handleGameOver);
  }

  void _handleGameOver() {
    final gameState = Provider.of<GameState>(context, listen: false);
    if (gameState.gameOver) {
      _blinkCount = 0;
      _blinkTimer?.cancel(); // Cancel any existing timer
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        setState(() {
          _showGameOverText = !_showGameOverText;
          _blinkCount++;
        });
        if (_blinkCount >= 6) { // Blink 3 times (on/off is 2 blinks)
          _blinkTimer?.cancel();
          // Navigate to GameOverScreen after blinking
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GameOverScreen(
                finalScore: gameState.score,
                highScore: gameState.highScore,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    Provider.of<GameState>(context, listen: false).removeListener(_handleGameOver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: TetrisGameScreenState.lcdPixelOn, width: 3),
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
                  border: Border.all(color: TetrisGameScreenState.lcdPixelOn, width: 1),
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
              color: TetrisGameScreenState.lcdPixelOn,
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
                        ? TetrisGameScreenState.lcdPixelOn
                        : isPiecePixel
                            ? TetrisGameScreenState.lcdPixelOn
                            : TetrisGameScreenState.lcdPixelOff,
                    border: Border.all(color: TetrisGameScreenState.lcdBackground, width: 0.5),
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
        _buildStatText('Points'),
        _buildStatNumber(score.toString().padLeft(5, '0')),
        SizedBox(height: 1),
        _buildStatText('Cleans'),
        _buildStatNumber(lines.toString().padLeft(5, '0')),
        SizedBox(height: 1),
        _buildStatText('Level'),
        _buildStatNumber(level.toString().padLeft(5, '0')),
        SizedBox(height: 1),
        _buildStatText('HIGH SCORE'),
        _buildStatNumber(highScore.toString().padLeft(5, '0')),
        SizedBox(height: 1),
        _buildStatText('Next'),
        SizedBox(height: 1),
        _buildNextPiece(nextPiece),
        Spacer(),

        // Temps de jeu
        _buildStatText('TIME'),
        Padding(
          padding: EdgeInsets.only(bottom: 1),
          child: _buildStatNumber('${elapsedSeconds ~/ 60}:${(elapsedSeconds % 60).toString().padLeft(2, '0')}'),
        ),

        // Icônes dynamiques
        Padding(
          padding: EdgeInsets.only(bottom: 1),
          child: Row(
            children: [
              Icon(
                soundOn ? Icons.volume_up : Icons.volume_off,
                size: 12,
                color: TetrisGameScreenState.lcdPixelOn,
              ),
              SizedBox(width: 2),
              Row(
                children: List.generate(3, (i) => Container(
                  width: 4,
                  height: 8,
                  margin: EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: i < volume ? TetrisGameScreenState.lcdPixelOn : TetrisGameScreenState.lcdPixelOn.withAlpha((255 * 0.3).round()),
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
                  color: TetrisGameScreenState.lcdPixelOn,
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
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        border: Border.all(color: TetrisGameScreenState.lcdPixelOn, width: 1),
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
                      color: isPixelOn ? TetrisGameScreenState.lcdPixelOn : TetrisGameScreenState.lcdPixelOff,
                      border: Border.all(color: TetrisGameScreenState.lcdBackground, width: 0.5),
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

  Widget _buildStatText(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          color: TetrisGameScreenState.lcdPixelOn,
          fontSize: 12, // Increased font size
          fontWeight: FontWeight.bold,
          fontFamily: 'Digital7', // Apply Digital7 font
        ),
      ),
    );
  }

  Widget _buildStatNumber(String number) {
    return Padding(
      padding: EdgeInsets.only(top: 2),
      child: Text(
        number,
        style: TextStyle(
          color: TetrisGameScreenState.lcdPixelOn,
          fontSize: 18, // Increased font size
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          fontFamily: 'Digital7', // Apply Digital7 font
        ),
      ),
    );
  }
}