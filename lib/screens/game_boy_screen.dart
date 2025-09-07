// import 'package:bricks/screens/bricks_game_content.dart';
import 'package:bricks/widgets/arrow_painter.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math; // Added for Random
import 'package:audioplayers/audioplayers.dart';
import 'package:bricks/style/app_style.dart';

typedef GameButtonCallback = void Function()?;

class GameBoyScreen extends StatefulWidget {
  final Widget gameContent;
  final Map<String, GameButtonCallback?> onButtonPressed;
  final Map<String, GameButtonCallback?>? onButtonReleased; // New property
  // Optional per-button auto-repeat configuration. If provided and returns true
  // for a button, holding that button will auto-repeat the action with DAS+ARR.
  final bool Function(String buttonName)? shouldAutoRepeat;
  final Duration autoRepeatDelay; // DAS (initial delay)
  final Duration autoRepeatInterval; // ARR (repeat interval)
  final double rotateButtonSize;
  final double dropButtonSize;

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

  const GameBoyScreen({
    super.key,
    required this.gameContent,
    required this.onButtonPressed,
    this.onButtonReleased, // New parameter
    this.shouldAutoRepeat,
    this.autoRepeatDelay = const Duration(milliseconds: 180),
    this.autoRepeatInterval = const Duration(milliseconds: 50),
    this.rotateButtonSize = 60,
    this.dropButtonSize = 80,
    this.customButtonTexts,
  });

  final Map<String, String>? customButtonTexts;

  @override
  GameBoyScreenState createState() => GameBoyScreenState();
}

class GameBoyScreenState extends State<GameBoyScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final AudioPlayer _soundEffectsPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();

  late AnimationController _ledAnimationController;
  late Animation<double> _ledAnimation;

  Color _mickeyImageColor = Colors.black12; // Initial color
  final List<Color> _randomColors = [Colors.red, Colors.orange, LcdColors.background, Colors.green, Colors.blue, Colors.indigo, Colors.purple];
  Timer? _mickeyColorTimer;
  final math.Random _random = math.Random();

  // Rectangle colors: use an immutable base list and a ValueNotifier for the current "lit" index
  final List<Color> _baseRectangleColors = const [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
  ];
  final ValueNotifier<int> _currentRectangleIndex = ValueNotifier<int>(0);
  Timer? _rectangleColorTimer;
  late AnimationController _rectPulseController;
  late Animation<double> _rectPulseAnim;

  // Map pour suivre quel bouton est actuellement pressé
  final Map<String, bool> _buttonsPressed = {
    GameBoyScreen.btnUp: false,
    GameBoyScreen.btnDown: false,
    GameBoyScreen.btnLeft: false,
    GameBoyScreen.btnRight: false,
    GameBoyScreen.btnDrop: false,
    GameBoyScreen.btnRotate: false,
    GameBoyScreen.btnSound: false,
    GameBoyScreen.btnPause: false,
    GameBoyScreen.btnStart: false,
    GameBoyScreen.btnSettings: false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLedAnimation();
    _startMickeyColorTimer();
    // Pulse animation for the lit rectangle
    _rectPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _rectPulseAnim = Tween<double>(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _rectPulseController, curve: Curves.easeInOut));
    _rectPulseController.repeat(reverse: true);

    // Start a timer that only updates the current index (minimize rebuild work)
    _startRectangleTimer();

  }

  void _startRectangleTimer() {
    _rectangleColorTimer?.cancel();
    _rectangleColorTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      _currentRectangleIndex.value = (_currentRectangleIndex.value + 1) % _baseRectangleColors.length;
    });
  }

  void _stopRectangleTimer() {
    _rectangleColorTimer?.cancel();
    _rectangleColorTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause animations/timers when app is not active to save CPU
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _rectPulseController.stop();
      _stopRectangleTimer();
    } else if (state == AppLifecycleState.resumed) {
      _rectPulseController.repeat(reverse: true);
      _startRectangleTimer();
    }
    super.didChangeAppLifecycleState(state);
  }

  void _startMickeyColorTimer() {
    _mickeyColorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _mickeyImageColor = _randomColors[_random.nextInt(_randomColors.length)];
      });
    });
  }

  void _initLedAnimation() {
    _ledAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _ledAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ledAnimationController, curve: Curves.easeInOut),
    );
    _ledAnimationController.repeat(reverse: true);
  }

  Timer? _continuousMoveTimer;
  Timer? _dasTimer; // initial delay for auto-repeat (DAS)
  final Map<String, int> _lastTapMs = {};

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

    // Logique spécifique à chaque bouton
    if (widget.onButtonPressed.containsKey(buttonName)) {
      widget.onButtonPressed[buttonName]?.call();
    }
  }

  void _startAutoRepeat(String buttonName, Function action) {
    _stopContinuousMove();
    _dasTimer?.cancel();
    // Execute once immediately
    action();
    // Start DAS (delayed auto shift)
    final delay = widget.autoRepeatDelay;
    final interval = widget.autoRepeatInterval;
    _dasTimer = Timer(delay, () {
      // Start ARR (auto repeat rate)
      _continuousMoveTimer = Timer.periodic(interval, (_) => action());
    });
  }

  void _stopContinuousMove() {
    _continuousMoveTimer?.cancel();
    _continuousMoveTimer = null;
    _dasTimer?.cancel();
    _dasTimer = null;
  }

  void _tapWithBooster(String buttonName, Function action) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int last = _lastTapMs[buttonName] ?? 0;
    final int delta = now - last;

    // Always perform the immediate action once
    action();
    // Booster: if user taps fast, schedule 1-2 extra actions with small delay
    if (delta < 200) {
      Timer(const Duration(milliseconds: 80), () => action());
      if (delta < 130) {
        Timer(const Duration(milliseconds: 160), () => action());
      }
    }
    _lastTapMs[buttonName] = now;
  }

  @override
  void dispose() {
    _soundEffectsPlayer.dispose();
    _musicPlayer.dispose();
    _ledAnimationController.dispose();
  WidgetsBinding.instance.removeObserver(this);
  _rectPulseController.dispose();
    _continuousMoveTimer?.cancel();
    _dasTimer?.cancel();
    _mickeyColorTimer?.cancel();
    _rectangleColorTimer?.cancel(); // Cancel the new timer
    super.dispose();
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
                      // Rainbow rectangles with a single changing "lit" index
                      ValueListenableBuilder<int>(
                        valueListenable: _currentRectangleIndex,
                        builder: (context, currentIndex, _) {
                          return AnimatedBuilder(
                            animation: _rectPulseController,
                            builder: (context, __) {
                              return Row(
                                children: List.generate(_baseRectangleColors.length, (i) {
                                  final base = _baseRectangleColors[i];
                                  final bool isLit = i == currentIndex;
                                  final displayColor = isLit
                                      ? Color.alphaBlend(Colors.white.withOpacity(0.6 * _rectPulseAnim.value), base)
                                      : base.withOpacity(0.9);
                                  return SizedBox(
                                    width: 9,
                                    height: 15,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: displayColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          );
                        },
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
                            child: widget.gameContent,
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
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildCircularFunctionButton('SOUND', Colors.green, GameBoyScreen.btnSound),
                            SizedBox(width: 12),
                            _buildCircularFunctionButton('PAUSE', Colors.orange, GameBoyScreen.btnPause),
                            SizedBox(width: 12),
                            _buildCircularFunctionButton('START', Colors.blue, GameBoyScreen.btnStart),
                            SizedBox(width: 12),
                            _buildCircularFunctionButton('SETTINGS', Colors.blueGrey, GameBoyScreen.btnSettings),
                          ],
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
    final callback = widget.onButtonPressed[buttonName];
    if (callback == null) {
      return Container(); // Don't render the button if no callback is provided
    }
    bool isPressed = _buttonsPressed[buttonName] ?? false;
    return GestureDetector(
      onTapDown: (_) {
        _onButtonPressed(buttonName);
      },
      onTapUp: (_) {
        // No need to set _buttonsPressed[buttonName] = false here, it's handled by Future.delayed in _onButtonPressed
      },
      onTapCancel: () {
        // No need to set _buttonsPressed[buttonName] = false here, it's handled by Future.delayed in _onButtonPressed
      },
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
          _buildDPadButton(alignment: Alignment.topCenter, buttonName: GameBoyScreen.btnUp, icon: Icons.arrow_upward),
          _buildDPadButton(alignment: Alignment.centerRight, buttonName: GameBoyScreen.btnRight, icon: Icons.arrow_forward),
          _buildDPadButton(alignment: Alignment.bottomCenter, buttonName: GameBoyScreen.btnDown, icon: Icons.arrow_downward),
          _buildDPadButton(alignment: Alignment.centerLeft, buttonName: GameBoyScreen.btnLeft, icon: Icons.arrow_back),
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
  // Widget pour un bouton individuel du D-Pad
  Widget _buildDPadButton({required Alignment alignment, required String buttonName, required IconData icon}) {
    bool isPressed = _buttonsPressed[buttonName] ?? false;
    Function? moveFunction = widget.onButtonPressed[buttonName];

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _buttonsPressed[buttonName] = true;
          });
          if (moveFunction != null) {
            final shouldRepeat = widget.shouldAutoRepeat?.call(buttonName) ?? false;
            if (shouldRepeat) {
              _startAutoRepeat(buttonName, moveFunction);
            } else {
              _tapWithBooster(buttonName, moveFunction);
            }
          }
        },
        onTapUp: (_) {
          setState(() {
            _buttonsPressed[buttonName] = false;
          });
          _stopContinuousMove();
          widget.onButtonReleased?[buttonName]?.call(); // Call onButtonReleased
        },
        onTapCancel: () {
          setState(() {
            _buttonsPressed[buttonName] = false;
          });
          _stopContinuousMove();
          widget.onButtonReleased?[buttonName]?.call(); // Call onButtonReleased
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
        ),
      ),
    );
  }

  // Widget pour les boutons d'action (DROP, BREAK)
  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildActionButton('BREAK', GameBoyScreen.btnRotate, widget.rotateButtonSize),
        SizedBox(width: 15),
        _buildActionButton('DROP', GameBoyScreen.btnDrop, widget.dropButtonSize),
      ],
    );
  }

  // Widget pour un bouton d'action individuel
  Widget _buildActionButton(String text, String buttonName, double size) {
    final callback = widget.onButtonPressed[buttonName];
    if (callback == null) {
      return Container(); // Don't render the button if no callback is provided
    }
    bool isPressed = _buttonsPressed[buttonName] ?? false;
    final buttonText = widget.customButtonTexts?[buttonName] ?? text;
    return GestureDetector(
      onTapDown: (_) {
        // Debounce actions like DROP/ROTATE to avoid double triggers
        final now = DateTime.now().millisecondsSinceEpoch;
        final last = _lastTapMs[buttonName] ?? 0;
        final int cooldownMs = (buttonName == GameBoyScreen.btnDrop) ? 180 : 120;
        if (now - last >= cooldownMs) {
          _lastTapMs[buttonName] = now;
          // mark pressed and call handler
          setState(() {
            _buttonsPressed[buttonName] = true;
          });
          _onButtonPressed(buttonName);
        }
      },
      onTapUp: (_) {
        setState(() {
          _buttonsPressed[buttonName] = false;
        });
        // notify release callbacks if any
        widget.onButtonReleased?[buttonName]?.call();
      },
      onTapCancel: () {
        setState(() {
          _buttonsPressed[buttonName] = false;
        });
        widget.onButtonReleased?[buttonName]?.call();
      },
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
            buttonText,
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
