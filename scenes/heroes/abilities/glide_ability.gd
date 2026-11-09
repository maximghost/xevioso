class_name GlideAbility
extends HeroAbility
## Le Pagne-voile d'Afi, la Tisseuse : elle tend son pagne au-dessus d'elle et plane.
##
## On maintient le bouton de capacité en l'air : la chute devient lente et douce.
## En tenant aussi une direction, Afi prend le vent : elle file dans ce sens, plus vite
## qu'en courant, en ne perdant que très peu d'altitude (de quoi traverser un grand vide).
## On lâche le bouton (ou on touche le sol) pour replier le voile.
## Tenir le bouton dès le saut l'ouvre automatiquement au sommet.
## Pas de recharge : c'est un outil de déplacement, pas une attaque.
## (Plus tard : les courants d'air chaud des niveaux la feront remonter.)


## Vitesse de chute maximale sous le voile, sans direction tenue, en pixels par seconde
## (chute normale : 380).
@export var glide_fall_speed: float = 40.0
## En planant dans une direction : vitesse de descente (très faible) et vitesse horizontale.
## Exemple : lancée à 50 px du sol, elle parcourt environ 250 / 22 × 50 ≈ 570 px.
@export var drift_fall_speed: float = 22.0
@export var drift_speed: float = 250.0
## Rapidité avec laquelle elle prend (ou change) de direction sous le voile.
@export var drift_acceleration: float = 900.0

## Balancement du voile, en degrés, et sa vitesse.
@export var sway_angle: float = 6.0
@export var sway_speed: float = 5.0

## Texture du voile.
@export var canopy_texture: Texture2D = preload("res://assets/fx/pagne_voile.png")

# Le voile affiché au-dessus de la tête (créé au démarrage, caché quand replié).
var _canopy: Sprite2D
# Filets de vent qui suivent Afi pendant qu'elle plane.
var _wind: CPUParticles2D
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
	_wind = CPUParticles2D.new()
	_wind.texture = preload("res://assets/fx/streak.png")
	_wind.emitting = false
	_wind.amount = 10
	_wind.lifetime = 0.35
	_wind.local_coords = false
	_wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_wind.emission_rect_extents = Vector2(6, 18)
	_wind.position = Vector2(0, -12)
	_wind.gravity = Vector2.ZERO
	_wind.initial_velocity_min = 0.0
	_wind.initial_velocity_max = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.75))
	fade.set_color(1, Color(0.8, 0.95, 1.0, 0.0))
	_wind.color_ramp = fade
	player.add_child.call_deferred(_wind)


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
	# Le voile claque : petite onde turquoise.
	Fx.ring(player.get_parent(), player.global_position + Vector2(0, -30), Color(0.55, 0.9, 0.85), 16.0, 0.25, 2.0, 0.5)
	_wind.emitting = true


func physics_update(delta: float) -> void:
	_time += delta
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		# Elle prend le vent : vitesse de croisière dans la direction tenue.
		player.velocity.x = move_toward(player.velocity.x, direction * drift_speed, drift_acceleration * delta)
	# Le voile se balance et s'incline dans le sens de la marche (quand elle file).
	var lean: float = clampf(player.velocity.x / drift_speed, -1.0, 1.0) * 8.0 * float(player.facing)
	_canopy.rotation_degrees = sin(_time * sway_speed) * sway_angle - lean
	if not Input.is_action_pressed("ability") or player.is_on_floor():
		finish()


func limit_fall_speed(default_speed: float) -> float:
	var drifting: bool = Input.get_axis("move_left", "move_right") != 0.0
	return minf(default_speed, drift_fall_speed if drifting else glide_fall_speed)


func _on_finish() -> void:
	_canopy.visible = false
	if _wind != null:
		_wind.emitting = false

