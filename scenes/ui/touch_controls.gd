class_name TouchControls
extends CanvasLayer
## Les boutons tactiles, pour jouer sur téléphone et tablette.
##
## Chaque bouton est un TouchScreenButton relié à une action d'entrée (move_left, jump...) :
## pour le reste du jeu, appuyer sur un bouton revient exactement à appuyer sur la touche
## du clavier correspondante. Le héros n'a donc rien à savoir des écrans tactiles.
##
## Les boutons ne s'affichent que sur un appareil tactile. Sur ordinateur, ils restent cachés,
## sauf si l'on coche « Always Visible » pour régler leur position.

## Affiche les boutons même sans écran tactile (pour les tester sur ordinateur).
@export var always_visible: bool = false

## Marge entre les boutons et les bords de l'écran, en pixels du jeu.
@export var margin: float = 14.0

@onready var _left: TouchScreenButton = $Left
@onready var _right: TouchScreenButton = $Right
@onready var _jump: TouchScreenButton = $Jump
@onready var _attack: TouchScreenButton = $Attack
@onready var _ability: TouchScreenButton = $Ability
@onready var _switch: TouchScreenButton = $Switch
@onready var _pause: TouchScreenButton = $Pause


func _ready() -> void:
	if always_visible:
		for button: TouchScreenButton in _buttons():
			button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	# L'écran peut changer de taille (rotation, redimensionnement du navigateur) :
	# on replace les boutons à chaque fois.
	get_viewport().size_changed.connect(_layout)
	_layout()


func _buttons() -> Array[TouchScreenButton]:
	return [_left, _right, _jump, _attack, _ability, _switch, _pause]


## Place les boutons dans les coins, quelle que soit la largeur de l'écran.
##
## La hauteur du jeu vaut toujours 360 pixels ; sa largeur varie selon l'écran
## (640 en 16:9, davantage sur un téléphone allongé). La position d'un TouchScreenButton
## est celle de son coin supérieur gauche.
func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size

	# À gauche : les deux flèches de déplacement.
	_left.position = Vector2(margin, screen.y - margin - 44.0)
	_right.position = Vector2(margin + 52.0, screen.y - margin - 44.0)

	# À droite : le saut, le plus gros bouton, sous le pouce ; les actions autour de lui.
	_jump.position = Vector2(screen.x - margin - 52.0, screen.y - margin - 52.0)
	_attack.position = Vector2(screen.x - margin - 104.0, screen.y - margin - 42.0)
	_ability.position = Vector2(screen.x - margin - 46.0, screen.y - margin - 104.0)
	_switch.position = Vector2(screen.x - margin - 92.0, screen.y - margin - 88.0)

	# En haut à droite : la pause, petite et à l'écart pour éviter les appuis involontaires.
	_pause.position = Vector2(screen.x - margin - 28.0, margin)
