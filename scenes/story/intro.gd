extends Control
## Scène d'ouverture : une nuit d'orage sur le village asséché. Kodjo et Afi lèvent les yeux ;
## la foudre frappe et l'emblème de Xɛvioso, la hache double, apparaît dans le ciel.
## Sa voix désigne les Envoyés et leur mission. On peut passer la scène à tout moment.


@onready var _emblem: Node2D = $Emblem
@onready var _flash: ColorRect = $Flash
@onready var _fade: ColorRect = $Fade
@onready var _skip: Button = $Skip

var _leaving: bool = false
var _box: DialogueBox


func _ready() -> void:
	_emblem.modulate.a = 0.0
	_flash.color.a = 0.0
	_fade.color.a = 1.0
	_skip.pressed.connect(_leave)
	_run()


func _process(_delta: float) -> void:
	# L'emblème respire doucement, comme une braise.
	var t: float = Time.get_ticks_msec() / 1000.0
	$Emblem/Glow.scale = Vector2.ONE * (1.0 + 0.06 * sin(t * 2.4))
	_emblem.position.y = 150.0 + 2.0 * sin(t * 1.3)


func _run() -> void:
	# La nuit se dévoile.
	await create_tween().tween_property(_fade, "color:a", 0.0, 1.2).finished
	await get_tree().create_timer(0.6).timeout
	# La foudre frappe : l'emblème apparaît.
	_lightning(0.9)
	_emblem.modulate.a = 1.0
	await get_tree().create_timer(0.8).timeout
	_box = preload("res://scenes/ui/dialogue_box.tscn").instantiate()
	add_child(_box)
	_box.finished.connect(_leave)
	_box.play(Voices.lines(&"intro"), false)
	_ambient_lightning()


## Quelques éclairs lointains pendant que Xɛvioso parle.
func _ambient_lightning() -> void:
	while not _leaving and is_inside_tree():
		await get_tree().create_timer(randf_range(4.0, 8.0)).timeout
		if not _leaving:
			_lightning(0.35)


func _lightning(strength: float) -> void:
	_flash.color.a = strength
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)


## Fin de la scène (ou « Passer ») : un dernier éclair, fondu au noir, premier niveau.
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_skip.disabled = true
	if _box != null:
		_box.queue_free()
	_lightning(1.0)
	await create_tween().tween_property(_fade, "color:a", 1.0, 0.9).finished
	Game.go_to_level(Game.FIRST_LEVEL)
