import 'package:bricks/screens/game_boy_screen.dart';
import 'package:flutter/material.dart';

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
                  MaterialPageRoute(builder: (context) => const GameBoyScreen()),
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
          ],
        ),
      ),
    );
  }
}
