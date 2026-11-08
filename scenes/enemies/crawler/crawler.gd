class_name Crawler
extends CharacterBody2D
## La Motte sèche : une motte d'argile desséchée, sbire du Mangeur de Pluie.
##
## Le plus simple des ennemis : elle patrouille, fait demi-tour devant un mur ou au bord
## du vide, et blesse le héros qui la touche. Deux coups de hache la réduisent en poussière.
## Elle sert de modèle aux ennemis suivants :
##   - Health : ses points de vie ;
##   - take_hit() : appelée quand elle est touchée ;
##   - Hitbox : zone où elle peut être touchée, volontairement plus grande que le dessin
##     (un coup qui « frôle » doit compter : c'est plus juste pour le joueur) ;
##   - Hurtbox : zone de contact qui blesse les héros, un peu plus petite que le dessin
##     (un héros qui frôle l'ennemi ne doit pas être puni).


## Vitesse de marche, en pixels par seconde.
@export var speed: float = 36.0

## Direction de départ : -1 vers la gauche, 1 vers la droite.
@export_enum("Gauche:-1", "Droite:1") var start_direction: int = -1

## Dégâts infligés au héros qui la touche.
@export var contact_damage: int = 1

## Gravité, en pixels par seconde au carré.
@export var gravity: float = 900.0

## Recul quand elle est touchée, en pixels par seconde.
@export var knockback_speed: float = 110.0

## Durée pendant laquelle elle est sonnée après un coup (elle ne marche plus).
@export var stun_time: float = 0.25

# Direction de marche actuelle.
var _direction: int = -1
# Temps restant avant de reprendre la marche après un coup.
var _stun_timer: float = 0.0
# Vrai dès qu'elle est vaincue : elle ne fait plus rien et disparaît.
var _dead: bool = false

@onready var _health: Health = $Health
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _ledge_ray: RayCast2D = $LedgeRay
@onready var _hurtbox: Area2D = $Hurtbox

# Écart horizontal du rayon qui détecte le bord du vide, devant ses pattes.
var _ledge_ray_offset: float = 0.0


func _ready() -> void:
	_ledge_ray_offset = absf(_ledge_ray.position.x)
	_set_direction(start_direction)
	_health.died.connect(_on_died)
	_sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	if _dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	if _stun_timer > 0.0:
		# Sonnée : elle glisse sur son recul et ralentit.
		_stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	else:
		velocity.x = _direction * speed
		# Demi-tour devant un mur, ou quand le sol s'arrête devant elle.
		if is_on_floor() and (is_on_wall() or not _ledge_ray.is_colliding()):
			_set_direction(-_direction)
			velocity.x = _direction * speed

	move_and_slide()
	_hurt_touching_heroes()


## Blesse les héros qui la touchent. Vérifié à chaque image (et pas seulement à l'entrée
## dans la zone) : un héros qui reste collé reprend un coup dès la fin de son invincibilité.
func _hurt_touching_heroes() -> void:
	for body in _hurtbox.get_overlapping_bodies():
		if body.has_method("take_hit"):
			# Repousse le héros du côté opposé à la motte.
			var side: float = signf(body.global_position.x - global_position.x)
			body.take_hit(contact_damage, side if side != 0.0 else float(-_direction))


## Reçoit un coup (appelée par la hache). « from_direction » : sens du coup (-1 ou 1).
func take_hit(damage: int, from_direction: float) -> void:
	if _dead or not _health.damage(damage):
		return
	_stun_timer = stun_time
	velocity.x = from_direction * knockback_speed
	# Éclair blanc : le coup se voit.
	_sprite.modulate = Color(4.0, 4.0, 4.0)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)


## Change de sens : retourne le sprite et place le rayon devant les pattes.
func _set_direction(new_direction: int) -> void:
	_direction = new_direction
	# Le dessin regarde vers la gauche : on le retourne quand elle va vers la droite.
	_sprite.flip_h = _direction > 0
	_ledge_ray.position.x = _ledge_ray_offset * _direction


## Vaincue : elle ne blesse plus, s'écrase et part en poussière.
func _on_died() -> void:
	_dead = true
	# set_deferred : on ne modifie pas la physique au milieu d'un calcul de collision.
	_hurtbox.set_deferred("monitoring", false)
	$Hitbox.set_deferred("monitorable", false)
	$CollisionShape2D.set_deferred("disabled", true)
	_sprite.stop()
	_spawn_dust()
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "scale", Vector2(1.4, 0.4), 0.18)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)


## Petit nuage de poussière de latérite à l'endroit où elle disparaît.
func _spawn_dust() -> void:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 14
	dust.lifetime = 0.45
	dust.direction = Vector2.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 80.0
	dust.gravity = Vector2(0.0, 160.0)
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.5
	dust.color = Color(0.72, 0.44, 0.24)
	dust.global_position = global_position + Vector2(0.0, -4.0)
	dust.emitting = true
	get_parent().add_child(dust)
	# Le nuage se supprime une fois fini.
	dust.finished.connect(dust.queue_free)
