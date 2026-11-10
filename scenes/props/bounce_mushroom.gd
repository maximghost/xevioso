class_name BounceMushroom
extends StaticBody2D
## Champignon de la forêt : on retombe dessus, il nous renvoie très haut (environ deux sauts).
## Le chapeau est solide (on s'y pose si on arrive de côté) ; une zone fine juste au-dessus
## le déclenche dès qu'un héros y tombe. Le nœud est posé au sol, au pied du champignon.

## Hauteur du bond, en pixels (au-dessus du chapeau).
@export var bounce_height: float = 120.0

var _sprite: Sprite2D
var _zone: Area2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/props/mushroom.png")
	_sprite.offset = Vector2(0, -9)
	add_child(_sprite)
	var cap := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 6)
	cap.shape = rect
	cap.position = Vector2(0, -11)
	add_child(cap)
	var zone := Area2D.new()
	_zone = zone
	zone.collision_layer = 0
	zone.collision_mask = 2
	var trigger := CollisionShape2D.new()
	var top := RectangleShape2D.new()
	top.size = Vector2(26, 8)
	trigger.shape = top
	trigger.position = Vector2(0, -17)
	zone.add_child(trigger)
	add_child(zone)
	zone.body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	# Un héros posé doucement sur le chapeau (sans vitesse de chute) rebondit aussi.
	for body in _zone.get_overlapping_bodies():
		if body is Player and body.is_on_floor():
			_on_body_entered(body)

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null or player.velocity.y < -10.0:
		return
	# Il faut arriver par le dessus : les pieds au-dessus du chapeau.
	if player.global_position.y + 19.0 > global_position.y - 12.0:
		return
	player.bounce(sqrt(2.0 * player.get_gravity_strength() * bounce_height))
	Audio.play_at(&"bounce", global_position)
	Fx.puff(get_parent(), global_position + Vector2(0, -16), Color(0.95, 0.85, 0.6), 4, Vector2(0, -1), 30.0, 0.5)
	var squash := create_tween()
	squash.tween_property(_sprite, "scale", Vector2(1.35, 0.6), 0.06)
	squash.tween_property(_sprite, "scale", Vector2(0.85, 1.2), 0.1)
	squash.tween_property(_sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
