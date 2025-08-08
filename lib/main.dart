import 'package:bricks/game/game_state.dart';
import 'package:bricks/screens/menu_game_screen.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final gameState = GameState();
  await gameState.loadHighScore();

  runApp(
    ChangeNotifierProvider.value(
      value: gameState,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brick Game',
      theme: ThemeData(
        primarySwatch: Colors.yellow,
        fontFamily: 'PressStart2P',
      ),
      home: const MenuGameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
