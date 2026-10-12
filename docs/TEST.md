# Tester le jeu dans Roblox Studio

## Avant de commencer

Ouvre la fenêtre Sortie : onglet Affichage (View) > Sortie (Output). Les erreurs y apparaissent en rouge. Si quelque chose ne marche pas, copie-moi les lignes rouges, c'est ce qui m'aide le plus.

Deux réglages pratiques pendant les tests, dans `Config.luau` (pense à les remettre ensuite) :

- `Config.NewPlayerShield = 10` au lieu de 120 : sinon chaque joueur est protégé contre le vol pendant 2 minutes à son arrivée, et tu attends longtemps avant de pouvoir tester un vol.
- `Config.ForceLanguage = "en"` pour voir le jeu en anglais (ou `"fr"`), au lieu de la langue de ton Roblox.

Si tu utilises le fichier `.rbxlx`, tu peux faire ces changements directement dans Studio : Explorateur > ReplicatedStorage > Shared > Config (double-clic pour l'ouvrir).

## Test à un joueur

Clique sur Jouer (Play) ou F5. Tu dois voir :

1. Ton personnage dans ta base, avec "TA BASE" écrit au-dessus de l'entrée.
2. Un Drap Mou sur ton premier socle et le message "Cadeau ! Voici ton premier fantôme".
3. Le compteur de pièces en haut qui monte chaque seconde.
4. Le bouton bouclier à droite avec un compte à rebours de 2:00 (protection débutant).

Ensuite :

- **Acheter** : va sur le chemin au milieu, approche-toi d'un fantôme et appuie sur E (ou touche le bouton sur mobile). Il apparaît sur un de tes socles dans un petit nuage, et le prix est retiré.
- **Vendre** : sur un de tes socles, maintiens E pendant 1 seconde. Tu récupères la moitié du prix.
- **Verrouiller** : attends la fin du bouclier, puis appuie sur le bouton 🔒 à droite (ou sur le gros bouton rouge au sol dans ta base). Une barrière apparaît à l'entrée pendant 60 secondes. Toi, tu peux la traverser. Ensuite le bouton recharge pendant 2 minutes.

## Test à 2 ou 3 joueurs

C'est le test le plus important (vol, annonces, récupération).

1. Onglet Test. Dans la zone "Clients et serveurs" (Clients and Servers), choisis "Serveur local" (Local Server) et le nombre de joueurs : 2 ou 3.
2. Clique sur Démarrer (Start). Studio ouvre une fenêtre "Serveur" et une fenêtre par joueur (Player1, Player2, Player3). Passe d'une fenêtre à l'autre avec la barre des tâches.
3. Pour tout arrêter, clique sur "Nettoyer" (Cleanup) dans la fenêtre du serveur.

Scénarios à vérifier :

1. **Vol réussi** : avec Player2, entre dans la base de Player1 et maintiens E sur un fantôme pendant 1,5 s. Le fantôme passe au-dessus de ta tête, tu es ralenti, une ligne verte te montre ta base. Dans la fenêtre de Player1, tu dois voir Player2 surligné en rouge avec "VOLEUR !". Rentre dans ta base avec Player2 : confettis, son, et l'annonce "Player2 a volé Drap Mou à Player1 !" pour tout le monde.
2. **Récupération** : recommence un vol, puis avec Player1 cours toucher Player2. Le fantôme retourne sur son socle.
3. **Marteau Pouet** (3 joueurs) : pendant que Player2 vole, approche Player3 de lui. Un bouton 🔨 apparaît à droite (ou touche Q sur PC). Des étoiles, Player2 lâche le fantôme et reste étourdi une seconde.
4. **Trop lent** : vole un fantôme et attends 45 secondes sans rentrer. Il retourne chez son propriétaire.
5. **Base verrouillée** : verrouille la base de Player1, puis essaie d'entrer avec Player2. La barrière bloque, et si tu passes quand même tu es renvoyé dehors.
6. **Départ pendant un vol** : pendant que Player2 porte le fantôme de Player1, ferme la fenêtre de Player1. Player2 reçoit le fantôme directement.

Les joueurs de test de Studio ne sont pas "amis" entre eux, donc le bonus amis (+10 %) ne s'affiche pas ici. Il marchera dans le vrai jeu.

## Tester la Nuit Hantée, le rebirth et le reste

Pour ne pas attendre 8 minutes, mets `Config.DayDuration = 30` pendant les tests (puis remets 480).

- **Nuit Hantée** : 10 secondes avant, une annonce prévient. Le ciel devient violet, un fantôme spécial apparaît sur le chemin (Halloween pendant l'événement, sinon Légendaire) et Gloutrouille sort du portail. Reste dans ta base : il ne peut pas entrer. Sors : il te fonce dessus, les bords de l'écran deviennent rouges et tu entends des battements de cœur. S'il t'attrape, tu retournes chez toi avec 5 % de pièces en moins, et tout le serveur le voit dans une annonce.
- **Voleur attrapé la nuit** : si tu portes un fantôme volé, Gloutrouille te le fait lâcher. Il préfère d'ailleurs poursuivre les voleurs.
- **Rebirth** : dans `Config.luau`, mets temporairement `Config.RebirthBaseCost = 1000`. Bouton ♻️ à gauche, puis REBIRTH deux fois (la deuxième pression confirme). Tes pièces et tes fantômes repartent à zéro, tu gardes un Drap Mou, tu gagnes x1,5 sur tes revenus et un 9e socle. Une aura apparaît autour de ton personnage.
- **Cadeau du jour** : bouton 🎁 à gauche (un point rouge indique qu'il est prêt). Il s'ouvre aussi tout seul à l'arrivée, sauf pendant le tutoriel.
- **Tutoriel** : avec un compte qui n'a jamais joué (ou après avoir effacé sa sauvegarde), trois flèches jaunes s'enchaînent : "Achète !", "Ta base", "Vole !".
- **Boutique** : bouton 🛒. Les articles affichent "Bientôt" tant que leurs IDs valent 0 dans `Config.luau`. Les achats Robux ne se testent vraiment qu'une fois le jeu publié (dans Studio, Roblox simule l'achat sans débiter de Robux).
- **Fantômes Halloween** : ils n'apparaissent que la nuit, entre le 1er octobre et le 3 novembre 2026. Pour les voir hors période, mets `Config.ForceHalloween = true`.

## Tester le Fantômédex et les codes

- **Fantômédex** : bouton 📖 à gauche. Les 36 fantômes sont rangés par rareté. Ceux que tu n'as jamais eus sont des silhouettes noires avec "???". Touche une case pour lire la blague du fantôme. Achète un nouveau fantôme : un message "Nouveau dans le Fantômédex" apparaît et un point rouge s'allume sur le bouton.
- **Série complète** : trouve les 8 Communs (ils coûtent peu) pour recevoir 500 pièces. Quand toutes les raretés sauf Halloween sont complètes, tu gagnes +10 % de revenus pour toujours et tout le serveur reçoit une annonce.
- **Codes** : boutique 🛒, dernière ligne. Tape `BOUH2026` puis OK : +5 000 pièces. Le même code une deuxième fois est refusé. Les codes de départ sont `BOUH2026` (5 000 pièces), `GLOUTROUILLE` (10 minutes de revenus) et `POUET` (un Caquetôme offert). Les majuscules et les espaces ne comptent pas.

## Tester les variantes, les nuits à thème et le classement

- **Fantômes Dorés et Arc-en-ciel** : environ 1 fantôme sur 30 sur le chemin est Doré (reflets dorés, revenu et prix x3), et environ 1 sur 170 est Arc-en-ciel (néon multicolore, petit arc-en-ciel au-dessus de la tête, x5, annonce à tout le serveur). C'est deux fois plus fréquent la nuit. Pour en voir vite, mets temporairement `Chance = 0.5` pour Gold dans `GhostData.Mutations`.
- **Nuits à thème** : chaque nuit tire au hasard Classique, Brouillard (brume très épaisse, Gloutrouille plus rapide) ou Bonbons (pièces dorées qui tournent sur le chemin, à ramasser en passant dessus). Pour forcer un thème : `Config.NightThemes = { Classic = 0, Fog = 0, Candy = 1 }`.
- **Super Nuit** : le samedi de 17h à 18h UTC. Pour la tester un autre jour, mets dans `Config.SuperNight` le jour d'aujourd'hui (1 = dimanche ... 7 = samedi), `StartHour = 0` et `EndHour = 24`. Gloutrouille devient géant, un Mythique apparaît et le ciel vire au rouge.
- **Week-end x2** : du vendredi 17h UTC au dimanche 23h UTC, une pastille "Week-end x2 !" apparaît sous les pièces et les revenus doublent. `Config.WeekendBoost.Enabled = false` pour le couper.
- **Classement** : le grand écran au-dessus du milieu du chemin affiche le top 10 des voleurs de la semaine. Dans Studio sans accès aux API, il montre les vols de la partie en cours. Il se met à jour toutes les minutes.

## Tester les missions du jour

Bouton 📋 à gauche. Chaque joueur a 3 missions par jour : une facile, une moyenne, une difficile (par exemple "Achète 3 fantômes", "Vends 2 fantômes", "Vole un fantôme à un autre joueur"). La barre avance toute seule, et quand une mission est finie les pièces arrivent directement avec un message "Mission réussie". Les 3 réussies donnent un bonus. Les missions changent à minuit UTC (2h du matin à Paris en été, 1h en hiver).

Les missions difficiles demandent souvent un deuxième joueur (vol, Marteau Pouet) : teste-les avec le Serveur local à 2 ou 3 joueurs.

## Tester la sauvegarde

Il faut avoir publié le jeu et activé l'accès aux API (voir le README).

1. Joue, achète quelques fantômes, note ton nombre de pièces.
2. Arrête le jeu, attends 5 secondes, relance.
3. Tu dois retrouver tes fantômes et tes pièces, plus un message "Pendant ton absence, tes fantômes ont gagné..." si tu es parti plus d'une minute.

Sans l'accès aux API, la fenêtre Sortie affiche "Mode test : la sauvegarde est désactivée". C'est normal et le jeu fonctionne quand même.

## Tester sur un écran de téléphone

Onglet Test > Appareil (Device), puis choisis un téléphone (iPhone, Galaxy...) dans la liste en haut de la vue 3D. Lance le jeu : les gros boutons doivent rester lisibles et ne pas cacher le joystick ni le bouton de saut. Essaie aussi en mode portrait.
