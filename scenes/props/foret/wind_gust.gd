class_name WindGust
extends Area2D
## Rafales de la canopée : toutes les « period » secondes, le vent souffle « blow_time »
## secondes dans le sens « direction » et pousse les héros (plus fort en l'air et sous le voile).
## Une seconde avant, les feuilles se mettent à filer : c'est le signal.

@export var size: Vector2 = Vector2(160, 120)
@export_enum("Gauche:-1", "Droite:1") var direction: int = 1
@export var period: float = 5.0
@export var blow_time: float = 1.8
@export var strength: float = 150.0
@export var phase: float = 0.0

var _time: float = 0.0
var _streaks: CPUParticles2D
var _sound_played: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	_streaks = CPUParticles2D.new()
	_streaks.amount = int(size.y / 6.0)
	_streaks.lifetime = 0.9
	_streaks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_streaks.emission_rect_extents = Vector2(4.0, size.y / 2.0)
	_streaks.position = Vector2(-direction * size.x / 2.0, -size.y / 2.0)
	_streaks.direction = Vector2(direction, 0)
	_streaks.spread = 4.0
	_streaks.gravity = Vector2.ZERO
	_streaks.initial_velocity_min = size.x * 1.2
	_streaks.initial_velocity_max = size.x * 1.6
	_streaks.color = Color(1, 1, 1, 0.22)
	_streaks.texture = preload("res://assets/fx/air_streak_h.png")
	_streaks.emitting = false
	add_child(_streaks)
	_time = phase * period


func _physics_process(delta: float) -> void:
	_time = fmod(_time + delta, period)
	var warn: bool = _time > period - blow_time - 1.0 and _time < period - blow_time
	var blowing: bool = _time >= period - blow_time
	_streaks.emitting = warn or blowing
	_streaks.speed_scale = 0.5 if warn else 1.0
	if warn and not _sound_played:
		_sound_played = true
		Audio.play_at(&"wind_gust", global_position)
	if not warn and not blowing:
		_sound_played = false
	for body in get_overlapping_bodies():
		if body is Player:
			var k: float = 0.0
			if blowing:
				k = strength * (1.6 if body.is_gliding() else (1.2 if not body.is_on_floor() else 0.8))
			body.wind = direction * k
