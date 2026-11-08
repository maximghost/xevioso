class_name Spitter
extends StaticBody2D
## La Termitière cracheuse : immobile, elle crache des mottes de terre en cloche
## sur le héros qui passe à portée. Trois coups pour la faire taire.
##
## On peut aussi passer entre deux tirs : elle prévient en ouvrant grand la bouche
## une fraction de seconde avant de cracher.


## Intervalle entre deux tirs, en secondes.
@export var fire_interval: float = 2.2
## Portée, en pixels.
@export var fire_range: float = 230.0
## Vitesse verticale de départ de la motte (la hauteur de la cloche).
@export var launch_up: float = 240.0
## Décalage de départ dans le rythme des tirs (0 à 1).
@export_range(0.0, 1.0) var phase: float = 0.0

var _timer: float
var _dead: bool = false

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _health: Health = $Health


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	_timer = fire_interval * (1.0 - phase)
	_health.died.connect(_on_died)
	_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_timer -= delta
	var target := _find_target()
	if target == null:
		_timer = maxf(_timer, 0.4)
		return
	if _timer <= 0.35 and _sprite.animation != &"spit":
		_sprite.play(&"spit")            # avertissement : la bouche s'ouvre
	if _timer <= 0.0:
		_timer = fire_interval
		_fire_at(target.global_position)
		await get_tree().create_timer(0.2, false).timeout
		if not _dead:
			_sprite.play(&"idle")
	for body in $Hurtbox.get_overlapping_bodies():
		if body.has_method("take_hit"):
			var side: float = signf(body.global_position.x - global_position.x)
			body.take_hit(1, side if side != 0.0 else 1.0)


func _find_target() -> Node2D:
	for node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Node2D
		if player.global_position.distance_to(global_position) < fire_range:
			return player
	return null


## Tire en cloche pour retomber sur la cible : on connaît la vitesse verticale de départ
## et la gravité, on en déduit le temps de vol, puis la vitesse horizontale nécessaire.
func _fire_at(target: Vector2) -> void:
	var clod: Clod = preload("res://scenes/enemies/spitter/clod.tscn").instantiate()
	var start: Vector2 = global_position + Vector2(0, -22)
	var g: float = clod.gravity_strength
	var dy: float = (target.y - 4.0) - start.y                  # positif si la cible est plus bas
	# y(t) = -launch_up·t + g·t²/2 = dy  →  t = (launch_up + √(launch_up² + 2·g·dy)) / g
	var disc: float = maxf(launch_up * launch_up + 2.0 * g * dy, 0.0)
	var t: float = (launch_up + sqrt(disc)) / g
	clod.velocity = Vector2((target.x - start.x) / maxf(t, 0.2), -launch_up)
	clod.position = start
	get_parent().add_child(clod)


func take_hit(damage: int, _from_direction: float, _stun: float = -1.0) -> void:
	if _dead or not _health.damage(damage):
		return
	_sprite.modulate = Color(4, 4, 4)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)


func _on_died() -> void:
	_dead = true
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox.set_deferred("monitoring", false)
	Fx.dust(get_parent(), global_position + Vector2(0, -16), Color(0.72, 0.44, 0.24), 24, 110.0, 160.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "scale", Vector2(1.3, 0.2), 0.3)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
