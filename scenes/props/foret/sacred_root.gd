class_name SacredRoot
extends AnimatableBody2D
## Une racine sacrée endormie. Au repos, on ne voit qu'une souche marquée d'un signe qui luit
## faiblement. Quand le Tambour parlant de Kokou résonne à portée, elle se réveille et pousse :
## un pilier qui monte (direction « up ») ou un pont qui s'allonge depuis une paroi (« left »
## ou « right »). Elle reste tant qu'on joue, puis « stay_time » secondes ; elle clignote
## avant de se rétracter (on a le temps de descendre). Dans l'arène d'Adan, ce sont les seuls
## appuis que sa Fureur ne brûle pas.

## Taille une fois poussée, en cases (largeur, hauteur).
@export var size_tiles: Vector2i = Vector2i(2, 3)
@export_enum("up", "left", "right") var grow: String = "up"
## Portée du tambour, en pixels.
@export var radius: float = 176.0
## Durée de vie après le dernier battement entendu, en secondes.
@export var stay_time: float = 6.0
## Ignifugée : la Fureur d'Adan ne la brûle pas (toujours vrai ; pour le décor du feu).
var grown: float = 0.0

var _sprite: Sprite2D
var _sigil: Sprite2D
var _shape: CollisionShape2D
var _left: float = 0.0
var _tween: Tween
var _full: Vector2


func _ready() -> void:
	add_to_group(&"drum_listener")
	add_to_group(&"sacred_roots")
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	_full = Vector2(size_tiles) * 16.0
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/props/foret/root_tile.png")
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.centered = false
	_sprite.region_enabled = true
	add_child(_sprite)
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	# Le signe : une souche marquée, qui luit doucement (et brille quand on joue près d'elle).
	_sigil = Sprite2D.new()
	_sigil.texture = preload("res://assets/props/foret/root_sigil.png")
	_sigil.offset = Vector2(0, -5)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sigil.material = unshaded
	add_child(_sigil)
	_set_grown(0.0)


func _physics_process(delta: float) -> void:
	_sigil.modulate.a = 0.55 + 0.35 * sin(Time.get_ticks_msec() / 400.0 + position.x)
	if grown <= 0.0 or _left <= 0.0:
		return
	_left -= delta
	if _left < 1.5:
		# Bientôt la fin : elle clignote (on a le temps de descendre).
		_sprite.modulate.a = 0.55 + 0.45 * float(int(_left * 8.0) % 2)
	if _left <= 0.0:
		_sprite.modulate.a = 1.0
		_animate_to(0.0, 0.4)
		Audio.play_at(&"root_shrink", global_position, -4.0)


## Le Tambour parlant résonne à « from ».
func hear_drum(from: Vector2) -> void:
	if global_position.distance_to(from) > radius:
		return
	_left = stay_time
	_sprite.modulate.a = 1.0
	if grown < 1.0 and (_tween == null or not _tween.is_running() or _tween_target < 1.0):
		_animate_to(1.0, 0.55)
		Audio.play_at(&"root_grow", global_position)
		Fx.dust(get_parent(), global_position + Vector2(0, -2), Color(0.5, 0.42, 0.3), 10, 60.0, 90.0)
	_sigil.modulate = Color(2.0, 2.0, 1.4)
	create_tween().tween_property(_sigil, "modulate", Color.WHITE, 0.4)


var _tween_target: float = 0.0

func _animate_to(target: float, time: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween_target = target
	_tween = create_tween()
	_tween.tween_method(_set_grown, grown, target, time).set_trans(Tween.TRANS_BACK if target > 0.0 else Tween.TRANS_SINE)


## Avancement de la pousse (0 = souche, 1 = poussée).
func _set_grown(k: float) -> void:
	grown = clampf(k, 0.0, 1.2)
	var g: float = clampf(k, 0.0, 1.0)
	var size := _full
	var rect := Rect2()
	match grow:
		"up":
			size.y = maxf(1.0, _full.y * k)
			rect = Rect2(-_full.x / 2.0, -size.y, _full.x, size.y)
		"right":
			size.x = maxf(1.0, _full.x * k)
			rect = Rect2(0, -_full.y, size.x, _full.y)
		"left":
			size.x = maxf(1.0, _full.x * k)
			rect = Rect2(-size.x, -_full.y, size.x, _full.y)
	_sprite.position = rect.position
	_sprite.region_rect = Rect2(Vector2.ZERO, rect.size)
	_sprite.visible = g > 0.02
	(_shape.shape as RectangleShape2D).size = rect.size
	_shape.position = rect.get_center()
	_shape.disabled = g < 0.5
