import 'package:bricks/game/snake/snake_game_state.dart';
import 'package:bricks/game/snake/snake_game_widget.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SnakeGameScreen extends StatelessWidget {
  const SnakeGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snakeGameState = Provider.of<SnakeGameState>(context, listen: false);
    final Map<String, GameButtonCallback> buttonCallbacks = {
      GameBoyScreen.btnUp: () => snakeGameState.changeDirection(Direction.up),
      GameBoyScreen.btnDown: () => snakeGameState.changeDirection(Direction.down),
      GameBoyScreen.btnLeft: () => snakeGameState.changeDirection(Direction.left),
      GameBoyScreen.btnRight: () => snakeGameState.changeDirection(Direction.right),
      GameBoyScreen.btnDrop: null, // hide DROP in snake
      GameBoyScreen.btnRotate: () => snakeGameState.toggleAcceleration(), // use ROTATE to accelerate (reduced speed)
      GameBoyScreen.btnSound: () => snakeGameState.toggleSound(),
      GameBoyScreen.btnPause: () => snakeGameState.togglePlaying(),
      GameBoyScreen.btnStart: () => snakeGameState.startGame(),
      GameBoyScreen.btnSettings: () { snakeGameState.stop(); Navigator.pop(context); },
    };
    return GameBoyScreen(
      gameContent: const Center(
        child: SnakeGameWidget(),
      ),
      onButtonPressed: buttonCallbacks,
      // No auto-repeat for Snake; booster taps are sufficient
      shouldAutoRepeat: (_) => false,
      rotateButtonSize: 90, // Bigger ROTATE button for Snake
      dropButtonSize: 60, // Smaller/irrelevant in Snake (hidden)
    );
  }
}
