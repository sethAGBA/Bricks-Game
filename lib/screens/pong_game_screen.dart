import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:bricks/game/pong/pong_game_state.dart';
import 'package:bricks/game/pong/pong_game_widget.dart';

class PongGameScreen extends StatelessWidget {
  const PongGameScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final gs = Provider.of<PongGameState>(context, listen: false);
    final Map<String, GameButtonCallback> map = {
      GameBoyScreen.btnUp: () => gs.moveUp(),
      GameBoyScreen.btnDown: () => gs.moveDown(),
      GameBoyScreen.btnLeft: null,
      GameBoyScreen.btnRight: null,
      GameBoyScreen.btnRotate: () => gs.togglePlaying(),
      GameBoyScreen.btnPause: () => gs.togglePlaying(),
      GameBoyScreen.btnStart: () => gs.startGame(),
      GameBoyScreen.btnSound: () => gs.toggleSound(),
      GameBoyScreen.btnSettings: () { gs.stop(); Navigator.pop(context); },
    };
    return GameBoyScreen(
      gameContent: const PongGameWidget(),
      onButtonPressed: map,
      shouldAutoRepeat: (b) => b == GameBoyScreen.btnUp || b == GameBoyScreen.btnDown,
    );
  }
}

