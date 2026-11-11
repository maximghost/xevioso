class_name SwingingVine
extends Node2D
## Liane-balancier : une liane pend de la voûte et balance une grosse boule de ronces.
## Elle passe au plus bas à hauteur de buste : debout, elle blesse ; accroupi, elle passe
## au-dessus de la tête. Son rythme est régulier : on l'observe, puis on choisit son moment
## (se baisser quand elle arrive, ou passer quand elle est de l'autre côté).
## Le nœud est l'attache, en haut ; la boule est au bout, « length » pixels plus bas.

## Longueur de la liane, de l'attache au centre de la boule.
@export var length: float = 120.0
## Écart maximal de part et d'autre de la verticale, en degrés.
@export var amplitude: float = 55.0
## Durée d'un aller-retour complet, en secondes.
@export var period: float = 2.4
## Décalage dans le cycle (0 à 1) : deux lianes voisines ne battent pas ensemble.
@export_range(0.0, 1.0) var phase: float = 0.0

const RADIUS := 8.0
const ROPE := [Color(0.2, 0.3, 0.16), Color(0.32, 0.42, 0.22)]
const LEAF := Color(0.36, 0.5, 0.26)
const BALL := [Color(0.16, 0.14, 0.12), Color(0.28, 0.25, 0.21), Color(0.42, 0.38, 0.32)]
const SPIKE := Color(0.78, 0.72, 0.6)

var _time: float = 0.0
var _angle: float = 0.0
var _speed: float = 0.0
var _hit: Area2D


func _ready() -> void:
	_hit = Area2D.new()
	_hit.collision_layer = 0
	_hit.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	_hit.add_child(shape)
	add_child(_hit)
	_time = phase * period
	_update_pose(0.0)


func _physics_process(delta: float) -> void:
	_time += delta
	var before := _angle
	_update_pose(delta)
	# Au passage de la verticale (le point le plus bas, le plus rapide) : le sifflement.
	if signf(before) != signf(_angle) and before != 0.0:
		Audio.play_at(&"vine_swish", global_position + tip(), -2.0)
	for body in _hit.get_overlapping_bodies():
		if body is Player:
			body.take_hit(1, signf(_speed) if _speed != 0.0 else 1.0)
	queue_redraw()


func _update_pose(delta: float) -> void:
	var a := deg_to_rad(amplitude) * sin(TAU * _time / period)
	_speed = (a - _angle) / delta if delta > 0.0 else 0.0
	_angle = a
	_hit.position = tip()


## Position de la boule, par rapport à l'attache.
func tip() -> Vector2:
	return Vector2(sin(_angle), cos(_angle)) * length


func _draw() -> void:
	# L'attache : une touffe de feuilles et de lianes enroulées, accrochée à la voûte.
	draw_circle(Vector2.ZERO, 5.0, ROPE[0])
	for k in 6:
		var a := TAU * k / 6.0 + 0.4
		var d := Vector2(cos(a), sin(a) * 0.6)
		draw_colored_polygon(PackedVector2Array([d * 3.0, d * 9.0 + Vector2(-d.y, d.x) * 2.0, d * 7.0]), LEAF)
	var end := tip()
	# La liane : une courbe qui traîne un peu derrière le mouvement (elle n'est pas rigide).
	var side := Vector2(cos(_angle), -sin(_angle))
	var bend := clampf(-_speed * 6.0, -10.0, 10.0)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append((end * t + side * sin(PI * t) * bend).round())
	draw_polyline(pts, ROPE[0], 3.0)
	draw_polyline(pts, ROPE[1], 1.0)
	for i in range(2, 12, 2):           # de petites feuilles le long de la liane
		var p := pts[i]
		var d := 1.0 if i % 4 == 0 else -1.0
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(4 * d, 1), p + Vector2(2 * d, 3)]), LEAF)
	# La boule de ronces : une masse sombre hérissée d'épines claires.
	for k in 10:
		var a := TAU * k / 10.0 + _angle * 0.5
		var dir := Vector2(cos(a), sin(a))
		var base := end + dir * (RADIUS - 2.0)
		var side2 := Vector2(-dir.y, dir.x) * 1.6
		draw_colored_polygon(PackedVector2Array([base - side2, base + dir * 6.0, base + side2]), SPIKE)
	draw_circle(end, RADIUS + 1.0, Color(0.06, 0.05, 0.05))
	draw_circle(end, RADIUS, BALL[0])
	draw_circle(end + Vector2(-1, -1), RADIUS - 2.0, BALL[1])
	draw_circle(end + Vector2(-2, -3), 2.0, BALL[2])
