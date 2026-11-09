class_name FragileBlock
extends StaticBody2D
## Bloc de latérite fragile : solide pour tout le monde, mais le Marteau d'Abla le brise.
##
## Il fait partie du monde (couche 1) : on marche dessus, il arrête la hache.
## Seule une frappe de marteau appelle smash() et le réduit en éclats.
## Un bloc fragile posé dessus s'écroule à son tour, une fraction de seconde plus tard :
## un mur frappé à la base s'effondre en cascade, au lieu de laisser des blocs flotter.


## Délai avant que le bloc du dessus s'écroule, en secondes.
@export var collapse_delay: float = 0.07

## Couleur des éclats.
@export var debris_color: Color = Color(0.72, 0.41, 0.23)

var _broken: bool = false


## Brise le bloc. La collision est coupée tout de suite : un héros qui le frappe
## en tombant (Marteau en piqué) passe au travers dans la même image.
func smash() -> void:
	if _broken:
		return
	_broken = true
	$CollisionShape2D.disabled = true
	Fx.dust(get_parent(), global_position, debris_color, 16, 120.0, 180.0)
	Fx.puff(get_parent(), global_position, Color(0.86, 0.72, 0.56), 4, Vector2.ZERO, 30.0, 0.7)
	_collapse_block_above()
	queue_free()


## Fait s'écrouler le bloc fragile posé juste au-dessus (s'il y en a un).
func _collapse_block_above() -> void:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + Vector2(0.0, -16.0)
	query.collision_mask = collision_layer
	for result in get_world_2d().direct_space_state.intersect_point(query, 4):
		var above := result.collider as FragileBlock
		if above != null and above != self:
			# Ce bloc-ci disparaît tout de suite : la minuterie ne doit pas dépendre de lui.
			get_tree().create_timer(collapse_delay, false).timeout.connect(
				func() -> void:
					if is_instance_valid(above):
						above.smash())
