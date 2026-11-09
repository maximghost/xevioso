class_name LightningAxe
extends Area2D
## La hache de foudre lancée par un Envoyé : la double hache de Xɛvioso.
##
## Elle file en ligne droite en tournoyant, entourée d'un halo, laisse une traînée
## lumineuse et crépite d'arcs électriques. Elle disparaît quand elle touche un mur,
## un ennemi, ou qu'elle a parcouru sa distance maximale (elle s'éteint alors en fondu).
##
## Couches de collision (Projet → Paramètres → Noms de couches → Physique 2D) :
##   1 = monde (sols, murs)   2 = héros   3 = ennemis   4 = projectiles
## La hache est sur la couche 4 et détecte les couches 1 (monde) et 3 (ennemis).

## Vitesse de vol, en pixels par seconde.
@export var speed: float = 400.0

## Distance maximale avant de disparaître, en pixels.
@export var max_distance: float = 220.0

## Dégâts infligés à un ennemi touché.
@export var damage: int = 1

## Longueur de la traînée lumineuse (nombre de positions retenues).
@export var trail_length: int = 9

## Sens du vol : 1 vers la droite, -1 vers la gauche. Fixé par le héros au lancer.
var direction: int = 1

var _travelled: float = 0.0
var _time: float = 0.0
var _crackle_timer: float = 0.0
var _trail: Line2D

# Vrai dès que la hache a touché quelque chose : un seul coup par hache, même si elle
# touche deux choses dans la même image (le corps et la zone d'un ennemi, par exemple).
var _spent: bool = false


func _ready() -> void:
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)
	# La hache tourne dans le sens du lancer.
	$Sprite.flip_h = direction < 0
	$Sprite.speed_scale = 1.0
	# Elle jaillit de la main : petite, puis à sa taille.
	scale = Vector2(0.5, 0.5)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.08)
	_trail = Line2D.new()
	_trail.top_level = true          # dans le repère du monde : la traînée reste derrière
	_trail.width = 6.0
	var width := Curve.new()
	width.add_point(Vector2(0.0, 0.1))
	width.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = width
	var colors := Gradient.new()
	colors.set_color(0, Color(0.55, 0.7, 1.0, 0.0))
	colors.set_color(1, Color(1.0, 0.9, 0.55, 0.85))
	_trail.gradient = colors
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_trail.material = add
	add_child(_trail)
	move_child(_trail, 0)            # derrière la hache


func _physics_process(delta: float) -> void:
	var step: float = speed * delta
	position.x += direction * step
	_travelled += step
	_time += delta
	# Traînée : on ajoute la position courante, on oublie les plus anciennes.
	_trail.add_point(global_position)
	while _trail.get_point_count() > trail_length:
		_trail.remove_point(0)
	# Le halo palpite.
	$Glow.scale = Vector2.ONE * (0.9 + 0.15 * sin(_time * 40.0))
	# Petits arcs électriques qui crépitent autour de la hache.
	_crackle_timer -= delta
	if _crackle_timer <= 0.0:
		_crackle_timer = randf_range(0.04, 0.09)
		var tip: Vector2 = global_position + Vector2.from_angle(randf() * TAU) * randf_range(8.0, 13.0)
		LightningBolt.strike(get_parent(), global_position, tip, 1.0, 0.07, 0)
	if _travelled >= max_distance:
		_fizzle()


## En bout de course : la hache s'éteint en fondu au lieu de disparaître d'un coup.
func _fizzle() -> void:
	if _spent:
		return
	_spent = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	Fx.sparks(get_parent(), global_position, Color(1.0, 0.9, 0.6), 4)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.12)
	tween.chain().tween_callback(queue_free)


## Appelée quand la hache touche un corps (mur, sol, ennemi) ou une zone (Hitbox d'ennemi).
func _on_hit(target: Node) -> void:
	if _spent:
		return
	_spent = true
	var level: Node = get_parent()
	var victim := _find_damageable(target)
	if victim != null:
		victim.take_hit(damage, direction)
		# Impact sur une cible : éclats, onde, arcs, micro-arrêt, secousse.
		Fx.sparks(level, global_position, Color(1.0, 0.85, 0.35), 16)
		Fx.ring(level, global_position, Color(1.0, 0.9, 0.55), 18.0, 0.22, 2.0)
		for i in 3:
			LightningBolt.strike(level, global_position,
				global_position + Vector2.from_angle(randf() * TAU) * randf_range(12.0, 20.0), 1.0, 0.12, 0)
		Fx.hit_stop(get_tree(), 0.06)
		var player := get_tree().get_first_node_in_group(&"player")
		if player != null and player.has_method("shake_camera"):
			player.shake_camera(2.0, 0.1)
	else:
		# Contre le décor : étincelles et petite onde.
		Fx.sparks(level, global_position, Color(1.0, 0.9, 0.6), 8)
		Fx.ring(level, global_position, Color(1.0, 0.9, 0.6), 10.0, 0.18, 1.5)
	queue_free()


## Trouve qui doit recevoir le coup : la cible elle-même si elle sait encaisser
## (méthode take_hit), sinon la scène à laquelle appartient la zone touchée
## (la Hitbox d'un ennemi transmet le coup à son ennemi).
func _find_damageable(target: Node) -> Node:
	if target.has_method("take_hit"):
		return target
	if target.owner != null and target.owner.has_method("take_hit"):
		return target.owner
	return null
