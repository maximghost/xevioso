# Xɛvioso : les Envoyés de la foudre

Jeu de plateforme 2D en pixel art, développé avec **Godot 4.7**, pensé d'abord pour le
web (ordinateur et mobile en paysage), puis pour le Play Store et l'App Store.

La pluie a disparu : le Mangeur de Pluie l'a volée. Cinq Envoyés de Xɛvioso, divinité
de la foudre, partent la reprendre, de leur village jusqu'au ciel d'orage, en
rassemblant les pierres sokpe tombées du ciel.

## Origine du projet

Xɛvioso est la reprise en solo de **Harvest World**, un jeu 2D réalisé avec Godot dans le
cadre d'un projet d'équipe à l'IFRI (cinq étudiants). J'y avais conçu les mouvements du
personnage et son armement. Ce dépôt repart uniquement de mon propre travail, avec un
nouveau gameplay, cinq héros, un nouvel univers et un nouveau décor.

## Les Envoyés

| Héros | Capacité |
|---|---|
| Kodjo, le Coureur | **Ruée** : un bond horizontal fulgurant, invulnérable |
| Afi, la Tisseuse | **Pagne-voile** : plane en tenant son pagne au-dessus d'elle |
| Yawa, de la lagune | **Perche-filet** : s'accroche aux pieux et se balance |
| Abla, la Forgeronne | **Marteau** : brise les blocs fragiles, piqué dévastateur |
| Kokou, le Tambourinaire | **Onde** : une onde de choc qui sonne les ennemis alentour |

Kodjo et Afi sont disponibles dès le début ; les trois autres rejoignent l'équipe en cours
de route. Tous lancent la hache de foudre.

## Commandes

| Action | Clavier | Manette | Mobile |
|---|---|---|---|
| Se déplacer | A / D ou ← → (Q / D en AZERTY) | Stick gauche, croix | Croix (pouce gauche) |
| Sauter | Espace, W ou ↑ (Z en AZERTY) | A | Bouton saut ou flèche haut |
| Descendre d'une plateforme | Bas + saut | Bas + A | Bas + saut |
| Hache de foudre | J ou clic gauche | X | Bouton hache |
| Capacité du héros | K ou clic droit (à maintenir : Pagne-voile, Perche) | B | Bouton éclair |
| Changer de héros | Tab | RB | Bouton flèches |
| Pause | Échap | Start | Bouton pause |

## Structure

```
assets/       images : héros, ennemis, décor, tuiles, arrière-plans, interface
scenes/
  heroes/     le héros (player) et les capacités des cinq Envoyés
  enemies/    les ennemis (la Motte sèche)
  props/      éléments du décor : stèles, pierres sokpe, pieux, blocs fragiles, autels
  levels/     les niveaux (script commun level.gd, village/, terrain d'essai)
  fx/         effets : hache, onde, météo
  ui/         écran titre, interface en jeu, menus, contrôles tactiles
scripts/core/ services globaux : Game (progression, sauvegarde), Display, Fx, Health
```

L'export web est automatique : à chaque `git push` sur `main`, GitHub Actions exporte le jeu
et publie le résultat sur la branche `web`, que Vercel met en ligne.

## Droits

© 2026 Maxim Tokinlo — Ghost.Technologies. Tous droits réservés.
Le code et les ressources de ce dépôt ne sont pas sous licence libre.
