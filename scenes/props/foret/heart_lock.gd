class_name HeartLock
extends Node2D
## Le cœur du vieil iroko : la serrure qui retient l'éclat de la Pierre de foudre.
##
## Trois roues de bois sculptées s'engrènent, au fond du creux de l'arbre. Chacune porte un
## sillon de sève. Quand on frappe une roue (hache, onde), elle tourne d'un quart, et ses
## voisines, prises dans ses dents, tournent d'un quart dans l'autre sens. Il faut que les
## trois sillons ne fassent qu'un chemin : du ciel (par le haut de la première roue) jusqu'aux
## racines de la colère (par le haut de la dernière).
##
## Le cœur de colère bat encore : à chaque battement, il pousse la roue du milieu (et donc ses
## deux voisines). Le tambour parlant de Kokou l'endort un moment. Et quand le chemin est
## d'un seul tenant, le même tambour appelle la foudre de Xɛvioso : elle descend par les
## sillons, brûle les racines, et l'éclat se libère. On l'emporte jusqu'au tabernacle.

signal solved
signal shard_taken

## Rotation de départ de chaque roue (en quarts de tour, sens horaire, depuis la bonne position).
@export var start_turns: Array[int] = [2, 3, 2]
## Battement du cœur de colère (s) et durée de son sommeil après un coup de tambour (s).
@export var pulse_period: float = 4.5
@export var calm_time: float = 12.0
## La porte de racines qui ferme la sortie de l'arbre : elle s'ouvre quand on prend l'éclat.
@export var exit_gate: NodePath
## Largeur du creux de l'arbre (px), depuis ce nœud (posé au sol, bord gauche du creux).
@export var room_width: float = 400.0

const WHEEL := preload("res://assets/props/foret/roue_coeur.png")
const ELBOW := preload("res://assets/props/foret/canal_coude.png")
const STRAIGHT := preload("res://assets/props/foret/canal_droit.png")
const ROOTS := preload("res://assets/props/foret/racines_colere.png")
const SHARD := preload("res://assets/props/foret/eclat_foudre.png")
const WHEEL_X := [140.0, 200.0, 260.0]
const WHEEL_Y := -36.0
const CLAMP := Vector2(304.0, -158.0)
## Chaque coup : la roue frappée avance (+1), ses voisines reculent (-1).
const GEARS := [[1, -1, 0], [-1, 1, -1], [0, -1, 1]]
const CARVED := Color(0.32, 0.2, 0.14)
const SAP := Color(0.55, 0.8, 1.0)

var turns: Array[int] = [0, 0, 0]
var _wheels: Array[Sprite2D] = []
var _channels: Array[Sprite2D] = []
var _grooves: Array[Line2D] = []
var _roots: Sprite2D
var _red: PointLight2D
var _pulse_t: float = 2.0
var _calm: float = 0.0
var _busy: float = 0.0
var _hits: int = 0
var _state := 0            # 0 : verrouillé ; 1 : la foudre est tombée ; 2 : l'éclat est pris
var _said := {}
var _was_aligned := false
var _calm_tween: Tween


func _ready() -> void:
	add_to_group(&"drum_listener")
	for i in 3:
		turns[i] = posmod(start_turns[i], 4)
	_build_grooves()
	for i in 3:
		var w := Sprite2D.new()
		w.texture = WHEEL
		w.position = Vector2(WHEEL_X[i], WHEEL_Y)
		add_child(w)
		var c := Sprite2D.new()
		c.texture = STRAIGHT if i == 1 else ELBOW
		c.modulate = CARVED
		w.add_child(c)
		# la roue de droite : le sillon va de la gauche vers le haut (le coude, retourné)
		if i == 2:
			c.rotation_degrees = -90.0
		w.rotation_degrees = 90.0 * turns[i]
		_wheels.append(w)
		_channels.append(c)
		var hit := Area2D.new()
		hit.collision_layer = 4          # la hache et l'onde la détectent
		hit.collision_mask = 0
		hit.set_script(_HitZone)
		hit.set("lock", self)
		hit.set("index", i)
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 16.0
		cs.shape = circle
		hit.add_child(cs)
		hit.position = w.position
		add_child(hit)
	_roots = Sprite2D.new()
	_roots.texture = ROOTS
	_roots.position = CLAMP
	add_child(_roots)
	var shard_in := Sprite2D.new()
	shard_in.name = "EclatPrisonnier"
	shard_in.texture = SHARD
	shard_in.position = CLAMP
	shard_in.modulate = Color(0.75, 0.8, 0.9)
	add_child(shard_in)
	move_child(shard_in, _roots.get_index())
	_red = PointLight2D.new()
	_red.texture = Fx.light_texture()
	_red.texture_scale = 1.6
	_red.color = Color(1.0, 0.25, 0.15)
	_red.energy = 0.5
	_red.position = CLAMP
	add_child(_red)
	_refresh(false)


## Une zone de frappe sur le moyeu de chaque roue.
const _HitZone := preload("res://scenes/props/foret/heart_wheel_hit.gd")


func _process(delta: float) -> void:
	_busy -= delta
	if _state != 0:
		return
	var inside := _player_inside()
	if _calm > 0.0:
		_calm -= delta
		_red.energy = 0.15
		return
	_red.energy = 0.35 + 0.25 * maxf(0.0, sin(Time.get_ticks_msec() / 1000.0 * TAU / pulse_period * 2.0))
	if not inside:
		return
	_pulse_t -= delta
	if _pulse_t <= 0.0:
		_pulse_t = pulse_period
		_heartbeat()


func _player_inside() -> bool:
	var level := Level.of(self)
	if level == null or level.player == null:
		return false
	var p: Vector2 = level.player.global_position - global_position
	return p.x > -10.0 and p.x < room_width + 10.0 and p.y > -260.0 and p.y < 20.0


## Un battement du cœur de colère : les racines se serrent, la roue du milieu est poussée.
func _heartbeat() -> void:
	Audio.play_at(&"heartbeat", to_global(CLAMP), 2.0)
	var t := _roots.create_tween()
	t.tween_property(_roots, "scale", Vector2(1.15, 1.15), 0.08)
	t.tween_property(_roots, "scale", Vector2.ONE, 0.3)
	var level := Level.of(self)
	if level != null and level.player != null:
		level.player.shake_camera(2.0, 0.2)
	_turn(1, true)
	if not _said.has(&"pouls"):
		_hint(&"foret_coeur_pouls")


## Une roue est frappée (par la zone de son moyeu).
func strike_wheel(i: int) -> void:
	if _state != 0 or _busy > 0.0:
		return
	_hits += 1
	_turn(i, false)
	if _hits == 16:
		_hint(&"foret_coeur_astuce")


func _turn(i: int, by_heart: bool) -> void:
	_busy = 0.3
	Audio.play_at(&"wheel_turn", to_global(Vector2(WHEEL_X[i], WHEEL_Y)), 0.0 if not by_heart else -3.0)
	for k in 3:
		var step: int = GEARS[i][k]
		if step == 0:
			continue
		turns[k] = posmod(turns[k] + step, 4)
		var w: Sprite2D = _wheels[k]
		var tw := w.create_tween()
		tw.tween_property(w, "rotation_degrees", w.rotation_degrees + 90.0 * step, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if by_heart:
		var w1: Sprite2D = _wheels[1]
		w1.modulate = Color(1.0, 0.5, 0.45)
		w1.create_tween().tween_property(w1, "modulate", Color.WHITE, 0.6)
	_refresh(true)


func _wheel_ok(k: int) -> bool:
	return turns[k] == 0 or (k == 1 and turns[k] == 2)


func is_aligned() -> bool:
	return _wheel_ok(0) and _wheel_ok(1) and _wheel_ok(2)


func _refresh(animate: bool) -> void:
	var aligned := is_aligned()
	for k in 3:
		var target: Color = SAP if aligned else (Color(0.42, 0.52, 0.62) if _wheel_ok(k) else CARVED)
		if animate:
			_channels[k].create_tween().tween_property(_channels[k], "modulate", target, 0.3)
		else:
			_channels[k].modulate = target
	for g in _grooves:
		g.default_color = SAP if aligned else CARVED
	if aligned and not _was_aligned:
		Audio.play(&"lightning_ready", -4.0)
		if not _said.has(&"seve"):
			_hint(&"foret_coeur_seve")
	_was_aligned = aligned


func _build_grooves() -> void:
	var paths := [
		[Vector2(WHEEL_X[0], -330.0), Vector2(WHEEL_X[0], WHEEL_Y - 28.0)],
		[Vector2(WHEEL_X[0] + 28.0, WHEEL_Y), Vector2(WHEEL_X[1] - 28.0, WHEEL_Y)],
		[Vector2(WHEEL_X[1] + 28.0, WHEEL_Y), Vector2(WHEEL_X[2] - 28.0, WHEEL_Y)],
		[Vector2(WHEEL_X[2], WHEEL_Y - 28.0), Vector2(WHEEL_X[2], -110.0), Vector2(WHEEL_X[2] + 18.0, -140.0), CLAMP + Vector2(-14.0, 6.0)],
	]
	for pts in paths:
		var shadow := Line2D.new()
		shadow.width = 6.0
		shadow.default_color = Color(0.06, 0.03, 0.03)
		shadow.points = PackedVector2Array(pts)
		add_child(shadow)
		var g := Line2D.new()
		g.width = 2.0
		g.points = PackedVector2Array(pts)
		g.default_color = CARVED
		add_child(g)
		_grooves.append(g)


## Le tambour parlant de Kokou : il endort le cœur, ou appelle la foudre si la sève est prête.
func hear_drum(from: Vector2) -> void:
	if _state != 0:
		return
	var d: Vector2 = from - global_position
	if d.x < -40.0 or d.x > room_width + 40.0 or absf(d.y) > 220.0:
		return
	if is_aligned():
		_call_lightning()
	elif _calm <= 0.0:
		_calm = calm_time
		var t := _roots.create_tween()
		_calm_tween = t
		t.tween_property(_roots, "modulate", Color(0.6, 0.6, 0.7), 0.4)
		t.tween_interval(calm_time - 1.2)
		t.tween_property(_roots, "modulate", Color.WHITE, 0.8)
		if not _said.has(&"calme"):
			_hint(&"foret_coeur_calme")


func _call_lightning() -> void:
	_state = 1
	solved.emit()
	if _calm_tween != null and _calm_tween.is_valid():
		_calm_tween.kill()
	var level := Level.of(self)
	var pts := [Vector2(WHEEL_X[0] + randf_range(-20, 20), -520.0), Vector2(WHEEL_X[0], WHEEL_Y), Vector2(WHEEL_X[1], WHEEL_Y),
		Vector2(WHEEL_X[2], WHEEL_Y), Vector2(WHEEL_X[2], -110.0), CLAMP]
	Audio.play(&"thunder_close", 2.0)
	if level != null:
		level.flash(0.9)
	for k in range(pts.size() - 1):
		LightningBolt.strike(get_parent(), to_global(pts[k]), to_global(pts[k + 1]), 3.0, 0.5, 2)
		Fx.sparks(get_parent(), to_global(pts[k + 1]), Color(0.8, 0.9, 1.0), 10)
		await get_tree().create_timer(0.07).timeout
	for g in _grooves:
		g.default_color = Color(1.0, 1.0, 0.9)
	if level != null and level.player != null:
		level.player.shake_camera(6.0, 0.6)
	# les racines de la colère brûlent et lâchent
	_red.color = Color(1.0, 0.6, 0.3)
	var t := _roots.create_tween()
	t.tween_property(_roots, "modulate", Color(0.15, 0.1, 0.1), 0.5)
	t.parallel().tween_property(_red, "energy", 1.6, 0.2)
	t.tween_property(_roots, "scale", Vector2(1.3, 1.3), 0.25)
	t.parallel().tween_property(_roots, "modulate:a", 0.0, 0.5)
	t.parallel().tween_property(_red, "energy", 0.0, 0.8)
	Fx.dust(get_parent(), to_global(CLAMP), Color(0.3, 0.12, 0.08), 26, 120.0, 90.0)
	await t.finished
	_free_shard()


## L'éclat sort de sa prison et descend, en spirale de lumière, à hauteur des héros.
func _free_shard() -> void:
	var old := get_node_or_null("EclatPrisonnier")
	var start: Vector2 = CLAMP if old == null else old.position
	if old != null:
		old.queue_free()
	Audio.play_at(&"shard_free", to_global(start))
	var shard := Area2D.new()
	shard.name = "Eclat"
	shard.collision_layer = 0
	shard.collision_mask = 2
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	cs.shape = circle
	shard.add_child(cs)
	var spr := Sprite2D.new()
	spr.texture = SHARD
	shard.add_child(spr)
	var light := PointLight2D.new()
	light.texture = Fx.light_texture()
	light.color = Color(0.6, 0.8, 1.0)
	light.energy = 1.1
	shard.add_child(light)
	shard.position = start
	add_child(shard)
	var target := Vector2(room_width * 0.5, -30.0)
	var t := shard.create_tween()
	t.tween_method(func(k: float) -> void:
		var base: Vector2 = start.lerp(target, k)
		shard.position = base + Vector2(cos(k * TAU * 2.0), sin(k * TAU * 2.0)) * 18.0 * (1.0 - k), 0.0, 1.0, 2.4).set_trans(Tween.TRANS_SINE)
	await t.finished
	var bob := spr.create_tween().set_loops()
	bob.tween_property(spr, "position:y", -3.0, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(spr, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	shard.body_entered.connect(_on_shard_touched.bind(shard))
	_hint(&"foret_coeur_eclat")
	# un héros déjà dessous le prend tout de suite
	await get_tree().physics_frame
	if is_instance_valid(shard):
		for b in shard.get_overlapping_bodies():
			_on_shard_touched(b, shard)


func _on_shard_touched(body: Node2D, shard: Area2D) -> void:
	if _state != 1 or not body is Player:
		return
	_state = 2
	var level := Level.of(self)
	Audio.play(&"sokpe")
	Audio.play(&"lightning_ready", -2.0)
	# l'éclat suit le héros, au-dessus de sa tête
	shard.set_deferred("monitoring", false)
	var carried := Node2D.new()
	carried.name = "EclatPorte"
	carried.position = Vector2(0, -50)
	for c in shard.get_children():
		if c is Sprite2D or c is PointLight2D:
			c.reparent(carried, false)
	shard.queue_free()
	body.add_child(carried)
	if level != null:
		level.set("shard_taken", true)
	var gate := get_node_or_null(exit_gate)
	if gate != null and gate.has_method("open"):
		gate.open()
	shard_taken.emit()
	_hint(&"foret_coeur_porte")


func _hint(id: StringName) -> void:
	_said[id] = true
	var key := String(id).trim_prefix("foret_coeur_")
	_said[StringName(key)] = true
	var level := Level.of(self)
	if level != null:
		level.say(Voices.lines(id))
