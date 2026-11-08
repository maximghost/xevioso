class_name Checkpoint
extends Area2D
## Stèle de foudre : un point de contrôle.
##
## Quand un héros la touche, l'éclair gravé s'allume : c'est désormais là qu'il réapparaît
## s'il meurt, et la partie est sauvegardée. Elle rend aussi toute sa vie à l'équipe.
## Une seule stèle est allumée à la fois : allumer la nouvelle éteint l'ancienne.
## Le nom du nœud sert d'identifiant dans la sauvegarde : deux stèles d'un même niveau
## doivent porter des noms différents (Godot s'en assure dans l'éditeur).


@export var texture_off: Texture2D = preload("res://assets/props/checkpoint_off.png")
@export var texture_on: Texture2D = preload("res://assets/props/checkpoint_on.png")

var _lit: bool = false

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group(&"checkpoint")
	_sprite.texture = texture_off
	body_entered.connect(_on_body_entered)


## Là où le héros réapparaît : juste devant la stèle, au niveau du sol.
func spawn_position() -> Vector2:
	return global_position + Vector2(0.0, -20.0)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null or _lit:
		return
	light_up(true)
	player.set_respawn_point(spawn_position())
	player.health.refill()
	var level := Level.of(self)
	if level != null:
		Game.set_checkpoint(level.level_id, name)


## Allume la stèle (et éteint les autres). « celebrate » : éclair et étincelles.
func light_up(celebrate: bool) -> void:
	for node in get_tree().get_nodes_in_group(&"checkpoint"):
		if node != self:
			(node as Checkpoint).put_out()
	_lit = true
	_sprite.texture = texture_on
	if celebrate:
		_sprite.modulate = Color(3.0, 3.0, 2.0)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.4)
		Fx.dust(get_parent(), global_position + Vector2(0.0, -16.0), Color(1.0, 0.85, 0.4), 16, 90.0, 180.0)


func put_out() -> void:
	_lit = false
	_sprite.texture = texture_off
