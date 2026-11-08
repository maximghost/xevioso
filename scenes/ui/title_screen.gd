extends Control
## Écran titre : le village sous l'harmattan défile lentement derrière le logo,
## les cinq Envoyés regardent l'horizon, et de temps en temps la foudre éclaire le ciel.
##
## « Nouvelle partie » efface la progression (après confirmation s'il y en a une)
## et lance le premier niveau ; « Continuer » reprend au dernier point de contrôle.
## (Développement : la touche T ouvre le terrain d'essai.)


@onready var _new_game: Button = %NewGame
@onready var _continue: Button = %Continue
@onready var _flash: ColorRect = $Flash

# Vrai après un premier clic sur « Nouvelle partie » alors qu'une partie existe.
var _confirming: bool = false


func _ready() -> void:
	_continue.disabled = not Game.has_save()
	_new_game.pressed.connect(_on_new_game)
	_continue.pressed.connect(func() -> void: Game.go_to_level(Game.level_to_continue()))
	# Le bouton sélectionné d'avance (clavier, manette) : celui qui sert le plus.
	(_new_game if _continue.disabled else _continue).grab_focus()
	_flash.color.a = 0.0
	_lightning_loop()


func _on_new_game() -> void:
	if Game.has_save() and not _confirming:
		# Garde-fou : on ne perd pas sa partie sur un clic distrait.
		_confirming = true
		_new_game.text = "Effacer la partie ?"
		return
	Game.reset_progress()
	Game.go_to_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_T:
		Game.go_to_level(&"test")


## La foudre, à intervalles irréguliers : un double éclair.
func _lightning_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(5.0, 10.0)).timeout
		for strength in [0.55, 0.3]:
			_flash.color.a = strength
			create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
			await get_tree().create_timer(0.16).timeout
