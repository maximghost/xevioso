# Portfolio — Yaovi Joël Maxim Tokinlo

## Structure du projet

```
portfolio/
├── index.html            → structure de la page (une seule page qui scrolle)
├── css/
│   └── style.css         → tout le style
├── js/
│   ├── data.js            → LE fichier à modifier : compétences, projets, certificats
│   └── main.js             → moteur de rendu + interactions (pas besoin d'y toucher)
├── certificates/          → dépose ici tes scans de certificats (images)
└── assets/projects/       → dépose ici tes captures d'écran de projets
```

## Pour ajouter du contenu

Ouvre **js/data.js** et suis les instructions en commentaire en haut du fichier.
C'est le seul fichier que tu dois modifier pour :
- ajouter une compétence,
- ajouter un projet,
- ajouter un certificat (obtenu ou en cours).

Les images (`certificates/xxx.jpg`, `assets/projects/xxx.jpg`) peuvent être
ajoutées plus tard : tant qu'un champ `image` est vide (`""`), une vignette
de remplacement s'affiche automatiquement, rien ne casse.

## Pour héberger gratuitement (GitHub Pages)

1. Crée un dépôt GitHub, par exemple `portfolio`.
2. Mets tout le contenu de ce dossier (`index.html`, `css/`, `js/`, etc.)
   à la racine du dépôt.
3. Va dans **Settings → Pages**, choisis la branche `main` et le dossier
   `/root`, puis sauvegarde.
4. Ton portfolio est en ligne à une adresse du type
   `https://ton-pseudo.github.io/portfolio/`.
