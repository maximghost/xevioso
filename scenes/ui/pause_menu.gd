class_name PauseMenu
extends CanvasLayer
## Le menu de pause : il fige le jeu et propose de reprendre ou de recommencer.
##
## Ce nœud fonctionne même quand le jeu est en pause (process_mode = Always) :
## sans cela, il ne pourrait plus recevoir la touche qui enlève la pause.

@onready var _panel: Control = $Panel
@onready var _resume: Button = $Panel/Box/Resume
@onready var _restart: Button = $Panel/Box/Restart
@onready var _reset: Button = $Panel/Box/ResetSave


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.hide()
	_resume.pressed.connect(toggle)
	_restart.pressed.connect(_on_restart)
	_reset.pressed.connect(_on_reset_save)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


## Met le jeu en pause, ou le relance.
func toggle() -> void:
	var paused: bool = not get_tree().paused
	get_tree().paused = paused
	_panel.visible = paused
	if paused:
		_resume.grab_focus()  # pour naviguer au clavier ou à la manette


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Bouton de test : efface toute la progression (héros, pierres, point de contrôle)
## et relance le niveau. Il sera remplacé par « Nouvelle partie » dans le menu principal.
func _on_reset_save() -> void:
	Game.reset_progress()
	_on_restart()
