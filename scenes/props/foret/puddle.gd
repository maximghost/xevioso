class_name Puddle
extends Area2D
## Une flaque d'eau sur le sol de la forêt. Quand un héros la traverse en courant, l'eau
## gicle à chaque pas ; quand il y retombe d'un saut, c'est une grande éclaboussure.
## L'eau reflète le jour (un peu plus vive quand la forêt est guérie).

## Largeur de la flaque (px).
@export var width: float = 56.0

const WATER := Color(0.62, 0.78, 0.84, 0.9)
var _cool: float = 0.0
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 10.0)
	cs.shape = r
	cs.position = Vector2(0, -5)
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_cool -= delta
	if _cool > 0.0:
		return
	for b in get_overlapping_bodies():
		if b is Player and b.is_on_floor() and absf(b.velocity.x) > 50.0:
			_splash(b.global_position.x, 0.55, signf(b.velocity.x))
			_cool = 0.24


func _on_body_entered(body: Node2D) -> void:
	if body is Player and body.velocity.y > 140.0:
		_splash(body.global_position.x, 1.0, 0.0)
		_cool = 0.3


func _splash(x: float, strength: float, dir: float) -> void:
	var at := Vector2(clampf(x, global_position.x - width / 2.0 + 4.0, global_position.x + width / 2.0 - 4.0), global_position.y - 1.0)
	Audio.play_at(&"splash", at, -2.0 if strength >= 1.0 else -6.0, 0.15)
	var drops := CPUParticles2D.new()
	drops.one_shot = true
	drops.explosiveness = 0.95
	drops.amount = int(10 + 16 * strength)
	drops.lifetime = 0.55
	drops.direction = Vector2(-dir * 0.3, -1.0)
	drops.spread = 55.0
	drops.initial_velocity_min = 50.0 * strength + 30.0
	drops.initial_velocity_max = 120.0 * strength + 40.0
	drops.gravity = Vector2(0, 520)
	drops.scale_amount_min = 1.0
	drops.scale_amount_max = 2.0
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.94, 1.0, 1.0))
	g.set_color(1, Color(0.62, 0.78, 0.84, 0.0))
	drops.color_ramp = g
	drops.position = at
	drops.z_index = 6
	get_parent().add_child(drops)
	drops.emitting = true
	get_tree().create_timer(1.0).timeout.connect(drops.queue_free)
	# une ride qui s'élargit sur l'eau
	var ring := Line2D.new()
	ring.width = 1.0
	ring.default_color = Color(0.9, 0.97, 1.0, 0.8)
	var pts := PackedVector2Array()
	for i in 17:
		var a: float = PI * i / 16.0
		pts.append(Vector2(cos(a) * 6.0, sin(a) * 1.2))
	ring.points = pts
	ring.position = at + Vector2(0, -1)
	ring.z_index = 6
	get_parent().add_child(ring)
	var t := ring.create_tween().set_parallel()
	t.tween_property(ring, "scale", Vector2(2.6 + strength, 1.8), 0.5)
	t.tween_property(ring, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(ring.queue_free)
