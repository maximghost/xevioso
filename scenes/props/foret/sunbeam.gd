class_name Sunbeam
extends Node2D
## Un rai de lumière qui tombe d'une trouée de la canopée : une colonne oblique de lumière
## dorée (additive), plus forte en haut, qui respire lentement ; des poussières et des
## graines y flottent et accrochent la lumière. Dans la forêt malade, la lumière est pâle et
## grise ; elle se réchauffe quand la forêt guérit (la teinte du niveau s'en charge).

@export var width: float = 40.0
@export var length: float = 300.0
@export var slant: float = 60.0
@export var strength: float = 0.16

var _beam: Polygon2D
var _t: float = 0.0


func _ready() -> void:
	_t = randf() * 10.0
	_beam = Polygon2D.new()
	_beam.polygon = PackedVector2Array([Vector2(-width * 0.5, 0), Vector2(width * 0.5, 0),
		Vector2(width * 0.9 + slant, length), Vector2(-width * 0.9 + slant, length)])
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = add
	add_child(_beam)
	var motes := CPUParticles2D.new()
	motes.amount = int(length / 14.0)
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.position = Vector2(slant * 0.5, length * 0.5)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(width * 0.6, length * 0.45)
	motes.direction = Vector2(0.3, 1)
	motes.spread = 60.0
	motes.gravity = Vector2(0, 3)
	motes.initial_velocity_min = 1.0
	motes.initial_velocity_max = 5.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.75, 0.0))
	fade.add_point(0.3, Color(1.0, 0.95, 0.75, 0.75))
	fade.add_point(0.7, Color(1.0, 0.95, 0.75, 0.6))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.95, 0.75, 0.0))
	motes.color_ramp = fade
	motes.material = add
	add_child(motes)


func _process(delta: float) -> void:
	_t += delta
	var a: float = strength * (0.75 + 0.25 * sin(_t * 0.6))
	var top := Color(1.0, 0.93, 0.72, a)
	var bottom := Color(1.0, 0.93, 0.72, 0.0)
	_beam.vertex_colors = PackedColorArray([top, top, bottom, bottom])
