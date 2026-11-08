extends CanvasLayer
## Fin de la partie : les deux vies sont perdues. Le jeu se fige, la voix de Xɛvioso
## encourage à se relever ; on recommence le niveau depuis le début (les pierres sokpe
## déjà ramassées restent acquises).


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
	Game.clear_checkpoint(level_id)
	get_tree().paused = false
	get_tree().reload_current_scene()
