class_name MessengerBird
extends Node2D
## L'oiseau messager (un touraco) : il connaît l'ordre dans lequel les tambours-arbres doivent
## parler. Perché sur l'arbre sacré, il s'envole, se pose sur chaque tambour à son tour et
## siffle sa voix ; puis il revient, attend, et recommence. À l'Envoyé de l'observer.

signal song_done

## Les positions où se poser, dans l'ordre (calculées par l'énigme : au-dessus des tambours).
var stops: Array[Vector2] = []
## Les voix à siffler, dans le même ordre.
var voices: PackedInt32Array = PackedInt32Array()
var drums: Array = []
var perch: Vector2
var _sprite: AnimatedSprite2D
var _running: bool = false
var _stop: bool = false


func _ready() -> void:
	perch = global_position
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = preload("res://assets/props/foret/bird_frames.tres")
	_sprite.play(&"perch")
	add_child(_sprite)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sprite.material = unshaded


## Chante la suite en boucle tant qu'on ne l'arrête pas.
func start() -> void:
	if _running:
		return
	_running = true
	_stop = false
	while not _stop and is_inside_tree():
		await get_tree().create_timer(2.2).timeout
		if _stop or not is_inside_tree():
			break
		Audio.play_at(&"bird_call", global_position, -2.0)
		await get_tree().create_timer(0.6).timeout
		for i in stops.size():
			if _stop:
				break
			await _fly_to(stops[i])
			if _stop:
				break
			_sprite.play(&"perch")
			Audio.play_at(StringName("bird_note_%d" % voices[i]), global_position)
			if i < drums.size() and drums[i] != null:
				drums[i].sound(true)        # le tambour répond tout bas : on voit lequel
			Fx.ring(get_parent(), global_position, Color(0.9, 1.0, 0.7), 14.0, 0.4, 1.5)
			await get_tree().create_timer(0.9).timeout
		await _fly_to(perch)
		_sprite.play(&"perch")
		song_done.emit()
		await get_tree().create_timer(2.5).timeout
	_running = false


func stop() -> void:
	_stop = true


## Énigme résolue : il chante de joie, fait un tour et s'en va.
func celebrate() -> void:
	stop()
	Audio.play_at(&"bird_happy", global_position)
	await _fly_to(global_position + Vector2(-40, -50))
	await _fly_to(global_position + Vector2(80, -30))
	await _fly_to(global_position + Vector2(220, -160))
	queue_free()


func _fly_to(target: Vector2) -> void:
	_sprite.play(&"fly")
	_sprite.flip_h = target.x < global_position.x      # le dessin regarde vers la droite
	var d: float = global_position.distance_to(target)
	var t := create_tween()
	var start := global_position
	var mid := (start + target) / 2.0 + Vector2(0, -20 - d * 0.15)
	t.tween_method(func(k: float) -> void:
		global_position = start.lerp(mid, k).lerp(mid.lerp(target, k), k), 0.0, 1.0, maxf(0.35, d / 150.0))
	await t.finished
