import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/style/app_style.dart';
import 'package:bricks/game/brick/brick_game_state.dart';
import 'package:bricks/widgets/game_stats_widgets.dart';

class BrickGameWidget extends StatelessWidget {
  const BrickGameWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 3)),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOff, width: 2), color: LcdColors.background),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 1)),
                child: const _BrickBoard(),
              ),
            ),
            Container(width: 2, color: LcdColors.pixelOn, margin: const EdgeInsets.symmetric(horizontal: 4)),
            const Expanded(flex: 1, child: _BrickStats()),
          ],
        ),
      ),
    );
  }
}

class _BrickBoard extends StatelessWidget {
  const _BrickBoard();
  @override
  Widget build(BuildContext context) {
    return Consumer<BrickGameState>(builder: (context, gs, _) {
      return CustomPaint(painter: _BrickPainter(gs), child: Container());
    });
  }
}

class _BrickPainter extends CustomPainter {
  final BrickGameState gs;
  _BrickPainter(this.gs);

  @override
  void paint(Canvas canvas, Size size) {
    final double cellW = size.width / BrickGameState.cols;
    final double cellH = size.height / BrickGameState.rows;
    final Paint bg = Paint()..color = LcdColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    const double gapPx = 1.0;
    const double outerStrokeWidth = 1.0;
    const double innerSizeFactor = 0.6;
    final Paint offPaint = Paint()..color = LcdColors.pixelOff;
    final Paint borderOff = Paint()
      ..color = LcdColors.pixelOff
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStrokeWidth;

    Rect contentRect(int c, int r) => Rect.fromLTWH(c * cellW + gapPx / 2, r * cellH + gapPx / 2, cellW - gapPx, cellH - gapPx);

    for (int r = 0; r < BrickGameState.rows; r++) {
      for (int c = 0; c < BrickGameState.cols; c++) {
        final Rect outer = contentRect(c, r);
        canvas.drawRect(outer, borderOff);
        final Rect inner = Rect.fromLTWH(
          outer.left + outer.width * (1 - innerSizeFactor) / 2,
          outer.top + outer.height * (1 - innerSizeFactor) / 2,
          outer.width * innerSizeFactor,
          outer.height * innerSizeFactor,
        );
        canvas.drawRect(inner, offPaint);
      }
    }

    void drawOn(int x, int y, Color color) {
      if (x < 0 || x >= BrickGameState.cols || y < 0 || y >= BrickGameState.rows) return;
      final Rect outer = contentRect(x, y);
      final Paint borderOn = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStrokeWidth;
      final Paint onPaint = Paint()..color = Color.alphaBlend(LcdColors.background.withOpacity(0.2), color);
      canvas.drawRect(outer, borderOn);
      final Rect inner = Rect.fromLTWH(
        outer.left + outer.width * (1 - innerSizeFactor) / 2,
        outer.top + outer.height * (1 - innerSizeFactor) / 2,
        outer.width * innerSizeFactor,
        outer.height * innerSizeFactor,
      );
      canvas.drawRect(inner, onPaint);
    }

    // Bricks with color varying by row for visual variety
    for (final b in gs.bricks) {
      final int r = b.y;
      final Color col = (r % 3 == 0)
          ? const Color(0xFFFF9800)
          : (r % 3 == 1)
              ? const Color(0xFF4CAF50)
              : const Color(0xFF2196F3);
      drawOn(b.x, b.y, col);
    }

    // Paddle (blue 3-wide)
    final int py = BrickGameState.rows - 2;
    drawOn(gs.paddleX - 1, py, const Color(0xFF1E88E5));
    drawOn(gs.paddleX, py, const Color(0xFF1E88E5));
    drawOn(gs.paddleX + 1, py, const Color(0xFF1E88E5));

    // Ball (red)
    drawOn(gs.ball.x, gs.ball.y, const Color(0xFFF44336));

    // UFO bonus (magenta)
    if (gs.ufo != null) {
      drawOn(gs.ufo!.x, gs.ufo!.y, const Color(0xFFE91E63));
    }

    // Falling power-ups
    for (final p in gs.powerUps) {
      Color c;
      switch (p.kind) {
        case PowerUpKind.expand:
          c = const Color(0xFF4CAF50); // green
          break;
        case PowerUpKind.slow:
          c = const Color(0xFF00BCD4); // cyan
          break;
        case PowerUpKind.life:
          c = const Color(0xFFFFC107); // amber
          break;
      }
      drawOn(p.pos.x, p.pos.y, c);
    }

    // Game over rings
    if (gs.gameOver && gs.gameOverAnimFrame > 0) {
      final int rings = (gs.gameOverAnimFrame / 2).clamp(1, 12).toInt();
      for (int r = 0; r < rings; r++) {
        final int inset = r;
        final Color col = r < 4 ? const Color(0xFFFFEB3B) : (r < 8 ? const Color(0xFFFF9800) : const Color(0xFFF44336));
        for (int x = inset; x < BrickGameState.cols - inset; x++) {
          drawOn(x, inset, col);
          drawOn(x, BrickGameState.rows - 1 - inset, col);
        }
        for (int y = inset; y < BrickGameState.rows - inset; y++) {
          drawOn(inset, y, col);
          drawOn(BrickGameState.cols - 1 - inset, y, col);
        }
      }
      // Text overlay
      final textPainter = TextPainter(
        text: const TextSpan(text: 'GAME OVER', style: TextStyle(color: Colors.red, fontSize: 22, fontFamily: 'Digital7')),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BrickPainter oldDelegate) => oldDelegate.gs != gs;
}

class _BrickStats extends StatelessWidget {
  const _BrickStats();

  @override
  Widget build(BuildContext context) {
    return Consumer<BrickGameState>(builder: (context, gs, _) {
      return Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _SidePanelGridPainter())),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildStatText('Score'),
              buildStatNumber(gs.score.toString().padLeft(5, '0')),
              const SizedBox(height: 10),
              buildStatText('Level'),
              buildStatNumber(gs.level.toString()),
              const SizedBox(height: 10),
              buildStatText('HIGH SCORE'),
              buildStatNumber(gs.highScore.toString().padLeft(5, '0')),
              const SizedBox(height: 10),
              buildStatText('LIFE'),
              _lifeIcons(gs.life),
              const SizedBox(height: 10),
              buildStatText('TIME'),
              buildStatNumber('${gs.elapsedSeconds ~/ 60}:${(gs.elapsedSeconds % 60).toString().padLeft(2, '0')}'),
            ],
          ),
        ],
      );
    });
  }

  Widget _lifeIcons(int life) {
    final int lives = life.clamp(0, 4);
    return LayoutBuilder(builder: (context, constraints) {
      final double baseCell = constraints.maxWidth / BrickGameState.cols;
      final double iconHeight = (baseCell * 1.0).clamp(10.0, 28.0);
      final double side = iconHeight - 2;
      return SizedBox(
        height: iconHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) {
            final bool on = i < lives;
            return CustomPaint(size: Size(side, side), painter: _LifeSquare(on: on));
          }),
        ),
      );
    });
  }
}

class _LifeSquare extends CustomPainter {
  final bool on;
  _LifeSquare({required this.on});
  @override
  void paint(Canvas canvas, Size size) {
    const double gapPx = 1.0;
    const double outerStrokeWidth = 1.0;
    const double innerSizeFactor = 0.6;
    final Rect outer = Rect.fromLTWH(gapPx / 2, gapPx / 2, size.width - gapPx, size.height - gapPx);
    final Paint border = Paint()
      ..color = LcdColors.pixelOn
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStrokeWidth;
    final Paint offPaint = Paint()..color = LcdColors.pixelOff;
    final Paint onPaint = Paint()..color = LcdColors.pixelOn;
    canvas.drawRect(outer, border);
    final Rect inner = Rect.fromLTWH(
      outer.left + outer.width * (1 - innerSizeFactor) / 2,
      outer.top + outer.height * (1 - innerSizeFactor) / 2,
      outer.width * innerSizeFactor,
      outer.height * innerSizeFactor,
    );
    canvas.drawRect(inner, on ? onPaint : offPaint);
  }
  @override
  bool shouldRepaint(covariant _LifeSquare oldDelegate) => oldDelegate.on != on;
}

class _SidePanelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const int rows = BrickGameState.rows;
    final int cols = (BrickGameState.cols / 2).ceil();
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
    Rect contentRect(int c, int r) => Rect.fromLTWH(c * cellWidth + gapPx / 2, r * cellHeight + gapPx / 2, cellWidth - gapPx, cellHeight - gapPx);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final Rect outer = contentRect(c, r);
        canvas.drawRect(outer, borderPaintOff);
        final Rect inner = Rect.fromLTWH(
          outer.left + outer.width * (1 - innerSizeFactor) / 2,
          outer.top + outer.height * (1 - innerSizeFactor) / 2,
          outer.width * innerSizeFactor,
          outer.height * innerSizeFactor,
        );
        canvas.drawRect(inner, offPaint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
