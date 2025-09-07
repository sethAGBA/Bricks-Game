
   1. Snake (Serpent) : Un classique intemporel. Le joueur contrôle un serpent qui grandit en mangeant de la nourriture, tout en évitant les murs et son propre
      corps. C'est simple, addictif et facile à adapter à un affichage pixelisé.


   2. Pong : Le tout premier jeu vidéo populaire. Deux raquettes et une balle. Très simple à implémenter, idéal pour un mode deux joueurs local ou contre une IA
      basique.


   3. Space Invaders (ou un clone de shoot 'em up simple) : Le joueur contrôle un vaisseau en bas de l'écran et tire sur des ennemis qui descendent. Cela
      introduirait des éléments de tir et de gestion de vagues d'ennemis.

   4. Breakout / Arkanoid : Le joueur contrôle une raquette en bas de l'écran pour faire rebondir une balle et détruire des briques. Cela ajoute une mécanique de
      destruction et de précision.


   5. Minesweeper (Démineur) : Un jeu de puzzle logique. Le joueur doit découvrir des cases sans faire exploser de mines. C'est un excellent ajout pour varier les
      types de jeux et ne nécessite pas de mouvement constant.

 Voici 6 idées sympas qui collent bien au style “LCD/brick” du projet, avec réutilisation possible et difficulté estimée.

  - Frogger (traversée) : reprise de “Racing” côté circulation, mais en grille multi‑voies avec allers‑retours, troncs/rivières éventuels.
      - Réutilise: renderer LCD + logique de lanes.
      - Difficulté: moyenne.
      - Difficulté: moyenne.
  -
  Pong (1P vs IA) : raquettes haut/bas, balle qui accélère, score en side panel.
      - Réutilise: collisions balle/raquette déjà robustes dans Brick.
      - Difficulté: facile.
  -
  Flappy (one‑button) : obstacles en colonnes, gravité simple, vitesse progressive, score en side panel.
      - Réutilise: timer loop + painter existants.
      - Difficulté: facile.
  -
  Asteroids (wrap-around) : vaisseau rotatif, tirs, rochers qui se subdivisent, inertie simplifiée.
      - Réutilise: tir/collisions de Tanks/Shoot.
      - Difficulté: moyenne+.
  -
  Pac‑like (labyrinthe) : pastilles, 4 “fantômes” avec IA simple (chase/scatter), bonus.
      - Réutilise: grille Tetris/Bricks + painter.
      - Difficulté: élevée.
  -
  Space Runner (endless) : couloir vertical, obstacles/bonus, vitesse level‑dépendante.
      - Réutilise: boucle Racing + spawn pattern.
      - Difficulté: facile–moyenne.


       Tune layout: adjust number of water/road lanes or shift rows if you want more safe zones.
  - Require exact goal alignment vs “snap within range” (currently exact column).
  - Add obstacles on roads (trucks spanning multiple cells), bonus insects at goals, or a time bonus per frog delivered.
  - Add hop SFX on each move (can be subtle to avoid noise).
