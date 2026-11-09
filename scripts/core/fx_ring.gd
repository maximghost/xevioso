class_name FxRing
extends Node2D
## Onde circulaire d'un effet (voir Fx.ring) : elle s'élargit en ralentissant,
## s'amincit et s'efface, puis se supprime.

var color: Color = Color.WHITE
var max_radius: float = 24.0
var duration: float = 0.3
var width: float = 2.0
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta / duration
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = 1.0 - pow(1.0 - _t, 3.0)          # départ rapide, fin douce
	var radius: float = maxf(max_radius * k, 1.0)
	var a: float = 1.0 - _t
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, a), maxf(width * (1.0 - _t * 0.6), 1.0))
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 32, Color(color, a * 0.35), 1.0)
