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
  static const double innerSizeFactor = 0.6; // make inner square larger

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / GameState.cols;
    final double cellHeight = size.height / GameState.rows;

    // Draw background
    final Paint backgroundPaint = Paint()..color = lcdBackground;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

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

    void drawCell(int col, int row, bool on) {
      final Rect outer = cellContentRect(col, row);
      // outer border
      canvas.drawRect(outer, on ? borderPaintOn : borderPaintOff);

      // inner square centered
      final double innerW = outer.width * innerSizeFactor;
      final double innerH = outer.height * innerSizeFactor;
      final double innerOffsetFactor = (1.0 - innerSizeFactor) / 2.0;
      final double innerX = outer.left + outer.width * innerOffsetFactor;
      final double innerY = outer.top + outer.height * innerOffsetFactor;
      final Rect inner = Rect.fromLTWH(innerX, innerY, innerW, innerH);
      canvas.drawRect(inner, on ? onPaint : offPaint);
    }

    // First, draw all cells in OFF state
    for (int row = 0; row < GameState.rows; row++) {
      for (int col = 0; col < GameState.cols; col++) {
        drawCell(col, row, false);
      }
    }

    // Then overlay locked ON cells
    for (int row = 0; row < GameState.rows; row++) {
      for (int col = 0; col < GameState.cols; col++) {
        if (grid[row][col] != null) {
          drawCell(col, row, true);
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
              drawCell(pixelCol, pixelRow, true);
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
