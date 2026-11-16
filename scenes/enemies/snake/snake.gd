class_name Snake
extends Crawler
## Le serpent (un python assombri par la poussière d'Adaka). Il ondule sur le sol ; quand un
## héros passe devant lui, il se love, siffle (c'est l'avertissement) puis se détend d'un coup
## et mord, avant de reprendre son souffle. Le moment de le frapper : pendant qu'il siffle,
## ou juste après sa morsure.

## Distance à laquelle il repère un héros devant lui (px).
@export var strike_range: float = 78.0
## Vitesse de la détente (px/s).
@export var strike_speed: float = 280.0

enum { SLITHER, COIL, STRIKE, RECOVER }
var _state: int = SLITHER
var _t: float = 0.0


func _physics_process(delta: float) -> void:
	if _dead or _sleep_timer > 0.0 or _stun_timer > 0.0:
		if _state != SLITHER:
			_state = SLITHER
			_sprite.play(&"walk")
		super(delta)
		return
	match _state:
		SLITHER:
			super(delta)
			var hero := _hero_in_front()
			if hero != null and is_on_floor():
				_state = COIL
				_t = 0.55
				_sprite.play(&"coil")
				Audio.play_at(&"snake_hiss", global_position)
			return
		COIL:
			_t -= delta
			velocity.x = 0.0
			var hero := _hero_in_front(1.4)
			if hero != null:
				_set_direction(int(signf(hero.global_position.x - global_position.x)))
			if _t <= 0.0:
				_state = STRIKE
				_t = 0.2
				_sprite.play(&"strike")
				Audio.play_at(&"snake_strike", global_position)
		STRIKE:
			_t -= delta
			velocity.x = _direction * strike_speed
			if _t <= 0.0:
				_state = RECOVER
				_t = 0.75
				_sprite.play(&"coil")
		RECOVER:
			_t -= delta
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _t <= 0.0:
				_state = SLITHER
				_sprite.play(&"walk")
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	_hurt_touching_heroes()


func _hero_in_front(reach: float = 1.0) -> Node2D:
	for hero in get_tree().get_nodes_in_group(&"player"):
		var d: Vector2 = hero.global_position - global_position
		if absf(d.y + 12.0) < 30.0 and absf(d.x) < strike_range * reach and (signf(d.x) == _direction or reach > 1.0):
			return hero
	return null


func _on_died() -> void:
	Audio.play_at(&"snake_die", global_position)
	super()
