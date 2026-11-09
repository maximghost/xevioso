# Xɛvioso : les Envoyés de la foudre

Jeu de plateforme 2D en pixel art, développé avec **Godot 4.7**, pensé d'abord pour le
web (ordinateur et mobile en paysage), puis pour le Play Store et l'App Store.

Au pays des collines rouges, un sanctuaire gardait la Pierre de foudre, don de Xɛvioso,
divinité du tonnerre. Une nuit, **Adaka**, le Mangeur de pluie (« adaka » : la méchanceté,
en fon), l'arrache : elle se brise en éclats, les sokpe, et il avale les nuages. Depuis,
les malheurs s'enchaînent. Xɛvioso choisit ses Envoyés pour reprendre son pouvoir, étape
par étape, de leur village jusqu'au ciel d'orage. Les deux premiers sont désignés par sa
foudre : Kodjo reçoit la Ruée et la vitesse, Afi le pagne volant et la sagesse. Première
étape : ramener la pluie pour soulager le village et sauver les récoltes.

À la fin de la première partie, une scène annonce la suite : la nuit après la pluie, une lueur
rouge au-dessus de la forêt, la carte du voyage à la manière des tentures d'Abomey, le vieil
iroko malade dont le tronc bat d'une lueur de colère, et un tambour qui gronde sous les arbres.
Partie 2 : la forêt des irokos.

## Origine du projet

Xɛvioso est la reprise en solo de **Harvest World**, un jeu 2D réalisé avec Godot dans le
cadre d'un projet d'équipe à l'IFRI (cinq étudiants). J'y avais conçu les mouvements du
personnage et son armement. Ce dépôt repart uniquement de mon propre travail, avec un
nouveau gameplay, cinq héros, un nouvel univers et un nouveau décor.

## La voix de Xɛvioso

Xɛvioso n'apparaît jamais sous forme humaine : c'est une voix venue de l'orage, représentée
par son emblème, la hache double. Il ouvre la partie et guide les Envoyés par des paroles
énigmatiques, accompagnées d'une aide discrète aux commandes. Ses paroles sont réunies dans
`scripts/story/voices.gd`.

## Vies

Trois cœurs ; perdre tous ses cœurs coûte une vie (on repart de la dernière stèle).
Deux vies par niveau : à la seconde, c'est la fin de la partie. Xɛvioso fait trembler la
terre, la foudre tombe sans une goutte de pluie, et l'on reprend le niveau depuis le début :
les sokpe ramassés pendant la tentative et la charge de foudre sont remis en jeu.
Tomber dans le vide coûte un cœur.

## Les Envoyés

| Héros | Capacité |
|---|---|
| Kodjo, le Coureur | **Ruée** : un bond horizontal fulgurant, invulnérable |
| Afi, la Tisseuse | **Pagne-voile** : plane en tenant son pagne au-dessus d'elle |
| Yawa, de la lagune | **Perche-filet** : s'accroche aux pieux et se balance |
| Abla, la Forgeronne | **Marteau** : brise les blocs fragiles, piqué dévastateur |
| Kokou, le Tambourinaire | **Onde** : une onde de choc qui sonne les ennemis alentour |

Tous les Envoyés partagent un pouvoir de circonstance, **la foudre de Xɛvioso** :
chaque pierre sokpe ramassée remplit un cran de la jauge ; à quatre, la foudre peut
tomber du ciel sur les deux ennemis les plus proches à portée et les vaincre d'un coup.

Kodjo et Afi sont disponibles dès le début ; les trois autres rejoignent l'équipe en cours
de route. Tous lancent la hache de foudre.

## Commandes

| Action | Clavier | Manette | Mobile |
|---|---|---|---|
| Se déplacer | A / D ou ← → (Q / D en AZERTY) | Stick gauche, croix | Croix (pouce gauche) |
| Sauter | Espace, W ou ↑ (Z en AZERTY) | A | Bouton saut ou flèche haut |
| Hache de foudre | J ou clic gauche | X | Bouton hache |
| Capacité du héros | K ou clic droit (à maintenir : Pagne-voile, Perche) | B | Bouton éclair |
| Changer de héros | Tab | RB | Bouton flèches |
| Foudre de Xɛvioso (4 pierres sokpe) | L | — | Bouton violet (apparaît quand la foudre est prête) |
| Pause | Échap | Start | Bouton pause |

## Le village (région 1, niveau 1)

Neuf passages aux défis variés : sauts sur les planches des greniers, haies d'épines
d'acacia, dalles de terre sèche qui s'effritent, nuées de criquets, termitières cracheuses,
un grand vide à franchir avec la Ruée ou le Pagne-voile, l'énigme du portail du chef
(viser le tambour à travers une fente de la falaise), les nacelles du puits et les séchoirs.
Huit pierres sokpe, dont une qu'on ne peut atteindre qu'en revenant avec Abla. Au bout,
l'autel de la foudre : la pluie revient et le village refleurit.

## Le son

Tout l'audio est original, calculé par des scripts Python (`tools/audio/`) : aucun
échantillon extérieur.

- **Musiques**, sur des rythmes du sud du Bénin :
  - la cloche gankogui joue la « ligne du temps » à 7 frappes ; le hochet axatsɛ et les
    tambours kaganu, kidi, sogo et atsimevu lui répondent ;
  - **agbadja** pour le village ;
  - **zinli** (jarre frappée, lent et grave) pour les malheurs ;
  - **tchinkoumé** (tambour d'eau) pour la saison des pluies ;
  - les mélodies sont jouées à l'agidigbo (lamellophone) et par des voix en appel et réponse.
- **Morceaux** : titre, village, fête de la pluie, quatre ambiances de la scène d'ouverture,
  et deux jingles (victoire, fin de partie).
- **Bruitages** : 75 sons. Pas, saut, réception, hache, Ruée, pagne, coups, ennemis,
  sokpe, foudre, stèles, plateformes, interface, scène d'ouverture.
- **Ambiances** : vent sec, village, pluie, nuit, feu, vent d'orage.
- **Volume** : trois réglages dans le menu pause (Musique, Bruitages, Ambiances), gardés
  d'une partie à l'autre.

Régénérer les sons :
`python3 tools/audio/sfx.py assets/audio` et `python3 tools/audio/music.py assets/audio`
(Python 3, numpy, scipy, pyloudnorm, ffmpeg).

## Structure

```
assets/       images : héros, ennemis, décor, tuiles, arrière-plans, interface ;
              audio/ : musiques, bruitages, ambiances
scenes/
  heroes/     le héros (player) et les capacités des cinq Envoyés
  enemies/    les ennemis : Motte sèche, Criquet, Termitière cracheuse
  props/      éléments du décor : stèles, pierres sokpe, pieux, blocs et dalles fragiles,
              nacelles, portail et tambour, épines, autels
  levels/     les niveaux (script commun level.gd, village/, terrain d'essai)
  fx/         effets : hache, onde, météo
  ui/         écran titre, interface en jeu, menus, contrôles tactiles
scripts/core/ services globaux : Game (progression, sauvegarde), Audio, Display, Fx, Health
tools/audio/  générateurs des musiques et des bruitages (Python)
```

L'export web est automatique : à chaque `git push` sur `main`, GitHub Actions exporte le jeu
et publie le résultat sur la branche `web`, que Vercel met en ligne.

## Droits

© 2026 Maxim Tokinlo — Ghost.Technologies. Tous droits réservés.
Le code et les ressources de ce dépôt ne sont pas sous licence libre.
