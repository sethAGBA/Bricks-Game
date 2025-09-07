import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/style/app_style.dart';
import 'package:bricks/game/frogger/frogger_game_state.dart';
import 'package:bricks/widgets/game_stats_widgets.dart';

class FroggerGameWidget extends StatelessWidget {
  const FroggerGameWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 3)),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOff, width: 2), color: LcdColors.background),
        child: Row(children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 1)),
              child: const _FroggerBoard(),
            ),
          ),
          Container(width: 2, color: LcdColors.pixelOn, margin: const EdgeInsets.symmetric(horizontal: 4)),
          Expanded(flex: 1, child: Container(decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 1)), child: const _FroggerStats())),
        ]),
      ),
    );
  }
}

class _FroggerBoard extends StatelessWidget {
  const _FroggerBoard();
  @override
  Widget build(BuildContext context) {
    return Consumer<FroggerGameState>(builder: (context, gs, _) => CustomPaint(painter: _FroggerPainter(gs), child: Container()));
  }
}

class _FroggerPainter extends CustomPainter {
  final FroggerGameState gs;
  _FroggerPainter(this.gs);

  @override
  void paint(Canvas canvas, Size size) {
    final double cellW = size.width / FroggerGameState.cols;
    final double cellH = size.height / FroggerGameState.rows;
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
    Rect rcell(int c, int r) => Rect.fromLTWH(c * cellW + gapPx / 2, r * cellH + gapPx / 2, cellW - gapPx, cellH - gapPx);
    void drawOff(int c, int r) {
      final ro = rcell(c, r);
      canvas.drawRect(ro, borderOff);
      final Rect ri = Rect.fromLTWH(ro.left + ro.width * (1 - innerSizeFactor) / 2, ro.top + ro.height * (1 - innerSizeFactor) / 2, ro.width * innerSizeFactor, ro.height * innerSizeFactor);
      canvas.drawRect(ri, offPaint);
    }
    void drawOn(int c, int r, Color color) {
      if (c < 0 || c >= FroggerGameState.cols || r < 0 || r >= FroggerGameState.rows) return;
      final ro = rcell(c, r);
      final Paint borderOn = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStrokeWidth;
      final Paint onPaint = Paint()..color = Color.alphaBlend(LcdColors.background.withOpacity(0.2), color);
      canvas.drawRect(ro, borderOn);
      final Rect ri = Rect.fromLTWH(ro.left + ro.width * (1 - innerSizeFactor) / 2, ro.top + ro.height * (1 - innerSizeFactor) / 2, ro.width * innerSizeFactor, ro.height * innerSizeFactor);
      canvas.drawRect(ri, onPaint);
    }

    for (int r = 0; r < FroggerGameState.rows; r++) {
      for (int c = 0; c < FroggerGameState.cols; c++) {
        drawOff(c, r);
      }
    }

    // Draw water logs (brown)
    for (final l in gs.logs) {
      for (int i = 0; i < l.len; i++) {
        drawOn(l.pos.x + i, l.pos.y, const Color(0xFF795548));
      }
    }
    // Draw cars and trucks (red); trucks occupy multiple cells
    for (final c in gs.cars) {
      final int step = (c.dir > 0) ? 1 : -1;
      for (int i = 0; i < c.len; i++) {
        drawOn(c.pos.x + i * step, c.pos.y, const Color(0xFFE53935));
      }
    }
    // Draw goals (green): filled vs empty
    for (int i = 0; i < gs.filledGoals.length; i++) {}
    // For simplicity, mark five goal slots at columns [0,2,4,6,8]
    const List<int> goalXs = [0, 2, 4, 6, 8];
    for (int i = 0; i < goalXs.length; i++) {
      final int x = goalXs[i];
      final bool filled = gs.filledGoals.contains(i);
      drawOn(x, 0, filled ? const Color(0xFF4CAF50) : const Color(0xFF00BCD4));
    }
    // Draw bonuses: life (yellow) and score (magenta)
    for (final b in gs.bonuses) {
      final Color col = (b.kind == BonusKind.life) ? const Color(0xFFFFEB3B) : const Color(0xFF9C27B0);
      drawOn(b.pos.x, b.pos.y, col);
    }
    // Draw player (blue)
    drawOn(gs.player.x, gs.player.y, const Color(0xFF1E88E5));

    // Crash animations
    for (final cr in gs.crashes) {
      final int r = (cr.frame / 2).clamp(0, 6).toInt();
      Color col;
      switch (cr.kind) {
        case CrashKind.vehicle:
          col = const Color(0xFFFF9800); // orange spark
          break;
        case CrashKind.water:
          col = const Color(0xFF00BCD4); // cyan ripple
          break;
        case CrashKind.edge:
          col = const Color(0xFFF44336); // red
          break;
      }
      // Draw a simple ring around the crash pos, growing with frame
      for (int dx = -r; dx <= r; dx++) {
        for (int dy = -r; dy <= r; dy++) {
          final bool edge = (dx.abs() == r || dy.abs() == r);
          if (!edge) continue;
          if (r >= 3 && ((dx + dy) % 2 != 0)) continue; // downsample outer rings
          drawOn(cr.pos.x + dx, cr.pos.y + dy, col);
        }
      }
    }

    // End-of-game animation: closing rings and centered text
    if (gs.gameOver && gs.gameOverAnimFrame > 0) {
      final int rings = (gs.gameOverAnimFrame / 2).clamp(1, 12).toInt();
      for (int r = 0; r < rings; r++) {
        final Color col = r < 4 ? const Color(0xFFFFEB3B) : (r < 8 ? const Color(0xFFFF9800) : const Color(0xFFF44336));
        for (int x = r; x < FroggerGameState.cols - r; x++) {
          drawOn(x, r, col); drawOn(x, FroggerGameState.rows - 1 - r, col);
        }
        for (int y = r; y < FroggerGameState.rows - r; y++) {
          drawOn(r, y, col); drawOn(FroggerGameState.cols - 1 - r, y, col);
        }
      }
      final tp = TextPainter(text: const TextSpan(text: 'GAME OVER', style: TextStyle(color: Colors.red, fontSize: 22, fontFamily: 'Digital7')), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    }
  }
  @override
  bool shouldRepaint(covariant _FroggerPainter oldDelegate) => oldDelegate.gs != gs;
}

class _FroggerStats extends StatelessWidget {
  const _FroggerStats();
  @override
  Widget build(BuildContext context) {
    return Consumer<FroggerGameState>(builder: (context, gs, _) {
      return Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _SidePanelGridPainter())),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          buildStatText('Score'), buildStatNumber(gs.score.toString().padLeft(5, '0')),
          const SizedBox(height: 10), buildStatText('Level'), buildStatNumber(gs.level.toString()),
          const SizedBox(height: 10), buildStatText('HIGH SCORE'), buildStatNumber(gs.highScore.toString().padLeft(5, '0')),
          const SizedBox(height: 10), buildStatText('LIFE'), _lifeIcons(gs.life),
          const SizedBox(height: 10), buildStatText('TIME'), buildStatNumber('${gs.elapsedSeconds ~/ 60}:${(gs.elapsedSeconds % 60).toString().padLeft(2, '0')}'),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(gs.soundOn ? Icons.volume_up : Icons.volume_off, size: 12, color: LcdColors.pixelOn),
            const SizedBox(width: 6),
            Row(children: List.generate(3, (i) => Container(width: 4, height: 8, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: i < gs.volume ? LcdColors.pixelOn : LcdColors.pixelOn.withAlpha((255 * 0.3).round()), borderRadius: BorderRadius.circular(1))))),
          ]),
        ])
      ]);
    });
  }

  Widget _lifeIcons(int life) {
    final int lives = life.clamp(0, 4);
    return LayoutBuilder(builder: (context, constraints) {
      final double baseCell = constraints.maxWidth / FroggerGameState.cols;
      final double iconH = (baseCell * 1.0).clamp(10.0, 28.0);
      final double side = iconH - 2;
      return SizedBox(height: iconH, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(4, (i) => CustomPaint(size: Size(side, side), painter: _LifeSquare(on: i < lives)))));
    });
  }
}

class _LifeSquare extends CustomPainter {
  final bool on;
  _LifeSquare({required this.on});
  @override
  void paint(Canvas canvas, Size size) {
    const double gapPx = 1.0; const double os = 1.0; const double inner = 0.6;
    final Rect o = Rect.fromLTWH(gapPx / 2, gapPx / 2, size.width - gapPx, size.height - gapPx);
    final Paint border = Paint()..color = LcdColors.pixelOn..style = PaintingStyle.stroke..strokeWidth = os;
    final Paint off = Paint()..color = LcdColors.pixelOff; final Paint onp = Paint()..color = LcdColors.pixelOn;
    canvas.drawRect(o, border);
    final Rect i = Rect.fromLTWH(o.left + o.width * (1 - inner) / 2, o.top + o.height * (1 - inner) / 2, o.width * inner, o.height * inner);
    canvas.drawRect(i, on ? onp : off);
  }
  @override
  bool shouldRepaint(covariant _LifeSquare old) => old.on != on;
}

class _SidePanelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const int rows = FroggerGameState.rows; final int cols = (FroggerGameState.cols / 2).ceil();
    final double cw = size.width / cols; final double ch = size.height / rows;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = LcdColors.background);
    const double gapPx = 1.0; const double os = 1.0; const double inner = 0.6;
    final Paint off = Paint()..color = LcdColors.pixelOff; final Paint boff = Paint()..color = LcdColors.pixelOff..style = PaintingStyle.stroke..strokeWidth = os;
    Rect cell(int c, int r) => Rect.fromLTWH(c * cw + gapPx / 2, r * ch + gapPx / 2, cw - gapPx, ch - gapPx);
    for (int r = 0; r < rows; r++) { for (int c = 0; c < cols; c++) { final o = cell(c, r); canvas.drawRect(o, boff); final i = Rect.fromLTWH(o.left + o.width * (1 - inner) / 2, o.top + o.height * (1 - inner) / 2, o.width * inner, o.height * inner); canvas.drawRect(i, off);} }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
