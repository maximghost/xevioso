class_name TouchControls
extends CanvasLayer
## Les boutons tactiles, pour jouer sur téléphone et tablette.
##
## Chaque bouton est un TouchScreenButton relié à une action d'entrée (move_left, attack...) :
## pour le reste du jeu, appuyer sur un bouton revient exactement à appuyer sur la touche
## du clavier correspondante. Le héros n'a donc rien à savoir des écrans tactiles.
##
## Les boutons ne s'affichent que sur un appareil tactile. Sur ordinateur, ils restent cachés,
## sauf si l'on coche « Always Visible » pour régler leur position.

## Affiche les boutons même sans écran tactile (pour les tester sur ordinateur).
@export var always_visible: bool = false

## Marge entre les boutons et les bords de l'écran, en pixels du jeu.
@export var margin: float = 10.0

## Zone de toucher plus large que le dessin, en pixels : un doigt qui tombe
## juste à côté du bouton le déclenche quand même.
@export var touch_padding: float = 4.0

## Côté de la croix de déplacement, vu par le joueur qui tient le téléphone.
## Décoché (par défaut) : croix sous le pouce gauche, actions sous le pouce droit.
## Coché : l'inverse, pour les joueurs qui préfèrent.
@export var movement_on_right: bool = false

## Écart entre les flèches de la croix, en pixels.
@export var dpad_gap: float = 3.0

## Écart entre le saut et les boutons disposés en arc autour de lui, en pixels.
@export var arc_gap: float = 6.0

@onready var _left: TouchScreenButton = $Left
@onready var _right: TouchScreenButton = $Right
@onready var _up: TouchScreenButton = $Up
@onready var _down: TouchScreenButton = $Down
@onready var _jump: TouchScreenButton = $Jump
@onready var _attack: TouchScreenButton = $Attack
@onready var _ability: TouchScreenButton = $Ability
@onready var _switch: TouchScreenButton = $Switch
@onready var _pause: TouchScreenButton = $Pause


func _ready() -> void:
	if DisplayServer.is_touchscreen_available():
		_remove_mouse_bindings()
	# La flèche haut sert à sauter (son action est « jump ») ; elle déclenche aussi
	# « move_up », pour les mécaniques à venir (portes, grimper, viser vers le haut).
	_fit_touch_zones()
	# Les boutons sont dessinés lisses (pas en pixel art) : filtrage doux à l'agrandissement.
	for button: TouchScreenButton in _buttons():
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_up.pressed.connect(Input.action_press.bind(&"move_up"))
	_up.released.connect(Input.action_release.bind(&"move_up"))
	if always_visible:
		for button: TouchScreenButton in _buttons():
			button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	# L'écran peut changer de taille (rotation, redimensionnement du navigateur) :
	# on replace les boutons à chaque fois.
	get_viewport().size_changed.connect(_layout)
	_layout()


## Sur écran tactile, chaque appui est aussi converti en faux clic de souris (c'est ce qui
## permet de toucher les boutons des menus). Or la hache et la capacité répondent aussi
## au clic : sans précaution, toucher n'importe où sur l'écran lancerait la hache.
## On retire donc les clics de souris de ces actions : sur mobile, seuls les boutons
## tactiles les déclenchent. Le clavier et la manette ne sont pas touchés.
func _remove_mouse_bindings() -> void:
	for action: StringName in [&"attack", &"ability"]:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventMouseButton:
				InputMap.action_erase_event(action, event)


func _buttons() -> Array[TouchScreenButton]:
	return [_left, _right, _up, _down, _jump, _attack, _ability, _switch, _pause]


## Place les boutons dans les coins, quelle que soit la largeur de l'écran.
##
## La hauteur du jeu vaut toujours 360 pixels ; sa largeur varie selon l'écran
## (640 en 16:9, davantage sur un téléphone allongé). La position d'un TouchScreenButton
## est celle de son coin supérieur gauche.
func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size

	# --- La croix de déplacement, sous le pouce gauche --------------------------
	# Quatre flèches de 54 px autour d'un centre (environ 58 points sur un iPhone).
	var arrow: float = _left.texture_normal.get_width()
	var step: float = arrow + dpad_gap
	var half_cross: float = arrow * 1.5 + dpad_gap
	var center := Vector2(
		screen.x - margin - half_cross if movement_on_right else margin + half_cross,
		screen.y - margin - half_cross)
	var corner: Vector2 = center - Vector2(arrow, arrow) / 2.0
	_up.position = corner + Vector2(0.0, -step)
	_down.position = corner + Vector2(0.0, step)
	_left.position = corner + Vector2(-step, 0.0)
	_right.position = corner + Vector2(step, 0.0)

	# --- Les actions, en arc autour du saut, sous le pouce droit -----------------
	# Le saut (doré, le plus gros) dans le coin. Autour de lui, de bas en haut :
	# le changement de héros (vert) à sa gauche, la hache (rouge) en diagonale,
	# la capacité (bleue) au-dessus. Chaque action garde sa couleur et sa place.
	var right: bool = not movement_on_right
	var jump_size: float = _jump.texture_normal.get_width()
	var jump_center := Vector2(margin + jump_size / 2.0, screen.y - margin - jump_size / 2.0)
	_place_center(_jump, jump_center, right)
	_place_on_arc(_switch, jump_center, 180.0, jump_size, right)
	_place_on_arc(_attack, jump_center, 133.0, jump_size, right, 20.0)
	_place_on_arc(_ability, jump_center, 86.0, jump_size, right)

	# En haut à droite : la pause, à l'écart pour éviter les appuis involontaires.
	_pause.position = Vector2(screen.x - margin - _pause.texture_normal.get_width(), margin)


## Donne à chaque bouton une zone de toucher ronde, un peu plus grande que son dessin.
func _fit_touch_zones() -> void:
	for button: TouchScreenButton in _buttons():
		var zone := CircleShape2D.new()
		zone.radius = button.texture_normal.get_width() / 2.0 + touch_padding
		button.shape = zone
		button.shape_centered = true


## Centre un bouton en « center », compté depuis le coin bas du côté choisi :
## x depuis le bord droit si « on_right » (sinon depuis le bord gauche).
func _place_center(button: TouchScreenButton, center: Vector2, on_right: bool) -> void:
	var size: float = button.texture_normal.get_width()
	var x: float = get_viewport().get_visible_rect().size.x - center.x if on_right else center.x
	button.position = Vector2(x, center.y) - Vector2(size, size) / 2.0


## Place un bouton sur un arc autour du saut. « angle » en degrés, mesuré depuis le bord
## de l'écran vers l'intérieur (180 = à côté du saut, 90 = au-dessus). « extra » éloigne
## un peu plus le bouton (pour qu'il ne touche pas ses voisins sur l'arc).
func _place_on_arc(button: TouchScreenButton, around: Vector2, angle: float, around_size: float,
		on_right: bool, extra: float = 0.0) -> void:
	var size: float = button.texture_normal.get_width()
	var radius: float = around_size / 2.0 + arc_gap + size / 2.0 + extra
	var a: float = deg_to_rad(angle)
	# x compté vers l'intérieur de l'écran (cos négatif = on s'éloigne du bord).
	var center := around + Vector2(-cos(a) * radius, -sin(a) * radius)
	_place_center(button, center, on_right)
