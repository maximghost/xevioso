extends CanvasLayer
## Écran de fin de la démo : il apparaît en fondu par-dessus le village sous la pluie.


@onready var _panel: Control = $Panel
@onready var _menu: Button = $Panel/Box/Menu


func _ready() -> void:
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 1.2)
	_menu.pressed.connect(Game.go_to_title)
	_menu.grab_focus()
	Audio.music(&"fete")
