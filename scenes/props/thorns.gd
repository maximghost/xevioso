class_name Thorns
extends Area2D
## Épines d'acacia : un buisson bas et piquant. Le toucher coûte un cœur et fait rebondir.
## Largeur réglable en cases de 16 px ; le nœud est posé au sol, au milieu.


@export_range(1, 12) var width_tiles: int = 2
## L'image (raccordable, 10 px de haut) : épines d'acacia au village, ronces dans la forêt.
@export var texture: Texture2D = preload("res://assets/props/thorns.png")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var width: float = width_tiles * 16.0
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, width, 10)
	sprite.position = Vector2(0, -4)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width - 4, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player:
			var side: float = signf(body.global_position.x - global_position.x)
			body.take_hit(1, side if side != 0.0 else 1.0)
