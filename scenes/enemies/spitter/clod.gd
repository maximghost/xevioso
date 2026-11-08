class_name Clod
extends Area2D
## Motte de terre crachée par la termitière : elle suit une courbe et éclate au contact.


var velocity: Vector2 = Vector2.ZERO
@export var gravity_strength: float = 520.0
var _life: float = 4.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2          # le monde et les héros
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	velocity.y += gravity_strength * delta
	position += velocity * delta
	rotation += delta * 8.0
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.take_hit(1, signf(velocity.x) if velocity.x != 0.0 else 1.0)
	Fx.dust(get_parent(), global_position, Color(0.72, 0.44, 0.24), 6, 50.0, 120.0)
	queue_free()
