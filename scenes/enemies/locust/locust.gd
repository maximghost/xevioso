class_name Locust
extends CharacterBody2D
## Le Criquet : un sbire volant du Mangeur de Pluie (les nuées dévastent les champs en saison sèche).
##
## Il patrouille en l'air autour de son point de départ, en ondulant. Quand un héros passe
## en dessous, à portée, il plonge droit sur lui, puis remonte à son altitude.
## Fragile : un seul coup suffit. Il faut le voir venir et le frapper au bon moment
## (ou l'esquiver pendant sa remontée).


## Demi-largeur de la patrouille, en pixels.
@export var patrol_range: float = 48.0
## Vitesse de patrouille et de plongée, en pixels par seconde.
@export var patrol_speed: float = 40.0
@export var dive_speed: float = 190.0
## Distance à laquelle il repère un héros.
@export var detect_range: float = 120.0
## Dégâts au contact.
@export var contact_damage: int = 1

enum State { PATROL, DIVE, RETURN }
var _state: State = State.PATROL
var _home: Vector2
var _direction: int = -1
var _time: float = 0.0
var _dive_time: float = 0.0
var _dive_dir: Vector2
var _cooldown: float = 0.0
var _dead: bool = false

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurtbox: Area2D = $Hurtbox


var _buzz: AudioStreamPlayer2D

func _ready() -> void:
	add_to_group(&"enemies")   # cibles possibles de la foudre de Xɛvioso
	_home = global_position
	_time = randf() * TAU
	_sprite.play(&"fly")
	$Health.died.connect(_on_died)
	_buzz = Audio.loop_on(self, &"locust_buzz", 0.0, 360.0)   # le bourdonnement des ailes


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	match _state:
		State.PATROL:
			velocity = Vector2(_direction * patrol_speed, cos(_time * 3.0) * 18.0)
			if absf(global_position.x - _home.x) > patrol_range:
				_direction = -int(signf(global_position.x - _home.x))
			var target := _find_target()
			if target != null and _cooldown <= 0.0:
				_state = State.DIVE
				_dive_time = 0.9
				# Il vise le haut du corps du héros, à l'endroit où il est maintenant.
				_dive_dir = (target.global_position + Vector2(0, -8) - global_position).normalized()
				_sprite.speed_scale = 2.0
		State.DIVE:
			velocity = _dive_dir * dive_speed
			_dive_time -= delta
			if _dive_time <= 0.0 or is_on_floor() or is_on_wall():
				_state = State.RETURN
				_sprite.speed_scale = 1.0
		State.RETURN:
			var to_home: Vector2 = _home - global_position
			velocity = to_home.normalized() * patrol_speed * 2.0
			if to_home.length() < 6.0:
				_state = State.PATROL
				_cooldown = 1.2
	if absf(velocity.x) > 1.0:
		_sprite.flip_h = velocity.x > 0.0     # le dessin regarde vers la gauche
	move_and_slide()
	for body in _hurtbox.get_overlapping_bodies():
		if body.has_method("take_hit"):
			var side: float = signf(body.global_position.x - global_position.x)
			body.take_hit(contact_damage, side if side != 0.0 else 1.0)


## Un héros visible : à portée, plus bas que le criquet, dans un cône vers le bas.
func _find_target() -> Node2D:
	for node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Node2D
		var offset: Vector2 = player.global_position - global_position
		if offset.length() < detect_range and offset.y > 10.0 and absf(offset.x) < offset.y * 1.6:
			return player
	return null


func take_hit(damage: int, _from_direction: float, _stun: float = -1.0) -> void:
	if not _dead:
		Audio.play_at(&"enemy_hit", global_position, -2.0)
		$Health.damage(damage)


func _on_died() -> void:
	_dead = true
	_hurtbox.set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	if _buzz != null:
		_buzz.queue_free()
	Audio.play_at(&"locust_die", global_position)
	Fx.dust(get_parent(), global_position, Color(0.66, 0.64, 0.3), 10, 70.0, 180.0)
	Fx.ring(get_parent(), global_position, Color(1.0, 0.9, 0.55), 16.0, 0.25)
	Fx.sparks(get_parent(), global_position, Color(1.0, 0.85, 0.35), 8)
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "rotation_degrees", 180.0, 0.35)
	tween.tween_property(_sprite, "position:y", 20.0, 0.35)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)


## Vrai une fois vaincu (pendant son animation de disparition) : la foudre l'ignore.
func is_dead() -> bool:
	return _dead
