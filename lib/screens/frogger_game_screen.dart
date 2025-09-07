import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:bricks/game/frogger/frogger_game_state.dart';
import 'package:bricks/game/frogger/frogger_game_widget.dart';

class FroggerGameScreen extends StatelessWidget {
  const FroggerGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = Provider.of<FroggerGameState>(context, listen: false);
    final Map<String, GameButtonCallback> buttonCallbacks = {
      GameBoyScreen.btnUp: () => gs.moveUp(),
      GameBoyScreen.btnDown: () => gs.moveDown(),
      GameBoyScreen.btnLeft: () => gs.moveLeft(),
      GameBoyScreen.btnRight: () => gs.moveRight(),
      GameBoyScreen.btnRotate: () => gs.togglePlaying(),
      GameBoyScreen.btnPause: () => gs.togglePlaying(),
      GameBoyScreen.btnStart: () => gs.startGame(),
      GameBoyScreen.btnSound: () => gs.toggleSound(),
      GameBoyScreen.btnSettings: () { gs.stop(); Navigator.pop(context); },
    };
    return GameBoyScreen(
      gameContent: const FroggerGameWidget(),
      onButtonPressed: buttonCallbacks,
    );
  }
}
