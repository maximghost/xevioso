class_name LightningAxe
extends Area2D
## La hache de foudre lancée par un Envoyé.
##
## Elle file en ligne droite en tournoyant, et disparaît quand elle touche un mur,
## un ennemi, ou qu'elle a parcouru sa distance maximale.
##
## Couches de collision (Projet → Paramètres → Noms de couches → Physique 2D) :
##   1 = monde (sols, murs)   2 = héros   3 = ennemis   4 = projectiles
## La hache est sur la couche 4 et détecte les couches 1 (monde) et 3 (ennemis).

## Vitesse de vol, en pixels par seconde.
@export var speed: float = 320.0

## Distance maximale avant de disparaître, en pixels.
@export var max_distance: float = 220.0

## Dégâts infligés à un ennemi touché.
@export var damage: int = 1

## Sens du vol : 1 vers la droite, -1 vers la gauche. Fixé par le héros au lancer.
var direction: int = 1

var _travelled: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)
	# La hache tourne dans le sens du lancer.
	$Sprite.flip_h = direction < 0


func _physics_process(delta: float) -> void:
	var step: float = speed * delta
	position.x += direction * step
	_travelled += step
	if _travelled >= max_distance:
		queue_free()


## Appelée quand la hache touche un corps (mur, sol) ou une zone (ennemi).
func _on_hit(target: Node) -> void:
	# Les ennemis exposeront une méthode take_hit() : la hache leur inflige ses dégâts.
	if target.has_method("take_hit"):
		target.take_hit(damage, direction)
	queue_free()
