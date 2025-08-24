
import 'package:bricks/game/race/race_game_state.dart';
import 'package:bricks/game/race/race_game_widget.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RaceGameScreen extends StatelessWidget {
  const RaceGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final raceGameState = Provider.of<RaceGameState>(context, listen: false);
    final Map<String, GameButtonCallback?> buttonCallbacks = {
      GameBoyScreen.btnUp: () { if (raceGameState.playing) raceGameState.moveUp(); },
      GameBoyScreen.btnDown: () { if (raceGameState.playing) raceGameState.moveDown(); },
      GameBoyScreen.btnLeft: () { if (raceGameState.playing) raceGameState.moveLeft(); },
      GameBoyScreen.btnRight: () { if (raceGameState.playing) raceGameState.moveRight(); },
  GameBoyScreen.btnDrop: () { if (raceGameState.playing) raceGameState.startEnemyAcceleration(); }, // Big accel for enemies while held
      GameBoyScreen.btnRotate: null, // Or use for something else
      GameBoyScreen.btnSound: () => raceGameState.toggleSound(),
      GameBoyScreen.btnPause: () => raceGameState.togglePlaying(),
      GameBoyScreen.btnStart: () => raceGameState.startGame(),
      GameBoyScreen.btnSettings: () => Navigator.pop(context),
    };

    final Map<String, GameButtonCallback?> buttonReleaseCallbacks = {
      GameBoyScreen.btnUp: () { if (raceGameState.playing) raceGameState.stopAccelerating(); },
      GameBoyScreen.btnDown: () { if (raceGameState.playing) raceGameState.stopDecelerating(); },
      GameBoyScreen.btnDrop: () { if (raceGameState.playing) raceGameState.stopEnemyAcceleration(); },
    };

    return GameBoyScreen(
      gameContent: const Center(
        child: RaceGameWidget(),
      ),
      onButtonPressed: buttonCallbacks,
      onButtonReleased: buttonReleaseCallbacks, // New property
  shouldAutoRepeat: (btn) => btn == GameBoyScreen.btnLeft || btn == GameBoyScreen.btnRight || btn == GameBoyScreen.btnUp || btn == GameBoyScreen.btnDown,
    );
  }
}
