class_name ForestMist
extends Node2D
## Une nappe de brume au ras du sol, qui dérive lentement entre les troncs (et, si « fireflies »,
## des lucioles d'ambiance qui clignotent dans le noir — on ne peut pas les emporter, elles).

@export var width: float = 400.0
@export var alpha: float = 0.18
@export var fireflies: bool = false


func _ready() -> void:
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	var puff := GradientTexture2D.new()
	puff.gradient = soft
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 96
	puff.height = 32
	var mist := CPUParticles2D.new()
	mist.texture = puff
	mist.amount = int(width / 28.0)
	mist.lifetime = 12.0
	mist.preprocess = 12.0
	mist.position = Vector2(width / 2.0, -10)
	mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mist.emission_rect_extents = Vector2(width / 2.0, 6)
	mist.direction = Vector2(1, 0)
	mist.spread = 8.0
	mist.gravity = Vector2.ZERO
	mist.initial_velocity_min = 3.0
	mist.initial_velocity_max = 7.0
	mist.scale_amount_min = 1.0
	mist.scale_amount_max = 1.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.7, 0.8, 0.85, 0.0))
	ramp.add_point(0.5, Color(0.7, 0.8, 0.85, alpha))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.7, 0.8, 0.85, 0.0))
	mist.color_ramp = ramp
	add_child(mist)
	if fireflies:
		var ff := CPUParticles2D.new()
		ff.amount = int(width / 30.0)
		ff.lifetime = 5.0
		ff.preprocess = 5.0
		ff.position = Vector2(width / 2.0, -40)
		ff.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		ff.emission_rect_extents = Vector2(width / 2.0, 36)
		ff.gravity = Vector2.ZERO
		ff.spread = 180.0
		ff.initial_velocity_min = 2.0
		ff.initial_velocity_max = 7.0
		var blink := Gradient.new()
		blink.set_color(0, Color(0.8, 1.0, 0.5, 0.0))
		blink.add_point(0.2, Color(0.8, 1.0, 0.5, 1.0))
		blink.add_point(0.35, Color(0.8, 1.0, 0.5, 0.1))
		blink.add_point(0.55, Color(0.8, 1.0, 0.5, 1.0))
		blink.set_color(blink.get_point_count() - 1, Color(0.8, 1.0, 0.5, 0.0))
		ff.color_ramp = blink
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		ff.material = unshaded
		add_child(ff)
