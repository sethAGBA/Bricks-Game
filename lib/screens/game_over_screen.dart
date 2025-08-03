import 'package:bricks/game/game_state.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GameOverScreen extends StatelessWidget {
  final int finalScore;
  final int highScore;

  const GameOverScreen({super.key, required this.finalScore, required this.highScore});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD700),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 40,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'SCORE: ${finalScore.toString().padLeft(5, '0')}',
              style: const TextStyle(
                fontFamily: 'Digital7',
                fontSize: 30,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'HIGH SCORE: ${highScore.toString().padLeft(5, '0')}',
              style: const TextStyle(
                fontFamily: 'Digital7',
                fontSize: 30,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                // Reset game state and start new game
                Provider.of<GameState>(context, listen: false).startGame();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const GameBoyScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700],
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'REPLAY',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Reset game state and go to main menu
                Provider.of<GameState>(context, listen: false).startGame(); // Reset state before going to menu
                Navigator.popUntil(context, (route) => route.isFirst); // Go back to main menu
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700],
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'MAIN MENU',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
