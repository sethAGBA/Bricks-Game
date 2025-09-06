 1. Augmentation dynamique de la vitesse :
       * Actuellement, vous avez une vitesse initiale et une vitesse accélérée. Vous pourriez augmenter progressivement la vitesse du serpent à mesure que le
         joueur marque des points ou atteint de nouveaux niveaux. Le TODO dans _moveSnake le suggère déjà.
       * Par exemple, toutes les 5 ou 10 unités de score, la vitesse du serpent pourrait légèrement augmenter (diminuer le _initialSpeed ou _acceleratedSpeed par
         un petit pourcentage).


   2. Introduction d'obstacles :
       * Vous pourriez ajouter des "murs" ou des "blocs" statiques sur la grille de jeu qui apparaissent à certains niveaux ou après un certain score. Le serpent
         ne pourrait pas traverser ces obstacles.
       * Cela forcerait le joueur à naviguer dans des espaces plus restreints et à planifier ses mouvements plus soigneusement.


   3. Nourriture à durée limitée :
       * Faire en sorte que la nourriture disparaisse si elle n'est pas mangée dans un certain laps de temps. Cela ajouterait une pression temporelle et exigerait
         des décisions plus rapides.


   4. Réduction des vies ou pénalités plus sévères :
       * Vous pourriez réduire le nombre de vies initiales (life = 4).
       * Ou, au lieu de réinitialiser le serpent après une collision, le jeu pourrait se terminer immédiatement, ou le serpent pourrait perdre une partie de sa
         longueur.

  - Importe et branche les cartes Snake .map dans Flutter ?
  - Ajoute l’animation de clear Tetris ?
  - Ajuste finement l’accélération Race selon niveau/speed comme dans le Java ?