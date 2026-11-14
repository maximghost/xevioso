class_name RatCritter
extends Node2D
## Un rat du sous-bois : il ne fait rien de mal, il vit. Tapi dans l'ombre, il détale en
## couinant quand un héros approche, file dans le sens opposé et disparaît dans un trou.

var _sprite: AnimatedSprite2D
var _fleeing: float = 0.0
var _dir: float = 1.0


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = preload("res://assets/enemies/rat/rat_frames.tres")
	_sprite.offset = Vector2(0, -5)
	_sprite.stop()
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if _fleeing > 0.0:
		_fleeing -= delta
		position.x += _dir * 170.0 * delta
		if _fleeing < 0.3:
			_sprite.modulate.a = _fleeing / 0.3
		if _fleeing <= 0.0:
			queue_free()
		return
	for node in get_tree().get_nodes_in_group(&"player"):
		var p := node as Node2D
		if absf(p.global_position.x - global_position.x) < 72.0 and absf(p.global_position.y - global_position.y) < 48.0:
			_dir = signf(global_position.x - p.global_position.x)
			if _dir == 0.0:
				_dir = 1.0
			_sprite.flip_h = _dir > 0.0          # le dessin regarde vers la gauche
			_sprite.play(&"run")
			_fleeing = 1.1
			Audio.play_at(&"rat_squeak", global_position, -2.0, 0.2)
