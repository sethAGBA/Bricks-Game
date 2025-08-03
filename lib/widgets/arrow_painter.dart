import 'package:flutter/material.dart';

// Classe pour dessiner la flèche centrale
class ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double distance = 13;
    final double triangleSize = 8;

    // Triangle vers le haut
    _drawTriangle(canvas, center.translate(0, -distance), triangleSize, 0);
    // Triangle vers la droite
    _drawTriangle(canvas, center.translate(distance, 0), triangleSize, 90);
    // Triangle vers le bas
    _drawTriangle(canvas, center.translate(0, distance), triangleSize, 180);
    // Triangle vers la gauche
    _drawTriangle(canvas, center.translate(-distance, 0), triangleSize, 270);
  }

  void _drawTriangle(Canvas canvas, Offset position, double size, double angle) {
    final path = Path();
    path.moveTo(position.dx, position.dy - size / 2);
    path.lineTo(position.dx - size / 2, position.dy + size / 2);
    path.lineTo(position.dx + size / 2, position.dy + size / 2);
    path.close();

    final radians = angle * 3.1415926535 / 180;
    final matrix = Matrix4.identity()
      ..translate(position.dx, position.dy)
      ..rotateZ(radians)
      ..translate(-position.dx, -position.dy);
    canvas.save();
    canvas.transform(matrix.storage);
    canvas.drawPath(path, Paint()..color = Colors.black..style = PaintingStyle.fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
