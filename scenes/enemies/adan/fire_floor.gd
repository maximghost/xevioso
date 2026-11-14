class_name FireFloor
extends Area2D
## Le sol de l'arène qui s'embrase pendant la Fureur d'Adan. Une rangée de flammes au ras du
## sol ; tout héros qui touche le sol brûle. Les appuis surélevés (branches, racines sacrées)
## sont au-dessus des flammes. Une seconde avant, des fumerolles avertissent.

@export var width: float = 480.0

var active: bool = false
var _flames: Array[Sprite2D] = []
var _time: float = 0.0
var _hurt_cd: float = 0.0
var _light: PointLight2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 10)
	shape.shape = r
	shape.position = Vector2(width / 2.0, -5)
	add_child(shape)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in int(width / 16.0):
		var f := Sprite2D.new()
		f.texture = preload("res://assets/enemies/adan/flame.png")
		f.region_enabled = true
		f.region_rect = Rect2((i % 4) * 16, 0, 16, 16)
		f.position = Vector2(i * 16 + 8, -8)
		f.material = unshaded
		f.visible = false
		add_child(f)
		_flames.append(f)
	_light = PointLight2D.new()
	_light.texture = Fx.light_texture()
	_light.texture_scale = width / 110.0
	_light.color = Color(1.0, 0.45, 0.15)
	_light.energy = 0.0
	_light.position = Vector2(width / 2.0, -10)
	add_child(_light)


func set_active(on: bool) -> void:
	active = on
	for f in _flames:
		f.visible = on
		f.scale = Vector2(1, 0.2)
		if on:
			create_tween().tween_property(f, "scale", Vector2.ONE, 0.3 + randf() * 0.2)
	create_tween().tween_property(_light, "energy", 1.2 if on else 0.0, 0.3)
	if on:
		Audio.play_at(&"fire_whoosh", global_position + Vector2(width / 2.0, 0))


func _physics_process(delta: float) -> void:
	if not active:
		return
	_time += delta
	_hurt_cd = maxf(_hurt_cd - delta, 0.0)
	var frame: int = int(_time * 10.0)
	for i in _flames.size():
		_flames[i].region_rect = Rect2(((i + frame) % 4) * 16, 0, 16, 16)
	if _hurt_cd <= 0.0:
		for body in get_overlapping_bodies():
			if body is Player and body.is_on_floor():
				body.take_hit(1, 0.0)
				_hurt_cd = 0.5
