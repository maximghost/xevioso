class_name WaveAbility
extends HeroAbility
## L'Onde de Kokou, le Tambourinaire : un coup de tambour qui libère une onde de choc.
## Et, en gardant le bouton enfoncé, le Tambour parlant (don de Xɛvioso au sanctuaire de la
## forêt) : Kokou s'arrête et fait parler son tambour. À chaque battement, tout ce qui l'entend
## à portée réagit : les racines sacrées poussent, les créatures corrompues s'endorment, la
## colère d'Adan retombe. Il joue tant qu'on tient le bouton.
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

## Délai de maintien avant que l'Onde devienne le Tambour parlant, en secondes.
@export var hold_delay: float = 0.3
## Intervalle entre deux battements du Tambour parlant.
@export var beat_interval: float = 0.42
## Portée du Tambour parlant (pour l'effet visuel ; chaque auditeur a la sienne).
@export var drum_radius: float = 176.0

## Vrai pendant que Kokou joue du Tambour parlant.
var drumming: bool = false
var _held: float = 0.0
var _beat: float = 0.0
var _beat_count: int = 0


func _init() -> void:
	# Recharge courte : on peut enchaîner les frappes, comme un rythme de tambour.
	cooldown = 0.1
	takes_control = false
	animation = &"throw"


func _activate() -> void:
	_time_left = strike_time
	_held = 0.0
	drumming = false
	var wave: Node2D = wave_scene.instantiate()
	# L'onde naît à hauteur du tambour (la taille de Kokou) et reste sur place.
	wave.global_position = player.global_position + Vector2(0.0, -4.0)
	player.get_parent().add_child(wave)
	Audio.play(&"wave")


func physics_update(delta: float) -> void:
	_time_left -= delta
	var holding: bool = Input.is_action_pressed("ability") and player.is_on_floor()
	if holding:
		_held += delta
	if not drumming and holding and _held >= hold_delay and Game.talking_drum_unlocked():
		drumming = true
		_beat = 0.0
		_beat_count = 0
	if drumming:
		if not holding:
			drumming = false
			finish()
			return
		# Kokou est planté : il joue.
		player.velocity.x = 0.0
		_beat -= delta
		if _beat <= 0.0:
			_beat = beat_interval
			_beat_count += 1
			_drum_beat()
		return
	if _time_left <= 0.0 and not (holding and _held < hold_delay):
		finish()


## Un battement du Tambour parlant : le son (deux tons qui alternent, comme une parole), un
## anneau qui s'étend jusqu'à la portée, et tout ce qui écoute à portée réagit.
func _drum_beat() -> void:
	var origin: Vector2 = player.global_position + Vector2(0.0, -10.0)
	var sprite := player.get_node_or_null("Visual/Sprite") as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames.has_animation(&"throw"):
		sprite.play(&"throw")
		sprite.frame = 0
	Audio.play(&"talking_drum_hi" if _beat_count % 2 == 0 else &"talking_drum_lo", -2.0)
	Fx.ring(player.get_parent(), origin, Color(1.0, 0.85, 0.45), drum_radius, 0.5, 2.0, 0.55)
	player.get_tree().call_group(&"drum_listener", &"hear_drum", origin)
