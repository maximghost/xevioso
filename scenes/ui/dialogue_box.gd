class_name DialogueBox
extends CanvasLayer
## Boîte de dialogue de Xɛvioso : en haut de l'écran (loin des boutons tactiles),
## l'emblème de la hache double, la parole qui s'écrit lettre par lettre, et en dessous,
## en petit, l'aide concrète aux commandes (clavier ou tactile selon l'appareil).
##
## Avancer : saut, hache, Entrée, clic ou toucher n'importe où. Un premier appui pendant
## que le texte s'écrit l'affiche en entier ; le suivant passe à la réplique d'après.
## Pendant un dialogue « bloquant », le jeu est figé.


## Émis quand la dernière réplique est passée.
signal finished

## Vitesse d'écriture, en caractères par seconde.
@export var chars_per_second: float = 38.0

var _lines: Array = []
var _index: int = 0
var _typing: bool = false
var _paused_game: bool = false
var _cooldown: float = 0.0
var _shown: float = 0.0
var _touch: bool = false

@onready var _panel: Control = $Panel
@onready var _text: Label = $Panel/Margin/Row/Column/Text
@onready var _hint: Label = $Panel/Margin/Row/Column/Hint
@onready var _next: Label = $Panel/Next


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_touch = DisplayServer.is_touchscreen_available()
	_panel.visible = false


## Joue une suite de répliques. « pause_game » : fige le jeu pendant le dialogue.
## On peut attendre la fin avec « await box.play(...) ».
func play(lines: Array, pause_game: bool = true) -> Signal:
	_lines = lines
	_index = 0
	_paused_game = pause_game and not get_tree().paused
	if _paused_game:
		get_tree().paused = true
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)
	_show_line()
	return finished


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	_text.text = line.get("text", "")
	_text.visible_characters = 0
	_shown = 0.0
	var hint: String = line.get("mobile" if _touch else "pc", "")
	_hint.text = hint
	_hint.visible = false
	_typing = true
	_next.visible = false
	_cooldown = 0.15


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _typing:
		_shown += delta * chars_per_second
		_text.visible_characters = int(_shown)
		if _text.visible_characters >= _text.get_total_character_count():
			_finish_typing()
	else:
		# Le petit triangle « suite » clignote doucement.
		_next.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_hint.visible = _hint.text != ""
	_next.visible = true


func _input(event: InputEvent) -> void:
	if not _panel.visible or _cooldown > 0.0:
		return
	var advance := false
	if event is InputEventScreenTouch and event.pressed:
		advance = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Sur écran tactile, chaque toucher produit aussi un faux clic : on ne compte que le toucher.
		advance = event.device != InputEvent.DEVICE_ID_EMULATION
	elif event.is_action_pressed("jump") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		advance = true
	if not advance:
		return
	get_viewport().set_input_as_handled()
	_cooldown = 0.12
	if _typing:
		_finish_typing()
		return
	_index += 1
	if _index < _lines.size():
		_show_line()
	else:
		_close()


func _close() -> void:
	_panel.visible = false
	if _paused_game:
		get_tree().paused = false
	finished.emit()
