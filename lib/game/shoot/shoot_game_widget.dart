import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/style/app_style.dart';
import 'package:bricks/game/shoot/shoot_game_state.dart';
import 'package:bricks/widgets/game_stats_widgets.dart';

class ShootGameWidget extends StatelessWidget {
  const ShootGameWidget({super.key});

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
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: LcdColors.pixelOn, width: 1),
                ),
                child: const _ShootBoard(),
              ),
            ),
            Container(width: 2, color: LcdColors.pixelOn, margin: const EdgeInsets.symmetric(horizontal: 4)),
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: LcdColors.pixelOn, width: 1),
                ),
                child: const _ShootStats(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShootBoard extends StatelessWidget {
  const _ShootBoard();

  @override
  Widget build(BuildContext context) {
    return Consumer<ShootGameState>(
      builder: (context, gs, _) {
        return CustomPaint(
          painter: _ShootPainter(gs),
          child: Container(),
        );
      },
    );
  }
}

class _ShootPainter extends CustomPainter {
  final ShootGameState gs;
  _ShootPainter(this.gs);

  @override
  void paint(Canvas canvas, Size size) {
    final double cellW = size.width / ShootGameState.cols;
    final double cellH = size.height / ShootGameState.rows;
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
          c * cellW + gapPx / 2,
          r * cellH + gapPx / 2,
          cellW - gapPx,
          cellH - gapPx,
        );

    // Draw all OFF
    for (int r = 0; r < ShootGameState.rows; r++) {
      for (int c = 0; c < ShootGameState.cols; c++) {
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

    void drawOn(int x, int y, Color color) {
      if (x < 0 || x >= ShootGameState.cols || y < 0 || y >= ShootGameState.rows) return;
      final Rect outer = contentRect(x, y);
      final Paint borderOn = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStrokeWidth;
      final Color fill = Color.alphaBlend(LcdColors.background.withOpacity(0.2), color);
      final Paint onPaint = Paint()..color = fill;
      canvas.drawRect(outer, borderOn);
      final double innerW = outer.width * innerSizeFactor;
      final double innerH = outer.height * innerSizeFactor;
      final double innerOffset = (1.0 - innerSizeFactor) / 2.0;
      final Rect inner = Rect.fromLTWH(
        outer.left + outer.width * innerOffset,
        outer.top + outer.height * innerOffset,
        innerW,
        innerH,
      );
      canvas.drawRect(inner, onPaint);
    }

    // Draw army (falling points): purple
    for (final a in gs.army) { drawOn(a.x, a.y, const Color(0xFF9C27B0)); }

    // Draw player shots: red
    for (final s in gs.shots) {
      drawOn(s.x, s.y, const Color(0xFFF44336));
    }
    // Draw falling power-ups: green
    for (final p in gs.powerUps) {
      drawOn(p.pos.x, p.pos.y, const Color(0xFF4CAF50));
    }
    // Draw enemy shots: orange
    for (final s in gs.enemyShots) {
      drawOn(s.x, s.y, const Color(0xFFFFA726));
    }

    // Draw gun: single pixel at bottom row (Java-like), only when not fully ended
    final int gy = ShootGameState.rows - 1;
    if (!gs.gameOver || gs.gameOverAnimFrame < 6) {
      drawOn(gs.gunX, gy, const Color(0xFF1E88E5));
    }

    // Draw explosions (expanding rings)
    for (final e in gs.explosions) {
      final int r = e.frame; // 0..6
      Color col;
      if (r <= 1) {
        col = const Color(0xFFFFEB3B); // yellow
      } else if (r <= 3) {
        col = const Color(0xFFFF9800); // orange
      } else {
        col = const Color(0xFFF44336); // red
      }
      for (int dx = -r; dx <= r; dx++) {
        for (int dy = -r; dy <= r; dy++) {
          final bool onPerimeter = (dx.abs() == r || dy.abs() == r);
          if (!onPerimeter) continue;
          if (r >= 3 && ((dx + dy) % 2 != 0)) continue; // downsample outer ring
          final int x = e.pos.x + dx;
          final int y = e.pos.y + dy;
          drawOn(x, y, col);
        }
      }
    }

    // End-of-game animation: closing rings from edges inward
    if (gs.gameOver && gs.gameOverAnimFrame > 0) {
      final int f = gs.gameOverAnimFrame; // 1..24
      // Compute ring thickness and steps
      final int rings = (f / 2).clamp(1, 12).toInt();
      for (int r = 0; r < rings; r++) {
        final int inset = r;
        final Color col = r < 4
            ? const Color(0xFFFFEB3B)
            : (r < 8 ? const Color(0xFFFF9800) : const Color(0xFFF44336));
        // Top and bottom rows
        for (int x = inset; x < ShootGameState.cols - inset; x++) {
          drawOn(x, inset, col);
          drawOn(x, ShootGameState.rows - 1 - inset, col);
        }
        // Left and right columns
        for (int y = inset; y < ShootGameState.rows - inset; y++) {
          drawOn(inset, y, col);
          drawOn(ShootGameState.cols - 1 - inset, y, col);
        }
      }
      // Overlay GAME OVER text after some frames
      if (f > 10) {
        final textPainter = TextPainter(
          text: const TextSpan(
            text: 'GAME OVER',
            style: TextStyle(
              color: Colors.red,
              fontSize: 22,
              fontFamily: 'Digital7',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShootPainter oldDelegate) => oldDelegate.gs != gs;
}

class _ShootStats extends StatelessWidget {
  const _ShootStats();

  @override
  Widget build(BuildContext context) {
    return Consumer<ShootGameState>(builder: (context, gs, _) {
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SidePanelGridPainter(),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildStatText('Score'),
              buildStatNumber(gs.score.toString().padLeft(5, '0')),
              const SizedBox(height: 10),
              buildStatText('Level'),
              buildStatNumber(gs.level.toString()),
              const SizedBox(height: 10),
              buildStatText('POWER'),
              _powerIndicator(gs),
              const SizedBox(height: 10),
              buildStatText('HIGH SCORE'),
              buildStatNumber(gs.highScore.toString().padLeft(5, '0')),
              const SizedBox(height: 10),
              buildStatText('LIFE'),
              _lifeIcons(gs.life),
              const SizedBox(height: 10),
              buildStatText('TIME'),
              buildStatNumber('${gs.elapsedSeconds ~/ 60}:${(gs.elapsedSeconds % 60).toString().padLeft(2, '0')}'),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(gs.soundOn ? Icons.volume_up : Icons.volume_off, size: 12, color: LcdColors.pixelOn),
                  const SizedBox(width: 6),
                  Row(
                    children: List.generate(3, (i) => Container(
                          width: 4,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: i < gs.volume ? LcdColors.pixelOn : LcdColors.pixelOn.withAlpha((255 * 0.3).round()),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        )),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _lifeIcons(int life) {
    final int lives = life.clamp(0, 4);
    return LayoutBuilder(builder: (context, constraints) {
      final double baseCell = constraints.maxWidth / ShootGameState.cols;
      final double iconHeight = (baseCell * 1.0).clamp(10.0, 28.0);
      final double side = iconHeight - 2; // small padding
      return SizedBox(
        height: iconHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) {
            final bool on = i < lives;
            return CustomPaint(
              size: Size(side, side),
              painter: _LifeSquare(on: on),
            );
          }),
        ),
      );
    });
  }
}

Widget _powerIndicator(ShootGameState gs) {
  if (!gs.pierceActive) {
    return buildStatNumber('--');
  }
  final ticks = gs.pierceRemainingTicks;
  // Convert rough ticks to seconds estimate based on default loop pacing
  final secs = (ticks * 0.3).ceil();
  return buildStatNumber('PIERCE ${secs}s');
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
  @override
  bool shouldRepaint(covariant _LifeSquare oldDelegate) => oldDelegate.on != on;
}

class _SidePanelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const int rows = ShootGameState.rows;
    final int cols = (ShootGameState.cols / 2).ceil();
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
