class_name GlideAbility
extends HeroAbility
## Le Pagne-voile d'Afi, la Tisseuse : elle tend son pagne au-dessus d'elle et plane.
##
## On maintient le bouton de capacité en l'air : la chute devient lente et douce,
## et Afi garde tout son contrôle horizontal. On lâche le bouton (ou on touche le sol)
## pour replier le voile. Tenir le bouton dès le saut l'ouvre automatiquement au sommet.
## Pas de recharge : c'est un outil de déplacement, pas une attaque.
## (Plus tard : les courants d'air chaud des niveaux la feront remonter.)


## Vitesse de chute maximale sous le voile, en pixels par seconde (chute normale : 380).
@export var glide_fall_speed: float = 45.0

## Balancement du voile, en degrés, et sa vitesse.
@export var sway_angle: float = 6.0
@export var sway_speed: float = 5.0

## Texture du voile.
@export var canopy_texture: Texture2D = preload("res://assets/fx/pagne_voile.png")

# Le voile affiché au-dessus de la tête (créé au démarrage, caché quand replié).
var _canopy: Sprite2D
# Temps écoulé sous le voile, pour le balancement.
var _time: float = 0.0


func _init() -> void:
	cooldown = 0.0
	# Afi bouge normalement : seule sa chute est ralentie.
	takes_control = false


func _ready() -> void:
	# Le voile est rattaché au visuel du héros : il se retourne avec lui.
	_canopy = Sprite2D.new()
	_canopy.texture = canopy_texture
	_canopy.position = Vector2(2.0, -32.0)
	_canopy.visible = false
	player.get_node("Visual").add_child.call_deferred(_canopy)


## Ouvre le voile dès que le bouton est tenu, pas seulement au moment de l'appui.
func wants_activation() -> bool:
	return Input.is_action_pressed("ability")


## Seulement en l'air, et une fois le sommet du saut atteint (on ne freine pas la montée).
func can_activate() -> bool:
	return not player.is_on_floor() and player.velocity.y > -20.0


func _activate() -> void:
	_time = 0.0
	_canopy.visible = true
	# Le voile « claque » en s'ouvrant : il apparaît un peu écrasé puis prend sa forme.
	_canopy.scale = Vector2(0.4, 1.4)
	create_tween().tween_property(_canopy, "scale", Vector2.ONE, 0.12)


func physics_update(delta: float) -> void:
	_time += delta
	_canopy.rotation_degrees = sin(_time * sway_speed) * sway_angle
	if not Input.is_action_pressed("ability") or player.is_on_floor():
		finish()


func limit_fall_speed(default_speed: float) -> float:
	return minf(default_speed, glide_fall_speed)


func _on_finish() -> void:
	_canopy.visible = false

