extends Area2D
## Lance de braise lancée par Adan : elle vole en cloche, laisse des étincelles, blesse le héros
## touché et éclate en braises contre le sol ou un mur.

var velocity: Vector2 = Vector2.ZERO
var _sprite: Sprite2D
var _life: float = 3.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3           # monde + héros
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 4.0
	shape.shape = c
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/enemies/adan/spear.png")
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sprite.material = unshaded
	add_child(_sprite)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	velocity.y += 700.0 * delta
	position += velocity * delta
	rotation = velocity.angle()
	_life -= delta
	if randf() < 0.4:
		Fx.puff(get_parent(), global_position, Color(1.0, 0.55, 0.2), 1, -velocity, 10.0, 0.25)
	if _life <= 0.0:
		queue_free()


func _on_body(body: Node2D) -> void:
	if body is Player:
		body.take_hit(1, signf(velocity.x))
	Audio.play_at(&"spear_burst", global_position, -4.0)
	Fx.sparks(get_parent(), global_position, Color(1.0, 0.6, 0.2), 8)
	queue_free()
