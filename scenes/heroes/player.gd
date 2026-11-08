class_name Player
extends CharacterBody2D
## Contrôleur des Envoyés : course, saut, hache de foudre, capacités, coups reçus et réapparition.
##
## Un seul nœud Player représente toute l'équipe : changer de héros change son apparence
## et sa capacité, mais le corps physique reste le même, à la même place.
## Chaque héros est décrit par une fiche HeroData (nom, animations, capacité) ;
## sa capacité propre (la Ruée de Kodjo, le Pagne-voile d'Afi...) est un nœud HeroAbility
## que le Player crée au démarrage et pilote (voir hero_ability.gd).
##
## Toutes les valeurs sont en pixels et en secondes, à l'échelle du jeu (640 × 360).
## Les variables marquées @export apparaissent dans l'inspecteur de Godot :
## on peut les ajuster sans toucher au code.


# ---------------------------------------------------------------------------
# Apparence
# ---------------------------------------------------------------------------
@export_group("Équipe")

## Les héros jouables, dans l'ordre de passage (une fiche par Envoyé :
## assets/heroes/<nom>/<nom>_data.tres). Au début du jeu : Kodjo et Afi. Les autres
## s'ajouteront en progressant. Le premier de la liste est celui qu'on joue au départ.
@export var heroes: Array[HeroData] = []

## La scène de la hache de foudre.
@export var axe_scene: PackedScene = preload("res://scenes/fx/lightning_axe.tscn")

## Délai minimal entre deux lancers de hache, en secondes.
@export var throw_cooldown: float = 0.35

## Mémoire de la capacité : un appui un peu trop tôt (pendant la recharge) est retenu
## pendant ce délai et la capacité part dès qu'elle est prête. On ne perd pas d'appui.
@export var ability_buffer_time: float = 0.2


# ---------------------------------------------------------------------------
# Coups reçus
# ---------------------------------------------------------------------------
@export_group("Coups reçus")

## Recul quand le héros est touché (x : en arrière, y : vers le haut), en pixels par seconde.
@export var hurt_knockback: Vector2 = Vector2(150.0, -170.0)

## Durée pendant laquelle le héros, sonné, ne répond plus aux commandes.
@export var hurt_stun_time: float = 0.3

## Sous cette hauteur, le héros est tombé dans le vide : il réapparaît.
@export var death_height: float = 600.0

## Délai entre la mort et la réapparition, en secondes.
@export var respawn_delay: float = 0.8

## Invincibilité accordée à la réapparition, en secondes.
@export var respawn_invincibility: float = 1.5


## Émis quand on change de héros (pour l'interface).
signal hero_changed(hero: HeroData)
## Émis quand le héros meurt (avant de réapparaître).
signal died


# ---------------------------------------------------------------------------
# Réglages de la course
# ---------------------------------------------------------------------------
@export_group("Course")

## Vitesse horizontale maximale, en pixels par seconde.
@export var max_speed: float = 140.0

## Vitesse à laquelle le héros prend de l'élan au sol (pixels par seconde, chaque seconde).
@export var acceleration: float = 900.0

## Vitesse à laquelle il freine au sol quand on lâche la direction.
## Plus forte que l'accélération : le héros s'arrête net, sans glisser.
@export var friction: float = 1100.0

## Contrôle en l'air : plus faible qu'au sol, pour que le saut garde son élan.
@export var air_acceleration: float = 600.0

## Freinage en l'air quand on lâche la direction.
@export var air_friction: float = 400.0


# ---------------------------------------------------------------------------
# Réglages du saut
# ---------------------------------------------------------------------------
@export_group("Saut")

## Hauteur du saut complet, en pixels (le héros mesure 40 pixels).
@export var jump_height: float = 56.0

## Temps pour atteindre le sommet du saut, en secondes.
@export var time_to_apex: float = 0.38

## La chute est plus rapide que la montée : le saut paraît nerveux, pas flottant.
@export var fall_gravity_multiplier: float = 1.6

## Vitesse de chute maximale, pour garder le contrôle lors des longues chutes.
@export var max_fall_speed: float = 380.0

## Part de la vitesse de montée conservée quand on relâche le saut avant le sommet.
## 0,5 = la montée est coupée de moitié : un appui bref donne un petit saut.
@export_range(0.0, 1.0) var jump_cut: float = 0.5

## Délai pendant lequel on peut encore sauter après avoir quitté un bord.
@export var coyote_time: float = 0.1

## Délai pendant lequel un saut demandé juste avant l'atterrissage est mémorisé.
@export var jump_buffer_time: float = 0.12


# ---------------------------------------------------------------------------
# État
# ---------------------------------------------------------------------------

## Direction du regard : 1 vers la droite, -1 vers la gauche.
## Servira à orienter le sprite et à lancer la hache du bon côté.
var facing: int = 1

# Calculées à partir de jump_height et time_to_apex (voir _compute_jump_physics).
var _gravity: float = 0.0
var _jump_velocity: float = 0.0

# Comptes à rebours, en secondes, pour le coyote time et la mémoire du saut.
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

# Le visuel du héros : c'est lui qu'on retourne, jamais le corps physique.
@onready var _visual: Node2D = $Visual

# Le sprite animé, à l'intérieur du visuel.
@onready var _sprite: AnimatedSprite2D = $Visual/Sprite

# Les points de vie, partagés par toute l'équipe (un seul corps).
@onready var health: Health = $Health

# Temps restant pendant lequel le héros, touché, est sonné.
var _hurt_timer: float = 0.0

# Sens du dernier coup reçu, pour orienter le recul.
var _last_hit_direction: float = 1.0

# Vrai entre la mort et la réapparition : le héros ne fait plus rien.
var _respawning: bool = false

# Point de réapparition : la position de départ (plus tard, le dernier point de contrôle).
var _respawn_point: Vector2 = Vector2.ZERO

# Le héros joué : sa position dans la liste « heroes ».
var _hero_index: int = 0

# Compte à rebours avant de pouvoir relancer la hache.
var _throw_timer: float = 0.0

# Vrai pendant l'animation de lancer : elle passe alors avant la course ou le saut.
var _throwing: bool = false

# Les capacités, une par héros, dans le même ordre que « heroes » (null = pas de capacité).
var _abilities: Array[HeroAbility] = []

# La capacité du héros joué (null s'il n'en a pas encore).
var _ability: HeroAbility = null

# Temps restant pendant lequel un appui sur la capacité est mémorisé.
var _ability_buffer_timer: float = 0.0

# Matériau partagé des images rémanentes : mode de mélange additif (lumineux).
static var _ADDITIVE: CanvasItemMaterial = _make_additive()

static func _make_additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material

# Point de départ de la hache, par rapport au centre du héros (vers la droite).
# Lancée à hauteur de hanche : elle touche aussi les ennemis bas (comme la Motte sèche).
const AXE_OFFSET := Vector2(12.0, -2.0)


# ---------------------------------------------------------------------------
# Cycle de vie
# ---------------------------------------------------------------------------

func _ready() -> void:
	_compute_jump_physics()
	_create_abilities()
	if not heroes.is_empty():
		_apply_hero(0)
	# Le lancer se termine quand son animation est finie.
	_sprite.animation_finished.connect(_on_animation_finished)
	_respawn_point = global_position
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if _respawning:
		return  # entre la mort et la réapparition, le héros est figé et invisible

	# -1 à gauche, 1 à droite, 0 au repos ; une valeur intermédiaire avec un stick.
	var direction: float = Input.get_axis("move_left", "move_right")

	_update_timers(delta)
	_tick_abilities(delta)
	_update_blink()

	if _hurt_timer > 0.0:
		# Sonné : il subit son recul et la gravité, sans répondre aux commandes.
		_hurt_timer -= delta
		direction = 0.0
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
		_throw_timer = maxf(_throw_timer - delta, 0.0)
		move_and_slide()
		_update_animation()
		_check_fall()
		return

	_handle_switch()
	_handle_ability(delta)

	if _ability_in_control():
		# Une capacité pilote le mouvement (ex. la Ruée) : ni gravité, ni course, ni hache.
		_ability.physics_update(delta)
		_throw_timer = maxf(_throw_timer - delta, 0.0)
	else:
		_apply_gravity(delta)
		_handle_run(direction, delta)
		_handle_jump()
		_handle_throw(delta)
		# Capacité active qui laisse le héros bouger (Pagne-voile, Onde) : elle se met à jour
		# en plus du mouvement normal.
		if _ability != null and _ability.active:
			_ability.physics_update(delta)

	# Déplace le corps selon sa vitesse et le fait glisser le long des obstacles.
	move_and_slide()

	_update_facing(direction)
	_update_animation()
	_check_fall()


# ---------------------------------------------------------------------------
# Physique du saut
# ---------------------------------------------------------------------------

## Déduit la gravité et l'impulsion du saut à partir de sa hauteur et de sa durée.
##
## Ce sont les équations du mouvement uniformément accéléré :
##   hauteur = gravité × temps² / 2        →  gravité = 2 × hauteur / temps²
##   vitesse initiale = gravité × temps    →  impulsion = 2 × hauteur / temps
## L'impulsion est négative, car dans Godot l'axe vertical pointe vers le bas.
func _compute_jump_physics() -> void:
	_gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	_jump_velocity = -2.0 * jump_height / time_to_apex


# ---------------------------------------------------------------------------
# Étapes de chaque image
# ---------------------------------------------------------------------------

## Met à jour les deux comptes à rebours.
func _update_timers(delta: float) -> void:
	# Coyote time : plein tant qu'on touche le sol, puis il s'écoule une fois en l'air.
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# Mémoire du saut : chaque appui relance le compte à rebours.
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


## Applique la gravité en l'air, plus forte à la descente qu'à la montée.
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	var gravity: float = _gravity
	if velocity.y > 0.0:  # le héros descend
		gravity *= fall_gravity_multiplier

	# Vitesse de chute maximale, éventuellement réduite par une capacité (Pagne-voile).
	var fall_cap: float = max_fall_speed
	if _ability != null and _ability.active:
		fall_cap = _ability.limit_fall_speed(fall_cap)

	if velocity.y > fall_cap:
		# Déjà plus rapide que la limite (voile ouvert en pleine chute) : on freine
		# progressivement, pour un effet de parachute plutôt qu'un arrêt sec.
		velocity.y = move_toward(velocity.y, fall_cap, gravity * 2.0 * delta)
	else:
		velocity.y = minf(velocity.y + gravity * delta, fall_cap)


## Fait tendre la vitesse horizontale vers la vitesse voulue, sans à-coups.
func _handle_run(direction: float, delta: float) -> void:
	var target_speed: float = direction * max_speed
	var on_floor: bool = is_on_floor()

	# Choisit le rythme : prendre de l'élan, ou freiner.
	var rate: float
	if direction == 0.0:
		rate = friction if on_floor else air_friction
	else:
		rate = acceleration if on_floor else air_acceleration
		# Demi-tour : on freine aussi fort qu'à l'arrêt, pour que le héros réponde aussitôt.
		var turning: bool = velocity.x != 0.0 and signf(direction) != signf(velocity.x)
		if turning and on_floor:
			rate = maxf(rate, friction)

	# move_toward rapproche la vitesse de la cible d'au plus « rate × delta » à chaque image.
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)


## Lance le saut quand c'est permis, et le raccourcit si on relâche tôt.
func _handle_jump() -> void:
	# On saute si un saut a été demandé récemment (mémoire du saut)
	# et qu'on touche le sol, ou qu'on vient tout juste de le quitter (coyote time).
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = _jump_velocity
		# On vide les deux comptes à rebours : un appui ne doit donner qu'un seul saut.
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	# Saut à hauteur variable : relâcher pendant la montée coupe l'élan.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut


## Tourne le visuel du côté où l'on avance.
func _update_facing(direction: float) -> void:
	if direction == 0.0 or _ability_in_control():
		return  # au repos (ou pendant une capacité), le héros garde son orientation
	set_facing(1 if direction > 0.0 else -1)


## Oriente le héros : 1 vers la droite, -1 vers la gauche.
## Publique : les capacités s'en servent (la Ruée part dans la direction tenue).
func set_facing(new_facing: int) -> void:
	facing = new_facing
	_visual.scale.x = facing


## Choisit l'animation qui correspond à ce que fait le héros.
func _update_animation() -> void:
	if _hurt_timer > 0.0:
		_sprite.speed_scale = 1.0
		_sprite.play(&"hurt")
		return
	# Une capacité active impose son animation (si elle en a une et que le héros la possède).
	if _ability != null and _ability.active and _ability.animation != &"":
		if _sprite.sprite_frames.has_animation(_ability.animation):
			_sprite.speed_scale = 2.0
			_sprite.play(_ability.animation)
			return
	if _throwing:
		return  # le lancer garde la main jusqu'à la fin de son animation
	var animation: StringName
	if not is_on_floor():
		# En l'air : « jump » tant qu'il monte, « fall » dès qu'il redescend.
		animation = &"jump" if velocity.y < 0.0 else &"fall"
	elif absf(velocity.x) > 10.0:
		animation = &"run"
	else:
		animation = &"idle"

	# La course est jouée plus ou moins vite selon la vitesse réelle :
	# les pieds ne « patinent » pas quand le héros accélère ou freine.
	if animation == &"run":
		_sprite.speed_scale = clampf(absf(velocity.x) / max_speed, 0.5, 1.2)
	else:
		_sprite.speed_scale = 1.0

	# play() ne relance pas une animation déjà en cours : on peut l'appeler à chaque image.
	_sprite.play(animation)


# ---------------------------------------------------------------------------
# Hache de foudre
# ---------------------------------------------------------------------------

## Lance la hache quand on appuie sur « attack » et que le délai est écoulé.
func _handle_throw(delta: float) -> void:
	_throw_timer = maxf(_throw_timer - delta, 0.0)
	if not Input.is_action_just_pressed("attack") or _throw_timer > 0.0:
		return

	_throw_timer = throw_cooldown
	_throwing = true
	_sprite.speed_scale = 1.0
	_sprite.play(&"throw")

	var axe: LightningAxe = axe_scene.instantiate()
	axe.direction = facing
	axe.position = position + Vector2(AXE_OFFSET.x * facing, AXE_OFFSET.y)
	# La hache est ajoutée au niveau, pas au héros : sinon elle suivrait ses mouvements.
	get_parent().add_child(axe)


func _on_animation_finished() -> void:
	if _sprite.animation == &"throw":
		_throwing = false


# ---------------------------------------------------------------------------
# Changement de héros
# ---------------------------------------------------------------------------

## Passe au héros suivant de la liste, avec un éclair de lumière.
func _handle_switch() -> void:
	if not Input.is_action_just_pressed("switch_hero") or heroes.size() < 2:
		return

	# Une capacité en cours est interrompue : le nouveau héros ne la possède pas.
	if _ability != null and _ability.active:
		_ability.cancel()
	_ability_buffer_timer = 0.0
	_apply_hero((_hero_index + 1) % heroes.size())
	_throwing = false

	# L'éclair : le visuel devient éblouissant (couleurs au-delà du blanc),
	# puis revient à la normale en un quart de seconde.
	_visual.modulate = Color(3.0, 3.0, 1.8)
	create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.25)


## Fait du héros n° « index » le héros joué : ses animations et sa capacité.
func _apply_hero(index: int) -> void:
	_hero_index = index
	_sprite.sprite_frames = heroes[index].frames
	_ability = _abilities[index]
	hero_changed.emit(heroes[index])


## Le héros joué (sa fiche), par exemple pour afficher son nom.
func current_hero() -> HeroData:
	return heroes[_hero_index] if not heroes.is_empty() else null


# ---------------------------------------------------------------------------
# Capacités
# ---------------------------------------------------------------------------

## Crée la capacité de chaque héros (s'il en a une) et la rattache au Player.
## Toutes existent en même temps : chacune garde son temps de recharge, même en réserve.
func _create_abilities() -> void:
	_abilities.clear()
	for hero in heroes:
		var ability: HeroAbility = null
		if hero != null and hero.ability_scene != null:
			ability = hero.ability_scene.instantiate()
			ability.player = self
			add_child(ability)
		_abilities.append(ability)


## Fait avancer les recharges de toutes les capacités, et la mise à jour passive
## de celle du héros joué (ex. la Ruée se recharge en touchant le sol).
func _tick_abilities(delta: float) -> void:
	for ability in _abilities:
		if ability != null:
			ability.tick(delta)
	if _ability != null:
		_ability.passive_update(delta)


## Déclenche la capacité du héros joué quand on appuie sur « ability ».
## L'appui est mémorisé un court instant : s'il arrive pendant la recharge,
## la capacité part dès qu'elle est prête (comme la mémoire du saut).
func _handle_ability(delta: float) -> void:
	if _ability == null:
		return
	if _ability.wants_activation():
		_ability_buffer_timer = ability_buffer_time
	else:
		_ability_buffer_timer = maxf(_ability_buffer_timer - delta, 0.0)

	if _ability_buffer_timer > 0.0 and not _ability.active and _ability.try_activate():
		_ability_buffer_timer = 0.0
		_throwing = false  # la capacité interrompt un lancer en cours


## Vrai si une capacité est en cours et pilote le mouvement.
func _ability_in_control() -> bool:
	return _ability != null and _ability.active and _ability.takes_control


# ---------------------------------------------------------------------------
# Effets visuels
# ---------------------------------------------------------------------------

## Laisse derrière le héros une silhouette lumineuse qui s'efface (image rémanente).
## Copie l'image d'animation en cours, à la même place et dans le même sens.
## Le mode additif ajoute sa couleur au décor : la silhouette semble briller.
func spawn_afterimage(color: Color, lifetime: float = 0.22) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	ghost.global_position = _sprite.global_position
	ghost.scale.x = facing
	ghost.modulate = color
	ghost.material = _ADDITIVE
	# Derrière le héros, sans être affectée par ses mouvements.
	ghost.z_index = z_index - 1
	get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, lifetime)
	tween.tween_callback(ghost.queue_free)


# ---------------------------------------------------------------------------
# Coups reçus, mort et réapparition
# ---------------------------------------------------------------------------

## Reçoit un coup (appelée par les ennemis). « from_direction » : sens du coup,
## 1 s'il vient de la gauche (le héros recule vers la droite), -1 sinon.
## « _stun » n'est pas utilisé pour le héros (sa durée est hurt_stun_time) : le paramètre
## existe pour que héros et ennemis encaissent les coups de la même façon.
func take_hit(damage: int, from_direction: float, _stun: float = -1.0) -> void:
	if _respawning or is_invulnerable():
		return
	# Le recul est appliqué dans _on_damaged, seulement si le coup porte vraiment.
	_last_hit_direction = signf(from_direction) if from_direction != 0.0 else -float(facing)
	health.damage(damage)


## Le coup a porté : recul, héros sonné, capacité ou lancer interrompus.
func _on_damaged(_amount: int) -> void:
	if health.is_dead():
		return  # la mort prend le relais (_on_died)
	if _ability != null and _ability.active:
		_ability.cancel()
	_throwing = false
	_hurt_timer = hurt_stun_time
	velocity = Vector2(hurt_knockback.x * _last_hit_direction, hurt_knockback.y)
	# Le héros regarde d'où vient le coup.
	set_facing(-int(_last_hit_direction))


## Vrai si le héros ne peut pas être blessé : capacité protectrice (Ruée)
## ou invincibilité après un coup.
func is_invulnerable() -> bool:
	return (_ability != null and _ability.grants_invulnerability()) or health.is_invincible()


## Fait clignoter le héros pendant son invincibilité après un coup.
func _update_blink() -> void:
	if health.is_invincible():
		# Visible une image sur deux, à 15 alternances par seconde environ.
		_visual.visible = int(Time.get_ticks_msec() / 66.0) % 2 == 0
	else:
		_visual.visible = true


## Tombé dans le vide : mort immédiate.
func _check_fall() -> void:
	if global_position.y > death_height:
		health.kill()


## Mort : le héros disparaît, puis réapparaît au point de départ.
func _on_died() -> void:
	if _respawning:
		return
	_respawning = true
	if _ability != null and _ability.active:
		_ability.cancel()
	_throwing = false
	_hurt_timer = 0.0
	velocity = Vector2.ZERO
	_visual.visible = false
	died.emit()
	# La minuterie respecte la pause (elle ne s'écoule pas pendant le menu).
	await get_tree().create_timer(respawn_delay, false).timeout
	_respawn()


## Replace le héros au point de réapparition, avec toute sa vie et un peu d'invincibilité.
func _respawn() -> void:
	global_position = _respawn_point
	velocity = Vector2.ZERO
	health.refill()
	health.make_invincible(respawn_invincibility)
	_visual.visible = true
	_respawning = false
	# La caméra rejoint le héros d'un coup, sans glisser à travers tout le niveau.
	$Camera2D.reset_smoothing()


## Change le point de réapparition (servira aux points de contrôle).
func set_respawn_point(point: Vector2) -> void:
	_respawn_point = point
