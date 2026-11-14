extends Area2D
## Onde de choc du coup de massue d'Adan : une vague de terre et de braise qui file au ras du
## sol jusqu'au bord de l'arène. On la saute.

var direction: int = 1
var speed: float = 200.0
var left: float = 0.0
var right: float = 99999.0
var _dust: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 14)
	shape.shape = r
	shape.position = Vector2(0, -7)
	add_child(shape)
	var flames := Sprite2D.new()
	flames.texture = preload("res://assets/enemies/adan/flame.png")
	flames.region_enabled = true
	flames.region_rect = Rect2(0, 0, 16, 16)
	flames.offset = Vector2(0, -8)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	flames.material = unshaded
	add_child(flames)
	body_entered.connect(func(b: Node2D) -> void:
		if b is Player:
			b.take_hit(1, float(direction)))


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	_dust -= delta
	if _dust <= 0.0:
		_dust = 0.06
		Fx.puff(get_parent(), global_position, Color(0.5, 0.42, 0.34), 2, Vector2(-direction, -1), 30.0, 0.6)
	if global_position.x < left + 8.0 or global_position.x > right - 8.0:
		queue_free()
