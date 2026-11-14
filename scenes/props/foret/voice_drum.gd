class_name VoiceDrum
extends Area2D
## Un tambour-arbre du sanctuaire : un tronçon d'arbre creusé, ceint d'une étoffe (blanche,
## rouge ou indigo). Chacun a sa voix : grave, médium, aiguë. On le fait parler en le frappant
## avec la hache (ou l'Onde de Kokou). Il prévient l'énigme qui l'écoute.

signal struck(voice: int)

## 0 = grave (étoffe blanche), 1 = médium (rouge), 2 = aiguë (indigo).
@export_range(0, 2) var voice: int = 0

var _sprite: Sprite2D
var _glow: PointLight2D
var lit: bool = false


func _ready() -> void:
	collision_layer = 4          # couche « ennemis » : la hache et l'Onde la détectent
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 30)
	shape.shape = rect
	shape.position = Vector2(0, -15)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/props/foret/drum_tree.png")
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(voice * 26, 0, 26, 34)
	_sprite.offset = Vector2(0, -17)
	add_child(_sprite)
	_glow = PointLight2D.new()
	_glow.texture = Fx.light_texture()
	_glow.texture_scale = 0.9
	_glow.color = [Color(1.0, 0.95, 0.8), Color(1.0, 0.5, 0.35), Color(0.5, 0.6, 1.0)][voice]
	_glow.energy = 0.0
	_glow.position = Vector2(0, -16)
	add_child(_glow)


## La hache ou l'Onde le frappe.
func take_hit(_damage: int, _from_direction: float, _stun: float = -1.0) -> void:
	sound()
	struck.emit(voice)


## Il parle (frappé, ou pour montrer sa voix) : son, secousse, onde de son étoffe.
func sound(quiet: bool = false) -> void:
	Audio.play_at(StringName("drum_voice_%d" % voice), global_position, -8.0 if quiet else 0.0)
	_sprite.region_rect = Rect2(voice * 26, 34, 26, 34)
	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2(1.12, 0.9), 0.05)
	t.tween_property(_sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	t.tween_callback(func() -> void: _sprite.region_rect = Rect2(voice * 26, 0, 26, 34))
	if not quiet:
		Fx.ring(get_parent(), global_position + Vector2(0, -16), _glow.color, 26.0, 0.35, 2.0)


## Allumé : il a été frappé au bon moment dans la suite (il garde une lueur).
func set_lit(on: bool) -> void:
	lit = on
	create_tween().tween_property(_glow, "energy", 1.0 if on else 0.0, 0.25)
