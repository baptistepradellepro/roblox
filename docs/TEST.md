# Tester le jeu dans Roblox Studio

## Avant de commencer

Ouvre la fenêtre Sortie : onglet Affichage (View) > Sortie (Output). Les erreurs y apparaissent en rouge. Si quelque chose ne marche pas, copie-moi les lignes rouges, c'est ce qui m'aide le plus.

Deux réglages pratiques pendant les tests, dans `Config.luau` (pense à les remettre ensuite) :

- `Config.NewPlayerShield = 10` au lieu de 45 : sinon chaque joueur est protégé contre le vol pendant 45 secondes à son arrivée, et tu attends avant de pouvoir tester un vol.
- `Config.ForceLanguage = "en"` pour voir le jeu en anglais (ou `"fr"`), au lieu de la langue de ton Roblox.

Si tu utilises le fichier `.rbxlx`, tu peux faire ces changements directement dans Studio : Explorateur > ReplicatedStorage > Shared > Config (double-clic pour l'ouvrir).

## Test à un joueur

Clique sur Jouer (Play) ou F5. Tu dois voir :

1. Ton personnage dans ta base, avec "TA BASE" écrit au-dessus de l'entrée.
2. Une allée au milieu, 5 socles à gauche et 5 à droite. Un Drap Mou sur ton premier socle et le message "Cadeau ! Voici ton premier fantôme".
3. Devant chaque socle occupé, une plaque verte avec un petit compteur de pièces qui monte.
4. Le compteur de pièces en haut qui monte doucement (1 pièce par seconde : c'est le petit revenu de base, pour ne jamais rester bloqué à zéro).
5. Sous les pièces, la pastille « 🛡️ Protégée : 45s » (protection débutant : la porte de ta base est fermée aux autres pendant 45 secondes). Ensuite elle devient « 🔒 Verrou prêt ».

Ensuite :

- **Acheter** : va sur le chemin au milieu, approche-toi d'un fantôme et appuie sur E (ou touche le bouton sur mobile). Il apparaît sur un de tes socles dans un petit nuage, et le prix est retiré.
- **Récupérer** : les fantômes ne versent plus leurs pièces directement sur ton compte. Elles s'empilent sur la plaque verte devant leur socle. Marche sur la plaque : les pièces passent sur ton compte avec un "+X" qui s'envole. Sous ton compteur, la pastille "💰 X à récupérer" te dit combien t'attend dans ta base.
- **Vendre** : sur un de tes socles, maintiens E pendant 1 seconde. Tu récupères la moitié du prix, plus les pièces qui attendaient sur sa plaque.
- **Verrouiller** : attends la fin du bouclier, puis va au fond de ta base. Le poste de verrouillage est entouré d'une barrière rouge et blanche, avec le panneau "🚧 VERROU". Appuie sur E devant le gros bouton rouge. C'est le seul moyen de verrouiller : pas de bouton à l'écran, et le serveur refuse si tu n'es pas devant ce bouton (« Va au bouton du verrou, au fond de ta base ! »). Une barrière à barreaux ferme l'entrée pendant 45 secondes, toujours (il n'y a plus de Game Pass pour la rallonger). Toi, tu la traverses et tu la vois presque transparente, les autres sont bloqués. Ensuite le verrou recharge pendant 2 minutes : la pastille sous les pièces affiche le temps restant.
- **Base pleine** : quand tes 10 socles sont pris et que tu essaies d'acheter, le message "Base pleine ! Achète l'étage 2 ou vends un fantôme." s'affiche.

## Tester l'étage 2

Au fond de ta base, à côté du poste de verrouillage, il y a une plaque violette avec "🔒 Étage 2 : 🪙 50K". Pour tester sans attendre, mets temporairement `Config.FloorPrice = 100` dans `Config.luau`.

1. Approche-toi de la plaque violette et appuie sur E (ou sur le bouton du téléphone). Si tu n'as pas assez de pièces, un message te le dit.
2. Une fois l'étage acheté, un plancher, des murs vitrés et 10 nouveaux socles apparaissent en hauteur, avec leurs plaques vertes. Le panneau devient "⬆️ Étage 2".
3. Marche sur la plaque violette : tu es téléporté à l'étage. Une autre plaque violette, au même endroit en haut, te ramène en bas.
4. Achète des fantômes sur le chemin : une fois le rez-de-chaussée plein, ils vont à l'étage.
5. Les voleurs peuvent aussi prendre ton ascenseur. Le verrou protège toute la base, étage compris.

L'étage reste acheté après un rebirth. Pour qu'il soit perdu au rebirth, mets `Config.RebirthKeepsFloors = false`.

## Test à 2 ou 3 joueurs

C'est le test le plus important (vol, annonces, récupération).

1. Onglet Test. Dans la zone "Clients et serveurs" (Clients and Servers), choisis "Serveur local" (Local Server) et le nombre de joueurs : 2 ou 3.
2. Clique sur Démarrer (Start). Studio ouvre une fenêtre "Serveur" et une fenêtre par joueur (Player1, Player2, Player3). Passe d'une fenêtre à l'autre avec la barre des tâches.
3. Pour tout arrêter, clique sur "Nettoyer" (Cleanup) dans la fenêtre du serveur.

Scénarios à vérifier :

1. **Vol réussi** : avec Player2, entre dans la base de Player1 et maintiens E sur un fantôme pendant 1,5 s. Le fantôme passe au-dessus de ta tête, tu es ralenti, une ligne verte te montre ta base. Dans la fenêtre de Player1, tu dois voir Player2 surligné en rouge avec "VOLEUR !". Rentre dans ta base avec Player2 : confettis, son, et l'annonce "Player2 a volé Drap Mou à Player1 !" pour tout le monde.
2. **Récupération** : recommence un vol, puis avec Player1 cours toucher Player2. Le fantôme retourne sur son socle.
3. **Coup de batte** (3 joueurs) : pendant que Player2 vole, approche Player3 de lui. Un gros bouton rouge 🏏 « Tape ! » apparaît à droite (ou touche Q sur PC, ou clic avec la batte en main). Des étoiles, Player2 lâche le fantôme, recule et reste étourdi une seconde et demie.
4. **Trop lent** : vole un fantôme et attends 45 secondes sans rentrer. Il retourne chez son propriétaire.
5. **Base verrouillée** : verrouille la base de Player1 (avec le bouton au fond de sa base), puis essaie d'entrer avec Player2. La barrière bloque, et si tu passes quand même tu es renvoyé dehors.
6. **Départ pendant un vol** : pendant que Player2 porte le fantôme de Player1, ferme la fenêtre de Player1. Player2 reçoit le fantôme directement.

Les joueurs de test de Studio ne sont pas "amis" entre eux, donc le bonus amis (+10 %) ne s'affiche pas ici. Il marchera dans le vrai jeu.

## Tester la Nuit Hantée, le rebirth et le reste

Pour ne pas attendre 8 minutes, mets `Config.DayDuration = 30` pendant les tests (puis remets 480).

- **Nuit Hantée** : 10 secondes avant, une annonce prévient. Le ciel devient violet, un fantôme spécial apparaît sur le chemin (Halloween pendant l'événement, sinon Légendaire) et Gloutrouille sort du portail. Reste dans ta base : il ne peut pas entrer. Sors : il te fonce dessus, les bords de l'écran deviennent rouges et tu entends des battements de cœur. S'il t'attrape, tu retournes chez toi avec 5 % de pièces en moins, et tout le serveur le voit dans une annonce.
- **Voleur attrapé la nuit** : si tu portes un fantôme volé, Gloutrouille te le fait lâcher. Il préfère d'ailleurs poursuivre les voleurs.
- **Rebirth** : dans `Config.luau`, mets temporairement `Config.RebirthBaseCost = 1000` (le vrai prix est 10 millions, puis x3 à chaque rebirth). Bouton ♻️ à gauche, puis REBIRTH deux fois (la deuxième pression confirme). Tes pièces, tes fantômes et les pièces en attente sur les plaques repartent à zéro. Tu gardes un Drap Mou et ton étage 2, et tu gagnes +50 % de revenus pour toujours. Une aura apparaît autour de ton personnage.
- **Cadeau du jour** : bouton 🎁 à gauche (un point rouge indique qu'il est prêt). Il s'ouvre aussi tout seul à l'arrivée, sauf pendant le tutoriel.
- **Tutoriel** : avec un compte qui n'a jamais joué (ou après avoir effacé sa sauvegarde), trois flèches jaunes s'enchaînent : "Achète !", "Récupère !" (sur la plaque verte qui a le plus de pièces) et "Vole !".
- **Boutique** : bouton 🛒, voir la partie "Tester la boutique" plus bas.
- **Fantômes Halloween** : ils n'apparaissent que la nuit, entre le 1er octobre et le 3 novembre 2026. Pour les voir hors période, mets `Config.ForceHalloween = true`.

## Tester le Fantômédex et les codes

- **Fantômédex** : bouton 📖 à gauche. Les 36 fantômes sont rangés par rareté. Ceux que tu n'as jamais eus sont des silhouettes noires avec "???". Touche une case pour lire la blague du fantôme. Achète un nouveau fantôme : un message "Nouveau dans le Fantômédex" apparaît et un point rouge s'allume sur le bouton.
- **Série complète** : trouve les 8 Communs (ils coûtent peu) pour recevoir 500 pièces. Quand toutes les raretés sauf Halloween sont complètes, tu gagnes +10 % de revenus pour toujours et tout le serveur reçoit une annonce.
- **Codes** : boutique 🛒, dernière ligne. Tape `BOUH2026` puis OK : +5 000 pièces (onglet 🎟️ Codes). Le même code une deuxième fois est refusé. Les codes de départ sont `BOUH2026` (5 000 pièces), `GLOUTROUILLE` (10 minutes de revenus) et `POUET` (un Caquetôme offert). Les majuscules et les espaces ne comptent pas.

## Tester les variantes, les nuits à thème et le classement

- **Fantômes Dorés et Arc-en-ciel** : environ 1 fantôme sur 30 sur le chemin est Doré (reflets dorés, revenu et prix x3), et environ 1 sur 170 est Arc-en-ciel (néon multicolore, petit arc-en-ciel au-dessus de la tête, x5, annonce à tout le serveur). C'est deux fois plus fréquent la nuit. Pour en voir vite, mets temporairement `Chance = 0.5` pour Gold dans `GhostData.Mutations`.
- **Nuits à thème** : chaque nuit tire au hasard Classique, Brouillard (brume très épaisse, Gloutrouille plus rapide) ou Bonbons (pièces dorées qui tournent sur le chemin, à ramasser en passant dessus). Pour forcer un thème : `Config.NightThemes = { Classic = 0, Fog = 0, Candy = 1 }`.
- **Super Nuit** : le samedi de 17h à 18h UTC. Pour la tester un autre jour, mets dans `Config.SuperNight` le jour d'aujourd'hui (1 = dimanche ... 7 = samedi), `StartHour = 0` et `EndHour = 24`. Gloutrouille devient géant, un Mythique apparaît et le ciel vire au rouge.
- **Week-end x2** : du vendredi 17h UTC au dimanche 23h UTC, une pastille "Week-end x2 !" apparaît sous les pièces et les revenus doublent. `Config.WeekendBoost.Enabled = false` pour le couper.
- **Classement** : le grand écran au-dessus du milieu du chemin affiche le top 10 des voleurs de la semaine. Dans Studio sans accès aux API, il montre les vols de la partie en cours. Il se met à jour toutes les minutes.

## Tester les missions du jour

Bouton 📋 à gauche. Chaque joueur a 3 missions par jour : une facile, une moyenne, une difficile (par exemple "Achète 3 fantômes", "Vends 2 fantômes", "Vole un fantôme à un autre joueur"). La barre avance toute seule, et quand une mission est finie les pièces arrivent directement avec un message "Mission réussie". Les 3 réussies donnent un bonus. Les missions changent à minuit UTC (2h du matin à Paris en été, 1h en hiver).

**Défis de la semaine** : dans le même panneau, onglet 🏆 « De la semaine ». Trois défis plus longs (par exemple « Vole 15 fantômes », « Piège 5 intrus dans ta base », « Achète un Légendaire »), qui changent le lundi à 0h UTC. Chaque défi réussi rapporte environ 45 minutes de revenus, et les trois réussis donnent un fantôme Épique Doré (payé en pièces si ta base est pleine), avec une annonce pour tout le serveur. Les défis et leurs objectifs se règlent dans `Missions.luau`.

Les missions difficiles demandent souvent un deuxième joueur (vol, coup de batte) : teste-les avec le Serveur local à 2 ou 3 joueurs.

## Tester la boutique (gratuit dans Studio)

Bouton 🛒 à gauche, ou le stand violet et orange au milieu de la map (côté sud, avec le chaudron). La boutique a 6 onglets : ⭐ Passes, ⚔️ Armes, 🎡 Roue, 👹 Monstres, 🪙 Pièces et 🎟️ Codes.

Tant que tu n'as pas créé les articles sur le Creator Hub (IDs à 0 dans `Config.luau`), chaque bouton affiche "🧪 Gratuit (test)" dans Studio : un clic te donne l'article sans payer, pour tout essayer. Dans le vrai jeu, ces mêmes articles affichent "Bientôt" tant que leur ID vaut 0. Personne ne peut donc les avoir gratuitement une fois le jeu publié.

## Tester la batte et les armes

- Chaque joueur a une **Batte** dans sa barre d'outils (touche 1). Clique pour frapper.
- Un voleur touché lâche le fantôme (il rentre chez son propriétaire), recule et marche au ralenti un moment.
- Un joueur qui entre dans TA base sans y être invité : un coup de batte le renvoie dehors avec le message "X t'a chassé de sa base !".
- Les autres joueurs ne sont pas touchés : pas de bagarre gratuite au milieu de la map.
- Quand tu portes un fantôme volé, tu ne peux pas frapper.
- Le gros bouton rouge « Tape ! » à droite apparaît tout seul quand un voleur est à portée. Il prend ta meilleure arme en main et frappe. C'est le plus pratique sur téléphone.
- Les armes Robux (onglet ⚔️, gratuites dans Studio) : **Marteau Pouet Géant** (plus loin, plus fort), **Balai de Sorcière** (touche tous les voleurs autour), **Aspira-Fantôme** (de très loin). Elles arrivent tout de suite dans le sac après l'achat, et à chaque réapparition.
- Les réglages (portée, recharge, étourdissement) sont dans `Weapons.luau`.

## Tester les pièges

Dans l'allée de ta base, trois emplacements gris avec leur prix : 🍌 Peau de banane (2,5K), 🕸️ Toile d'araignée (8K) et 🚨 Alarme (20K). Ils s'achètent avec des pièces, jamais avec des Robux. Mets-toi dessus et maintiens E pour poser le piège. Il reste pour toujours, même après un rebirth.

Tes pièges ne te touchent jamais. Pour les voir marcher, il faut un deuxième joueur (Serveur local à 2) :

1. **Alarme** : Player2 entre dans la base de Player1. La sirène clignote, ça sonne, et Player1 reçoit « ALARME ! Player2 est entré dans ta base ! », même s'il est loin.
2. **Peau de banane** : Player2 vole un fantôme et repasse sur la banane en partant. Il glisse, lâche le fantôme (qui rentre chez Player1) et reste étourdi. La banane disparaît puis revient 40 secondes plus tard.
3. **Toile d'araignée** : Player2 la traverse et marche au ralenti pendant 4 secondes.

Les prix et les durées se règlent dans `Config.Traps`, les positions dans `Traps.luau`.

## Les animations

- **Coups d'arme** : ce sont les animations officielles de Roblox, celles de l'épée classique (coup « Slash » pour la batte, le marteau et le balai, coup vers l'avant « Lunge » pour l'Aspira-Fantôme). Elles sont déjà dans chaque personnage et Roblox les montre à tous les joueurs.
- La batte, le marteau et le balai se tiennent dressés dans la main, comme l'épée classique. L'Aspira-Fantôme pointe devant soi.
- Une traînée de couleur suit l'arme pendant le coup, et l'Aspira-Fantôme lance un rayon vert vers le voleur.
- **Voleur** : il porte le fantôme au-dessus de sa tête, les deux bras levés. Ses armes sont rangées pendant le vol.

À tester à 2 joueurs (Serveur local) pour voir les gestes de l'autre. Si une animation te paraît encore bizarre, dis-moi laquelle et ce que tu vois (bras qui partent dans tous les sens, arme mal placée, geste trop lent...).

## Tester la Roue de la Fortune

La roue est au milieu de la map, côté nord, sur une estrade violette.

1. Approche-toi : le bouton "Roue de la Fortune" ouvre l'onglet 🎡 de la boutique, avec les chances de chaque case en %.
2. Achète des tours (gratuits dans Studio), puis appuie sur TOURNER. Il faut être devant la roue.
3. Tout le serveur voit la roue tourner, avec ton nom au-dessus. Le gain arrive quand elle s'arrête : des pièces, un fantôme Épique, Légendaire ou Mythique, un Épique Doré, ou revenus x2 pendant 15 minutes (une pastille ⚡ apparaît sous les pièces).
4. Si ta base est pleine, un fantôme gagné t'est payé en pièces.
5. Une seule personne peut jouer à la fois. Les autres reçoivent "La roue tourne déjà".

Les chances se règlent dans `Wheel.luau`. Elles doivent toujours faire 100 % au total, et chaque case doit donner quelque chose : c'est une règle de Roblox pour les objets aléatoires payants (un test automatique le vérifie).

## Tester les monstres payants

Onglet 👹 de la boutique, ou le chaudron vert du stand. Trois monstres : Gloutrouille, la Chauve-Souris Turbo (très rapide) et Mamie Toile (elle attrape de loin).

- Le monstre sort du portail et poursuit les joueurs qui sont dehors, sauf celui qui l'a lâché. Il n'entre jamais dans les bases.
- Attrapé : retour à la base et on lâche le fantôme volé, mais on ne perd pas de pièces (contrairement à Gloutrouille pendant la nuit).
- Tout le serveur reçoit l'annonce "X a lâché Y sur le serveur !", et le nom du joueur flotte au-dessus du monstre.
- Un seul monstre payant à la fois : si quelqu'un en achète un pendant qu'un autre court, il attend son tour.
- Pour le tester seul, mets-toi dehors avec un deuxième joueur (Serveur local à 2 joueurs) : c'est lui qui sera poursuivi.

## Redessiner un fantôme à la main

Tu peux remplacer n'importe quel fantôme par un modèle construit à la main dans Studio :

1. Dans l'Explorateur, crée un dossier `GhostModels` dans ReplicatedStorage (clic droit > Insérer un objet > Folder).
2. Construis ton fantôme avec des Parts (ou des MeshParts si tu sais faire des modèles 3D), sélectionne tout et groupe avec Ctrl+G.
3. Renomme le Model avec l'Id exact du fantôme, par exemple `DrapMou` (la liste des Id est dans `GhostData.luau`, la ligne `Id = "..."` de chaque fantôme).
4. Glisse le Model dans `ReplicatedStorage > GhostModels`, puis relance le jeu.

Le jeu le met à la bonne taille tout seul. Il ajoute aussi la lumière de rareté et les variantes Dorée et Arc-en-ciel. Deux réglages possibles, en attributs nombre sur le Model (Propriétés > Attributs > +) : `Height` pour choisir sa hauteur en studs, et `Turn` = 180 (ou 90, -90) s'il regarde dans la mauvaise direction en jeu. Garde une copie de tes modèles (clic droit > Enregistrer dans un fichier) : si tu retélécharges un nouveau `.rbxlx`, ce dossier n'y sera pas.

## Tester la sauvegarde

Il faut avoir publié le jeu et activé l'accès aux API (voir le README).

1. Joue, achète quelques fantômes, note ton nombre de pièces.
2. Arrête le jeu, attends 5 secondes, relance.
3. Tu dois retrouver tes fantômes, tes pièces et ton étage. Si tu es parti plus d'une minute, un message "Pendant ton absence, tes fantômes ont produit..." s'affiche, et ces pièces t'attendent sur les plaques vertes (la moitié du revenu normal, 3 heures au maximum).

Sans l'accès aux API, la fenêtre Sortie affiche "Mode test : la sauvegarde est désactivée". C'est normal et le jeu fonctionne quand même.

## Tester sur un écran de téléphone

Onglet Test > Appareil (Device), puis choisis un téléphone (iPhone, Galaxy...) dans la liste en haut de la vue 3D. Lance le jeu : les gros boutons doivent rester lisibles et ne pas cacher le joystick ni le bouton de saut. Essaie aussi en mode portrait.
