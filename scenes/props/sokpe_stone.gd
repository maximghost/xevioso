class_name SokpeStone
extends Area2D
## Pierre sokpe : une « pierre de foudre » tombée du ciel, à rapporter à Xɛvioso.
##
## Elle flotte en scintillant ; un héros qui la touche la ramasse. La sauvegarde retient
## chaque pierre (par son niveau et le nom de son nœud) : une pierre déjà ramassée
## lors d'une partie précédente apparaît en transparence et ne compte plus.


## Amplitude et vitesse du flottement.
@export var bob_height: float = 2.0
@export var bob_speed: float = 3.0

var _time: float = 0.0
var _collected_before: bool = false
var _taken: bool = false

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	# Décalage de départ aléatoire : les pierres voisines ne flottent pas en même temps.
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	var level := Level.of(self)
	_collected_before = level != null and Game.has_sokpe(level.level_id, name)
	if _collected_before:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 0.35)


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = sin(_time * bob_speed) * bob_height
	# Un reflet passe de temps en temps sur la pierre.
	if not _collected_before:
		var glint: float = maxf(sin(_time * 1.7), 0.0)
		_sprite.modulate = Color(1.0 + glint * 0.6, 1.0 + glint * 0.6, 1.0 + glint * 0.8)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or _taken:
		return
	_taken = true
	var level := Level.of(self)
	if level != null and not _collected_before:
		Game.collect_sokpe(level.level_id, name)
	# Elle monte en grossissant puis disparaît dans un éclat bleuté.
	set_deferred("monitoring", false)
	Fx.dust(get_parent(), global_position, Color(0.6, 0.75, 1.0), 12, 70.0, 180.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "position:y", _sprite.position.y - 14.0, 0.25)
	tween.tween_property(_sprite, "scale", Vector2(1.6, 1.6), 0.25)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
