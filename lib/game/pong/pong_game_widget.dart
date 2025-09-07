import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/style/app_style.dart';
import 'package:bricks/widgets/game_stats_widgets.dart';
import 'package:bricks/game/pong/pong_game_state.dart';

class PongGameWidget extends StatelessWidget {
  const PongGameWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 3)),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOff, width: 2), color: LcdColors.background),
        child: Row(children: [
          Expanded(flex: 2, child: Container(decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 1)), child: const _PongBoard())),
          Container(width: 2, color: LcdColors.pixelOn, margin: const EdgeInsets.symmetric(horizontal: 4)),
          Expanded(flex: 1, child: Container(decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 1)), child: const _PongStats())),
        ]),
      ),
    );
  }
}

class _PongBoard extends StatelessWidget {
  const _PongBoard();
  @override
  Widget build(BuildContext context) {
    return Consumer<PongGameState>(builder: (context, gs, _) => CustomPaint(painter: _PongPainter(gs), child: Container()));
  }
}

class _PongPainter extends CustomPainter {
  final PongGameState gs;
  const _PongPainter(this.gs);
  @override
  void paint(Canvas canvas, Size size) {
    final double cellW = size.width / PongGameState.cols;
    final double cellH = size.height / PongGameState.rows;
    final Paint bg = Paint()..color = LcdColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
    const double gapPx = 1.0;
    const double outerStrokeWidth = 1.0;
    const double innerSizeFactor = 0.6;
    final Paint offPaint = Paint()..color = LcdColors.pixelOff;
    final Paint borderOff = Paint()..color = LcdColors.pixelOff..style = PaintingStyle.stroke..strokeWidth = outerStrokeWidth;
    Rect rcell(int c, int r) => Rect.fromLTWH(c * cellW + gapPx / 2, r * cellH + gapPx / 2, cellW - gapPx, cellH - gapPx);
    void drawOff(int c, int r) {
      final ro = rcell(c, r);
      canvas.drawRect(ro, borderOff);
      final Rect ri = Rect.fromLTWH(ro.left + ro.width * (1 - innerSizeFactor) / 2, ro.top + ro.height * (1 - innerSizeFactor) / 2, ro.width * innerSizeFactor, ro.height * innerSizeFactor);
      canvas.drawRect(ri, offPaint);
    }
    void drawOn(int c, int r, Color color) {
      if (c < 0 || c >= PongGameState.cols || r < 0 || r >= PongGameState.rows) return;
      final ro = rcell(c, r);
      final Paint borderOn = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = outerStrokeWidth;
      final Paint onPaint = Paint()..color = Color.alphaBlend(LcdColors.background.withOpacity(0.2), color);
      canvas.drawRect(ro, borderOn);
      final Rect ri = Rect.fromLTWH(ro.left + ro.width * (1 - innerSizeFactor) / 2, ro.top + ro.height * (1 - innerSizeFactor) / 2, ro.width * innerSizeFactor, ro.height * innerSizeFactor);
      canvas.drawRect(ri, onPaint);
    }

    for (int r = 0; r < PongGameState.rows; r++) { for (int c = 0; c < PongGameState.cols; c++) { drawOff(c, r); } }

    // Draw paddles (3 tiles tall)
    for (int dy = -1; dy <= 1; dy++) { drawOn(1, (gs.paddleY + dy).clamp(0, PongGameState.rows - 1), const Color(0xFF1E88E5)); }
    for (int dy = -1; dy <= 1; dy++) { drawOn(PongGameState.cols - 2, (gs.aiPaddleY + dy).clamp(0, PongGameState.rows - 1), const Color(0xFFE53935)); }
    // Draw ball
    drawOn(gs.ball.x, gs.ball.y, const Color(0xFFF44336));

    // Sparks
    for (final s in gs.sparks) {
      final int r = (s.frame / 2).clamp(0, 3).toInt();
      for (int dx = -r; dx <= r; dx++) {
        for (int dy = -r; dy <= r; dy++) {
          if ((dx.abs() == r || dy.abs() == r)) {
            drawOn((s.pos.x + dx).clamp(0, PongGameState.cols - 1), (s.pos.y + dy).clamp(0, PongGameState.rows - 1), const Color(0xFFFFEE58));
          }
        }
      }
    }

    // Game over rings + text
    if (gs.gameOver && gs.gameOverAnimFrame > 0) {
      final int rings = (gs.gameOverAnimFrame / 2).clamp(1, 12).toInt();
      for (int r = 0; r < rings; r++) {
        final Color col = r < 4 ? const Color(0xFFFFEB3B) : (r < 8 ? const Color(0xFFFF9800) : const Color(0xFFF44336));
        for (int x = r; x < PongGameState.cols - r; x++) {
          drawOn(x, r, col); drawOn(x, PongGameState.rows - 1 - r, col);
        }
        for (int y = r; y < PongGameState.rows - r; y++) {
          drawOn(r, y, col); drawOn(PongGameState.cols - 1 - r, y, col);
        }
      }
      final tp = TextPainter(text: const TextSpan(text: 'GAME OVER', style: TextStyle(color: Colors.red, fontSize: 22, fontFamily: 'Digital7')), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    }
  }
  @override
  bool shouldRepaint(covariant _PongPainter oldDelegate) => oldDelegate.gs != gs;
}

class _PongStats extends StatelessWidget {
  const _PongStats();
  @override
  Widget build(BuildContext context) {
    return Consumer<PongGameState>(builder: (context, gs, _) {
      return Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _SidePanelGridPainter())),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          buildStatText('PLAYER'), buildStatNumber(gs.score.toString().padLeft(5, '0')),
          const SizedBox(height: 6), buildStatText('CPU'), buildStatNumber(gs.aiScore.toString().padLeft(5, '0')),
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
      final double baseCell = constraints.maxWidth / PongGameState.cols;
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
    const int rows = PongGameState.rows; final int cols = (PongGameState.cols / 2).ceil();
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
