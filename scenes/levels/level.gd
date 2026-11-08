class_name Level
extends Node2D
## Script commun à tous les niveaux : leur identité, et le départ du héros.
##
## À la création d'un niveau, on lui donne un identifiant unique (level_id) : c'est sous
## ce nom que la sauvegarde range ses pierres sokpe et son dernier point de contrôle.
## Au chargement, si un point de contrôle de ce niveau est enregistré, le héros y apparaît.


## Identifiant du niveau, unique et stable (ex. « village_1 »).
@export var level_id: StringName = &""

## Le héros du niveau.
@export var player: Player


func _ready() -> void:
	if level_id == &"":
		push_warning("Niveau sans level_id : la sauvegarde ne pourra pas s'y retrouver.")
	_place_player_at_checkpoint()


## Retrouve le niveau qui contient un nœud (pour les pierres, points de contrôle...).
static func of(node: Node) -> Level:
	var current: Node = node
	while current != null:
		if current is Level:
			return current
		current = current.get_parent()
	return null


## Si un point de contrôle de ce niveau est enregistré, le héros repart de là.
func _place_player_at_checkpoint() -> void:
	var point_name: StringName = Game.checkpoint_for(level_id)
	if point_name == &"" or player == null:
		return
	for node in get_tree().get_nodes_in_group(&"checkpoint"):
		var checkpoint := node as Checkpoint
		if checkpoint.name == point_name:
			checkpoint.light_up(false)  # allumée, sans fanfare : on la retrouve telle quelle
			player.global_position = checkpoint.spawn_position()
			player.set_respawn_point(checkpoint.spawn_position())
			player.get_node("Camera2D").reset_smoothing()
			return
