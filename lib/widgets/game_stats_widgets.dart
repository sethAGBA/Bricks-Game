import 'package:flutter/material.dart';
import 'package:bricks/style/app_style.dart';

Widget buildStatText(String text) {
  return Padding(
    padding: EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: TextStyle(
        color: LcdColors.pixelOn,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        fontFamily: 'Digital7',
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
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        fontFamily: 'Digital7',
      ),
    ),
  );
}
