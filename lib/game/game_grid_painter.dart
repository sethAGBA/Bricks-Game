import 'package:bricks/game/game_state.dart';
import 'package:bricks/game/piece.dart';
import 'package:flutter/material.dart';

class GameGridPainter extends CustomPainter {
  final List<List<Tetromino?>> grid;
  final Piece currentPiece;
  final bool gameOver;
  final bool isAnimatingLineClear;

  GameGridPainter(this.grid, this.currentPiece, this.gameOver, this.isAnimatingLineClear);

  static const Color lcdPixelOn = Color(0xFF3E3B39);
  static const Color lcdPixelOff = Color(0xFFC4C0B3);
  static const Color lcdBackground = Color(0xFFD3CDBF);

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / GameState.cols;
    final double cellHeight = size.height / GameState.rows;

    // Draw background and grid lines
    final Paint backgroundPaint = Paint()..color = lcdBackground;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final Paint borderPaint = Paint()
      ..color = lcdBackground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int row = 0; row < GameState.rows; row++) {
      for (int col = 0; col < GameState.cols; col++) {
        final Rect cellRect = Rect.fromLTWH(
          col * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        );
        canvas.drawRect(cellRect, borderPaint); // Draw grid lines
      }
    }

    // Draw locked pieces
    final Paint pixelOnPaint = Paint()..color = lcdPixelOn;

    for (int row = 0; row < GameState.rows; row++) {
      for (int col = 0; col < GameState.cols; col++) {
        final tetromino = grid[row][col];
        if (tetromino != null) {
          final Rect cellRect = Rect.fromLTWH(
            col * cellWidth,
            row * cellHeight,
            cellWidth,
            cellHeight,
          );
          canvas.drawRect(cellRect, pixelOnPaint);
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
              final Rect cellRect = Rect.fromLTWH(
                pixelCol * cellWidth,
                pixelRow * cellHeight,
                cellWidth,
                cellHeight,
              );
              canvas.drawRect(cellRect, pixelOnPaint);
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
