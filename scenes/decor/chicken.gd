class_name Chicken
extends Node2D
## Une poule du village (décor, sans collision).
##
## Elle reste près de sa case : elle s'arrête, picore, fait quelques pas, repart.
## Si le héros s'approche, elle s'enfuit en battant des ailes et perd une plume.
## Elle ne quitte jamais le sol plat où elle est née (pas de chute dans le vide).

## 0 = blanche, 1 = rousse.
@export var variant: int = 0
## Distance maximale à son point de départ, en pixels.
@export var roam: float = 40.0

var terrain: TileMapLayer
var player: Node2D

enum State { IDLE, PECK, WALK, FLEE }

const WALK_SPEED := 14.0
const FLEE_SPEED := 85.0
const SCARE_DISTANCE := 44.0

var _sprite: AnimatedSprite2D
var _state: State = State.IDLE
var _timer: float = 1.0
var _target_x: float = 0.0
var _home_x: float = 0.0
var _dir: float = 1.0
var _hop: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_home_x = position.x
	_rng.randomize()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _make_frames()
	_sprite.position = Vector2(0, -6)       # les pattes au point de pose
	add_child(_sprite)
	_sprite.flip_h = _rng.randf() < 0.5
	_dir = -1.0 if _sprite.flip_h else 1.0
	_set_state(State.IDLE)


func _make_frames() -> SpriteFrames:
	var sheet: Texture2D = load("res://assets/decor/village/chicken_%s.png" % ["white", "red"][variant])
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in [["idle", [0], 2.0, true], ["peck", [1, 2, 2, 1, 0], 10.0, false],
			["walk", [3, 4, 5, 6], 8.0, true], ["flap", [7, 8], 14.0, true]]:
		frames.add_animation(anim[0])
		frames.set_animation_speed(anim[0], anim[2])
		frames.set_animation_loop(anim[0], anim[3])
		for i in anim[1]:
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(i * 16, 0, 16, 12)
			frames.add_frame(anim[0], region)
	return frames


## Vrai si le sol est plein sous ce point et l'espace libre au-dessus.
func can_stand_at(x: float) -> bool:
	if terrain == null:
		return false
	var below: Vector2i = terrain.local_to_map(terrain.to_local(Vector2(x, position.y + 6.0)))
	var above: Vector2i = terrain.local_to_map(terrain.to_local(Vector2(x, position.y - 6.0)))
	return terrain.get_cell_source_id(below) != -1 and terrain.get_cell_source_id(above) == -1


func _set_state(state: State) -> void:
	_state = state
	match state:
		State.IDLE:
			_timer = _rng.randf_range(0.8, 2.4)
			_sprite.play(&"idle")
		State.PECK:
			_timer = 0.5
			_sprite.play(&"peck")
			_sprite.frame = 0
		State.WALK:
			_target_x = clampf(_home_x + _rng.randf_range(-roam, roam), _home_x - roam, _home_x + roam)
			_timer = 4.0
			_sprite.play(&"walk")
		State.FLEE:
			_timer = 1.1
			_sprite.play(&"flap")
			_drop_feather()


func _process(delta: float) -> void:
	_timer -= delta
	# Le héros approche : on détale à l'opposé.
	if player != null and _state != State.FLEE:
		var to_player: Vector2 = player.global_position + Vector2(0, 20) - global_position
		if absf(to_player.x) < SCARE_DISTANCE and absf(to_player.y) < 30.0:
			_dir = -signf(to_player.x) if to_player.x != 0.0 else 1.0
			_set_state(State.FLEE)

	match _state:
		State.IDLE:
			if _timer <= 0.0:
				_set_state(State.PECK if _rng.randf() < 0.55 else State.WALK)
		State.PECK:
			if _timer <= 0.0:
				_set_state(State.IDLE if _rng.randf() < 0.6 else State.PECK)
		State.WALK:
			var dx: float = _target_x - position.x
			if absf(dx) < 1.0 or _timer <= 0.0:
				_set_state(State.IDLE)
			else:
				_dir = signf(dx)
				_step(_dir * WALK_SPEED * delta)
		State.FLEE:
			_hop += delta * 16.0
			_step(_dir * FLEE_SPEED * delta)
			if _timer <= 0.0:
				_hop = 0.0
				_home_x = position.x   # elle s'installe là où elle s'est arrêtée
				_set_state(State.IDLE)

	_sprite.flip_h = _dir < 0.0
	# Petits bonds pendant la fuite.
	_sprite.position.y = -6.0 - absf(sin(_hop)) * 4.0 if _state == State.FLEE else -6.0


## Avance si le sol continue ; sinon fait demi-tour (jamais de chute).
func _step(amount: float) -> void:
	var next: float = position.x + amount
	if can_stand_at(next + signf(amount) * 5.0):
		position.x = next
	else:
		_dir = -_dir
		if _state == State.WALK:
			_set_state(State.IDLE)


func _drop_feather() -> void:
	var feather := Sprite2D.new()
	feather.texture = preload("res://assets/fx/feather.png")
	feather.position = position + Vector2(0, -8)
	get_parent().add_child(feather)
	var tween := feather.create_tween().set_parallel(true)
	tween.tween_property(feather, "position", feather.position + Vector2(-_dir * 10.0, 10.0), 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(feather, "rotation", _rng.randf_range(-2.0, 2.0), 1.2)
	tween.tween_property(feather, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.chain().tween_callback(feather.queue_free)
