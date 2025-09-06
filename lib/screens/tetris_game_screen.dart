import 'package:bricks/game/game_state.dart';
import 'package:bricks/screens/bricks_game_content.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TetrisGameScreen extends StatelessWidget {
  const TetrisGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context, listen: false);
    final Map<String, GameButtonCallback> buttonCallbacks = {
      // Only START launches the game. Movement actions affect only if playing.
      GameBoyScreen.btnUp: () { if (gameState.playing) gameState.rotate(); },
      GameBoyScreen.btnDown: () { if (gameState.playing) gameState.moveDown(); },
      GameBoyScreen.btnLeft: () { if (gameState.playing) gameState.moveLeft(); },
      GameBoyScreen.btnRight: () { if (gameState.playing) gameState.moveRight(); },
      GameBoyScreen.btnDrop: () { if (gameState.playing) gameState.hardDrop(); },
      GameBoyScreen.btnRotate: () { if (gameState.playing) gameState.rotate(); },
      GameBoyScreen.btnSound: () => gameState.toggleSound(),
      GameBoyScreen.btnPause: () => gameState.togglePlaying(),
      GameBoyScreen.btnStart: () => gameState.startGame(),
      GameBoyScreen.btnSettings: () { gameState.stop(); Navigator.pop(context); },
    };
    return GameBoyScreen(
      gameContent: BricksGameContent(),
      onButtonPressed: buttonCallbacks,
      shouldAutoRepeat: (btn) => btn == GameBoyScreen.btnLeft || btn == GameBoyScreen.btnRight || btn == GameBoyScreen.btnDown,
      autoRepeatDelay: const Duration(milliseconds: 140), // faster DAS for tetris
      autoRepeatInterval: const Duration(milliseconds: 40), // fast ARR
    );
  }
}
