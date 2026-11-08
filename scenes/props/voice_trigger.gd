class_name VoiceTrigger
extends Area2D
## Zone invisible : quand un héros y entre, Xɛvioso parle (une seule fois par partie).
## Les paroles viennent de scripts/story/voices.gd, d'après « voice_id ».


@export var voice_id: StringName = &""
## Hauteur de la zone, en pixels (sa largeur est de 16 px : on la traverse forcément).
@export var height: float = 400.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, height)
	shape.shape = rect
	shape.position = Vector2(0, -height / 2.0)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or Game.has_heard(voice_id):
		return
	Game.mark_heard(voice_id)
	var level := Level.of(self)
	if level != null:
		level.say(Voices.lines(voice_id))
