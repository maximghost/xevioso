extends CanvasLayer
## Écran de fin de la première partie : il apparaît en fondu par-dessus le village sous
## la pluie. On peut rejouer le niveau (depuis le début) ou revenir au menu.

## Le niveau qu'on vient de finir (renseigné par le niveau).
var level_id: StringName = &""


@onready var _panel: Control = $Panel
@onready var _menu: Button = $Panel/Box/Menu
@onready var _replay: Button = $Panel/Box/Replay


func _ready() -> void:
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 1.2)
	_menu.pressed.connect(Game.go_to_title)
	_replay.pressed.connect(_on_replay)
	_menu.grab_focus()
	Audio.music(&"fete")


func _on_replay() -> void:
	if level_id != &"":
		Game.clear_checkpoint(level_id)
		Game.go_to_level(level_id)
