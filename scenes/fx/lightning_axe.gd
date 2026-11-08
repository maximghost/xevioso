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
@export var speed: float = 380.0

## Distance maximale avant de disparaître, en pixels.
@export var max_distance: float = 220.0

## Dégâts infligés à un ennemi touché.
@export var damage: int = 1

## Sens du vol : 1 vers la droite, -1 vers la gauche. Fixé par le héros au lancer.
var direction: int = 1

var _travelled: float = 0.0

# Vrai dès que la hache a touché quelque chose : un seul coup par hache, même si elle
# touche deux choses dans la même image (le corps et la zone d'un ennemi, par exemple).
var _spent: bool = false


func _ready() -> void:
	_add_trail()
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


## Appelée quand la hache touche un corps (mur, sol, ennemi) ou une zone (Hitbox d'ennemi).
func _on_hit(target: Node) -> void:
	if _spent:
		return
	_spent = true
	var victim := _find_damageable(target)
	if victim != null:
		victim.take_hit(damage, direction)
		# Impact sur une cible : étincelles, micro-arrêt, secousse.
		Fx.sparks(get_parent(), global_position, Color(1.0, 0.85, 0.35), 16)
		Fx.hit_stop(get_tree(), 0.06)
		var player := get_tree().get_first_node_in_group(&"player")
		if player != null and player.has_method("shake_camera"):
			player.shake_camera(2.0, 0.1)
	else:
		# Contre le décor : quelques étincelles seulement.
		Fx.sparks(get_parent(), global_position, Color(1.0, 0.9, 0.6), 6)
	queue_free()


## Traînée d'étincelles électriques derrière la hache en vol.
func _add_trail() -> void:
	var trail := CPUParticles2D.new()
	trail.amount = 18
	trail.lifetime = 0.22
	trail.local_coords = false            # les étincelles restent sur place quand la hache avance
	trail.direction = Vector2(-direction, 0.0)
	trail.spread = 40.0
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 40.0
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 1.0
	trail.scale_amount_max = 1.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.7, 0.9))
	fade.set_color(1, Color(0.6, 0.75, 1.0, 0.0))
	trail.color_ramp = fade
	add_child(trail)


## Trouve qui doit recevoir le coup : la cible elle-même si elle sait encaisser
## (méthode take_hit), sinon la scène à laquelle appartient la zone touchée
## (la Hitbox d'un ennemi transmet le coup à son ennemi).
func _find_damageable(target: Node) -> Node:
	if target.has_method("take_hit"):
		return target
	if target.owner != null and target.owner.has_method("take_hit"):
		return target.owner
	return null
