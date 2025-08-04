import 'package:flutter/material.dart';
import 'package:bricks/style/app_style.dart';

Widget buildStatText(String text) {
  return Padding(
    padding: EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: TextStyle(
        color: LcdColors.pixelOn,
        fontSize: 10, // Increased font size
        fontWeight: FontWeight.bold,
        fontFamily: 'Digital7', // Apply Digital7 font
      ),
    ),
  );
}

Widget buildStatNumber(String number) {
  return Padding(
    padding: EdgeInsets.only(top: 2),
    child: Text(
      number,
      style: TextStyle(
        color: LcdColors.pixelOn,
        fontSize: 16, // Increased font size
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        fontFamily: 'Digital7', // Apply Digital7 font
      ),
    ),
  );
}
