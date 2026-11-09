extends CanvasLayer
## Fin de la partie : les deux vies sont perdues (la colère de Xɛvioso a déjà fait trembler
## la terre, voir Level). Le jeu se fige, sa voix ordonne de se relever ; on recommence le
## niveau vraiment du début : les pierres sokpe ramassées pendant cette tentative sont à
## reprendre, la foudre revient à sa charge d'avant.


## Le niveau à recommencer (renseigné par le niveau).
var level_id: StringName = &""

@onready var _panel: Control = $Panel
@onready var _retry: Button = $Panel/Box/Retry
@onready var _menu: Button = $Panel/Box/Menu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.8)
	_retry.pressed.connect(_on_retry)
	_menu.pressed.connect(Game.go_to_title)
	_retry.grab_focus()


func _on_retry() -> void:
	Game.restart_attempt(level_id)
	get_tree().paused = false
	get_tree().reload_current_scene()
