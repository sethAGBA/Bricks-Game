import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bricks/game/race/race_game_state.dart';
import 'package:bricks/game/piece.dart'; // Re-add this import

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Add this line
  group('RaceGameState Acceleration/Deceleration', () {
    late RaceGameState gameState;

    setUp(() {
      SharedPreferences.setMockInitialValues({}); // Mock SharedPreferences
      gameState = RaceGameState();
      gameState.startGame();
    });

    test('Player car accelerates upwards when moveUp is called and gameLoop runs', () {
      final initialY = gameState.playerCar.points.first.y;
      gameState.moveUp();

      // Simulate multiple game loop ticks
      for (int i = 0; i < 5; i++) {
        gameState.gameLoop();
      }
      gameState.stopAccelerating(); // Explicitly stop accelerating

      final afterAccelerationY = gameState.playerCar.points.first.y;
      expect(afterAccelerationY, lessThan(initialY)); // Y should decrease (move up)
      expect(gameState.isAccelerating, isFalse); // Now this expectation is correct
    });

    test('Player car decelerates downwards when moveDown is called and gameLoop runs', () {
      gameState.playerCar = Car([Point(4, 0)]); // Set initial position to top
      final initialY = gameState.playerCar.points.first.y;
      gameState.moveDown();

      // Simulate multiple game loop ticks
      for (int i = 0; i < 5; i++) {
        gameState.gameLoop();
      }
      gameState.stopDecelerating(); // Explicitly stop decelerating

      final afterDecelerationY = gameState.playerCar.points.first.y;
      expect(afterDecelerationY, greaterThan(initialY)); // Y should increase (move down)
      expect(gameState.isDecelerating, isFalse); // Now this expectation is correct
    });

    test('Acceleration stops when stopAccelerating is called', () {
      gameState.moveUp();
      expect(gameState.isAccelerating, isTrue);
      gameState.stopAccelerating();
      expect(gameState.isAccelerating, isFalse);
    });

    test('Deceleration stops when stopDecelerating is called', () {
      gameState.moveDown();
      expect(gameState.isDecelerating, isTrue);
      gameState.stopDecelerating();
      expect(gameState.isDecelerating, isFalse);
    });

    test('Collision is detected during acceleration', () {
      // Position car to allow movement and then collide
      gameState.playerCar = Car([Point(4, 5)]); // Start car lower
      gameState.otherCars = []; // Clear other cars for simpler test
      
      gameState.moveUp(); // Initiate acceleration
      // Set road points AFTER player car moves, but before gameLoop's collision check
      gameState.road.points.clear(); // Clear existing road points
      gameState.road.points.add(Point(4, 4)); // Add specific road point for collision

      gameState.gameLoop(); // Run game loop to apply movement and check collision

      expect(gameState.isCrashing, isTrue);
    });

    test('Collision is detected during deceleration', () {
      // Position car to allow movement and then collide
      gameState.playerCar = Car([Point(4, RaceGameState.rows - 5)]); // Start car higher
      gameState.otherCars = []; // Clear other cars for simpler test
      
      gameState.moveDown(); // Initiate deceleration
      // Set road points AFTER player car moves, but before gameLoop's collision check
      gameState.road.points.clear(); // Clear existing road points
      gameState.road.points.add(Point(4, RaceGameState.rows - 4)); // Add specific road point for collision

      gameState.gameLoop(); // Run game loop to apply movement and check collision

      expect(gameState.isCrashing, isTrue);
    });
  });
}
