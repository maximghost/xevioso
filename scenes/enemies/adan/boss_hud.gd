extends CanvasLayer
## La barre d'Adan, en bas de l'écran : son nom, ses points de vie (rouge braise) et sa jauge
## de Fureur (orange, qui pulse quand elle approche du plein).

var _hp: ColorRect
var _rage: ColorRect
var _rage_back: ColorRect
var _root: Control
var _rage_value: float = 0.0
const W := 220.0


func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var box := Control.new()
	box.position = Vector2(320 - W / 2.0, 318)
	_root.add_child(box)
	var name_l := Label.new()
	name_l.text = "ADAN — la Colère"
	name_l.add_theme_font_size_override("font_size", 9)
	name_l.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	name_l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	name_l.add_theme_constant_override("outline_size", 3)
	name_l.position = Vector2(0, -14)
	box.add_child(name_l)
	var back := ColorRect.new()
	back.color = Color(0.08, 0.04, 0.03, 0.85)
	back.size = Vector2(W + 4, 8)
	back.position = Vector2(-2, -2)
	box.add_child(back)
	_hp = ColorRect.new()
	_hp.color = Color(0.85, 0.2, 0.1)
	_hp.size = Vector2(W, 4)
	box.add_child(_hp)
	_rage_back = ColorRect.new()
	_rage_back.color = Color(0.08, 0.04, 0.03, 0.85)
	_rage_back.size = Vector2(W * 0.6 + 4, 6)
	_rage_back.position = Vector2(-2, 8)
	box.add_child(_rage_back)
	_rage = ColorRect.new()
	_rage.color = Color(1.0, 0.55, 0.15)
	_rage.size = Vector2(0, 2)
	_rage.position = Vector2(0, 10)
	box.add_child(_rage)
	var fl := Label.new()
	fl.text = "Fureur"
	fl.add_theme_font_size_override("font_size", 7)
	fl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	fl.position = Vector2(W * 0.6 + 6, 4)
	box.add_child(fl)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.5)


func set_health(current: int, maximum: int) -> void:
	create_tween().tween_property(_hp, "size:x", W * float(current) / float(maxi(maximum, 1)), 0.2)


func set_rage(value: float) -> void:
	_rage_value = value
	_rage.size.x = W * 0.6 * value / 100.0


func _process(_delta: float) -> void:
	if _rage_value > 75.0:
		_rage.color = Color(1.0, 0.55 + 0.35 * absf(sin(Time.get_ticks_msec() / 120.0)), 0.15)
	else:
		_rage.color = Color(1.0, 0.55, 0.15)


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 1.0)
	t.tween_callback(queue_free)
