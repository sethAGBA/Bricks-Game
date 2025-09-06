import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/style/app_style.dart';
import 'package:bricks/game/tanks/tanks_game_state.dart';
import 'package:bricks/widgets/game_stats_widgets.dart';

class TanksGameWidget extends StatelessWidget {
  const TanksGameWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 3)),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOff, width: 2), color: LcdColors.background),
        child: Row(children: [
          Expanded(flex: 2, child: Container(decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 1)), child: const _TanksBoard())),
          Container(width: 2, color: LcdColors.pixelOn, margin: const EdgeInsets.symmetric(horizontal: 4)),
          const Expanded(flex: 1, child: _TanksStats()),
        ]),
      ),
    );
  }
}

class _TanksBoard extends StatelessWidget {
  const _TanksBoard();
  @override
  Widget build(BuildContext context) {
    return Consumer<TanksGameState>(builder: (context, gs, _) => CustomPaint(painter: _TanksPainter(gs), child: Container()));
  }
}

class _TanksPainter extends CustomPainter {
  final TanksGameState gs;
  _TanksPainter(this.gs);
  @override
  void paint(Canvas canvas, Size size) {
    final double cellW = size.width / TanksGameState.cols;
    final double cellH = size.height / TanksGameState.rows;
    final Paint bg = Paint()..color = LcdColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
    const double gapPx = 1.0;
    const double outerStrokeWidth = 1.0;
    const double innerSizeFactor = 0.6;
    final Paint off = Paint()..color = LcdColors.pixelOff;
    final Paint borderOff = Paint()
      ..color = LcdColors.pixelOff
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStrokeWidth;
    Rect rcell(int c, int r) => Rect.fromLTWH(c * cellW + gapPx / 2, r * cellH + gapPx / 2, cellW - gapPx, cellH - gapPx);
    void drawOff(int c, int r) {
      final ro = rcell(c, r);
      canvas.drawRect(ro, borderOff);
      final Rect ri = Rect.fromLTWH(ro.left + ro.width * (1 - innerSizeFactor) / 2, ro.top + ro.height * (1 - innerSizeFactor) / 2, ro.width * innerSizeFactor, ro.height * innerSizeFactor);
      canvas.drawRect(ri, off);
    }
    void drawOn(int c, int r, Color color) {
      if (c < 0 || c >= TanksGameState.cols || r < 0 || r >= TanksGameState.rows) return;
      final ro = rcell(c, r);
      final border = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStrokeWidth;
      final fill = Paint()..color = Color.alphaBlend(LcdColors.background.withOpacity(0.2), color);
      canvas.drawRect(ro, border);
      final Rect ri = Rect.fromLTWH(ro.left + ro.width * (1 - innerSizeFactor) / 2, ro.top + ro.height * (1 - innerSizeFactor) / 2, ro.width * innerSizeFactor, ro.height * innerSizeFactor);
      canvas.drawRect(ri, fill);
    }
    for (int r = 0; r < TanksGameState.rows; r++) {
      for (int c = 0; c < TanksGameState.cols; c++) {
        drawOff(c, r);
      }
    }
    for (final w in gs.walls) { drawOn(w.x, w.y, const Color(0xFF795548)); }
    void drawTank(Point<int> topLeft, Dir dir, Color color) {
      // 3x3 masks from Java STATES by direction order: UP, RIGHT, DOWN, LEFT
      List<int> rows;
      switch (dir) {
        case Dir.up: rows = [0x2, 0x7, 0x5]; break;      // 010,111,101
        case Dir.right: rows = [0x6, 0x3, 0x6]; break;   // 110,011,110
        case Dir.down: rows = [0x5, 0x7, 0x2]; break;    // 101,111,010
        case Dir.left: rows = [0x3, 0x6, 0x3]; break;    // 011,110,011
      }
      for (int ry = 0; ry < 3; ry++) {
        for (int rx = 0; rx < 3; rx++) {
          if (((rows[ry] >> (2 - rx)) & 1) == 1) {
            drawOn(topLeft.x + rx, topLeft.y + ry, color);
          }
        }
      }
    }

    // Player tank (use pos as top-left, to match Java rendering)
    drawTank(gs.player.pos, gs.player.dir, const Color(0xFF1E88E5));
    // Enemies
    for (final e in gs.enemies) {
      drawTank(e.pos, e.dir, const Color(0xFFE53935));
    }
    // Bullets
    for (final b in gs.bullets) { drawOn(b.pos.x, b.pos.y, const Color(0xFFF44336)); }
    for (final b in gs.enemyBullets) { drawOn(b.pos.x, b.pos.y, const Color(0xFFFFA726)); }
    // Power-ups: shield (cyan), rapid (purple)
    for (final p in gs.powerUps) {
      final color = p.kind == TankPowerUpKind.shield ? const Color(0xFF00BCD4) : const Color(0xFF9C27B0);
      drawOn(p.pos.x, p.pos.y, color);
    }
    // Effects icons on player (center pixel): shield cyan, rapid purple
    final int pcx = gs.player.pos.x + 1;
    final int pcy = gs.player.pos.y + 1;
    if (gs.shieldActive) drawOn(pcx, pcy, const Color(0xFF00BCD4));
    if (gs.rapidActive) drawOn(pcx, pcy, const Color(0xFF9C27B0));

    // Impacts (short rings)
    for (final im in gs.impacts) {
      final int r = im.frame; // expand radius by frame
      final Color col = r <= 2 ? const Color(0xFFFFEB3B) : const Color(0xFFFF9800);
      for (int dx = -r; dx <= r; dx++) {
        for (int dy = -r; dy <= r; dy++) {
          final bool edge = (dx.abs() == r || dy.abs() == r);
          if (!edge) continue;
          drawOn(im.pos.x + dx, im.pos.y + dy, col);
        }
      }
    }

    // Game over rings
    if (gs.gameOver && gs.gameOverAnimFrame > 0) {
      final int rings = (gs.gameOverAnimFrame / 2).clamp(1, 12).toInt();
      for (int rr = 0; rr < rings; rr++) {
        final Color col = rr < 4 ? const Color(0xFFFFEB3B) : (rr < 8 ? const Color(0xFFFF9800) : const Color(0xFFF44336));
        for (int x = rr; x < TanksGameState.cols - rr; x++) {
          drawOn(x, rr, col); drawOn(x, TanksGameState.rows - 1 - rr, col);
        }
        for (int y = rr; y < TanksGameState.rows - rr; y++) {
          drawOn(rr, y, col); drawOn(TanksGameState.cols - 1 - rr, y, col);
        }
      }
      final tp = TextPainter(text: const TextSpan(text: 'GAME OVER', style: TextStyle(color: Colors.red, fontSize: 22, fontFamily: 'Digital7')), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    }
  }
  @override
  bool shouldRepaint(covariant _TanksPainter oldDelegate) => oldDelegate.gs != gs;
}

class _TanksStats extends StatelessWidget {
  const _TanksStats();
  @override
  Widget build(BuildContext context) {
    return Consumer<TanksGameState>(builder: (context, gs, _) {
      return Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _SidePanelGridPainter())),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          buildStatText('Score'), buildStatNumber(gs.score.toString().padLeft(5, '0')),
          const SizedBox(height: 10), buildStatText('Level'), buildStatNumber(gs.level.toString()),
          const SizedBox(height: 10), buildStatText('HIGH SCORE'), buildStatNumber(gs.highScore.toString().padLeft(5, '0')),
          const SizedBox(height: 10), buildStatText('LIFE'), _lifeIcons(gs.life),
          const SizedBox(height: 10), buildStatText('TIME'), buildStatNumber('${gs.elapsedSeconds ~/ 60}:${(gs.elapsedSeconds % 60).toString().padLeft(2, '0')}'),
          const SizedBox(height: 8),
          _effectsRow(gs),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(gs.soundOn ? Icons.volume_up : Icons.volume_off, size: 12, color: LcdColors.pixelOn),
            const SizedBox(width: 6),
            Row(children: List.generate(3, (i) => Container(width: 4, height: 8, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: i < gs.volume ? LcdColors.pixelOn : LcdColors.pixelOn.withAlpha((255 * 0.3).round()), borderRadius: BorderRadius.circular(1))))),
            const SizedBox(width: 10),
            GestureDetector(onTap: gs.togglePlaying, child: Icon(gs.playing ? Icons.pause : Icons.play_arrow, size: 12, color: LcdColors.pixelOn)),
          ]),
        ])
      ]);
    });
  }

  Widget _lifeIcons(int life) {
    final int lives = life.clamp(0, 4);
    return LayoutBuilder(builder: (context, constraints) {
      final double baseCell = constraints.maxWidth / TanksGameState.cols;
      final double iconH = (baseCell * 1.0).clamp(10.0, 28.0);
      final double side = iconH - 2;
      return SizedBox(height: iconH, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(4, (i) => CustomPaint(size: Size(side, side), painter: _LifeSquare(on: i < lives)))));
    });
  }

  Widget _effectsRow(TanksGameState gs) {
    final chips = <Widget>[];
    void addChip(String label) {
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(border: Border.all(color: LcdColors.pixelOn, width: 1)),
        child: Text(label, style: const TextStyle(color: LcdColors.pixelOn, fontFamily: 'Digital7', fontSize: 10, fontWeight: FontWeight.bold)),
      ));
    }
    if (gs.shieldActive) addChip('SHLD ${gs.shieldRemainingSeconds}s');
    if (gs.rapidActive) addChip('RAPD ${gs.rapidRemainingSeconds}s');
    if (chips.isEmpty) return const SizedBox(height: 0);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: chips);
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
    const int rows = TanksGameState.rows; final int cols = (TanksGameState.cols / 2).ceil();
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
