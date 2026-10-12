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

## Tester la sauvegarde

Il faut avoir publié le jeu et activé l'accès aux API (voir le README).

1. Joue, achète quelques fantômes, note ton nombre de pièces.
2. Arrête le jeu, attends 5 secondes, relance.
3. Tu dois retrouver tes fantômes et tes pièces, plus un message "Pendant ton absence, tes fantômes ont gagné..." si tu es parti plus d'une minute.

Sans l'accès aux API, la fenêtre Sortie affiche "Mode test : la sauvegarde est désactivée". C'est normal et le jeu fonctionne quand même.

## Tester sur un écran de téléphone

Onglet Test > Appareil (Device), puis choisis un téléphone (iPhone, Galaxy...) dans la liste en haut de la vue 3D. Lance le jeu : les gros boutons doivent rester lisibles et ne pas cacher le joystick ni le bouton de saut. Essaie aussi en mode portrait.
