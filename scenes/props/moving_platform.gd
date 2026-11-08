class_name MovingPlatform
extends AnimatableBody2D
## Nacelle de bois suspendue : elle fait l'aller-retour entre deux points.
##
## Le héros posé dessus est transporté avec elle (Godot s'en charge : c'est un
## AnimatableBody2D). Elle compte parmi les sols « peu sûrs » (on ne revient pas dessus
## après une chute : elle aura bougé).


## Déplacement depuis la position de départ jusqu'au bout du trajet, en pixels.
@export var travel: Vector2 = Vector2(96, 0)
## Durée d'un trajet simple (aller), en secondes.
@export var duration: float = 2.5
## Pause à chaque extrémité, en secondes.
@export var pause: float = 0.6
## Décalage de départ dans le cycle (0 à 1) : pour que deux nacelles voisines ne bougent pas ensemble.
@export_range(0.0, 1.0) var phase: float = 0.0

var _start: Vector2
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"unsafe_ground")
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	_start = position
	_time = phase * _cycle()
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/props/pallet.png")
	sprite.position = Vector2(0, -6)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(46, 6)
	shape.shape = rect
	shape.position = Vector2(0, 0)
	add_child(shape)


func _cycle() -> float:
	return 2.0 * (duration + pause)


func _physics_process(delta: float) -> void:
	_time = fmod(_time + delta, _cycle())
	# Aller (avec pause au bout), puis retour : t va de 0 à 1 puis de 1 à 0.
	var leg: float = duration + pause
	var k: float
	if _time < leg:
		k = minf(_time / duration, 1.0)
	else:
		k = 1.0 - minf((_time - leg) / duration, 1.0)
	# Démarrage et arrêt en douceur (courbe en « S »).
	k = k * k * (3.0 - 2.0 * k)
	position = _start + travel * k
