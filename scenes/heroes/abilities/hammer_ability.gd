class_name HammerAbility
extends HeroAbility
## Le Marteau d'Abla, la forgeronne : il brise les blocs fragiles et écrase les ennemis.
##
## Au sol : une frappe devant elle. Les blocs fragiles touchés volent en éclats,
## les ennemis prennent un gros coup (2 points) et restent sonnés.
## En l'air : un piqué. Abla fonce vers le sol, invulnérable ; à l'impact, elle frappe
## tout ce qui est sous ses pieds et autour. Si elle brise des blocs fragiles en tombant,
## elle continue son piqué à travers : on peut percer un plancher de latérite.


## Vitesse du piqué, en pixels par seconde.
@export var slam_speed: float = 520.0

## Dégâts et étourdissement infligés aux ennemis.
@export var damage: int = 2
@export var stun: float = 0.6

## Zone de la frappe au sol, devant Abla (largeur, hauteur) et son décalage.
@export var strike_size: Vector2 = Vector2(30.0, 34.0)
@export var strike_offset: Vector2 = Vector2(20.0, -2.0)

## Zone de l'impact du piqué, sous ses pieds.
@export var impact_size: Vector2 = Vector2(52.0, 22.0)
@export var impact_offset: Vector2 = Vector2(0.0, 22.0)

## Durée de la frappe au sol, en secondes.
@export var strike_time: float = 0.18

# Vrai pendant un piqué (faux pendant une frappe au sol).
var _slamming: bool = false
# Temps restant de la frappe au sol.
var _time_left: float = 0.0


func _init() -> void:
	cooldown = 0.3
	takes_control = true


func _activate() -> void:
	_slamming = not player.is_on_floor()
	if _slamming:
		animation = &"fall"
		player.velocity = Vector2(0.0, slam_speed)
	else:
		animation = &"throw"
		_time_left = strike_time
		player.velocity = Vector2.ZERO
		var offset := Vector2(strike_offset.x * player.facing, strike_offset.y)
		if _strike(offset, strike_size) > 0:
			player.shake_camera(2.0, 0.1)


func physics_update(delta: float) -> void:
	if _slamming:
		_update_slam()
	else:
		player.velocity = Vector2.ZERO
		_time_left -= delta
		if _time_left <= 0.0:
			finish()


## Le piqué : on fonce vers le bas jusqu'à toucher quelque chose.
func _update_slam() -> void:
	if not player.is_on_floor():
		player.velocity = Vector2(0.0, slam_speed)
		return
	# Impact !
	var feet: Vector2 = player.global_position + Vector2(0.0, 20.0)
	Fx.dust(player.get_parent(), feet, Color(0.72, 0.44, 0.24), 18, 110.0, 70.0)
	# L'onde de choc court au ras du sol, la poussière gicle des deux côtés.
	Fx.ring(player.get_parent(), feet, Color(1.0, 0.82, 0.5), 40.0, 0.35, 3.0, 0.3)
	Fx.puff(player.get_parent(), feet, Color(0.86, 0.72, 0.56), 4, Vector2(-1, -0.2), 70.0, 0.7)
	Fx.puff(player.get_parent(), feet, Color(0.86, 0.72, 0.56), 4, Vector2(1, -0.2), 70.0, 0.7)
	player.shake_camera(3.0, 0.15)
	var broken: int = _strike(impact_offset, impact_size)
	if broken > 0:
		# Le plancher a cédé : le piqué continue à travers.
		player.velocity = Vector2(0.0, slam_speed)
	else:
		finish()


## Pendant le piqué, Abla ne craint rien (elle peut atterrir sur un ennemi).
func grants_invulnerability() -> bool:
	return active and _slamming


## Frappe une zone rectangulaire (décalage par rapport au centre d'Abla, et taille).
## Brise les blocs fragiles, blesse les ennemis. Renvoie le nombre de blocs brisés.
func _strike(offset: Vector2, size: Vector2) -> int:
	var shape := RectangleShape2D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, player.global_position + offset)
	query.collision_mask = 1 | 4        # couche 1 (monde : blocs) et couche 3 (ennemis)
	query.collide_with_areas = true     # pour toucher les zones de coup (Hitbox) des ennemis
	query.exclude = [player.get_rid()]
	var results: Array[Dictionary] = player.get_world_2d().direct_space_state.intersect_shape(query, 32)

	var broken: int = 0
	var already_hit: Array[Node] = []
	for result in results:
		var collider: Node = result.collider
		# La Hitbox d'un ennemi transmet le coup à l'ennemi lui-même (son « owner »).
		var target: Node = collider
		if not (collider.has_method("smash") or collider.has_method("take_hit")):
			target = collider.owner
		if target == null or target in already_hit:
			continue
		already_hit.append(target)
		if target.has_method("smash"):
			target.smash()
			broken += 1
		elif target.has_method("take_hit") and target != player:
			var side: float = signf(target.global_position.x - player.global_position.x)
			target.take_hit(damage, side if side != 0.0 else float(player.facing), stun)
	return broken
