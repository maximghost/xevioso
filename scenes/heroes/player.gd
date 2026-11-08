class_name Player
extends CharacterBody2D
## Contrôleur des Envoyés : course, saut, chute, hache de foudre et changement de héros.
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

# Matériau partagé des images rémanentes : mode de mélange additif (lumineux).
static var _ADDITIVE: CanvasItemMaterial = _make_additive()

static func _make_additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material

# Point de départ de la hache, par rapport au centre du héros (vers la droite).
const AXE_OFFSET := Vector2(12.0, -14.0)


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


func _physics_process(delta: float) -> void:
	# -1 à gauche, 1 à droite, 0 au repos ; une valeur intermédiaire avec un stick.
	var direction: float = Input.get_axis("move_left", "move_right")

	_update_timers(delta)
	_tick_abilities(delta)
	_handle_switch()
	_handle_ability()

	if _ability_in_control():
		# Une capacité pilote le mouvement (ex. la Ruée) : ni gravité, ni course, ni hache.
		_ability.physics_update(delta)
		_throw_timer = maxf(_throw_timer - delta, 0.0)
	else:
		_apply_gravity(delta)
		_handle_run(direction, delta)
		_handle_jump()
		_handle_throw(delta)

	# Déplace le corps selon sa vitesse et le fait glisser le long des obstacles.
	move_and_slide()

	_update_facing(direction)
	_update_animation()


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

	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


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
func _handle_ability() -> void:
	if _ability != null and Input.is_action_just_pressed("ability"):
		if _ability.try_activate():
			_throwing = false  # la capacité interrompt un lancer en cours


## Vrai si une capacité est en cours et pilote le mouvement.
func _ability_in_control() -> bool:
	return _ability != null and _ability.active and _ability.takes_control


## Vrai si le héros ne peut pas être blessé (servira avec les ennemis).
func is_invulnerable() -> bool:
	return _ability != null and _ability.grants_invulnerability()


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
