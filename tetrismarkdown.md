

   1. Game Grid: The game takes place on a defined grid (e.g., 20 rows x 10 columns). Each cell on this grid can either be empty, contain a part of the snake, or
      contain food.


   2. Snake:
       * Represented as a list of coordinates (points) on the grid. The first coordinate in the list is the snake's head, and the last is its tail.
       * It has a direction (Up, Down, Left, Right) which determines its next move.


   3. Food:
       * A single coordinate on the grid.
       * Randomly generated in an empty cell.


   4. Game Loop:
       * A timer (_timer in SnakeGameState) periodically triggers the snake's movement. The interval of this timer controls the game speed.
       * Movement (`_moveSnake()`):
           * The snake calculates its newHead position based on its current direction.
           * The newHead is added to the front of the snake's body list.
           * If the newHead lands on food:
               * The player's score increases.
               * New food is generated.
               * The snake's tail is not removed, making the snake grow longer.
           * If the newHead does not land on food:
               * The last segment (tail) of the snake is removed, simulating movement without growth.
       * Collision Detection: Before moving, the game checks if the newHead would:
           * Hit the boundaries of the grid (walls).
           * Collide with any part of the snake's own body.
           * If a collision occurs, the game transitions to the _gameOver() state.


   5. Input Handling (`changeDirection()`):
       * Players can change the snake's direction.
       * A crucial rule is to prevent immediate reversals (e.g., from moving Right to immediately moving Left), as this would cause an instant self-collision.


   6. Game Over (`_gameOver()`):
       * The isGameOver flag is set to true.
       * The game timers are stopped.
       * The current score is compared to the highScore, and the highScore is updated and saved if the current score is higher.

   7. Pause/Resume (`pauseGame()`):
       * Toggles the isPlaying flag and pauses/resumes the game timers.


   8. Rendering (`_SnakeGamePainter`):
       * This component is responsible for visually drawing the game state on the screen: the grid background, each segment of the snake, and the food. It
         receives the current snake and food positions from the SnakeGameState and translates them into pixels on the screen.
