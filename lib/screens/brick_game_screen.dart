import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:bricks/game/brick/brick_game_state.dart';
import 'package:bricks/game/brick/brick_game_widget.dart';

class BrickGameScreen extends StatelessWidget {
  const BrickGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = Provider.of<BrickGameState>(context, listen: false);
    final Map<String, GameButtonCallback> btns = {
      GameBoyScreen.btnLeft: () { if (gs.playing) gs.moveLeft(); },
      GameBoyScreen.btnRight: () { if (gs.playing) gs.moveRight(); },
      GameBoyScreen.btnRotate: () { if (gs.playing) gs.launchBall(); },
      GameBoyScreen.btnStart: () => gs.startGame(),
      GameBoyScreen.btnPause: () => gs.togglePlaying(),
      GameBoyScreen.btnSound: () => gs.toggleSound(),
      GameBoyScreen.btnSettings: () { gs.stop(); Navigator.pop(context); },
    };
    return GameBoyScreen(
      gameContent: const Center(child: BrickGameWidget()),
      onButtonPressed: btns,
      shouldAutoRepeat: (b) => b == GameBoyScreen.btnLeft || b == GameBoyScreen.btnRight,
      autoRepeatDelay: const Duration(milliseconds: 140),
      autoRepeatInterval: const Duration(milliseconds: 40),
      rotateButtonSize: 80,
    );
  }
}

