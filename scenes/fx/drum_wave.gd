class_name DrumWave
extends Area2D
## L'Onde du tambour de Kokou : un anneau qui s'élargit autour de lui.
##
## Chaque ennemi touché par l'anneau prend un coup, est repoussé vers l'extérieur
## et reste sonné longtemps. Un ennemi n'est touché qu'une fois par onde.
## L'anneau est dessiné par le code (_draw) : pas besoin d'image.
##
## Couches : l'onde est sur la couche 4 (projectiles) et détecte la couche 3
## (zones de coup des ennemis, « Hitbox »).


## Rayon final de l'onde, en pixels.
@export var max_radius: float = 64.0

## Durée de l'expansion, en secondes.
@export var duration: float = 0.28

## Dégâts infligés.
@export var damage: int = 1

## Durée pendant laquelle les ennemis restent sonnés, en secondes.
@export var stun_time: float = 1.2

## Couleur de l'anneau.
@export var color: Color = Color(1.0, 0.82, 0.3)

var _radius: float = 0.0
var _elapsed: float = 0.0
# Ennemis déjà touchés par cette onde.
var _already_hit: Array[Node] = []

@onready var _shape: CircleShape2D = $CollisionShape2D.shape


func _ready() -> void:
	# Chaque onde a sa propre forme (sinon toutes les ondes partageraient le même rayon).
	_shape = _shape.duplicate()
	$CollisionShape2D.shape = _shape
	_shape.radius = 1.0
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var t: float = minf(_elapsed / duration, 1.0)
	# Expansion rapide au début, qui ralentit à la fin (courbe « ease out »).
	_radius = max_radius * (1.0 - pow(1.0 - t, 3.0))
	_shape.radius = maxf(_radius, 1.0)
	queue_redraw()
	if t >= 1.0:
		queue_free()


func _draw() -> void:
	var t: float = minf(_elapsed / duration, 1.0)
	var fade: float = 1.0 - t
	# Deux anneaux : un épais et lumineux, un fin à l'intérieur, qui s'effacent ensemble.
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(color, 0.9 * fade), 3.0)
	draw_arc(Vector2.ZERO, _radius * 0.7, 0.0, TAU, 40, Color(color, 0.4 * fade), 1.0)


func _on_area_entered(target: Node) -> void:
	# La Hitbox d'un ennemi transmet le coup à l'ennemi lui-même (son « owner »).
	var victim: Node = target if target.has_method("take_hit") else target.owner
	if victim == null or not victim.has_method("take_hit") or victim in _already_hit:
		return
	_already_hit.append(victim)
	var side: float = signf(victim.global_position.x - global_position.x)
	victim.take_hit(damage, side if side != 0.0 else 1.0, stun_time)
