extends CanvasLayer
## Écran de fin d'une partie : il apparaît en fondu par-dessus le niveau gagné. On peut passer
## à la partie suivante (s'il y en a une), rejouer le niveau (depuis le début) ou revenir au menu.

## Titre et texte selon la partie finie.
const ENDINGS := {
	&"village_1": ["Fin de la première partie", "La pluie est revenue sur le village.\nMais Adaka court toujours : la forêt des irokos vous attend."],
	&"foret_1": ["Fin de la deuxième partie", "Adan est vaincu, les irokos sont redevenus sacrés.\nMais Adaka court toujours : la suite de l'aventure arrive bientôt."],
}

## Le niveau qu'on vient de finir (renseigné par le niveau).
var level_id: StringName = &""


@onready var _panel: Control = $Panel
@onready var _menu: Button = $Panel/Box/Menu
@onready var _replay: Button = $Panel/Box/Replay
@onready var _next: Button = $Panel/Box/Next


func _ready() -> void:
	if ENDINGS.has(level_id):
		$Panel/Box/Title.text = ENDINGS[level_id][0]
		$Panel/Box/Text.text = ENDINGS[level_id][1]
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 1.2)
	_menu.pressed.connect(Game.go_to_title)
	_replay.pressed.connect(_on_replay)
	var following: StringName = Game.next_level(level_id)
	_next.visible = following != &""
	_next.pressed.connect(func() -> void: Game.go_to_level(following))
	if _next.visible:
		_next.grab_focus()
	else:
		_menu.grab_focus()
	Audio.music(&"fete")


func _on_replay() -> void:
	if level_id != &"":
		Game.clear_checkpoint(level_id)
		Game.go_to_level(level_id)
