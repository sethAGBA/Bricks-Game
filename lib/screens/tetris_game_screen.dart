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
      GameBoyScreen.btnUp: () => {},
      GameBoyScreen.btnDown: gameState.moveDown,
      GameBoyScreen.btnLeft: gameState.moveLeft,
      GameBoyScreen.btnRight: gameState.moveRight,
      GameBoyScreen.btnDrop: gameState.hardDrop,
      GameBoyScreen.btnRotate: gameState.rotate,
      GameBoyScreen.btnSound: () => gameState.toggleSound(),
      GameBoyScreen.btnPause: () => gameState.togglePlaying(),
      GameBoyScreen.btnStart: () => gameState.startGame(),
      GameBoyScreen.btnSettings: () => Navigator.pop(context),
    };
    return GameBoyScreen(
      gameContent: BricksGameContent(),
      onButtonPressed: buttonCallbacks,
    );
  }
}
