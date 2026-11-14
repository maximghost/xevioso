class_name BossArena
extends Area2D
## L'arène du cœur de l'iroko : quand l'Envoyé y entre, la porte de racines se referme
## derrière lui, la musique change, la barre d'Adan apparaît et le combat commence.
## Si l'Envoyé tombe, tout se remet en place (il reviendra à la dernière stèle).
## Adan vaincu : les portes se rouvrent, le cœur de l'iroko (l'autel) s'éveille.

@export var adan_path: NodePath
@export var gate_behind_path: NodePath
@export var gate_ahead_path: NodePath
@export var size: Vector2 = Vector2(32, 300)

var _adan: Adan
var _hud: CanvasLayer
var _fighting: bool = false
var won: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	shape.shape = r
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	_adan = get_node(adan_path) as Adan
	_adan.defeated.connect(_on_defeated)
	body_entered.connect(_on_enter)


func _on_enter(body: Node2D) -> void:
	if _fighting or won or not body is Player:
		return
	_fighting = true
	var player := body as Player
	if not player.health.died.is_connected(_on_player_died):
		player.health.died.connect(_on_player_died)
	var behind := get_node_or_null(gate_behind_path) as RootGate
	if behind != null:
		behind.close()
	Audio.music(&"adan", 0.6)
	_hud = preload("res://scenes/enemies/adan/boss_hud.gd").new()
	add_child(_hud)
	_adan.health_changed.connect(_hud.set_health)
	_adan.rage_changed.connect(_hud.set_rage)
	await get_tree().create_timer(0.6).timeout
	_adan.awaken(player)


func _on_player_died() -> void:
	if not _fighting or won:
		return
	_fighting = false
	_adan.reset()
	if _hud != null:
		_hud.queue_free()
		_hud = null
	var behind := get_node_or_null(gate_behind_path) as RootGate
	if behind != null:
		behind.open()
	var level := Level.of(self)
	Audio.music(level.music_track if level != null else &"foret", 1.0)


func _on_defeated() -> void:
	won = true
	_fighting = false
	if _hud != null:
		_hud.fade_out()
	Audio.stop_music(2.0)
	for p in [gate_behind_path, gate_ahead_path]:
		var g := get_node_or_null(p) as RootGate
		if g != null:
			g.open()
	var level := Level.of(self)
	if level != null:
		level.boss_defeated = true
		level.say(Voices.lines(&"foret_adan_vaincu"))
