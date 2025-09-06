import 'package:flutter/material.dart';
import 'package:bricks/game/piece.dart';

class LcdColors {
  static const Color pixelOn = Color(0xFF3E3B39);
  static const Color pixelOff = Color(0xFFC4C0B3);
  static const Color background = Color(0xFFD3CDBF);
  // static const Color background = Color.fromARGB(255, 5, 230, 117);
}

class TetrominoPalette {
  // Vivid hues for strong readability
  static const Map<Tetromino, Color> colors = {
    Tetromino.I: Color(0xFF2196F3), // blue
    Tetromino.O: Color(0xFF1976D2), // dark blue
    Tetromino.T: Color(0xFF9C27B0), // purple
    Tetromino.S: Color(0xFF1B5E20), // dark green
    Tetromino.Z: Color(0xFFF44336), // red
    Tetromino.L: Color(0xFFBF360C), // deep orange
    Tetromino.J: Color(0xFF3F51B5), // indigo
  };

  static Color colorFor(Tetromino type) => colors[type] ?? LcdColors.pixelOn;
}
