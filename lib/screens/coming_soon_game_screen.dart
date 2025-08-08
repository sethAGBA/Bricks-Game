import 'package:flutter/material.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:bricks/style/app_style.dart';

class ComingSoonGameScreen extends StatelessWidget {
  final String title;
  const ComingSoonGameScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final Map<String, GameButtonCallback> callbacks = {
      GameBoyScreen.btnSettings: () => Navigator.pop(context),
    };
    return GameBoyScreen(
      onButtonPressed: callbacks,
      gameContent: Container(
        decoration: BoxDecoration(
          border: Border.all(color: LcdColors.pixelOn, width: 3),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'Digital7',
                  color: LcdColors.pixelOn,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'COMING SOON',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Digital7',
                  color: LcdColors.pixelOn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
