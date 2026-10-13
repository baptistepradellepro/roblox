# Publier Steal a Ghost

Checklist dans l'ordre. Compte une soirée pour tout faire. Les images (icône, miniatures, Game Pass, produits, badges) sont déjà prêtes dans [docs/publication](publication). Version courte pour un matin : [PUBLIER_DEMAIN.md](PUBLIER_DEMAIN.md).

## 1. Remettre les réglages normaux

Dans `Config.luau`, vérifie que les valeurs de test sont revenues à la normale :

- [ ] `Config.ForceLanguage = nil`
- [ ] `Config.NewPlayerShield = 45`
- [ ] `Config.DayDuration = 480`
- [ ] `Config.RebirthBaseCost = 10000000`
- [ ] `Config.FloorPrice = 50000`
- [ ] `Config.ForceHalloween = false`
- [ ] `Config.ForceWinter = false`

Les tests automatiques vérifient déjà ces valeurs (`lune run tests/run.luau`), mais un coup d'œil ne coûte rien si tu as modifié le fichier à la main.

Puis un dernier test à 3 joueurs (voir [TEST.md](TEST.md)), sans ligne rouge dans la fenêtre Sortie.

## 2. Ton compte créateur

Depuis le 19 mai 2026, Roblox répartit les joueurs par âge : Roblox Kids (5-8 ans), Roblox Select (9-15 ans) et les comptes 16+. Ça change beaucoup de choses pour un jeu qui vise les 9-15 ans.

Pour publier en public (joueurs 16+ dont l'âge a été vérifié) :

- [ ] Compte en règle, créé depuis au moins 2 jours
- [ ] Vérification de l'âge faite (paramètres du compte Roblox)
- [ ] Questionnaire de maturité rempli (étape 4)

Pour que le jeu soit visible par les 9-15 ans (Roblox Select), il faut en plus :

- [ ] Compte créateur vérifié : pièce d'identité si tu as 18 ans ou plus, estimation faciale de l'âge sinon
- [ ] Validation en deux étapes (2-Step Verification) activée sur ton compte
- [ ] Soit des frais par jeu, remboursés automatiquement 90 jours après que le jeu devient éligible (1 000 Robux selon l'annonce Roblox sur le DevForum), soit un abonnement Roblox Plus ou Premium actif depuis au moins 2 mois
- [ ] Passer l'évaluation : un nouveau jeu commence visible uniquement par les 16+, puis Roblox attend qu'un nombre minimum de joueurs "très engagés" y aient joué sur 60 jours (250 selon la doc officielle, 500 selon d'autres sources ; ça bouge) et fait une revue de sécurité. Le suivi se fait dans Creator Hub, tableau de bord "Audience Reach".

Ce que ça veut dire pour un budget de 0 € : les frais sont remboursés, mais il faut les avancer. Le chemin gratuit, c'est de lancer d'abord pour les 16+, de gagner 1 000 Robux avec la boutique (Game Passes, tours de roue, monstres, pack de pièces), puis de payer les frais avec ces Robux. Soyons clairs aussi sur le calendrier : l'évaluation ne sera probablement pas terminée avant le 31 octobre. Halloween se jouera surtout avec les 16+, et les 9-15 ans arriveront pour les mises à jour de novembre.

Ces règles sont récentes et changent souvent : vérifie la page officielle avant de payer quoi que ce soit (liens en bas de page).

## 3. Paramètres du jeu

Dans Studio : Accueil > Paramètres du jeu (Game Settings). Certains réglages sont aussi sur le Creator Hub (create.roblox.com > Creations > ton jeu).

- [ ] **Infos de base** : nom `Steal a Ghost` (pendant l'événement tu peux mettre `[🎃] Steal a Ghost`, c'est l'usage sur Roblox, à retirer après le 3 novembre). Description : voir la section 7.
- [ ] **Genre** : le plus proche de "Simulation" / "Tycoon" dans la liste proposée.
- [ ] **Appareils** : Ordinateur, Téléphone, Tablette. Laisse Console et VR décochés pour l'instant (l'interface n'est pas pensée pour la manette).
- [ ] **Places** : 12 joueurs maximum (une base par joueur). Pour le remplissage des serveurs, choisis "Personnaliser" et réserve 2 places : un ami pourra toujours te rejoindre, et le bonus amis +10 % prend tout son sens.
- [ ] **Serveurs privés** : gratuits au lancement, pour pousser à jouer entre amis. Tu pourras les rendre payants plus tard si le jeu décolle.
- [ ] **Sécurité** : "Enable Studio Access to API Services" activé. "Allow HTTP Requests" désactivé (inutile ici).
- [ ] **Communication** : chat activé, système standard de Roblox (TextChatService, déjà réglé dans le fichier).
- [ ] **Avatar** : laisse les réglages par défaut (R15).
- [ ] **Traduction** (Creator Hub > ton jeu > Localization) : langue source **anglais**, active la traduction automatique pour les autres langues. Les joueurs francophones voient déjà le jeu en français grâce au code, les autres le voient en anglais, et Roblox traduit l'anglais vers l'espagnol, le portugais, l'allemand, etc. Ajoute aussi le nom et la description en français dans la partie "Experience Information".

## 4. Questionnaire de maturité

Creator Hub > Creations > ton jeu > Audience > Maturity & Compliance Questionnaire. Réponds toujours selon le contenu le plus fort qu'un joueur peut rencontrer. Pour Steal a Ghost :

- **Violence** : des armes cartoon (batte, marteau en caoutchouc, balai, aspirateur) qui repoussent les voleurs, sans dégât, sans barre de vie et sans sang. Les monstres cartoon renvoient seulement les joueurs chez eux. Réponds "violence légère / non réaliste, répétée" si la question le propose.
- **Peur** : la Nuit Hantée a une ambiance sombre et une poursuite avec battements de cœur. C'est de la peur légère et occasionnelle, à déclarer comme telle.
- **Sang, humour vulgaire, romance, alcool, drogues, jeux d'argent** : non.
- **Objets aléatoires payants** : **oui**. La Roue de la Fortune vend des tours avec des Robux. Le jeu respecte déjà les règles de Roblox : chances de chaque case affichées en % avant l'achat, total de 100 %, chaque case fait gagner quelque chose, et achat bloqué automatiquement pour les joueurs où c'est interdit (PolicyService, par exemple au Brésil). Déclare-le honnêtement : un oubli peut faire retirer le jeu.
- **Lieu de rencontre (social hangout), création libre, texte libre** : non (seulement le chat standard de Roblox).

Avec les armes, le résultat attendu est plutôt le label **Mild** (léger). Il reste accepté pour Roblox Select (9-15 ans). Vérifie le résultat affiché à la fin du questionnaire.

## 5. Monétisation (gratuite à créer)

Le jeu tourne sans. Tant qu'un ID vaut 0, l'article affiche "Bientôt" dans le vrai jeu, et "🧪 Gratuit (test)" dans Studio pour que tu puisses tout essayer.

Pour créer un article : Creator Hub > Creations > Steal a Ghost > Monetization.

- **Game Pass** (acheté une fois, gardé pour toujours) : Passes > Create a Pass. Image carrée 512×512 : prends `docs/publication/pass_<nom>.png` (par exemple `pass_DoubleCoins.png`), puis nom et description. Une fois créé, ouvre-le > Sales > mets-le en vente et choisis le prix.
- **Developer Product** (peut être acheté plusieurs fois) : Developer Products > Create. Nom, image (`docs/publication/produit_<nom>.png`), prix.
- Copie ensuite l'ID de chaque article (le nombre dans l'adresse de la page) dans `Config.luau`, à la ligne qui porte le même nom, puis republie le jeu.

| Article | Type | Ligne dans Config | Prix conseillé |
|---|---|---|---|
| x2 Pièces | Game Pass | `GamePasses.DoubleCoins` | 149 R$ |
| Marteau Pouet Géant | Game Pass | `GamePasses.WeaponHammer` | 99 R$ |
| Balai de Sorcière | Game Pass | `GamePasses.WeaponBroom` | 149 R$ |
| Aspira-Fantôme | Game Pass | `GamePasses.WeaponVacuum` | 199 R$ |
| 1 tour de roue | Developer Product | `Products.Spin1` | 25 R$ |
| 5 tours de roue | Developer Product | `Products.Spin5` | 99 R$ |
| Lâcher Gloutrouille | Developer Product | `Products.MonsterGloutrouille` | 39 R$ |
| Lâcher la Chauve-Souris Turbo | Developer Product | `Products.MonsterBat` | 59 R$ |
| Lâcher Mamie Toile | Developer Product | `Products.MonsterSpider` | 79 R$ |
| Pack de pièces | Developer Product | `Products.CoinPack` | 25 R$ |

### Noms et descriptions à copier

Mets l'anglais dans les champs principaux. Si la page Localization du Creator Hub propose les Passes et les Developer Products, ajoute le français.

**Game Passes**

| Pass | Nom (EN) | Description (EN) | Nom (FR) | Description (FR) |
|---|---|---|---|---|
| DoubleCoins | x2 Coins | Your ghosts make twice as many coins, forever. | x2 Pièces | Tes fantômes fabriquent deux fois plus de pièces, pour toujours. |
| WeaponHammer | Giant Squeaky Hammer | Longer reach than the bat, knocks thieves back harder and goes SQUEAK! The thief drops your ghost. | Marteau Pouet Géant | Plus long que la batte, il repousse les voleurs plus fort et fait POUET ! Le voleur lâche ton fantôme. |
| WeaponBroom | Witch Broom | One big sweep hits every thief around you at once. Perfect when your base gets crowded. | Balai de Sorcière | Un grand coup de balai qui touche tous les voleurs autour de toi d'un coup. Idéal quand ta base est envahie. |
| WeaponVacuum | Ghost Vacuum | The longest reach in the game: suck your stolen ghost back from far away before the thief gets home. | Aspira-Fantôme | La plus longue portée du jeu : aspire ton fantôme volé de très loin, avant que le voleur arrive chez lui. |

**Developer Products**

| Produit | Nom (EN) | Description (EN) | Nom (FR) | Description (FR) |
|---|---|---|---|---|
| Spin1 | 1 Wheel Spin | Spin the Wheel of Fortune once. Every slot wins something: coins, ghosts or a x2 boost. | 1 tour de roue | Fais tourner la Roue de la Fortune une fois. Chaque case fait gagner quelque chose : pièces, fantômes ou bonus x2. |
| Spin5 | 5 Wheel Spins | 5 spins of the Wheel of Fortune for the price of 4. | 5 tours de roue | 5 tours de la Roue de la Fortune pour le prix de 4. |
| MonsterGloutrouille | Release Gloutrouille | The hungry jelly pumpkin chases everyone in the server for 40 seconds. Except you! | Lâcher Gloutrouille | La citrouille en gelée affamée poursuit tout le serveur pendant 40 secondes. Sauf toi ! |
| MonsterBat | Release the Turbo Bat | Small, but way too fast. It chases everyone in the server for 30 seconds. Except you! | Lâcher la Chauve-Souris Turbo | Petite, mais beaucoup trop rapide. Elle poursuit tout le serveur pendant 30 secondes. Sauf toi ! |
| MonsterSpider | Release Granny Web | A giant spider with glasses who throws her web from far away, for 45 seconds. Everyone runs, except you! | Lâcher Mamie Toile | Une araignée géante à lunettes qui lance sa toile de loin, pendant 45 secondes. Tout le monde court, sauf toi ! |
| CoinPack | Coin Pack | 10 minutes of your income right now (at least 5,000 coins). | Pack de pièces | 10 minutes de tes revenus tout de suite (5 000 pièces minimum). |

Les prix conseillés sont aussi dans `Shop.luau`, avec les noms et descriptions affichés en jeu. Le prix qui compte est celui que tu mets sur le Creator Hub : la boutique le lit toute seule une fois l'ID renseigné.

Pour afficher des images dans la boutique (armes, monstres, roue) à la place des emojis : importe les fichiers `docs/publication/boutique_*.png` (fond transparent) sur le Creator Hub comme décalcomanies (Decals), puis colle `"rbxassetid://ID"` dans `Config.ShopIcons`, à la ligne qui porte le même nom. C'est facultatif.

Roblox garde environ 30 % de chaque vente.

Ce qui reste juste pour les joueurs qui ne paient pas :
- les armes Robux servent seulement à défendre (on ne peut pas frapper en portant un fantôme volé), et la batte gratuite fait la même chose en un peu moins bien ;
- les monstres payants ne prennent jamais de pièces et n'entrent pas dans les bases. Seul avantage pour l'acheteur : le monstre ne le poursuit pas pendant 30 à 45 secondes ;
- la roue donne des pièces, des fantômes ou un bonus de revenus, qu'on peut aussi obtenir en jouant.

## 5 bis. Badges (facultatif)

Les badges s'affichent sur le profil des joueurs, leurs amis les voient : c'est de la pub gratuite. Le jeu en prévoit 7 : Bienvenue, Premier vol, Premier Mythique, Premier Secret, Premier rebirth, Fantômédex complet et Défis de la semaine.

1. Creator Hub > Creations > Steal a Ghost > Engagement > Badges > Create a Badge.
2. L'image : `docs/publication/badge_<nom>.png` (par exemple `badge_FirstSteal.png`), puis un nom et une description. Roblox affiche les badges dans un rond, les images sont prévues pour.
3. Copie l'ID du badge dans `Config.Badges`, à la ligne qui correspond.

| Badge | Image | Nom (EN) | Description (EN) | Nom (FR) | Description (FR) |
|---|---|---|---|---|---|
| Welcome | `badge_Welcome.png` | Welcome, Ghost Hunter! | You played Steal a Ghost for the first time. Now go fill your base! | Bienvenue, chasseur de fantômes ! | Tu as joué à Steal a Ghost pour la première fois. Maintenant, remplis ta base ! |
| FirstSteal | `badge_FirstSteal.png` | First Heist | You stole a ghost and made it back to your base. Sneaky! | Premier vol | Tu as volé un fantôme et tu l'as ramené jusqu'à ta base. Bien joué, petit malin ! |
| FirstMythic | `badge_FirstMythic.png` | Mythic Collector | You got your first Mythic ghost. Very few players have one! | Collectionneur Mythique | Tu as eu ton premier fantôme Mythique. Très peu de joueurs en ont un ! |
| FirstSecret | `badge_FirstSecret.png` | Secret Found | You found a Secret ghost. Shhh, don't tell anyone where! | Secret découvert | Tu as trouvé un fantôme Secret. Chut, ne dis à personne où ! |
| FirstRebirth | `badge_FirstRebirth.png` | Reborn | You did your first rebirth. Your ghosts will make more coins, forever. | Renaissance | Tu as fait ton premier rebirth. Tes fantômes rapporteront plus de pièces, pour toujours. |
| IndexComplete | `badge_IndexComplete.png` | Ghostdex Master | You completed the Ghostdex. You have met every ghost in town! | Maître du Fantômédex | Tu as complété le Fantômédex. Tu as rencontré tous les fantômes de la ville ! |
| WeeklyChallenges | `badge_WeeklyChallenges.png` | Weekly Champion | You completed all 3 challenges of the week. | Champion de la semaine | Tu as réussi les 3 défis de la semaine. |

Roblox laisse créer quelques badges gratuitement chaque jour, les suivants coûtent des Robux : vérifie le prix affiché avant de valider. Tant qu'un ID vaut 0, le badge est simplement ignoré.

## 6. Codes promo

Les codes sont dans `Config.Codes` (fichier `Config.luau`). Avant de publier, remplace les codes d'exemple par les tiens : si ton dépôt GitHub est public, n'importe qui peut les lire dans le fichier.

Tu peux annoncer les codes sur TikTok, mais le jeu lui-même ne doit pas parler de TikTok ni d'aucun autre site : Roblox interdit de renvoyer les joueurs hors de la plateforme, surtout les plus jeunes. C'est pour ça que la boutique dit seulement "Codes secrets". Pour qu'un code arrête de marcher à une date précise, renseigne `Expires` (temps Unix).

## 7. Description du jeu (prête à copier)

Pas de lien externe, c'est interdit. Les emojis sont l'usage sur Roblox et aident les jeunes joueurs à lire vite. Roblox limite la description à 1 000 caractères : ces versions en font environ 840 (français) et 770 (anglais). Après le 3 novembre, supprime la ligne 🎃.

**Français**

```
Achète des fantômes complètement absurdes, pose-les dans ta base et ramasse les pièces qu'ils fabriquent. Mais les autres joueurs peuvent entrer chez toi et repartir avec tes fantômes !

👻 Plus de 40 fantômes à collectionner, dont des Dorés, des Arc-en-ciel et des Secrets
🦹 Vole ceux des autres et cours jusqu'à ta base
🏏 Un voleur chez toi ? Un coup de batte et il lâche tout
🍌 Piège ta base : peau de banane, toile d'araignée, alarme
🔒 Verrouille ta base au bon moment
🌙 Toutes les 10 minutes, la Nuit Hantée... et Gloutrouille qui te poursuit
🎡 La Roue de la Fortune au milieu de la map
🎃 Fantômes Halloween en édition limitée jusqu'au 3 novembre
🎁 Un cadeau et 3 missions par jour, 3 défis par semaine
🎉 Pièces x2 tout le week-end
👥 +10 % de pièces pour chaque ami dans ton serveur
🏆 Deviens le plus grand voleur de la semaine
```

**English**

```
Buy totally ridiculous ghosts, put them in your base and collect the coins they make. But other players can sneak in and run away with your ghosts!

👻 40+ ghosts to collect, including Golden, Rainbow and Secret ones
🦹 Steal other players' ghosts and run back to your base
🏏 Thief in your base? One swing of your bat and they drop everything
🍌 Trap your base: banana peel, spider web, alarm
🔒 Lock your base at the right moment
🌙 Every 10 minutes, the Haunted Night... and Gloutrouille chasing you
🎡 The Wheel of Fortune in the middle of the map
🎃 Limited Halloween ghosts until November 3
🎁 A free gift and 3 missions every day, 3 challenges every week
🎉 x2 coins all weekend
👥 +10% coins for each friend in your server
🏆 Become the top thief of the week
```

## 8. Icône et miniatures (déjà prêtes)

Tout est dans [docs/publication](publication), fait à partir des vrais modèles du jeu (les miniatures doivent montrer le vrai jeu, sinon Roblox les refuse).

- **Icône** : `icone.png` (512×512). Le Roi Patatôme porté par un voleur, et le nom du jeu.
- **Miniatures** (1920×1080), en anglais (`_en`) et en français (`_fr`) :
  1. `miniature_1_vol` : un voleur s'enfuit avec un fantôme, le propriétaire le poursuit avec sa batte
  2. `miniature_2_nuit` : Gloutrouille poursuit un joueur pendant la Nuit Hantée
  3. `miniature_3_collection` : une partie des fantômes à collectionner
  4. `miniature_4_halloween` : les 4 fantômes Halloween (à retirer après le 3 novembre)
  5. `miniature_5_defense` : un voleur glisse sur une peau de banane dans une base piégée

Où les mettre : Creator Hub > Creations > ton jeu > Places > ta place principale > Thumbnails pour les miniatures, et Experience Information pour l'icône. Mets les versions `_en` par défaut. Si la page Localization du Creator Hub te propose des images par langue, ajoute les versions `_fr` pour le français.

Pour les refaire après un changement de modèle : `lune run tools/export_scene.luau scene.json`, puis `python3 tools/render_publication.py scene.json docs/publication` (une vingtaine de minutes).

## 9. Mise en ligne

- [ ] Fichier > Publier sur Roblox
- [ ] Creator Hub > ton jeu > rends-le Public
- [ ] Joue une partie depuis l'application Roblox de ton téléphone pour vérifier
- [ ] Dans les jours qui suivent, regarde Creator Hub > Analytics : rétention à 1 jour, durée des sessions, nombre de joueurs simultanés. Et "Audience Reach" pour suivre l'accès aux 9-15 ans.

## Sources (règles 2026)

- [Roblox Kids and Select, doc officielle](https://create.roblox.com/docs/production/publishing/kids-and-select) et [sa version sur GitHub](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/kids-and-select.md)
- [Annonce du lancement mondial de Kids et Select (DevForum)](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717)
- [Labels de maturité (doc officielle)](https://create.roblox.com/docs/production/promotion/content-maturity)
- [Ce que les familles doivent savoir sur Kids et Select (Roblox Newsroom, mai 2026)](https://about.roblox.com/newsroom/2026/05/what-families-should-know-roblox-kids-select)
- [Icônes de jeu (doc officielle)](https://create.roblox.com/docs/production/promotion/game-icons)
- [Objets aléatoires payants : règles clarifiées (DevForum)](https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622) et [Community Standards de Roblox](https://about.roblox.com/community-standards)
