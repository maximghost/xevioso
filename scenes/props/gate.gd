class_name Gate
extends AnimatableBody2D
## Portail en palissade : il bloque le passage tant qu'on n'a pas frappé son tambour.
##
## Ouvert, il s'enfonce dans le sol ; il remonte au bout d'un délai fixé par le tambour.
## Il clignote juste avant de se refermer, pour prévenir le joueur.


## Hauteur du portail, en cases de 16 px (le dessin fait au plus 4 cases).
@export_range(1, 4) var height_tiles: int = 4

var HEIGHT: float = 64.0

var _base: Vector2
var _open_amount: float = 0.0
var _close_tween: Tween
var _sprite: Sprite2D
var _time_left: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	HEIGHT = height_tiles * 16.0
	_base = position
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/props/gate.png")
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, 16, HEIGHT)
	_sprite.position = Vector2(-8, -HEIGHT)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, HEIGHT)
	shape.shape = rect
	shape.position = Vector2(0, -HEIGHT / 2.0)
	add_child(shape)


## Ouvre le portail pour « seconds » secondes (0 = pour toujours).
func open_for(seconds: float) -> void:
	_time_left = seconds if seconds > 0.0 else INF
	if _close_tween != null:
		_close_tween.kill()
	_close_tween = create_tween()
	_close_tween.tween_method(_set_open, _open_amount, 1.0, 0.35 * (1.0 - _open_amount) + 0.01)


func _physics_process(delta: float) -> void:
	if _time_left == INF or _open_amount <= 0.0:
		return
	_time_left -= delta
	# Dernière seconde : le portail clignote.
	_sprite.modulate.a = 0.5 if _time_left < 1.0 and int(_time_left * 10.0) % 2 == 0 else 1.0
	if _time_left <= 0.0 and (_close_tween == null or not _close_tween.is_running()):
		_sprite.modulate.a = 1.0
		_close_tween = create_tween()
		_close_tween.tween_method(_set_open, _open_amount, 0.0, 0.3)


## 0 = fermé, 1 = complètement enfoncé dans le sol. Seule la partie hors du sol est dessinée.
func _set_open(amount: float) -> void:
	_open_amount = amount
	position = _base + Vector2(0, HEIGHT * amount)
	_sprite.region_rect = Rect2(0, 0, 16, HEIGHT * (1.0 - amount))
