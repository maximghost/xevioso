class_name DashAbility
extends HeroAbility
## La Ruée de Kodjo, le Coureur : un bond horizontal fulgurant.
##
## Pendant la Ruée, le héros file à vitesse fixe, sans gravité, et ne peut pas être
## blessé. Une seule Ruée par saut : elle se recharge en touchant le sol.
## À la fin, il garde un peu d'élan pour enchaîner naturellement avec la course.
## Des images rémanentes (silhouettes qui s'effacent) marquent sa trajectoire.


## Vitesse pendant la Ruée, en pixels par seconde (la course normale : 140 à 200).
@export var dash_speed: float = 460.0

## Durée de la Ruée, en secondes. Distance parcourue ≈ vitesse × durée (ici ≈ 74 px).
@export var duration: float = 0.16

## Vitesse conservée à la sortie, en part de la vitesse de course maximale du héros.
@export_range(0.0, 1.5) var exit_speed_ratio: float = 1.0

## Intervalle entre deux images rémanentes, en secondes.
@export var afterimage_interval: float = 0.03

## Couleur des images rémanentes (doré de la foudre). Elles sont dessinées en mode
## additif : leur couleur s'ajoute au décor, ce qui leur donne un aspect lumineux.
@export var afterimage_color: Color = Color(1.0, 0.7, 0.2, 0.85)

# Direction de la Ruée : 1 vers la droite, -1 vers la gauche.
var _direction: int = 1
# Temps restant avant la fin de la Ruée.
var _time_left: float = 0.0
# Temps restant avant la prochaine image rémanente.
var _afterimage_timer: float = 0.0
# Vrai quand la Ruée est disponible (rechargée au sol).
var _charged: bool = true


func _init() -> void:
	cooldown = 0.35
	takes_control = true
	animation = &"run"


func can_activate() -> bool:
	return _charged


func passive_update(_delta: float) -> void:
	# Toucher le sol recharge la Ruée (sauf pendant la Ruée elle-même).
	if not active and player.is_on_floor():
		_charged = true


func _activate() -> void:
	# On part dans la direction tenue ; sans direction, droit devant.
	var input: float = Input.get_axis("move_left", "move_right")
	_direction = int(signf(input)) if input != 0.0 else player.facing
	player.set_facing(_direction)

	_time_left = duration
	_afterimage_timer = 0.0
	# En l'air, la Ruée est consommée jusqu'au prochain atterrissage.
	_charged = player.is_on_floor()
	player.velocity = Vector2(_direction * dash_speed, 0.0)


func physics_update(delta: float) -> void:
	# Vitesse constante, trajectoire parfaitement horizontale.
	player.velocity = Vector2(_direction * dash_speed, 0.0)

	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = afterimage_interval
		player.spawn_afterimage(afterimage_color)

	_time_left -= delta
	# Fin de la Ruée : temps écoulé, ou mur percuté.
	if _time_left <= 0.0 or player.is_on_wall():
		finish()


func _on_finish() -> void:
	# Garde l'élan de la course : pas d'arrêt brutal à la sortie.
	player.velocity.x = _direction * player.max_speed * exit_speed_ratio


func grants_invulnerability() -> bool:
	return active
