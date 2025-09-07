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

/// Colored variant of the LCD cell drawing for highlights (centers/trails).
void _drawLcdCellColored({
  required Canvas canvas,
  required Rect bounds,
  required Color color,
  double innerSizeFactor = 0.6,
}) {
  final Paint border = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Color blended = Color.alphaBlend(LcdColors.background.withOpacity(0.2), color);
  final Paint fill = Paint()..color = blended;
  canvas.drawRect(bounds, border);
  final double innerW = bounds.width * innerSizeFactor;
  final double innerH = bounds.height * innerSizeFactor;
  final double innerOffsetFactor = (1.0 - innerSizeFactor) / 2.0;
  final double innerX = bounds.left + bounds.width * innerOffsetFactor;
  final double innerY = bounds.top + bounds.height * innerOffsetFactor;
  final Rect inner = Rect.fromLTWH(innerX, innerY, innerW, innerH);
  canvas.drawRect(inner, fill);
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
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: LcdColors.pixelOn, width: 1),
                    ),
                    child: _buildInfoPanel(gameState),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoPanel(RaceGameState gameState) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RaceSidePanelGridPainter(),
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
                final double baseCell = constraints.maxWidth / RaceGameState.cols;
                final double iconHeight = (baseCell * 1.0).clamp(10.0, 28.0);
                final double width = constraints.maxWidth;
                return SizedBox(height: iconHeight, width: width, child: _buildLifeDisplay(gameState.life));
              },
            ),
            SizedBox(height: 10),
            buildStatText('TIME'),
            buildStatNumber('${gameState.elapsedSeconds ~/ 60}:${(gameState.elapsedSeconds % 60).toString().padLeft(2, '0')}'),
            Spacer(),
            Padding(
              padding: EdgeInsets.only(bottom: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      ],
    );
  }

// Moved to top-level scope (outside State class)

  Widget _buildLifeDisplay(int life) {
    return CustomPaint(
      painter: _LifeCellsPainter(lifeCount: life),
    );
  }
}

class _RaceSidePanelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const int rows = RaceGameState.rows;
    final int cols = (RaceGameState.cols / 2).ceil();
    final double cellWidth = size.width / cols;
    final double cellHeight = size.height / rows;
    final Paint bg = Paint()..color = LcdColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
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

class _LifeCellsPainter extends CustomPainter {
  final int lifeCount;
  _LifeCellsPainter({required this.lifeCount});

  @override
  void paint(Canvas canvas, Size size) {
    // Render exactly 4 LCD-style squares: ON for remaining lives, OFF otherwise
    final int lives = lifeCount.clamp(0, 4);
    const double gapPx = 1.0;
    const double outerStrokeWidth = 1.0;
    const double innerSizeFactor = 0.6;
    final Paint offPaint = Paint()..color = LcdColors.pixelOff;
    final Paint borderOff = Paint()
      ..color = LcdColors.pixelOff
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStrokeWidth;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = LcdColors.background);

    final int slots = 4;
    final double slotW = size.width / slots;
    final double side = (min(slotW, size.height) - gapPx);

    Rect squareRect(double x, double y) => Rect.fromLTWH(x + gapPx / 2, y + gapPx / 2, side, side);

    void drawOffRect(Rect r) {
      canvas.drawRect(r, borderOff);
      final double innerW = r.width * innerSizeFactor;
      final double innerH = r.height * innerSizeFactor;
      final double innerOffset = (1.0 - innerSizeFactor) / 2.0;
      final Rect inner = Rect.fromLTWH(
        r.left + r.width * innerOffset,
        r.top + r.height * innerOffset,
        innerW,
        innerH,
      );
      canvas.drawRect(inner, offPaint);
    }

    void drawOnRect(Rect r) {
      final Paint borderOn = Paint()
        ..color = LcdColors.pixelOn
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStrokeWidth;
      final Paint onPaint = Paint()..color = LcdColors.pixelOn;
      canvas.drawRect(r, borderOn);
      final double innerW = r.width * innerSizeFactor;
      final double innerH = r.height * innerSizeFactor;
      final double innerOffset = (1.0 - innerSizeFactor) / 2.0;
      final Rect inner = Rect.fromLTWH(
        r.left + r.width * innerOffset,
        r.top + r.height * innerOffset,
        innerW,
        innerH,
      );
      canvas.drawRect(inner, onPaint);
    }

    for (int i = 0; i < slots; i++) {
      final double ox = i * slotW + (slotW - side - gapPx) / 2;
      final double oy = (size.height - side - gapPx) / 2;
      final Rect r = squareRect(ox, oy);
      drawOffRect(r);
      if (i < lives) {
        drawOnRect(r);
      }
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

    // 5. Highlights: single center point between the "wings" for player and enemies
    Point<int> nearestToCentroid(List<Point<int>> pts) {
      double sx = 0, sy = 0;
      for (final p in pts) { sx += p.x; sy += p.y; }
      final double cx = sx / pts.length;
      final double cy = sy / pts.length;
      Point<int> best = pts.first;
      double bestD = double.infinity;
      for (final p in pts) {
        final double dx = p.x - cx;
        final double dy = p.y - cy;
        final double d2 = dx * dx + dy * dy;
        if (d2 < bestD) { bestD = d2; best = p; }
      }
      return best;
    }

    // Player center point (blue). Blink while accelerating.
    final bool drawPlayerCenter = !gameState.isAccelerating || gameState.trailBlinkOn;
    if (drawPlayerCenter) {
      final pc = nearestToCentroid(gameState.playerCar.points);
      final int nx = pc.x;
      final int ny = pc.y - 1; // the tile just above the center
      if (ny >= 0 && ny < RaceGameState.rows && nx >= 0 && nx < RaceGameState.cols) {
        _drawLcdCellColored(
          canvas: canvas,
          bounds: cellContentRect(nx, ny),
          color: const Color(0xFF1E88E5),
        );
      }
    }

    // Enemy single center point (red)
    for (final car in gameState.otherCars) {
      if (car.points.isEmpty) continue;
      final c = nearestToCentroid(car.points);
      final int ex = c.x;
      final int ey = c.y - 1; // highlight tile just above the center
      if (ey >= 0 && ey < RaceGameState.rows && ex >= 0 && ex < RaceGameState.cols) {
        _drawLcdCellColored(
          canvas: canvas,
          bounds: cellContentRect(ex, ey),
          color: const Color(0xFFE53935),
        );
      }
    }

    // Overlay game-over rings if applicable
    if (gameState.gameOver && gameState.gameOverAnimFrame > 0) {
      final int f = gameState.gameOverAnimFrame;
      final int rings = (f / 2).clamp(1, 12).toInt();
      for (int r = 0; r < rings; r++) {
        final int inset = r;
        final Color col = r < 4 ? const Color(0xFFFFEB3B) : (r < 8 ? const Color(0xFFFF9800) : const Color(0xFFF44336));
        for (int x = inset; x < RaceGameState.cols - inset; x++) {
          _drawLcdCellColored(canvas: canvas, bounds: cellContentRect(x, inset), color: col);
          _drawLcdCellColored(canvas: canvas, bounds: cellContentRect(x, RaceGameState.rows - 1 - inset), color: col);
        }
        for (int y = inset; y < RaceGameState.rows - inset; y++) {
          _drawLcdCellColored(canvas: canvas, bounds: cellContentRect(inset, y), color: col);
          _drawLcdCellColored(canvas: canvas, bounds: cellContentRect(RaceGameState.cols - 1 - inset, y), color: col);
        }
      }
    }

    if (gameState.isCrashing) {
      // Improved explosion: expanding colored rings around approximate center
      Point<int> centerOf(List<Point<int>> pts) {
        double sx = 0, sy = 0;
        for (final p in pts) { sx += p.x; sy += p.y; }
        return Point((sx / pts.length).round(), (sy / pts.length).round());
      }

      final center = centerOf(gameState.playerCar.points);
      final int f = gameState.crashAnimationFrame; // 0..animationFrames
      final int maxRing = 5; // explosion radius in tiles
      final int ring = f.clamp(0, maxRing);

      // Draw all rings up to current ring for a fuller explosion effect
      for (int r = 0; r <= ring; r++) {
        // Choose color by ring: hot center (yellow) → orange → red
        Color col;
        if (r <= 1) {
          col = const Color(0xFFFFEB3B); // yellow
        } else if (r <= 3) {
          col = const Color(0xFFFF9800); // orange
        } else {
          col = const Color(0xFFF44336); // red
        }

        // Generate Chebyshev ring (square ring), sample the perimeter
        for (int dx = -r; dx <= r; dx++) {
          for (int dy = -r; dy <= r; dy++) {
            final bool onPerimeter = (dx.abs() == r || dy.abs() == r);
            if (!onPerimeter) continue;
            // Downsample to avoid filling every tile at large r
            if (r >= 3 && ((dx + dy) % 2 != 0)) continue;
            final int x = center.x + dx;
            final int y = center.y + dy;
            if (x >= 0 && x < RaceGameState.cols && y >= 0 && y < RaceGameState.rows) {
              _drawLcdCellColored(
                canvas: canvas,
                bounds: cellContentRect(x, y),
                color: col,
              );
            }
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
