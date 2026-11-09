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
@export var afterimage_interval: float = 0.025

## Couleur des images rémanentes (doré de la foudre). Elles sont dessinées en mode
## additif : leur couleur s'ajoute au décor, ce qui leur donne un aspect lumineux.
@export var afterimage_color: Color = Color(1.0, 0.8, 0.3, 0.95)
## Protection qui dure encore un peu après la Ruée : Kodjo ne se blesse pas sur des épines
## ou un ennemi qu'il vient de traverser. (Une chute dans le vide coûte toujours un cœur.)
@export var protection_after: float = 0.3

# Direction de la Ruée : 1 vers la droite, -1 vers la gauche.
var _direction: int = 1
# Temps restant avant la fin de la Ruée.
var _time_left: float = 0.0
# Temps restant avant la prochaine image rémanente.
var _afterimage_timer: float = 0.0
# Protection restante après la fin de la Ruée, en secondes.
var _grace: float = 0.0
# Vrai quand la Ruée est disponible (rechargée au sol).
var _charged: bool = true


func _init() -> void:
	cooldown = 0.35
	takes_control = true
	animation = &"run"


func can_activate() -> bool:
	return _charged


func passive_update(delta: float) -> void:
	_grace = maxf(_grace - delta, 0.0)
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
	Audio.play(&"dash")

	# Le départ : un claquement de foudre derrière lui, et la poussière s'il est au sol.
	var level: Node = player.get_parent()
	Fx.ring(level, player.global_position, Color(1.0, 0.85, 0.4), 18.0, 0.22, 2.0, 1.6)
	Fx.sparks(level, player.global_position - Vector2(_direction * 8.0, 0.0), Color(1.0, 0.8, 0.3), 8)
	if player.is_on_floor():
		Fx.puff(level, player.global_position + Vector2(0, 19), Color(0.86, 0.72, 0.56), 4,
			Vector2(-_direction, -0.3), 60.0, 0.55)


func physics_update(delta: float) -> void:
	# Vitesse constante, trajectoire parfaitement horizontale.
	player.velocity = Vector2(_direction * dash_speed, 0.0)

	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = afterimage_interval
		player.spawn_afterimage(afterimage_color)
		_speed_lines()

	_time_left -= delta
	# Fin de la Ruée : temps écoulé, ou mur percuté.
	if _time_left <= 0.0 or player.is_on_wall():
		finish()


## Traits de vitesse : de fines lignes dorées laissées en travers de la trajectoire.
func _speed_lines() -> void:
	for i in 2:
		var line := Sprite2D.new()
		line.texture = preload("res://assets/fx/streak.png")
		line.modulate = Color(1.0, 0.9, 0.55, 0.9)
		player.get_parent().add_child(line)
		line.global_position = player.global_position + Vector2(-_direction * randf_range(4.0, 14.0), randf_range(-16.0, 14.0))
		var tween := line.create_tween().set_parallel(true)
		tween.tween_property(line, "scale:x", 0.2, 0.18)
		tween.tween_property(line, "modulate:a", 0.0, 0.18)
		tween.chain().tween_callback(line.queue_free)


func _on_finish() -> void:
	_grace = protection_after
	# Garde l'élan de la course : pas d'arrêt brutal à la sortie.
	player.velocity.x = _direction * player.max_speed * exit_speed_ratio


func grants_invulnerability() -> bool:
	return active or _grace > 0.0
