class_name DialogueBox
extends CanvasLayer
## Boîte de dialogue de Xɛvioso : en haut de l'écran (loin des boutons tactiles),
## l'emblème de la hache double, la parole qui s'écrit lettre par lettre, et en dessous,
## en petit, l'aide concrète aux commandes (clavier ou tactile selon l'appareil).
##
## Deux façons de parler :
##  - bloquante (récit, fin de niveau) : le jeu est figé ; on avance avec saut, hache,
##    Entrée, clic ou toucher n'importe où (un premier appui affiche tout le texte) ;
##  - murmure (indications en plein niveau) : le jeu continue, le joueur garde la main.
##    Chaque réplique reste le temps de la lire (une fine barre montre le temps restant),
##    puis passe seule. Les touches de jeu ne la font pas passer (on ne veut pas qu'un saut
##    « avale » une indication) ; toucher ou cliquer le bandeau, si. Les murmures qui
##    arrivent pendant qu'un autre parle attendent leur tour.


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
var _murmur: bool = false
var _queue: Array = []
var _read_left: float = 0.0
var _read_total: float = 1.0
var _bar: ColorRect

@onready var _panel: Control = $Panel
@onready var _text: Label = $Panel/Margin/Row/Column/Text
@onready var _hint: Label = $Panel/Margin/Row/Column/Hint
@onready var _next: Label = $Panel/Next


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_touch = DisplayServer.is_touchscreen_available()
	_panel.visible = false
	# La barre du temps de lecture (murmures), en bas du bandeau.
	_bar = ColorRect.new()
	_bar.color = Color(0.96, 0.72, 0.28, 0.85)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.visible = false
	add_child(_bar)


## Joue une suite de répliques. « pause_game » : fige le jeu pendant le dialogue.
## On peut attendre la fin avec « await box.play(...) ».
func play(lines: Array, pause_game: bool = true) -> Signal:
	if not pause_game and _panel.visible and _murmur:
		_queue.append_array(lines)      # un murmure parle déjà : celui-ci attend son tour
		return finished
	_lines = lines.duplicate()
	_index = 0
	_murmur = not pause_game
	_queue.clear()
	_paused_game = pause_game and not get_tree().paused
	if _paused_game:
		get_tree().paused = true
	_panel.visible = true
	Audio.play(&"dialogue_open")
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 0.94 if _murmur else 1.0, 0.2)
	_show_line()
	return finished


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	_text.text = line.get("text", "")
	_text.visible_characters = 0
	_shown = 0.0
	var hint: String = line.get("mobile" if _touch else "pc", "")
	_hint.text = hint
	_hint.visible = _murmur and hint != ""   # en murmure, l'aide aux commandes tout de suite
	_typing = true
	_next.visible = false
	_cooldown = 0.15
	var chars: int = _text.text.length() + hint.length()
	_read_total = clampf(1.8 + chars * 0.055, 3.5, 9.0)
	_read_left = _read_total


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _typing:
		var before: int = int(_shown)
		_shown += delta * chars_per_second
		_text.visible_characters = int(_shown)
		# Un léger cliquetis toutes les trois lettres : la parole « s'écrit ».
		if int(_shown) / 3 != before / 3:
			Audio.play(&"text_tick", 0.0, 0.15)
		if _text.visible_characters >= _text.get_total_character_count():
			_finish_typing()
	elif _murmur:
		# Le temps de lecture s'écoule, puis la réplique passe d'elle-même.
		_read_left -= delta
		_place_bar()
		if _read_left <= 0.0:
			_advance()
	else:
		# Le petit triangle « suite » clignote doucement.
		_next.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)


func _place_bar() -> void:
	var r: Rect2 = _panel.get_global_rect()
	_bar.visible = true
	_bar.position = Vector2(r.position.x + 6.0, r.end.y - 4.0)
	_bar.size = Vector2(maxf(0.0, (r.size.x - 12.0) * _read_left / _read_total), 2.0)


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_hint.visible = _hint.text != ""
	_next.visible = not _murmur


func _input(event: InputEvent) -> void:
	if not _panel.visible or _cooldown > 0.0:
		return
	var advance := false
	if _murmur:
		# En murmure, seul un toucher ou un clic sur le bandeau le fait passer.
		var on_panel: bool = false
		if event is InputEventScreenTouch and event.pressed:
			on_panel = _panel.get_global_rect().has_point(event.position)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
				and event.device != InputEvent.DEVICE_ID_EMULATION:
			on_panel = _panel.get_global_rect().has_point(event.position)
		if not on_panel:
			return
		get_viewport().set_input_as_handled()
		_cooldown = 0.12
		if _typing:
			_finish_typing()
		else:
			_advance()
		return
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
	_advance()


## Passe à la réplique suivante (ou au murmure en attente), ou ferme le bandeau.
func _advance() -> void:
	_index += 1
	if _index >= _lines.size() and not _queue.is_empty():
		_lines.append_array(_queue)
		_queue.clear()
	if _index < _lines.size():
		Audio.play(&"dialogue_next")
		_show_line()
	else:
		_close()


func _close() -> void:
	_panel.visible = false
	_bar.visible = false
	if _paused_game:
		get_tree().paused = false
	finished.emit()
