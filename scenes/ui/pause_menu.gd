class_name PauseMenu
extends CanvasLayer
## Le menu de pause : il fige le jeu et propose de reprendre, de recommencer le niveau
## ou de revenir au menu principal.
##
## Ce nœud fonctionne même quand le jeu est en pause (process_mode = Always) :
## sans cela, il ne pourrait plus recevoir la touche qui enlève la pause.

@onready var _panel: Control = $Panel
@onready var _resume: Button = $Panel/Box/Resume
@onready var _restart: Button = $Panel/Box/Restart
@onready var _menu: Button = $Panel/Box/MainMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.hide()
	_resume.pressed.connect(toggle)
	_restart.pressed.connect(_on_restart)
	_menu.pressed.connect(Game.go_to_title)
	_build_volume_sliders()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


## Met le jeu en pause, ou le relance.
func toggle() -> void:
	var paused: bool = not get_tree().paused
	get_tree().paused = paused
	_panel.visible = paused
	Audio.play(&"pause_open" if paused else &"pause_close")
	if paused:
		_resume.grab_focus()  # pour naviguer au clavier ou à la manette


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()



## Réglages du son : trois curseurs (musique, bruitages, ambiances), gardés d'une partie à l'autre.
func _build_volume_sliders() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	for entry in [["Musique", "Musique"], ["Effets", "Bruitages"], ["Ambiance", "Ambiances"]]:
		var label := Label.new()
		label.text = entry[1]
		label.add_theme_font_size_override("font_size", 11)
		grid.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(110, 16)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value = Audio.get_volume(entry[0])
		var bus: String = entry[0]
		slider.value_changed.connect(func(v: float) -> void:
			Audio.set_volume(bus, v)
			if bus == "Effets":
				Audio.play(&"ui_move"))
		grid.add_child(slider)
	$Panel/Box.add_child(grid)
