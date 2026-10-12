# Publier ce matin

La version courte. Le détail de chaque étape est dans [PUBLICATION.md](PUBLICATION.md), au numéro de section indiqué. Compte environ une heure si ton compte est déjà vérifié.

Le jeu est prêt : les réglages de test sont coupés, tous les tests passent, et les images sont dans [docs/publication](publication).

## Avant de commencer (5 min)

- [ ] Ton compte Roblox a fait la vérification de l'âge (Paramètres du compte Roblox). Sans ça, Roblox ne te laissera pas rendre le jeu public. Voir section 2.
- [ ] Récupère le fichier `build/StealAGhost.rbxlx` (sur GitHub, branche `claude/funny-ptolemy-nywexs`) et ouvre-le dans Roblox Studio.

## 1. Dernier essai dans Studio (10 min)

- [ ] Onglet Test > Clients et serveurs > 2 joueurs > Démarrer.
- [ ] Achète un fantôme sur le chemin, vole celui de l'autre fenêtre, frappe le voleur avec la batte.
- [ ] Ouvre la boutique : en Studio chaque article affiche "🧪 Gratuit (test)", c'est normal. Dans le vrai jeu ils afficheront "Bientôt" tant que tu n'as pas créé les articles (étape 7).
- [ ] La fenêtre Sortie (Output) ne doit pas montrer de ligne rouge.

## 2. Publier (5 min)

- [ ] Fichier > Publier sur Roblox > Créer une nouvelle expérience.
- [ ] Nom : `[🎃] Steal a Ghost` (enlève le 🎃 après le 3 novembre).

## 3. Paramètres du jeu (10 min), section 3

- [ ] Appareils : Ordinateur, Téléphone, Tablette.
- [ ] 12 joueurs maximum, 2 places réservées pour les amis.
- [ ] Traduction : langue source anglais, traduction automatique activée, nom et description en français ajoutés.

## 4. Questionnaire de maturité (10 min), section 4

- [ ] Creator Hub > ton jeu > Audience > Maturity & Compliance Questionnaire.
- [ ] Réponds "oui" aux objets aléatoires payants (la Roue de la Fortune). C'est obligatoire et le jeu respecte déjà les règles.

## 5. Icône, miniatures, description (10 min), sections 7 et 8

- [ ] Icône : `docs/publication/icone.png`.
- [ ] Miniatures : les 5 fichiers `miniature_*_en.png`, dans l'ordre 1 à 5. Les versions `_fr` vont dans la partie française si le Creator Hub le propose.
- [ ] Description : copie les textes français et anglais de la section 7.

## 6. Mettre en public

- [ ] Creator Hub > ton jeu > rends-le Public.
- [ ] Lance une partie depuis ton téléphone pour vérifier que tout s'affiche bien.

## 7. Plus tard dans la journée : gagner des Robux, section 5

Le jeu tourne sans boutique, rien ne presse. Quand tu as le temps :

- [ ] Crée les 4 Game Passes et les 6 Developer Products. Les images sont prêtes : `pass_*.png` et `produit_*.png`.
- [ ] Crée les badges (section 5 bis) avec les images `badge_*.png`.
- [ ] Dans Studio, ouvre ReplicatedStorage > Shared > Config et colle chaque ID à la ligne qui porte le même nom, puis republie (Fichier > Publier sur Roblox). Envoie-moi aussi les IDs pour que je les mette dans le code, sinon ils seront écrasés à la prochaine mise à jour.

## Les codes promo du lancement

Déjà actifs, tu peux les annoncer :

- `BOUH2026` : 5 000 pièces
- `GLOUTROUILLE` : 10 minutes de revenus
- `POUET` : un Caquetôme offert

## Si quelque chose coince

Fais une capture de la fenêtre Sortie (les lignes rouges) et envoie-la moi. Les erreurs du serveur n'arrêtent plus le jeu : elles s'affichent une fois toutes les 30 secondes et la partie continue.
