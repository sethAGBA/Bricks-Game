import 'package:bricks/game/game_state.dart';
import 'package:bricks/screens/tetris_game_screen.dart';
import 'package:bricks/widgets/arrow_painter.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math'; // Added for Random
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';


class GameBoyScreen extends StatefulWidget {
  const GameBoyScreen({super.key});
  @override
  GameBoyScreenState createState() => GameBoyScreenState();
}

class GameBoyScreenState extends State<GameBoyScreen> with TickerProviderStateMixin {
  final AudioPlayer _soundEffectsPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();

  late AnimationController _ledAnimationController;
  late Animation<double> _ledAnimation;

  Color _mickeyImageColor = Colors.black; // Initial color
  final List<Color> _randomColors = [Colors.red, Colors.orange, TetrisGameScreenState.lcdBackground, Colors.green, Colors.blue, Colors.indigo, Colors.purple];
  Timer? _mickeyColorTimer;
  int _currentColorIndex = 0;
  final Random _random = Random();

  // Rectangle colors
  late List<Color> _rectangleColors;
  Timer? _rectangleColorTimer;
  int _currentRectangleColorIndex = 0;

  // Colors for the rectangles next to the Mickey image

  // Noms des boutons pour gérer leur état de pression
  static const String btnUp = 'up';
  static const String btnDown = 'down';
  static const String btnLeft = 'left';
  static const String btnRight = 'right';
  static const String btnDrop = 'drop';
  static const String btnRotate = 'rotate';
  static const String btnSound = 'sound';
  static const String btnPause = 'pause';
  static const String btnStart = 'start';
  static const String btnSettings = 'settings';

  // Map pour suivre quel bouton est actuellement pressé
  final Map<String, bool> _buttonsPressed = {
    btnUp: false,
    btnDown: false,
    btnLeft: false,
    btnRight: false,
    btnDrop: false,
    btnRotate: false,
    btnSound: false,
    btnPause: false,
    btnStart: false,
    btnSettings: false,
  };

  @override
  void initState() {
    super.initState();
    final gameState = Provider.of<GameState>(context, listen: false);
    _initMusic(gameState);
    _initLedAnimation();
    _startMickeyColorTimer();
    // Initialize rectangle colors (7 rectangles, default to grey)
  // Couleurs de l'arc-en-ciel
  _rectangleColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
  ];
  
    // // Start the rectangle color timer
    // _rectangleColorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
    //   setState(() {
    //     _currentRectangleColorIndex = (_currentRectangleColorIndex + 1) % _rectangleColors.length;
    //     _rectangleColors = List.generate(7, (index) => _rectangleColors[(_currentRectangleColorIndex + index) % _rectangleColors.length]);
    //   });
    // });

  // Animation des rectangles
  _rectangleColorTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
    setState(() {
      // Remet toutes les couleurs normales
      for (int i = 0; i < _rectangleColors.length; i++) {
        _rectangleColors[i] = [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.indigo,
          Colors.purple,
        ][i];
      }
      // Allume le rectangle courant (par exemple en blanc)
      _rectangleColors[_currentRectangleColorIndex] = Colors.transparent;
      // Passe au suivant
      _currentRectangleColorIndex = (_currentRectangleColorIndex + 1) % _rectangleColors.length;
    });
  });

  }

  void _startMickeyColorTimer() {
    _mickeyColorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _mickeyImageColor = _randomColors[_random.nextInt(_randomColors.length)];
      });
    });
  }

  void _initMusic(GameState gameState) async {
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setSource(AssetSource('sounds/8bit-music-for-game-68698.mp3'));
    await _musicPlayer.setVolume(0.3); // Volume de fond faible
    if (gameState.playing && gameState.soundOn) {
      await _musicPlayer.resume();
    }
  }

  void _initLedAnimation() {
    _ledAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _ledAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ledAnimationController, curve: Curves.easeInOut),
    );
    final gameState = Provider.of<GameState>(context, listen: false);
    if (!gameState.playing) {
      _ledAnimationController.repeat(reverse: true);
    }
  }

  Timer? _continuousMoveTimer;

  // Méthode générique pour gérer la pression des boutons
  void _onButtonPressed(String buttonName) {
    setState(() {
      _buttonsPressed[buttonName] = true;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _buttonsPressed[buttonName] = false;
        });
      }
    });

    final gameState = Provider.of<GameState>(context, listen: false);

    // Logique spécifique à chaque bouton
    switch (buttonName) {
      case btnSound:
        _toggleSound(gameState);
        break;
      case btnPause:
        gameState.togglePlaying();
        break;
      case btnStart:
        gameState.startGame();
        break;
      case btnRotate:
        gameState.rotate();
        break;
      case btnDrop:
        gameState.hardDrop();
        break;
      case btnSettings:
        Navigator.pop(context);
        break;
    }
  }

  void _startContinuousMove(Function moveFunction, {Duration interval = const Duration(milliseconds: 100)}) {
    _continuousMoveTimer?.cancel(); // Cancel any existing timer
    moveFunction(); // Execute once immediately
    _continuousMoveTimer = Timer.periodic(interval, (timer) {
      moveFunction();
    });
  }

  void _stopContinuousMove() {
    _continuousMoveTimer?.cancel();
    _continuousMoveTimer = null;
  }

  @override
  void dispose() {
    _soundEffectsPlayer.dispose();
    _musicPlayer.dispose();
    _ledAnimationController.dispose();
    _continuousMoveTimer?.cancel();
    _mickeyColorTimer?.cancel();
    _rectangleColorTimer?.cancel(); // Cancel the new timer
    super.dispose();
  }

  void _toggleSound(GameState gameState) async {
    gameState.toggleSound();
    await _soundEffectsPlayer.play(AssetSource('sounds/gameboy-pluck-41265.mp3'), volume: gameState.volume / 3);

    if (gameState.soundOn) {
      await _musicPlayer.setVolume(0.3);
      if (gameState.playing) {
        await _musicPlayer.resume();
      }
    } else {
      await _musicPlayer.setVolume(0.0);
      await _musicPlayer.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD700),
      body: SafeArea(
        child: Stack(
          children: [
            // LED Power animée
            Positioned(
              top: 4,
              left: 38,
              child: FadeTransition(
                opacity: _ledAnimation,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withAlpha((255 * 0.5).round()),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: -20,
              right: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Image and rectangles on the left
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 10), // Added space to move image right
                      Image.asset(
                    'assets/images/super_mouse_transparent.png',
                    width: 60,
                    height: 60,
                    color: _mickeyImageColor,
                  ),
                      SizedBox(width: 10), // Space between image and rectangles
                      Row(
                        children: List.generate(7, (i) => SizedBox(
                          width: 9,
                          height: 15,
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: _rectangleColors[i],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        )),
                      ),
                    ],
                  ),
                  // BRICK GAME text on the right
                  Text(
                    'BRICK GAME',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Digital7',
                    ),
                  ),
                ],
              ),
            ),
            // Colonne principale
            Column(
              children: [
                // Écran LCD
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Container(
                      margin: EdgeInsets.all(20),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                        color: const Color(0xFF2F2F2F),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Container(
                              width: 120,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withAlpha((255 * 0.18).round()),
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(40),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFD3CDBF),
                            ),
                            child: TetrisGameScreen(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Zone des contrôles
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Boutons de fonction
                        
                        Consumer<GameState>(
                          builder: (context, gameState, child) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _buildCircularFunctionButton(gameState.soundOn ? 'SOUND' : 'MUTE', Colors.green, btnSound),
                                SizedBox(width: 12),
                                _buildCircularFunctionButton(gameState.playing ? 'PAUSE' : 'PLAY', Colors.orange, btnPause),
                                SizedBox(width: 12),
                                _buildCircularFunctionButton('START', Colors.blue, btnStart),
                                SizedBox(width: 12),
                                _buildCircularFunctionButton('SETTINGS', Colors.blueGrey, btnSettings),
                              ],
                            );
                          },
                        ),
                        // Contrôles principaux
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildActionButtons(),
                            _buildDPad(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour un bouton de fonction (SOUND, PAUSE, RESET)
  Widget _buildCircularFunctionButton(String text, Color color, String buttonName) {
    bool isPressed = _buttonsPressed[buttonName] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonName),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPressed ? color.withAlpha((255 * 0.7).round()) : color,
              shape: BoxShape.circle,
              boxShadow: isPressed
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 2,
                      ),
                    ],
            ),
          ),
          SizedBox(height: 5),
          Text(
            text,
            style: TextStyle(
              color: Colors.black,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget pour le D-Pad
  Widget _buildDPad() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildDPadButton(alignment: Alignment.topCenter, buttonName: btnUp, icon: Icons.arrow_upward),
          _buildDPadButton(alignment: Alignment.centerRight, buttonName: btnRight, icon: Icons.arrow_forward),
          _buildDPadButton(alignment: Alignment.bottomCenter, buttonName: btnDown, icon: Icons.arrow_downward),
          _buildDPadButton(alignment: Alignment.centerLeft, buttonName: btnLeft, icon: Icons.arrow_back),
          Positioned(
            child: SizedBox(
              width: 60,
              height: 60,
              child: CustomPaint(
                painter: ArrowPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour un bouton individuel du D-Pad
  Widget _buildDPadButton({required Alignment alignment, required String buttonName, required IconData icon}) {
    bool isPressed = _buttonsPressed[buttonName] ?? false;
    final gameState = Provider.of<GameState>(context, listen: false);

    Function? moveFunction;
    switch (buttonName) {
      case btnLeft:
        moveFunction = gameState.moveLeft;
        break;
      case btnRight:
        moveFunction = gameState.moveRight;
        break;
      case btnDown:
        moveFunction = gameState.moveDown;
        break;
      case btnUp:
        // For UP, it's usually a single press for rotation or hard drop, not continuous movement.
        // We'll keep it as a single press for now, or you can assign a specific action.
        moveFunction = () { /* No action for UP by default, or assign rotate/hard drop */ };
        break;
    }

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _buttonsPressed[buttonName] = true;
          });
          if (buttonName == btnLeft || buttonName == btnRight || buttonName == btnDown) {
            _startContinuousMove(moveFunction!);
          } else {
            // For other buttons like BTN_UP, just trigger once
            moveFunction!();
          }
        },
        onTapUp: (_) {
          setState(() {
            _buttonsPressed[buttonName] = false;
          });
          _stopContinuousMove();
        },
        onTapCancel: () {
          setState(() {
            _buttonsPressed[buttonName] = false;
          });
          _stopContinuousMove();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isPressed ? const Color(0xFF314D9E) : const Color(0xFF4169E1),
            shape: BoxShape.circle,
            boxShadow: isPressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 3),
                      blurRadius: 3,
                    ),
                  ],
          ),
          child: Icon(icon, color: Colors.black.withAlpha((255 * 0.6).round()), size: 24),
        ),
      ),
    );
  }

  // Widget pour les boutons d'action (DROP, ROTATE)
  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildActionButton('ROTATE', btnRotate, 60),
        SizedBox(width: 15),
        _buildActionButton('DROP', btnDrop, 80),
      ],
    );
  }

  // Widget pour un bouton d'action individuel
  Widget _buildActionButton(String text, String buttonName, double size) {
    bool isPressed = _buttonsPressed[buttonName] ?? false;
    return GestureDetector(
      onTapDown: (_) => _onButtonPressed(buttonName),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isPressed ? const Color(0xFF314D9E) : const Color(0xFF4169E1),
              shape: BoxShape.circle,
              boxShadow: isPressed
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 3),
                        blurRadius: 3,
                      ),
                    ],
            ),
          ),
          SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}