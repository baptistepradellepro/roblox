# Publier Steal a Ghost

Checklist dans l'ordre. Compte une soirée pour tout faire, hors création des images.

## 1. Remettre les réglages normaux

Dans `Config.luau`, vérifie que les valeurs de test sont revenues à la normale :

- [ ] `Config.ForceLanguage = nil`
- [ ] `Config.NewPlayerShield = 120`
- [ ] `Config.DayDuration = 480`
- [ ] `Config.RebirthBaseCost = 5000000`
- [ ] `Config.FloorPrice = 25000`
- [ ] `Config.ForceHalloween = false`

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

Ce que ça veut dire pour un budget de 0 € : les frais sont remboursés, mais il faut les avancer. Le chemin gratuit, c'est de lancer d'abord pour les 16+, de gagner 1 000 Robux avec les Game Passes et le pack de pièces, puis de payer les frais avec ces Robux. Soyons clairs aussi sur le calendrier : l'évaluation ne sera probablement pas terminée avant le 31 octobre. Halloween se jouera surtout avec les 16+, et les 9-15 ans arriveront pour les mises à jour de novembre.

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

- **Violence** : un marteau en caoutchouc qui fait "pouet", sans dégât ni sang, et un monstre cartoon qui renvoie les joueurs chez eux. Réponds "violence légère / non réaliste" si la question le propose.
- **Peur** : la Nuit Hantée a une ambiance sombre et une poursuite avec battements de cœur. C'est de la peur légère et occasionnelle, à déclarer comme telle.
- **Sang, humour vulgaire, romance, alcool, drogues, jeux d'argent** : non.
- **Objets aléatoires payants (loot boxes)** : non. Le pack de pièces donne toujours la même chose.
- **Lieu de rencontre (social hangout), création libre, texte libre** : non (seulement le chat standard de Roblox).

Le résultat attendu est le label **Minimal** (au pire Mild). Les deux sont acceptés pour Roblox Select.

## 5. Monétisation (optionnelle, gratuite à créer)

Le jeu tourne sans. Si tu veux l'activer :

1. Creator Hub > Creations > Steal a Ghost > Monetization > Passes > Create a Pass.
2. Pass "x2 Pièces" : image carrée 512×512, description "Double tous tes revenus, pour toujours". Une fois créé, ouvre-le > Sales > mets-le en vente. Prix conseillé : 149 Robux.
3. Pass "Verrou+" : description "Verrou de 75 s au lieu de 45 s". Prix conseillé : 79 Robux.
4. Monetization > Developer Products > Create : "Pack de pièces", prix conseillé 25 Robux.
5. Copie chaque ID (le nombre dans l'adresse de la page) dans `Config.luau` : `Config.GamePasses.DoubleCoins`, `Config.GamePasses.LongLock`, `Config.Products.CoinPack`.
6. Republie le jeu.

Roblox garde environ 30 % de chaque vente. Rien de ce qu'on vend n'aide à voler.

## 6. Codes promo

Les codes sont dans `Config.Codes` (fichier `Config.luau`). Avant de publier, remplace les codes d'exemple par les tiens : si ton dépôt GitHub est public, n'importe qui peut les lire dans le fichier.

Tu peux annoncer les codes sur TikTok, mais le jeu lui-même ne doit pas parler de TikTok ni d'aucun autre site : Roblox interdit de renvoyer les joueurs hors de la plateforme, surtout les plus jeunes. C'est pour ça que la boutique dit seulement "Codes secrets". Pour qu'un code arrête de marcher à une date précise, renseigne `Expires` (temps Unix).

## 7. Description du jeu (prête à copier)

Pas de lien externe, c'est interdit. Les emojis sont l'usage sur Roblox et aident les jeunes joueurs à lire vite.

**Français**

```
Achète des fantômes complètement absurdes, pose-les dans ta base et ramasse les pièces qu'ils fabriquent. Mais les autres joueurs peuvent entrer chez toi et repartir avec tes fantômes !

👻 36 fantômes à collectionner : Drap Mou, Caquetôme, DJ Bouh-Boum, Méga Bouh Cosmique...
✨ Fantômes Dorés (x3) et Arc-en-ciel (x5) ultra rares
🦹 Vole les fantômes des autres et cours jusqu'à ta base
🔨 Un voleur passe près de toi ? Marteau Pouet !
🔒 Verrouille ta base au bon moment
🏰 Achète un 2e étage pour 10 fantômes de plus
🌙 Toutes les 10 minutes, la Nuit Hantée : Brouillard, Bonbons... et Gloutrouille qui te poursuit
🔥 Super Nuit chaque samedi soir : Gloutrouille GÉANT et Mythique garanti
🎃 Fantômes Halloween en édition limitée jusqu'au 3 novembre
🏆 Deviens le plus grand voleur de la semaine
🎉 Pièces x2 tout le week-end
♻️ Rebirth pour gagner plus, pour toujours
👥 +10 % de pièces par ami dans ton serveur
🎁 Un cadeau et 3 missions chaque jour
📖 Complète le Fantômédex pour +10 % de revenus
```

**English**

```
Buy totally ridiculous ghosts, put them in your base and collect the coins they make. But other players can sneak in and run away with your ghosts!

👻 36 ghosts to collect: Floppy Sheet, Cluck-a-Boo, DJ Boo-Boom, Cosmic Mega Boo...
✨ Ultra rare Golden (x3) and Rainbow (x5) ghosts
🦹 Steal other players' ghosts and run back to your base
🔨 Thief nearby? BONK them!
🔒 Lock your base at the right moment
🏰 Buy a 2nd floor for 10 more ghosts
🌙 Every 10 minutes, the Haunted Night: Fog, Candy... and Gloutrouille chasing you
🔥 Super Night every Saturday evening: GIANT Gloutrouille and a guaranteed Mythic
🎃 Limited Halloween ghosts until November 3
🏆 Become the top thief of the week
🎉 x2 coins all weekend
♻️ Rebirth to earn more, forever
👥 +10% coins for each friend in your server
🎁 A free gift and 3 missions every day
📖 Complete the Ghostdex for +10% income
```

## 8. Icône et miniatures à créer

**Icône** (carrée, 512×512 minimum) : elle s'affiche parfois en 150×150, donc une seule idée qui se lit de loin. Proposition : le Méga Bouh Cosmique en très gros plan, une main de personnage Roblox qui l'attrape, fond orange et violet. Pas de petit texte, au maximum un mot énorme ("STEAL").

**Miniatures** (1920×1080, format 16:9, jusqu'à 10) : fais-en au moins 3. Garde le texte important loin du bas de l'image, Roblox y affiche le nombre de joueurs.

1. Le vol : un joueur qui court, surligné en rouge, un fantôme Légendaire au-dessus de la tête, le propriétaire derrière lui. Texte : "VOLE-LE !" / "STEAL IT!"
2. La Nuit Hantée : Gloutrouille en gros plan qui poursuit un joueur sur le chemin violet.
3. Une base pleine de fantômes brillants avec des pièces qui volent.
4. Bonus : la rangée des fantômes Halloween avec "ÉDITION LIMITÉE".

Comment les faire gratuitement :

1. Lance le jeu dans Studio à 2 ou 3 joueurs et mets en scène le moment voulu.
2. Pour cacher l'interface : dans la fenêtre du joueur, Explorateur > Players > ton joueur > PlayerGui, décoche "Enabled" sur SAG_HUD et SAG_Panels.
3. Place la caméra avec la caméra libre (Maj+P en mode test, si ton compte la propose), puis fais une capture d'écran (Windows : Win+Maj+S, Mac : Cmd+Maj+4).
4. Ajoute le texte et recadre en 1920×1080 avec un outil gratuit dans le navigateur, comme Photopea ou la version gratuite de Canva.

Les miniatures doivent montrer le vrai jeu : Roblox refuse les images trompeuses.

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
