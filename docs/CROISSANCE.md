# Faire grandir Steal a Ghost

## 5 vidéos TikTok / Shorts à filmer

Matériel gratuit : OBS Studio pour enregistrer l'écran du PC (ou l'enregistreur d'écran du téléphone), CapCut pour monter en vertical 9:16. Vise 15 à 30 secondes, et que les 2 premières secondes donnent envie de rester. Poste en fin d'après-midi après l'école (17h-19h), et le mercredi ou le samedi après-midi.

Rappel : TikTok est interdit aux moins de 13 ans. Ne promets jamais de Robux gratuits et ne mets aucun lien dans le jeu.

### 1. Le vol à la dernière seconde

Avec un ami, chacun sur son compte. Il pose un Légendaire, tu le voles, il te court après, tu rentres dans ta base au moment où le chrono affiche 0:03. L'annonce "Léo a volé DJ Bouh-Boum à Inès !" apparaît pour tout le serveur.

- Accroche à l'écran : "Il lui restait 3 secondes..."
- Filme côté voleur, puis coupe sur la bannière et les confettis.
- Légende : "il a pas vu venir 😭 #roblox #stealaghost"

### 2. Le classement des fantômes les plus débiles

Un fantôme par passage, avec son nom et sa blague (elles sont dans `GhostData.luau`) : "Fantôme Pas Fini, encore en chargement... 99 %". Finis par le Mythique pour garder les gens jusqu'au bout. Ça peut devenir une série, "le fantôme du jour".

- Accroche : "Le pire fantôme du jeu c'est lui"
- Format tier list : S, A, B, "poubelle".

### 3. Gloutrouille m'a eu avec 1 million en poche

Pendant la Nuit Hantée, sors de ta base avec un fantôme volé. Les bords rouges et les battements de cœur font le travail. Ajoute ta réaction (caméra ou voix) au moment du "BOUH !".

- Accroche : le son des battements de cœur dès la première image, avec le texte "NE SORS PAS LA NUIT"
- Fin : l'annonce "Gloutrouille a attrapé ..." visible par tout le serveur.

### 4. Le piège parfait

Pose ton plus beau fantôme sur le socle le plus proche de l'entrée, laisse la base ouverte et cache-toi avec un ami. Le voleur arrive, attrape le fantôme, et ton ami lui met un coup de batte devant la porte.

- Accroche : "Il pensait que c'était gratuit..."
- Le coup de batte et les étoiles doivent tomber pile sur un temps fort de la musique.

### 5. De Drap Mou au Rebirth

Accélère une session de jeu : un seul Drap Mou au début, compteur de pièces qui monte, premier Légendaire, premier Mythique, puis le Rebirth avec confettis et aura.

- Accroche : "J'ai commencé avec un drap..."
- Mets le compteur de pièces en gros à chaque étape.

## Déjà dans le jeu au lancement

Pour que le jeu soit le plus complet possible dès le départ, tout ce qui était prévu pour l'automne et l'hiver est déjà codé :

- le Fantômédex et les codes secrets, les fantômes Dorés et Arc-en-ciel, les nuits à thème (Brouillard, Bonbons) et la Super Nuit du samedi soir ;
- le week-end x2, le classement des voleurs de la semaine, les 3 missions du jour et les 3 défis de la semaine ;
- la batte et les armes, la Roue de la Fortune, les monstres à lâcher, les pièges (banane, toile, alarme) ;
- la rareté Secrète (3 fantômes presque introuvables) et les badges Roblox ;
- l'Hiver Hanté, qui se lance seul le 1er décembre : neige, 4 fantômes Givrés et le Bonhomme Grelot la nuit, avec un avant-goût dès le 23 novembre.

Ça donne de quoi filmer dès la première semaine : un Arc-en-ciel annoncé à tout le serveur, une Super Nuit avec le Gloutrouille géant, un voleur qui glisse sur ta peau de banane, ou la première apparition d'un Secret.

## Après le lancement : un rythme d'une nouveauté par semaine

Le principe ne change pas : une nouveauté visible chaque semaine, annoncée dans le titre (`[🍂 UPDATE] Steal a Ghost`) et sur TikTok. Le 3 novembre, les fantômes Halloween arrêtent d'apparaître tout seuls (c'est réglé dans `Config.luau`). Ceux qui en ont un le gardent, et ils deviennent les cibles les plus recherchées du serveur.

Chaque semaine, regarde dans Creator Hub > Analytics la rétention à 1 jour (vise 20 % ou plus), la rétention à 7 jours (5 % ou plus) et la durée moyenne des sessions (12 minutes ou plus). Si la rétention à 1 jour passe sous 15 %, on retravaille d'abord les 5 premières minutes de jeu avant d'ajouter du contenu.

Comme tout le contenu prévu est déjà là, les semaines de novembre servent surtout à :

- **Équilibrer** à partir des vraies données : prix, revenus, chance des variantes et des Secrets, prix des pièges, difficulté des défis. Tout se règle dans `Config.luau`, `GhostData.luau`, `Rarities.luau`, `Missions.luau` et `Wheel.luau`.
- **Faire vivre les codes secrets** : un nouveau code chaque semaine (fin d'Halloween, 1 000 joueurs, arrivée de l'hiver), annoncé sur TikTok.
- **Mettre en avant une nouveauté déjà codée** chaque semaine dans le titre et les vidéos : les pièges, puis les défis de la semaine, puis la chasse aux Secrets, puis l'Hiver Hanté.

Idées pour la suite, à coder ensemble quand tu veux : un événement de la Saint-Valentin (février), des fantômes à fusionner (3 identiques donnent une version améliorée), un mode « équipe » à deux bases voisines, ou des auras de base à acheter avec des pièces.

Chaque idée représente du code que je peux écrire avec toi, avec les tests et un nouveau fichier `.rbxlx`.
