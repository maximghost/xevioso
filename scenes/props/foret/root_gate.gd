class_name RootGate
extends AnimatableBody2D
## Porte de racines : un rideau de racines entrelacées hérissées d'épines grises, du sol
## jusqu'à « height_tiles » cases. Elle s'ouvre en se rétractant dans le sol (pour de bon),
## ou se referme en jaillissant (l'arène d'Adan se scelle derrière les Envoyés).

@export_range(2, 5) var height_tiles: int = 5
@export var start_open: bool = false

var _sprite: Sprite2D
var _shape: CollisionShape2D
var _height: float = 80.0
var is_open: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	_height = height_tiles * 16.0
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/props/foret/root_gate.png")
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, 24, _height)
	_sprite.position = Vector2(-12, -_height)
	add_child(_sprite)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, _height)
	_shape.shape = rect
	_shape.position = Vector2(0, -_height / 2.0)
	add_child(_shape)
	if start_open:
		_set_amount(1.0)
		is_open = true


func open() -> void:
	if is_open:
		return
	is_open = true
	Audio.play_at(&"roots_open", global_position)
	Fx.dust(get_parent(), global_position + Vector2(0, -6), Color(0.45, 0.36, 0.28), 20, 90.0, 120.0)
	var t := create_tween()
	t.tween_method(_set_amount, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Audio.play_at(&"roots_close", global_position)
	Fx.dust(get_parent(), global_position + Vector2(0, -6), Color(0.45, 0.36, 0.28), 20, 90.0, 120.0)
	var t := create_tween()
	t.tween_method(_set_amount, 1.0, 0.0, 0.35).set_trans(Tween.TRANS_BACK)


## 0 = fermée (toute la hauteur), 1 = rentrée dans le sol.
func _set_amount(a: float) -> void:
	var h: float = _height * (1.0 - a)
	_sprite.region_rect = Rect2(0, 0, 24, maxf(h, 1.0))
	_sprite.position = Vector2(-12 + randf_range(-0.6, 0.6) * (1.0 if a > 0.0 and a < 1.0 else 0.0), -h)
	(_shape.shape as RectangleShape2D).size = Vector2(18, maxf(h, 1.0))
	_shape.position = Vector2(0, -h / 2.0)
	_shape.disabled = h < 4.0
	_sprite.visible = h >= 1.0
