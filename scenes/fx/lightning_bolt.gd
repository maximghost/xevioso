class_name LightningBolt
extends Node2D
## Un éclair dessiné : un tracé en zigzag entre deux points, avec des ramifications,
## un noyau blanc et un halo doré. Il scintille (le tracé change plusieurs fois)
## puis s'éteint et se supprime.
##
## Utilisation : LightningBolt.strike(parent, depuis, vers) — positions globales.
## Sert à la foudre de Xɛvioso (gros éclairs) et aux arcs autour de la hache (petits).

## Épaisseur du noyau, en pixels (le halo est plus large).
var thickness: float = 2.0
## Durée de vie, en secondes.
var duration: float = 0.35
## Nombre de fois où le tracé change pendant sa vie (scintillement).
var flickers: int = 3
## Ramifications (0 = aucune).
var branches: int = 3
## Couleurs du halo et du noyau.
var glow_color: Color = Color(1.0, 0.82, 0.35)
var core_color: Color = Color(1.0, 1.0, 0.92)

var _from: Vector2
var _to: Vector2
var _paths: Array[PackedVector2Array] = []
var _t: float = 0.0
var _next_flicker: float = 0.0
var _rng := RandomNumberGenerator.new()


## Crée et lance un éclair de « from » à « to » (positions globales).
static func strike(parent: Node, from: Vector2, to: Vector2, core: float = 2.0,
		life: float = 0.35, branch_count: int = 3) -> LightningBolt:
	var bolt := LightningBolt.new()
	bolt.thickness = core
	bolt.duration = life
	bolt.branches = branch_count
	bolt._from = from
	bolt._to = to
	# Repère du monde (indépendant du parent) : les positions données restent globales.
	bolt.top_level = true
	bolt.z_index = 15
	parent.add_child(bolt)
	return bolt


func _ready() -> void:
	_rng.randomize()
	_build()


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	if _t >= _next_flicker:
		_build()
	queue_redraw()


## Recalcule le tracé : déplacement des milieux (fractale), puis quelques branches.
func _build() -> void:
	_next_flicker = _t + duration / float(maxi(flickers, 1))
	_paths.clear()
	var length: float = _from.distance_to(_to)
	var main := _zigzag(_from, _to, length * 0.12, 5)
	_paths.append(main)
	for i in branches:
		var start: Vector2 = main[_rng.randi_range(main.size() / 5, main.size() * 3 / 5)]
		var dir: Vector2 = (_to - _from).normalized().rotated(_rng.randf_range(-0.9, 0.9))
		var end: Vector2 = start + dir * length * _rng.randf_range(0.15, 0.3)
		_paths.append(_zigzag(start, end, length * 0.05, 3))


func _zigzag(a: Vector2, b: Vector2, spread: float, depth: int) -> PackedVector2Array:
	var points := PackedVector2Array([a, b])
	var offset: float = spread
	for level in depth:
		var refined := PackedVector2Array()
		for i in points.size() - 1:
			var p: Vector2 = points[i]
			var q: Vector2 = points[i + 1]
			var normal: Vector2 = (q - p).orthogonal().normalized()
			refined.append(p)
			refined.append((p + q) * 0.5 + normal * _rng.randf_range(-offset, offset))
		refined.append(points[points.size() - 1])
		points = refined
		offset *= 0.5
	return points


func _draw() -> void:
	var fade: float = 1.0 - _t / duration
	# Il s'allume d'un coup puis faiblit, avec un léger battement.
	var alpha: float = fade * (0.75 + 0.25 * sin(_t * 90.0))
	for i in _paths.size():
		var w: float = thickness if i == 0 else thickness * 0.5
		draw_polyline(_paths[i], Color(glow_color, 0.35 * alpha), w * 4.0)
		draw_polyline(_paths[i], Color(glow_color, 0.8 * alpha), w * 2.0)
		draw_polyline(_paths[i], Color(core_color, alpha), maxf(w, 1.0))
