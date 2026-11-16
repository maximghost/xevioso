class_name LightRootGate
extends RootGate
## Rideau de racines qui fuient la lumière (le souterrain). Les racines de la forêt malade se
## sont habituées au noir : à l'approche d'un essaim de lucioles, elles se rétractent dans la
## terre en frémissant ; quand la lumière s'éloigne, elles se referment (jamais sur un héros).

## Distance à laquelle la lumière des lucioles les fait reculer.
@export var light_radius: float = 64.0


func _ready() -> void:
	super._ready()
	_sprite.modulate = Color(0.85, 0.8, 0.75)


func _physics_process(_delta: float) -> void:
	var lit := false
	for f in get_tree().get_nodes_in_group(&"fireflies"):
		if (f as Node2D).global_position.distance_to(global_position + Vector2(0, -_height / 2.0)) < light_radius + _height / 2.0:
			lit = true
			break
	if lit and not is_open:
		open()
	elif not lit and is_open and not _player_inside():
		close()


func _player_inside() -> bool:
	for p in get_tree().get_nodes_in_group(&"player"):
		var d: Vector2 = (p as Node2D).global_position - global_position
		if absf(d.x) < 18.0 and d.y > -_height - 20.0 and d.y < 4.0:
			return true
	return false
