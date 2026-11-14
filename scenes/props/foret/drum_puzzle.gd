class_name DrumPuzzle
extends Node2D
## L'énigme des trois voix (sanctuaire de Kokou).
##
## Trois tambours-arbres, chacun sa voix. L'oiseau messager siffle, en se posant dessus,
## l'ordre dans lequel ils doivent parler. L'Envoyé doit les frapper dans ce même ordre ; le
## délai entre deux coups est limité (« window »), et les tambours sont placés pour que le
## trajet compte : il faut prévoir d'où frapper chacun. Une erreur, ou trop d'attente, et
## tout s'éteint (on recommence). Réussi : la porte de racines s'ouvre pour de bon.

signal solved

@export var sequence: PackedInt32Array = PackedInt32Array([1, 0, 2, 0])
## Délai maximal entre deux coups justes, en secondes.
@export var window: float = 8.0
@export var drum_paths: Array[NodePath] = []
@export var gate_path: NodePath
@export var bird_path: NodePath
## Zone où l'oiseau commence à chanter (le héros doit être entré dans le sanctuaire).
@export var start_x: float = 0.0

var _drums: Array[VoiceDrum] = []
var _gate: RootGate
var _bird: MessengerBird
var _progress: int = 0
var _timer: float = 0.0
var _done: bool = false
var _started: bool = false


func _ready() -> void:
	for p in drum_paths:
		var d := get_node(p) as VoiceDrum
		_drums.append(d)
		d.struck.connect(_on_struck)
	_gate = get_node_or_null(gate_path) as RootGate
	_bird = get_node_or_null(bird_path) as MessengerBird


func _drum_of_voice(v: int) -> VoiceDrum:
	for d in _drums:
		if d.voice == v:
			return d
	return null


func _process(delta: float) -> void:
	if _done:
		return
	if not _started:
		var level := Level.of(self)
		if level != null and level.player != null and level.player.global_position.x > start_x:
			_started = true
			if _bird != null:
				for v in sequence:
					var d := _drum_of_voice(v)
					_bird.stops.append(d.global_position + Vector2(0, -38))
					_bird.drums.append(d)
				_bird.voices = sequence
				_bird.start()
	if _progress > 0:
		_timer -= delta
		if _timer <= 0.0:
			_fail(false)


func _on_struck(voice: int) -> void:
	if _done:
		return
	if voice == sequence[_progress]:
		_progress += 1
		_timer = window
		_drum_of_voice(voice).set_lit(true)
		Audio.play(&"puzzle_good", -6.0)
		if _progress >= sequence.size():
			_solve()
	else:
		_fail(true)


func _fail(wrong: bool) -> void:
	if _progress == 0 and not wrong:
		return
	_progress = 0
	for d in _drums:
		d.set_lit(false)
	Audio.play(&"puzzle_bad" if wrong else &"puzzle_timeout", -4.0)


func _solve() -> void:
	_done = true
	solved.emit()
	Audio.play(&"puzzle_solved")
	for d in _drums:
		Fx.ring(get_parent(), d.global_position + Vector2(0, -16), Color(1.0, 0.92, 0.6), 60.0, 0.8, 3.0)
	if _bird != null:
		_bird.celebrate()
	await get_tree().create_timer(0.8).timeout
	if _gate != null:
		_gate.open()
