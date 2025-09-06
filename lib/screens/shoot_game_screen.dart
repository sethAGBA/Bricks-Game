import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bricks/screens/game_boy_screen.dart';
import 'package:bricks/game/shoot/shoot_game_state.dart';
import 'package:bricks/game/shoot/shoot_game_widget.dart';

class ShootGameScreen extends StatelessWidget {
  const ShootGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = Provider.of<ShootGameState>(context, listen: false);
    final Map<String, GameButtonCallback> buttonCallbacks = {
      GameBoyScreen.btnLeft: () { if (gs.playing) gs.moveLeft(); },
      GameBoyScreen.btnRight: () { if (gs.playing) gs.moveRight(); },
      GameBoyScreen.btnUp: null,
      GameBoyScreen.btnDown: null,
      GameBoyScreen.btnDrop: null,
      GameBoyScreen.btnRotate: () { if (gs.playing) gs.fire(); },
      GameBoyScreen.btnStart: () => gs.startGame(),
      GameBoyScreen.btnPause: () => gs.togglePlaying(),
      GameBoyScreen.btnSound: () => gs.toggleSound(),
      GameBoyScreen.btnSettings: () { gs.stop(); Navigator.pop(context); },
    };

    return GameBoyScreen(
      gameContent: const Center(child: ShootGameWidget()),
      onButtonPressed: buttonCallbacks,
      shouldAutoRepeat: (btn) => btn == GameBoyScreen.btnLeft || btn == GameBoyScreen.btnRight,
      autoRepeatDelay: const Duration(milliseconds: 140),
      autoRepeatInterval: const Duration(milliseconds: 40),
      rotateButtonSize: 80,
      dropButtonSize: 60,
      customButtonTexts: const {
        GameBoyScreen.btnRotate: 'FIRE',
        GameBoyScreen.btnDrop: '—',
      },
    );
  }
}
