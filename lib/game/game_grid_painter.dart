import 'package:bricks/game/game_state.dart';
import 'package:bricks/game/piece.dart';
import 'package:bricks/style/app_style.dart';
import 'package:flutter/material.dart';

class GameGridPainter extends CustomPainter {
  final List<List<Tetromino?>> grid;
  final Piece currentPiece;
  final bool gameOver;
  final bool isAnimatingLineClear;

  GameGridPainter(this.grid, this.currentPiece, this.gameOver, this.isAnimatingLineClear);

  static const Color lcdBackground = LcdColors.background;

  // BrickPanel-like rendering: outer square + inner dot
  static const double gapPx = 1.0; // emulate GridLayout hgap/vgap = 1
  static const double outerStrokeWidth = 1.0;
  static const double outerSizeFactor = 1.0; // full cell (minus gap)
  static const double innerSizeFactor = 0.6; // inner square ratio; used by menu/preview too

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / GameState.cols;
    final double cellHeight = size.height / GameState.rows;

    // Draw background
    final Paint backgroundPaint = Paint()..color = lcdBackground;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final Paint offPaint = Paint()..color = LcdColors.pixelOff;
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

    void drawOffCell(int col, int row) {
      final Rect outer = cellContentRect(col, row);
      canvas.drawRect(outer, borderPaintOff);
      final double innerW = outer.width * innerSizeFactor;
      final double innerH = outer.height * innerSizeFactor;
      final double innerOffsetFactor = (1.0 - innerSizeFactor) / 2.0;
      final Rect inner = Rect.fromLTWH(
        outer.left + outer.width * innerOffsetFactor,
        outer.top + outer.height * innerOffsetFactor,
        innerW,
        innerH,
      );
      canvas.drawRect(inner, offPaint);
    }

    void drawOnCell(int col, int row, Color color) {
      final Rect outer = cellContentRect(col, row);
      final Paint borderPaintOn = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStrokeWidth;
      // Slightly blend toward LCD background to keep vivid yet readable
      final Color blendedFill = Color.alphaBlend(LcdColors.background.withOpacity(0.20), color);
      final Paint onPaint = Paint()..color = blendedFill;
      canvas.drawRect(outer, borderPaintOn);
      final double innerW = outer.width * innerSizeFactor;
      final double innerH = outer.height * innerSizeFactor;
      final double innerOffsetFactor = (1.0 - innerSizeFactor) / 2.0;
      final Rect inner = Rect.fromLTWH(
        outer.left + outer.width * innerOffsetFactor,
        outer.top + outer.height * innerOffsetFactor,
        innerW,
        innerH,
      );
      canvas.drawRect(inner, onPaint);
    }

    // First, draw all cells in OFF state
    for (int row = 0; row < GameState.rows; row++) {
      for (int col = 0; col < GameState.cols; col++) {
        drawOffCell(col, row);
      }
    }

    // Then overlay locked ON cells
    for (int row = 0; row < GameState.rows; row++) {
      for (int col = 0; col < GameState.cols; col++) {
        final tetro = grid[row][col];
        if (tetro != null) {
          drawOnCell(col, row, TetrominoPalette.colorFor(tetro));
        }
      }
    }

    // Draw current piece
    if (!gameOver && !isAnimatingLineClear) {
      for (int i = 0; i < currentPiece.shape.length; i++) {
        for (int j = 0; j < currentPiece.shape[i].length; j++) {
          if (currentPiece.shape[i][j] == 1) {
            final int pixelRow = currentPiece.position.y + i;
            final int pixelCol = currentPiece.position.x + j;

            if (pixelRow >= 0 && pixelRow < GameState.rows &&
                pixelCol >= 0 && pixelCol < GameState.cols) {
              drawOnCell(pixelCol, pixelRow, TetrominoPalette.colorFor(currentPiece.type));
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GameGridPainter oldDelegate) {
    // Only repaint if the grid, current piece, or game state changes
    return oldDelegate.grid != grid ||
        oldDelegate.currentPiece != currentPiece ||
        oldDelegate.gameOver != gameOver ||
        oldDelegate.isAnimatingLineClear != isAnimatingLineClear;
  }
}
