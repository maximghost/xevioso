class_name RootCrusher
extends Node2D
## Racine-pilon : une grosse racine pointue pend de la voûte du souterrain. Elle frémit et
## lâche de la terre (le signal), puis s'abat d'un coup jusqu'au sol, y reste un instant et
## remonte. Le nœud est à la voûte ; « drop » est la longueur de la chute en pixels.

@export var drop: float = 80.0
@export var period: float = 3.0
@export var phase: float = 0.0

const WARN := 0.7
const DOWN := 0.12
const STAY := 0.45
const UP := 0.6

var _t: float = 0.0
var _root: Sprite2D
var _hit: Area2D
var _dust: CPUParticles2D
var _was_down: bool = false


func _ready() -> void:
	_t = phase * period
	_root = Sprite2D.new()
	_root.texture = preload("res://assets/props/foret/root_spike.png")
	_root.centered = false
	_root.position = Vector2(-7, -96 + 10)
	add_child(_root)
	_hit = Area2D.new()
	_hit.collision_layer = 0
	_hit.collision_mask = 2
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 20)
	shape.shape = r
	shape.position = Vector2(0, -2)
	_hit.add_child(shape)
	add_child(_hit)
	_dust = CPUParticles2D.new()
	_dust.amount = 8
	_dust.lifetime = 0.8
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(6, 1)
	_dust.direction = Vector2.DOWN
	_dust.spread = 10.0
	_dust.gravity = Vector2(0, 200)
	_dust.initial_velocity_min = 10.0
	_dust.initial_velocity_max = 30.0
	_dust.color = Color(0.45, 0.36, 0.28)
	_dust.emitting = false
	add_child(_dust)


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, period)
	var rest: float = period - (WARN + DOWN + STAY + UP)
	var y := 0.0
	var dangerous := false
	if _t < rest:
		y = 0.0
		_dust.emitting = false
		_root.position.x = -7
	elif _t < rest + WARN:
		y = 0.0
		_dust.emitting = true
		_root.position.x = -7 + randf_range(-1.0, 1.0)      # elle frémit
	elif _t < rest + WARN + DOWN:
		y = drop * ((_t - rest - WARN) / DOWN)
		dangerous = true
		_dust.emitting = false
		_root.position.x = -7
	elif _t < rest + WARN + DOWN + STAY:
		y = drop
		dangerous = true
		if not _was_down:
			_was_down = true
			Audio.play_at(&"root_slam", global_position + Vector2(0, drop), -2.0)
			Fx.dust(get_parent(), global_position + Vector2(0, drop), Color(0.4, 0.32, 0.25), 8, 50.0, 80.0)
	else:
		y = drop * (1.0 - (_t - rest - WARN - DOWN - STAY) / UP)
		_was_down = false
	_root.position.y = -96 + 10 + y
	_hit.position.y = y
	_hit.monitoring = dangerous
	if dangerous:
		for body in _hit.get_overlapping_bodies():
			if body is Player:
				body.take_hit(1, signf(body.global_position.x - global_position.x))
