import 'package:bricks/screens/snake_game_screen.dart';
import 'package:bricks/screens/tetris_game_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/game/game_state.dart';
import 'package:bricks/game/snake/snake_game_state.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD700), // GameBoy color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'BRICK GAME',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 48,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChangeNotifierProvider.value(
                    value: GameState(),
                    child: const TetrisGameScreen(),
                  )),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700], // Button color
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'START GAME',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20), // Add some space between buttons
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChangeNotifierProvider.value(
                    value: SnakeGameState(),
                    child: const SnakeGameScreen(),
                  )),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700], // Button color
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'PLAY SNAKE',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 24,
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
