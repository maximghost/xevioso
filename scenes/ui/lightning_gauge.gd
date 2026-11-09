class_name LightningGauge
extends Control
## Jauge de la foudre de Xɛvioso (HUD) : un éclair et quatre crans, un par pierre sokpe.
## Les crans se remplissent d'or ; pleine, la jauge palpite en violet et rappelle la touche.

const SEGMENTS := 4
const SEG_W := 9.0
const SEG_H := 7.0
const GAP := 2.0
const ICON_W := 9.0

var _charge: int = 0
var _time: float = 0.0
var _pop: float = 0.0       # sursaut quand un cran se remplit
var _font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(ICON_W + 4.0 + SEGMENTS * (SEG_W + GAP) + 14.0, SEG_H + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	Game.lightning_changed.connect(_on_changed)
	_charge = Game.lightning_charge


func _on_changed(charge: int) -> void:
	if charge > _charge:
		_pop = 1.0
	_charge = charge


func _process(delta: float) -> void:
	_time += delta
	_pop = maxf(_pop - delta * 4.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var full: bool = _charge >= SEGMENTS
	var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
	var y0: float = 2.0
	# L'éclair : doré, violet et lumineux quand la jauge est pleine.
	var bolt_color: Color = Color(0.85, 0.7, 1.0).lerp(Color.WHITE, pulse * 0.5) if full else Color(1.0, 0.85, 0.4)
	var bolt := PackedVector2Array([Vector2(5, y0 - 1), Vector2(1, y0 + 4), Vector2(4, y0 + 4),
		Vector2(2, y0 + 9), Vector2(8, y0 + 2), Vector2(5, y0 + 2), Vector2(7, y0 - 1)])
	draw_colored_polygon(bolt, Color(0.1, 0.06, 0.12, 0.9))
	draw_colored_polygon(bolt, bolt_color)
	# Les crans, en parallélogrammes (comme un éclair qui file).
	for i in SEGMENTS:
		var x: float = ICON_W + 4.0 + i * (SEG_W + GAP)
		var lift: float = -2.0 * _pop if i == _charge - 1 else 0.0
		var shape := PackedVector2Array([Vector2(x + 2, y0 + lift), Vector2(x + SEG_W + 2, y0 + lift),
			Vector2(x + SEG_W, y0 + SEG_H + lift), Vector2(x, y0 + SEG_H + lift)])
		draw_colored_polygon(shape, Color(0.08, 0.05, 0.1, 0.75))
		if i < _charge:
			var fill: Color = Color(1.0, 0.82, 0.3)
			if full:
				fill = Color(0.78, 0.58, 1.0).lerp(Color(1.0, 0.95, 1.0), pulse * 0.6)
			var inner := PackedVector2Array([shape[0] + Vector2(1, 1), shape[1] + Vector2(-1, 1),
				shape[2] + Vector2(-1, -1), shape[3] + Vector2(1, -1)])
			draw_colored_polygon(inner, fill)
		draw_polyline(PackedVector2Array([shape[0], shape[1], shape[2], shape[3], shape[0]]),
			Color(1.0, 0.9, 0.7, 0.55), 1.0)
	# Pleine : la touche à presser (sur ordinateur ; sur mobile, le bouton violet apparaît).
	if full and not DisplayServer.is_touchscreen_available() and _font != null:
		var x: float = ICON_W + 4.0 + SEGMENTS * (SEG_W + GAP) + 2.0
		draw_string(_font, Vector2(x, y0 + SEG_H), "L", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.9, 0.8, 1.0).lerp(Color.WHITE, pulse))
