class_name Fireflies
extends Area2D
## Un essaim de lucioles. Dans le noir, il éclaire alentour. Si un héros le traverse, l'essaim
## le suit (sa lumière va avec lui) pendant « follow_time » secondes, puis se disperse et
## revient lentement à sa place : on peut le reprendre. C'est la lampe du sous-bois — à
## emporter au bon moment, car elle ne dure pas.

@export var follow_time: float = 22.0
@export var light_scale: float = 2.6
@export var color: Color = Color(0.85, 1.0, 0.55)

var _home: Vector2
var _player: Node2D
var _left: float = 0.0
var _rest: float = 0.0
var _light: PointLight2D
var _swarm: CPUParticles2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	_home = global_position
	_light = PointLight2D.new()
	_light.texture = Fx.light_texture()
	_light.texture_scale = light_scale * 0.6
	_light.color = color
	_light.energy = 0.9
	add_child(_light)
	_swarm = CPUParticles2D.new()
	_swarm.amount = 14
	_swarm.lifetime = 2.2
	_swarm.local_coords = false
	_swarm.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_swarm.emission_sphere_radius = 12.0
	_swarm.gravity = Vector2.ZERO
	_swarm.initial_velocity_min = 2.0
	_swarm.initial_velocity_max = 8.0
	_swarm.spread = 180.0
	_swarm.scale_amount_min = 1.0
	_swarm.scale_amount_max = 2.0
	var blink := Gradient.new()
	blink.set_color(0, Color(color, 0.0))
	blink.add_point(0.3, Color(color, 1.0))
	blink.add_point(0.55, Color(color, 0.2))
	blink.add_point(0.75, Color(color, 1.0))
	blink.set_color(blink.get_point_count() - 1, Color(color, 0.0))
	_swarm.color_ramp = blink
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_swarm.material = unshaded
	add_child(_swarm)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and _player == null and _rest <= 0.0:
		_player = body
		_left = follow_time
		_light.texture_scale = light_scale
		Audio.play_at(&"fireflies", global_position)


func _physics_process(delta: float) -> void:
	_rest = maxf(_rest - delta, 0.0)
	if _player != null:
		_left -= delta
		# L'essaim tourne au-dessus de l'épaule du héros, avec un peu de retard.
		var t := Time.get_ticks_msec() / 1000.0
		var target: Vector2 = _player.global_position + Vector2(-10.0 * _player.facing + 6.0 * sin(t * 2.0), -34.0 + 4.0 * cos(t * 3.1))
		global_position = global_position.lerp(target, minf(1.0, 6.0 * delta))
		# Les dernières secondes, la lumière faiblit et clignote : il est temps de se hâter.
		if _left < 4.0:
			_light.energy = 0.5 + 0.4 * absf(sin(_left * 6.0))
		if _left <= 0.0:
			_player = null
			_rest = 2.0
			_light.texture_scale = light_scale * 0.6
			_light.energy = 0.9
	else:
		global_position = global_position.move_toward(_home, 30.0 * delta)
