import 'package:bricks/game/piece.dart';
import 'package:bricks/game/race/race_game_state.dart';
import 'package:bricks/widgets/game_stats_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/style/app_style.dart';
import 'dart:math';

/// Fonction utilitaire pour dessiner une cellule de l'écran LCD.
void _drawLcdCell({
  required Canvas canvas,
  required Rect bounds,
  required bool isOn,
  required Paint onPaint,
  required Paint offPaint,
  required Paint borderPaintOn,
  required Paint borderPaintOff,
  double innerSizeFactor = 0.6,
}) {
  canvas.drawRect(bounds, isOn ? borderPaintOn : borderPaintOff);

  final double innerW = bounds.width * innerSizeFactor;
  final double innerH = bounds.height * innerSizeFactor;
  final double innerOffsetFactor = (1.0 - innerSizeFactor) / 2.0;
  final double innerX = bounds.left + bounds.width * innerOffsetFactor;
  final double innerY = bounds.top + bounds.height * innerOffsetFactor;
  final Rect inner = Rect.fromLTWH(innerX, innerY, innerW, innerH);
  canvas.drawRect(inner, isOn ? onPaint : offPaint);
}

class RaceGameWidget extends StatefulWidget {
  const RaceGameWidget({super.key});

  @override
  State<RaceGameWidget> createState() => _RaceGameWidgetState();
}

class _RaceGameWidgetState extends State<RaceGameWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RaceGameState>(
      builder: (context, gameState, child) {
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
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: LcdColors.pixelOn, width: 1),
                    ),
                    child: CustomPaint(
                      painter: _RaceGamePainter(gameState),
                      child: Container(),
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  color: LcdColors.pixelOn,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                Expanded(
                  flex: 1,
                  child: _buildInfoPanel(gameState),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoPanel(RaceGameState gameState) {
    return Column(
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
            final double baseCell = constraints.maxWidth / RaceGameState.cols;
            final double cellSize = baseCell * 1.25;
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
                  gameState.playing ? Icons.play_arrow : Icons.pause,
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

  Widget _buildLifeDisplay(int life) {
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
    const int rows = 1;
    final int cols = lifeCount.clamp(0, 10);

    final double cellHeight = size.height;
    final double cellWidth = cellHeight;

    const double gapPx = 1.0;
    const double outerStrokeWidth = 1.0;
    const double innerSizeFactor = 0.6;

    final Paint onPaint = Paint()..color = LcdColors.pixelOn;
    final Paint borderPaintOn = Paint()
      ..color = LcdColors.pixelOn
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStrokeWidth;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = LcdColors.background);

    Rect contentRect(int c, int r) => Rect.fromLTWH(
          c * cellWidth + gapPx / 2,
          r * cellHeight + gapPx / 2,
          cellWidth - gapPx,
          cellHeight - gapPx,
        );

    final int maxCols = size.width ~/ cellWidth;
    final int toDraw = min(cols, maxCols);
    for (int c = 0; c < toDraw; c++) {
      _drawLcdCell(
        canvas: canvas,
        bounds: contentRect(c, 0),
        isOn: true, // Les cellules de vie sont toujours "allumées"
        onPaint: onPaint,
        offPaint: onPaint, // Non utilisé, mais requis par la fonction
        borderPaintOn: borderPaintOn,
        borderPaintOff: borderPaintOn, // Non utilisé
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LifeCellsPainter oldDelegate) => oldDelegate.lifeCount != lifeCount;
}

class _RaceGamePainter extends CustomPainter {
  final RaceGameState gameState;

  _RaceGamePainter(this.gameState);

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / RaceGameState.cols;
    final double cellHeight = size.height / RaceGameState.rows;

    final Paint backgroundPaint = Paint()..color = LcdColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

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

    // 1. Dessine toutes les cellules en état "éteint" comme couche de base
    for (int row = 0; row < RaceGameState.rows; row++) {
      for (int col = 0; col < RaceGameState.cols; col++) {
        _drawLcdCell(
            canvas: canvas,
            bounds: cellContentRect(col, row),
            isOn: false, // Toutes les cellules sont initialement "éteintes"
            onPaint: onPaint, offPaint: offPaint, borderPaintOn: borderPaintOn, borderPaintOff: borderPaintOff
        );
      }
    }

    // 2. Dessine les éléments de la route
    for (final point in gameState.road.points) {
      if (point.y >= 0 && point.y < RaceGameState.rows && point.x >= 0 && point.x < RaceGameState.cols) {
        _drawLcdCell(
            canvas: canvas,
            bounds: cellContentRect(point.x, point.y),
            isOn: true, // Les pixels de la route sont "allumés"
            onPaint: onPaint, offPaint: offPaint, borderPaintOn: borderPaintOn, borderPaintOff: borderPaintOff
        );
      }
    }

    // 3. Dessine les autres voitures (par-dessus la route)
    for (final car in gameState.otherCars) {
      for (final point in car.points) {
        if (point.y >= 0 && point.y < RaceGameState.rows && point.x >= 0 && point.x < RaceGameState.cols) {
          _drawLcdCell(
            canvas: canvas,
            bounds: cellContentRect(point.x, point.y),
            isOn: true, // Les pixels des voitures sont "allumés"
            onPaint: onPaint, offPaint: offPaint, borderPaintOn: borderPaintOn, borderPaintOff: borderPaintOff
          );}}
        
      
    }

    // 4. Dessine la voiture du joueur (par-dessus tout le reste)
    for (final point in gameState.playerCar.points) {
      if (point.y >= 0 && point.y < RaceGameState.rows && point.x >= 0 && point.x < RaceGameState.cols) {
        _drawLcdCell(
            canvas: canvas,
            bounds: cellContentRect(point.x, point.y),
            isOn: true, // Les pixels de la voiture du joueur sont "allumés"
            onPaint: onPaint, offPaint: offPaint, borderPaintOn: borderPaintOn, borderPaintOff: borderPaintOff
        );
      }
    }

    if (gameState.isCrashing) {
      final crashShapes = [
        // Frame 0: single dot
        [Point(0, 0)],
        // Frame 1: cross
        [Point(-1, 0), Point(0, 0), Point(1, 0), Point(0, -1), Point(0, 1)],
        // Frame 2: expanding cross
        [Point(-2, 0), Point(-1, 0), Point(0, 0), Point(1, 0), Point(2, 0),
         Point(0, -2), Point(0, -1), Point(0, 1), Point(0, 2)],
      ];

      final currentFrame = gameState.crashAnimationFrame;
      if (currentFrame < crashShapes.length) {
        final crashPoints = crashShapes[currentFrame];
        final playerCarCenter = gameState.playerCar.points.first; // Approximate center

        for (final point in crashPoints) {
          final displayX = playerCarCenter.x + point.x;
          final displayY = playerCarCenter.y + point.y;
          if (displayX >= 0 && displayX < RaceGameState.cols &&
              displayY >= 0 && displayY < RaceGameState.rows) {
            _drawLcdCell(
              canvas: canvas,
              bounds: cellContentRect(displayX, displayY),
              isOn: true,
              onPaint: onPaint, offPaint: offPaint, borderPaintOn: borderPaintOn, borderPaintOff: borderPaintOff,
            );
          }
        }
      }
    } else if (gameState.gameOver) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'GAME OVER',
          style: TextStyle(
            color: Colors.red,
            fontSize: 24,
            fontFamily: 'Digital7',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RaceGamePainter oldDelegate) {
    // Ne redessine que si l'état du jeu a changé.
    return oldDelegate.gameState != gameState || oldDelegate.gameState.isCrashing != gameState.isCrashing || oldDelegate.gameState.crashAnimationFrame != gameState.crashAnimationFrame;
  }
}
