import 'package:bricks/game/game_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PauseMenuScreen extends StatelessWidget {
  const PauseMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.black.withAlpha((255 * 0.7).round()), // Semi-transparent background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 50),
            _buildMenuButton(
              context,
              'RESUME',
              () {
                gameState.togglePlaying(); // Resume game
                Navigator.pop(context); // Close pause menu
              },
            ),
            const SizedBox(height: 20),
            _buildMenuButton(
              context,
              'RESTART',
              () {
                gameState.startGame(); // Restart game
                Navigator.pop(context); // Close pause menu
              },
            ),
            const SizedBox(height: 20),
            _buildMenuButton(
              context,
              'MAIN MENU',
              () {
                gameState.startGame(); // Reset game state before going to main menu
                Navigator.popUntil(context, (route) => route.isFirst); // Go back to main menu
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey[700],
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}
