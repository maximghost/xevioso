class_name CrumblingPlatform
extends StaticBody2D
## Dalle de terre sèche : elle tient un instant sous les pieds, tremble, puis s'effrite.
##
## Elle se reforme quelques secondes plus tard. Il faut donc avancer sans hésiter.
## Elle fait partie des sols « peu sûrs » : on ne revient jamais dessus après une chute.
## Sa largeur se règle en cases de 16 px (width_tiles) ; le nœud est placé au milieu de son bord supérieur.


## Largeur, en cases de 16 px.
@export_range(1, 8) var width_tiles: int = 2
## Délai entre le premier pas et l'effondrement, en secondes.
@export var crumble_delay: float = 0.5
## Délai avant que la dalle se reforme, en secondes.
@export var respawn_time: float = 3.0

var _crumbling: bool = false
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _sensor: Area2D


func _ready() -> void:
	add_to_group(&"unsafe_ground")
	collision_layer = 1
	collision_mask = 0
	var width: float = width_tiles * 16.0
	# Le dessin : la dalle de 16 px répétée sur toute la largeur.
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/props/crumble_slab.png")
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, width, 10)
	_sprite.position = Vector2(0, 4)
	add_child(_sprite)
	# La collision : une plaque pleine de 8 px d'épaisseur.
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 8)
	_shape.shape = rect
	_shape.position = Vector2(0, 4)
	add_child(_shape)
	# Le capteur, juste au-dessus : il sent les pieds du héros.
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2
	var sensor_shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = Vector2(width - 4, 4)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = Vector2(0, -2)
	_sensor.add_child(sensor_shape)
	add_child(_sensor)
	_sensor.body_entered.connect(_on_stepped)


func _on_stepped(body: Node2D) -> void:
	if _crumbling or not body is Player:
		return
	_crumbling = true
	# Elle tremble de plus en plus, puis cède.
	var shake := create_tween()
	for i in 6:
		shake.tween_property(_sprite, "position:x", 1.0 if i % 2 == 0 else -1.0, crumble_delay / 6.0)
	shake.tween_callback(_collapse)


func _collapse() -> void:
	_sprite.position.x = 0.0
	_shape.set_deferred("disabled", true)
	Fx.dust(get_parent(), global_position + Vector2(0, 4), Color(0.78, 0.5, 0.31), 6 * width_tiles, 60.0, 120.0)
	_sprite.visible = false
	await get_tree().create_timer(respawn_time, false).timeout
	# Elle se reforme en fondu.
	_shape.set_deferred("disabled", false)
	_sprite.visible = true
	_sprite.modulate.a = 0.0
	create_tween().tween_property(_sprite, "modulate:a", 1.0, 0.3)
	_crumbling = false
