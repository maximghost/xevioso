class_name GrappleAbility
extends HeroAbility
## La Perche-filet de Yawa, la pêcheuse de la lagune : elle s'accroche aux pieux et se balance.
##
## Quand un pieu d'accroche (GrappleAnchor) est à portée, au-dessus d'elle, il s'entoure
## d'un halo. Appuyer sur la capacité y accroche la perche ; en la maintenant, Yawa se
## balance comme un pendule (gauche/droite pour prendre de l'élan). Lâcher le bouton la
## libère avec sa vitesse : on se propulse d'un pieu à l'autre. Sauter la libère aussi,
## avec un petit élan vers le haut.
##
## Le balancement est un pendule simple : à chaque image on applique la gravité et l'élan,
## puis on ramène Yawa sur le cercle centré sur le pieu (la perche ne s'allonge pas).


## Distance maximale pour s'accrocher, en pixels.
@export var reach: float = 120.0

## Longueur minimale de la perche (évite un pendule minuscule qui tourne trop vite).
@export var min_length: float = 28.0

## Élan donné par les flèches pendant le balancement, en pixels par seconde au carré.
@export var swing_acceleration: float = 520.0

## Vitesse maximale pendant le balancement.
@export var max_swing_speed: float = 420.0

## Élan vers le haut quand on saute pour se libérer, en pixels par seconde.
@export var jump_release_boost: float = 180.0

## Couleur de la perche.
@export var pole_color: Color = Color(0.6, 0.4, 0.22)

# Le pieu auquel Yawa est accrochée, et la longueur de la perche.
var _anchor: GrappleAnchor = null
var _length: float = 0.0
# Le pieu à portée (celui qui a le halo), qu'on accrochera si l'on appuie.
var _target: GrappleAnchor = null
# La perche dessinée entre la main et le pieu.
var _pole: Line2D


func _init() -> void:
	cooldown = 0.15
	takes_control = true
	animation = &"jump"


func _ready() -> void:
	_pole = Line2D.new()
	_pole.width = 1.5
	_pole.default_color = pole_color
	_pole.visible = false
	# La perche est ajoutée au niveau : ses points sont en coordonnées du monde.
	player.get_parent().add_child.call_deferred(_pole)


## Cherche, à chaque image, le pieu à portée et lui met le halo.
func passive_update(_delta: float) -> void:
	if active:
		return
	var best: GrappleAnchor = _find_anchor()
	if best != _target:
		_set_target(best)


func on_deselected() -> void:
	_set_target(null)


func can_activate() -> bool:
	return _target != null and is_instance_valid(_target)


func _activate() -> void:
	_anchor = _target
	_set_target(null)
	var offset: Vector2 = player.global_position - _anchor.global_position
	_length = maxf(offset.length(), min_length)
	# On ne garde que la vitesse le long du cercle (la composante qui tirerait sur la perche
	# disparaît) : l'accrochage paraît souple, sans à-coup.
	var radial: Vector2 = offset.normalized()
	player.velocity -= radial * player.velocity.dot(radial)
	_pole.visible = true
	Audio.play(&"grapple_throw")
	Audio.play(&"grapple_attach", -2.0)


func physics_update(delta: float) -> void:
	if not is_instance_valid(_anchor) or player.is_on_floor():
		finish()
		return
	if Input.is_action_just_pressed("jump"):
		player.velocity.y = minf(player.velocity.y, -jump_release_boost)
		finish()
		return
	if not Input.is_action_pressed("ability"):
		finish()  # on lâche : Yawa part avec sa vitesse
		return

	var anchor: Vector2 = _anchor.global_position
	var position: Vector2 = player.global_position
	var velocity: Vector2 = player.velocity

	# 1. Les forces : gravité et élan donné par les flèches.
	velocity.y += player.get_gravity_strength() * delta
	velocity.x += Input.get_axis("move_left", "move_right") * swing_acceleration * delta

	# 2. La perche ne s'allonge pas : si Yawa s'éloigne trop du pieu, on la ramène sur le cercle.
	var next: Vector2 = position + velocity * delta
	if next.distance_to(anchor) > _length:
		next = anchor + (next - anchor).normalized() * _length
	velocity = ((next - position) / delta).limit_length(max_swing_speed)

	player.velocity = velocity
	if absf(velocity.x) > 10.0:
		player.set_facing(1 if velocity.x > 0.0 else -1)

	_pole.points = PackedVector2Array([player.global_position + Vector2(0.0, -16.0), anchor])


func _on_finish() -> void:
	_pole.visible = false
	_anchor = null


## Le pieu le plus proche, à portée et au-dessus de Yawa (null s'il n'y en a pas).
func _find_anchor() -> GrappleAnchor:
	var best: GrappleAnchor = null
	var best_distance: float = reach
	var hand: Vector2 = player.global_position + Vector2(0.0, -16.0)
	for node in player.get_tree().get_nodes_in_group(&"grapple_anchor"):
		var anchor := node as GrappleAnchor
		var offset: Vector2 = anchor.global_position - hand
		if offset.y > -4.0:
			continue  # on ne s'accroche qu'au-dessus de soi
		var distance: float = offset.length()
		if distance < best_distance:
			best = anchor
			best_distance = distance
	return best


## Déplace le halo vers un autre pieu (ou l'éteint).
func _set_target(anchor: GrappleAnchor) -> void:
	if _target != null and is_instance_valid(_target):
		_target.set_highlighted(false)
	_target = anchor
	if _target != null:
		_target.set_highlighted(true)
