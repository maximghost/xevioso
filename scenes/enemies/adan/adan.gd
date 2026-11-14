class_name Adan
extends CharacterBody2D
## Adan, « la Colère » : serviteur d'Adaka, gardien du cœur malade de l'iroko.
##
## Un colosse d'écorce et de braise. Il a une jauge de Fureur qui monte à chaque coup qu'il
## reçoit (et, blessé, d'elle-même). Pleine, il entre en Fureur : il rugit, le sol de l'arène
## s'embrase quelques secondes — seuls les appuis surélevés, et surtout les racines sacrées
## que le Tambour parlant de Kokou fait pousser, ne brûlent pas. Après sa Fureur il est
## épuisé : c'est le moment de frapper. Le Tambour parlant fait aussi retomber sa Fureur :
## on peut choisir de la contenir… ou de la provoquer quand on est prêt.
##
## Phases (selon ses points de vie) :
##   1. il marche, charge d'un mur à l'autre (assommé s'il s'écrase contre la paroi) et lance
##      des lances de braise en cloche ;
##   2. il bondit et frappe le sol (deux ondes de choc à sauter) et appelle des chauves-souris ;
##   3. tout va plus vite, sa Fureur monte d'elle-même et ses lances pleuvent par trois.

signal defeated
signal health_changed(current: int, maximum: int)
signal rage_changed(value: float)

@export var max_health: int = 30
@export var arena_left: float = 0.0
@export var arena_right: float = 640.0
## Hauteur du sol de l'arène (y des pieds).
@export var floor_y: float = 0.0
@export var fire_floor_path: NodePath
@export var bat_scene: PackedScene

const GRAVITY := 1100.0
const WALK := 42.0
const CHARGE := 300.0

enum S { WAIT, INTRO, IDLE, WALK, CHARGE_WIND, CHARGE, STUNNED, THROW, LEAP, SLAM, FURY_WIND, FURY, TIRED, HURT, DEAD }
var state: S = S.WAIT
var health: int = 30
var rage: float = 0.0
var _t: float = 0.0
var _facing: int = -1
var _next: Array = []
var _player: Player
var _sprite: AnimatedSprite2D
var _hurtbox: Area2D
var _invuln: float = 0.0
var _fire: Node
var _thrown: int = 0
var _start_pos: Vector2
var _bats: Array = []
var _glow: PointLight2D


func _ready() -> void:
	collision_layer = 4          # couche « ennemis » : la hache le touche
	collision_mask = 1
	add_to_group(&"enemies")
	add_to_group(&"drum_listener")
	health = max_health
	_start_pos = global_position
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = preload("res://assets/enemies/adan/adan_frames.tres")
	_sprite.offset = Vector2(-22, -68)     # pieds de l'image (x 94, y 132 sur 144 × 136) sur l'origine
	_sprite.play(&"idle")
	add_child(_sprite)
	var body := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 60)
	body.shape = rect
	body.position = Vector2(0, -30)
	add_child(body)
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(30, 54)
	hs.shape = hr
	hs.position = Vector2(0, -28)
	_hurtbox.add_child(hs)
	add_child(_hurtbox)
	_glow = PointLight2D.new()
	_glow.texture = Fx.light_texture()
	_glow.texture_scale = 1.6
	_glow.color = Color(1.0, 0.5, 0.2)
	_glow.energy = 0.7
	_glow.position = Vector2(0, -40)
	add_child(_glow)
	_fire = get_node_or_null(fire_floor_path)
	visible = false


## Le combat commence (appelé par le déclencheur de l'arène).
func awaken(player: Player) -> void:
	if state != S.WAIT:
		return
	_player = player
	visible = true
	_set_state(S.INTRO, 2.4)
	_sprite.play(&"fury")
	Audio.play_at(&"adan_roar", global_position)
	player.shake_camera(5.0, 1.0)
	Fx.dust(get_parent(), global_position, Color(0.4, 0.35, 0.3), 30, 160.0, 140.0)
	health_changed.emit(health, max_health)
	rage_changed.emit(rage)


## Le héros est tombé : le combat reprendra du début quand il reviendra.
func reset() -> void:
	for b in _bats:
		if is_instance_valid(b):
			b.queue_free()
	_bats.clear()
	if _fire != null:
		_fire.set_active(false)
	global_position = _start_pos
	velocity = Vector2.ZERO
	health = max_health
	rage = 0.0
	state = S.WAIT
	visible = false
	_sprite.modulate = Color.WHITE


func phase() -> int:
	if health > max_health * 2 / 3:
		return 1
	if health > max_health / 3:
		return 2
	return 3


func _set_state(s: S, duration: float) -> void:
	state = s
	_t = duration


func _physics_process(delta: float) -> void:
	if state == S.WAIT or state == S.DEAD:
		return
	_invuln = maxf(_invuln - delta, 0.0)
	_t -= delta
	if not is_on_floor() and state != S.LEAP:
		velocity.y += GRAVITY * delta
	if phase() == 3 and state not in [S.FURY, S.FURY_WIND, S.TIRED, S.INTRO]:
		_add_rage(4.0 * delta)
	_glow.energy = 0.6 + rage / 100.0 * 0.9 + (0.6 if state == S.FURY else 0.0)
	match state:
		S.INTRO:
			velocity.x = 0.0
			if _t <= 0.0:
				_think()
		S.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_face_player()
			if _t <= 0.0:
				_think()
		S.WALK:
			_face_player()
			velocity.x = _facing * WALK * (1.4 if phase() == 3 else 1.0)
			if _t <= 0.0 or absf(_player.global_position.x - global_position.x) < 40.0:
				_think()
		S.CHARGE_WIND:
			velocity.x = 0.0
			_sprite.position.x = randf_range(-1.5, 1.5)
			if _t <= 0.0:
				_sprite.position.x = 0.0
				_set_state(S.CHARGE, 3.0)
				_sprite.play(&"charge")
				Audio.play_at(&"adan_charge", global_position)
		S.CHARGE:
			velocity.x = _facing * CHARGE * (1.2 if phase() == 3 else 1.0)
			if randf() < 0.3:
				Fx.puff(get_parent(), global_position, Color(0.5, 0.45, 0.4), 2, Vector2(-_facing, -0.3), 30.0, 0.6)
			var wall: bool = (global_position.x <= arena_left + 20.0 and _facing < 0) or (global_position.x >= arena_right - 20.0 and _facing > 0)
			if wall or is_on_wall() or _t <= 0.0:
				# Il s'écrase contre la paroi : assommé (le moment de frapper).
				velocity.x = 0.0
				_set_state(S.STUNNED, 2.2 if phase() < 3 else 1.6)
				_sprite.play(&"hurt")
				Audio.play_at(&"adan_crash", global_position)
				_player.shake_camera(6.0, 0.4)
				Fx.dust(get_parent(), global_position + Vector2(_facing * 18, -20), Color(0.45, 0.38, 0.3), 24, 120.0, 140.0)
				_stars()
		S.STUNNED, S.TIRED:
			velocity.x = 0.0
			if _t <= 0.0:
				_sprite.play(&"idle")
				_set_state(S.IDLE, 0.4)
		S.THROW:
			velocity.x = 0.0
			var total: int = 3 if phase() == 3 else 2
			# Trois temps : il lève le bras (0,5 s), lance, recommence.
			if _t <= 0.0:
				if _thrown < total:
					_throw_spear(_thrown)
					_thrown += 1
					_sprite.play(&"throw")
					_t = 0.55 if phase() < 3 else 0.4
				else:
					_set_state(S.IDLE, 0.8)
					_sprite.play(&"idle")
		S.LEAP:
			velocity.y += GRAVITY * 1.2 * delta
			if is_on_floor() and _t < 0.5:
				_set_state(S.SLAM, 0.7)
				velocity = Vector2.ZERO
				_sprite.play(&"slam")
				_sprite.frame = 2
				_slam()
		S.SLAM:
			velocity.x = 0.0
			if _t <= 0.0:
				_sprite.play(&"idle")
				_set_state(S.IDLE, 0.6)
		S.FURY_WIND:
			velocity.x = 0.0
			_sprite.position = Vector2(randf_range(-2, 2), randf_range(-1, 1))
			if _t <= 0.0:
				_sprite.position = Vector2.ZERO
				_set_state(S.FURY, 6.5)
				if _fire != null:
					_fire.set_active(true)
				Audio.play_at(&"fury_burst", global_position)
				_player.shake_camera(8.0, 0.6)
				Fx.ring(get_parent(), global_position + Vector2(0, -30), Color(1.0, 0.5, 0.15), 260.0, 0.8, 5.0)
		S.FURY:
			velocity.x = 0.0
			# En Fureur, il crache des braises au hasard au-dessus de l'arène.
			if fmod(_t, 1.1) < delta:
				_throw_spear(0, true)
			if _t <= 0.0:
				if _fire != null:
					_fire.set_active(false)
				rage = 0.0
				rage_changed.emit(rage)
				_set_state(S.TIRED, 3.2)
				_sprite.play(&"hurt")
				Audio.play_at(&"adan_tired", global_position)
		S.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if _t <= 0.0:
				_set_state(S.IDLE, 0.3)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_left + 16.0, arena_right - 16.0)
	_sprite.flip_h = _facing > 0              # le dessin regarde vers la gauche
	if state not in [S.STUNNED, S.TIRED, S.INTRO]:
		for body in _hurtbox.get_overlapping_bodies():
			if body is Player:
				body.take_hit(1, signf(body.global_position.x - global_position.x))


func _face_player() -> void:
	if _player != null:
		_facing = -1 if _player.global_position.x < global_position.x else 1


## Choisit la prochaine attaque.
func _think() -> void:
	if rage >= 100.0:
		_set_state(S.FURY_WIND, 1.4)
		_sprite.play(&"fury")
		Audio.play_at(&"adan_roar", global_position)
		return
	_face_player()
	var dx: float = absf(_player.global_position.x - global_position.x)
	var options: Array = [S.CHARGE_WIND, S.THROW, S.WALK]
	if phase() >= 2:
		options.append(S.LEAP)
		if _bats.filter(func(b): return is_instance_valid(b)).size() < 2 and randf() < 0.35:
			_summon_bats()
	var pick: S = options[randi() % options.size()]
	if dx < 60.0 and pick == S.WALK:
		pick = S.CHARGE_WIND if phase() == 1 else S.LEAP
	match pick:
		S.CHARGE_WIND:
			_set_state(S.CHARGE_WIND, 0.7 if phase() < 3 else 0.5)
			_sprite.play(&"charge")
			_sprite.pause()
			Audio.play_at(&"adan_growl", global_position)
		S.THROW:
			_thrown = 0
			_set_state(S.THROW, 0.5)
			_sprite.play(&"throw")
			_sprite.pause()
		S.WALK:
			_set_state(S.WALK, 1.4)
			_sprite.play(&"walk")
		S.LEAP:
			_set_state(S.LEAP, 1.6)
			_sprite.play(&"slam")
			var target: float = clampf(_player.global_position.x, arena_left + 40.0, arena_right - 40.0)
			velocity = Vector2((target - global_position.x) / 0.9, -520.0)
			Audio.play_at(&"adan_growl", global_position)


func _throw_spear(index: int, random_rain: bool = false) -> void:
	var spear: Node2D = preload("res://scenes/enemies/adan/ember_spear.gd").new()
	var from: Vector2 = global_position + Vector2(_facing * 20, -64)
	var target: Vector2 = _player.global_position + Vector2((index - 1) * 40.0, 0)
	if random_rain:
		target = Vector2(randf_range(arena_left + 30.0, arena_right - 30.0), floor_y)
	spear.global_position = from
	# Tir en cloche : on calcule la vitesse pour atteindre la cible en ~0,9 s.
	var time: float = 0.9 if not random_rain else 1.2
	spear.velocity = Vector2((target.x - from.x) / time, (target.y - from.y - 0.5 * 700.0 * time * time) / time)
	get_parent().add_child(spear)
	Audio.play_at(&"spear_throw", from, -2.0)


func _slam() -> void:
	Audio.play_at(&"adan_slam", global_position)
	_player.shake_camera(9.0, 0.5)
	Fx.dust(get_parent(), global_position, Color(0.45, 0.38, 0.3), 30, 160.0, 160.0)
	for dir in [-1, 1]:
		var wave: Node2D = preload("res://scenes/enemies/adan/shockwave.gd").new()
		wave.global_position = Vector2(global_position.x + dir * 20, floor_y)
		wave.direction = dir
		wave.left = arena_left
		wave.right = arena_right
		wave.speed = 200.0 if phase() < 3 else 250.0
		get_parent().add_child(wave)


func _summon_bats() -> void:
	if bat_scene == null:
		return
	Audio.play_at(&"adan_call", global_position)
	for i in 2:
		var bat: Node2D = bat_scene.instantiate()
		bat.global_position = Vector2(lerpf(arena_left + 60.0, arena_right - 60.0, 0.25 + 0.5 * i), floor_y - 150.0)
		get_parent().add_child(bat)
		_bats.append(bat)


func _stars() -> void:
	Fx.sparks(get_parent(), global_position + Vector2(0, -70), Color(1.0, 0.9, 0.6), 10)


func _add_rage(amount: float) -> void:
	rage = clampf(rage + amount, 0.0, 100.0)
	rage_changed.emit(rage)


## Le Tambour parlant résonne à portée : sa Fureur retombe (pas pendant la Fureur elle-même).
func hear_drum(from: Vector2) -> void:
	if state in [S.WAIT, S.DEAD, S.FURY, S.FURY_WIND] or global_position.distance_to(from) > 260.0:
		return
	_add_rage(-7.0)
	Fx.ring(get_parent(), global_position + Vector2(0, -40), Color(0.6, 0.85, 1.0), 30.0, 0.4, 2.0)


func take_hit(damage: int, from_direction: float, _stun: float = -1.0) -> void:
	if state in [S.WAIT, S.DEAD, S.INTRO] or _invuln > 0.0:
		return
	# Épuisé ou assommé : les coups portent double.
	var dmg: int = damage * (2 if state in [S.STUNNED, S.TIRED] else 1)
	health = maxi(health - dmg, 0)
	_invuln = 0.12
	health_changed.emit(health, max_health)
	Audio.play_at(&"adan_hit", global_position)
	_sprite.modulate = Color(4, 3, 2.5)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	Fx.sparks(get_parent(), global_position + Vector2(0, -40), Color(1.0, 0.6, 0.25), 6)
	if state not in [S.STUNNED, S.TIRED, S.FURY, S.FURY_WIND]:
		_add_rage(12.0)
	if health <= 0:
		_die()


func _die() -> void:
	_set_state(S.DEAD, 0.0)
	velocity = Vector2.ZERO
	_hurtbox.set_deferred("monitoring", false)
	if _fire != null:
		_fire.set_active(false)
	for b in _bats:
		if is_instance_valid(b) and b.has_method("take_hit"):
			b.take_hit(99, 0.0)
	_sprite.play(&"dead")
	Audio.play_at(&"adan_death", global_position)
	_player.shake_camera(10.0, 1.6)
	# Il se fend de partout, la braise s'éteint, il s'effondre en cendre.
	for i in 6:
		Fx.sparks(get_parent(), global_position + Vector2(randf_range(-20, 20), randf_range(-70, -10)), Color(1.0, 0.6, 0.2), 10)
		await get_tree().create_timer(0.25).timeout
	var t := create_tween().set_parallel()
	t.tween_property(_sprite, "modulate", Color(0.3, 0.3, 0.3, 0.0), 1.4)
	t.tween_property(_sprite, "scale", Vector2(1.2, 0.3), 1.4)
	t.tween_property(_glow, "energy", 0.0, 1.0)
	Fx.dust(get_parent(), global_position + Vector2(0, -30), Color(0.35, 0.33, 0.3), 50, 200.0, 120.0)
	await t.finished
	defeated.emit()
	queue_free()
