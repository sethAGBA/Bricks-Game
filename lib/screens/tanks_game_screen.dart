import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:bricks/game/tanks/tanks_game_state.dart';
import 'package:bricks/game/tanks/tanks_game_widget.dart';

class TanksGameScreen extends StatelessWidget {
  const TanksGameScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final gs = Provider.of<TanksGameState>(context, listen: false);
    final Map<String, GameButtonCallback> btns = {
      GameBoyScreen.btnLeft: () { if (gs.playing) gs.moveLeft(); },
      GameBoyScreen.btnRight: () { if (gs.playing) gs.moveRight(); },
      GameBoyScreen.btnUp: () { if (gs.playing) gs.moveUp(); },
      GameBoyScreen.btnDown: () { if (gs.playing) gs.moveDown(); },
      GameBoyScreen.btnRotate: () { if (gs.playing) gs.fire(); },
      GameBoyScreen.btnStart: () => gs.startGame(),
      GameBoyScreen.btnPause: () => gs.togglePlaying(),
      GameBoyScreen.btnSound: () => gs.toggleSound(),
      GameBoyScreen.btnSettings: () { gs.stop(); Navigator.pop(context); },
    };
    return GameBoyScreen(
      gameContent: const Center(child: TanksGameWidget()),
      onButtonPressed: btns,
      shouldAutoRepeat: (b) => b == GameBoyScreen.btnLeft || b == GameBoyScreen.btnRight || b == GameBoyScreen.btnUp || b == GameBoyScreen.btnDown,
      autoRepeatDelay: const Duration(milliseconds: 140),
      autoRepeatInterval: const Duration(milliseconds: 40),
      rotateButtonSize: 80,
    );
  }
}

