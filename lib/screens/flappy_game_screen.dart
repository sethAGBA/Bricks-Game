import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:bricks/game/flappy/flappy_game_state.dart';
import 'package:bricks/game/flappy/flappy_game_widget.dart';

class FlappyGameScreen extends StatelessWidget {
  const FlappyGameScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final gs = Provider.of<FlappyGameState>(context, listen: false);
    final Map<String, GameButtonCallback> map = {
      GameBoyScreen.btnUp: () { gs.holdUp(true); gs.moveUp(); },
      GameBoyScreen.btnDown: () { gs.holdDown(true); gs.moveDown(); },
      GameBoyScreen.btnLeft: () => gs.flap(),
      GameBoyScreen.btnRight: () => gs.flap(),
      GameBoyScreen.btnRotate: () => gs.togglePlaying(),
      GameBoyScreen.btnPause: () => gs.togglePlaying(),
      GameBoyScreen.btnStart: () => gs.startGame(),
      GameBoyScreen.btnSound: () => gs.toggleSound(),
      GameBoyScreen.btnSettings: () { gs.stop(); Navigator.pop(context); },
    };
    final Map<String, GameButtonCallback> released = {
      GameBoyScreen.btnUp: () => gs.holdUp(false),
      GameBoyScreen.btnDown: () => gs.holdDown(false),
    };
    return GameBoyScreen(
      gameContent: const FlappyGameWidget(),
      onButtonPressed: map,
      onButtonReleased: released,
      shouldAutoRepeat: (b) => b == GameBoyScreen.btnUp || b == GameBoyScreen.btnDown || b == GameBoyScreen.btnLeft || b == GameBoyScreen.btnRight,
    );
  }
}
