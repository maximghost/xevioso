class_name GrappleAnchor
extends Node2D
## Pieu d'accroche : Yawa peut y accrocher sa perche-filet pour se balancer.
##
## Il suffit de poser ce nœud dans un niveau : il s'inscrit dans le groupe
## « grapple_anchor », que la capacité de Yawa parcourt pour trouver le pieu le plus proche.
## Le pieu à portée s'entoure d'un halo doré, pour que le joueur sache qu'il peut s'y accrocher.


## Couleur du halo.
@export var highlight_color: Color = Color(1.0, 0.85, 0.35)

var _highlighted: bool = false
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"grapple_anchor")


## Allume ou éteint le halo (appelée par la capacité de Yawa).
func set_highlighted(on: bool) -> void:
	_highlighted = on
	queue_redraw()


func _process(delta: float) -> void:
	if _highlighted:
		_time += delta
		queue_redraw()  # le halo pulse : on le redessine à chaque image


func _draw() -> void:
	if not _highlighted:
		return
	# Le halo grandit et rétrécit doucement autour de l'anneau.
	var pulse: float = 0.5 + 0.5 * sin(_time * 8.0)
	draw_arc(Vector2.ZERO, 8.0 + pulse * 2.0, 0.0, TAU, 24, Color(highlight_color, 0.5 + 0.4 * pulse), 1.0)
