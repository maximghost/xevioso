class_name Updraft
extends Area2D
## Un courant ascendant de la canopée : l'air chaud monte du sol entre les troncs. Des
## feuilles et des graines y tourbillonnent vers le haut (on le voit). Afi, son Pagne-voile
## ouvert, y est portée vers le haut ; les autres héros n'en sentent presque rien.

@export var size: Vector2 = Vector2(48, 200)
## Vitesse de montée visée sous le voile, en pixels par seconde.
@export var lift_speed: float = 150.0

var _leaves: CPUParticles2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	_leaves = CPUParticles2D.new()
	_leaves.texture = preload("res://assets/story/leaf_grey.png")
	_leaves.amount = int(size.y / 12.0)
	_leaves.lifetime = size.y / 90.0
	_leaves.preprocess = _leaves.lifetime
	_leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_leaves.emission_rect_extents = Vector2(size.x / 2.0 - 4.0, 2.0)
	_leaves.direction = Vector2.UP
	_leaves.spread = 10.0
	_leaves.gravity = Vector2.ZERO
	_leaves.initial_velocity_min = 70.0
	_leaves.initial_velocity_max = 110.0
	_leaves.angular_velocity_min = -200.0
	_leaves.angular_velocity_max = 200.0
	_leaves.tangential_accel_min = -20.0
	_leaves.tangential_accel_max = 20.0
	_leaves.color = Color(0.85, 0.95, 0.75, 0.8)
	add_child(_leaves)
	var streaks := CPUParticles2D.new()
	streaks.amount = 6
	streaks.lifetime = 1.4
	streaks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	streaks.emission_rect_extents = Vector2(size.x / 2.0 - 4.0, 2.0)
	streaks.direction = Vector2.UP
	streaks.spread = 3.0
	streaks.gravity = Vector2.ZERO
	streaks.initial_velocity_min = 120.0
	streaks.initial_velocity_max = 160.0
	streaks.scale_amount_min = 1.0
	streaks.scale_amount_max = 1.0
	streaks.color = Color(1, 1, 1, 0.18)
	streaks.texture = preload("res://assets/fx/air_streak.png")
	add_child(streaks)


func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player and body.is_gliding():
			body.velocity.y = move_toward(body.velocity.y, -lift_speed, 2200.0 * delta)
