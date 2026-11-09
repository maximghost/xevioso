class_name HeroData
extends Resource
## Fiche d'un Envoyé : tout ce qui distingue un héros des autres.
##
## Le corps physique (Player) est commun à toute l'équipe ; ce qui change d'un héros
## à l'autre est décrit ici : son nom, ses animations et sa capacité propre.
## Une fiche par héros : assets/heroes/<nom>/<nom>_data.tres.
## Pour ajouter un héros, on crée une fiche ; on ne touche pas au code du Player.


## Identifiant stable (kodjo, afi...) : sert à la sauvegarde et au déblocage.
## Ne jamais le changer une fois le jeu publié, sinon les sauvegardes ne le reconnaîtront plus.
@export var id: StringName = &""

## Nom affiché (menus, interface).
@export var display_name: String = ""

## Les animations du héros (idle, run, jump, fall, throw, hurt).
@export var frames: SpriteFrames

## La scène de sa capacité propre (Ruée, Pagne-voile...). Vide = pas encore de capacité.
@export var ability_scene: PackedScene

## Vitesse de course, par rapport à celle de l'équipe (1 = normale). Kodjo, le Coureur,
## est plus rapide que les autres.
@export_range(0.5, 2.0, 0.05) var speed_multiplier: float = 1.0
