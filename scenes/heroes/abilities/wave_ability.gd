class_name WaveAbility
extends HeroAbility
## L'Onde de Kokou, le Tambourinaire : un coup de tambour qui libère une onde de choc.
##
## L'onde part de Kokou et s'élargit en anneau : tous les ennemis proches, devant
## comme derrière, prennent un coup, sont repoussés et restent sonnés. C'est l'outil
## pour se sortir d'un groupe. Kokou continue de bouger pendant la frappe.
## (Plus tard : l'onde fera aussi vibrer certains éléments du décor.)


## La scène de l'onde.
@export var wave_scene: PackedScene = preload("res://scenes/fx/drum_wave.tscn")

## Durée de la frappe (animation), en secondes.
@export var strike_time: float = 0.12

# Temps restant de la frappe.
var _time_left: float = 0.0


func _init() -> void:
	# Recharge courte : on peut enchaîner les frappes, comme un rythme de tambour.
	cooldown = 0.1
	takes_control = false
	animation = &"throw"


func _activate() -> void:
	_time_left = strike_time
	var wave: Node2D = wave_scene.instantiate()
	# L'onde naît à hauteur du tambour (la taille de Kokou) et reste sur place.
	wave.global_position = player.global_position + Vector2(0.0, -4.0)
	player.get_parent().add_child(wave)
	Audio.play(&"wave")


func physics_update(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		finish()
