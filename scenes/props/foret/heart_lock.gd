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
@export var pulse_period: float = 6.0
@export var calm_time: float = 18.0
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
const CLAMP := Vector2(332.0, -98.0)    # sous le bandeau des paroles : on le voit toujours
## Chaque coup : la roue frappée avance (+1), ses voisines reculent (-1).
const GEARS := [[1, -1, 0], [-1, 1, -1], [0, -1, 1]]
const CARVED := Color(0.32, 0.2, 0.14)
const SAP := Color(0.55, 0.8, 1.0)
const SAP_DIM := Color(0.42, 0.62, 0.82)
## Côtés ouverts du sillon de chaque roue, à sa bonne position (0 haut, 1 droite, 2 bas, 3 gauche).
const OPEN := [[0, 1], [3, 1], [3, 0]]
const SIDE_DIR := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
## Le battement est annoncé : les racines s'embrasent, la roue du milieu tremble.
const WARN_TIME := 1.3

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
var _drip: CPUParticles2D
var _mural: Node2D
var _lit_count := -1
var _intro_done := false


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
	_build_mural()
	_drip = CPUParticles2D.new()
	_drip.amount = 6
	_drip.lifetime = 0.9
	_drip.direction = Vector2(0, 1)
	_drip.spread = 10.0
	_drip.gravity = Vector2(0, 160)
	_drip.initial_velocity_min = 4.0
	_drip.initial_velocity_max = 12.0
	_drip.scale_amount_min = 1.0
	_drip.scale_amount_max = 1.6
	_drip.color = SAP
	_drip.emitting = false
	add_child(_drip)
	_refresh(false)


## Une zone de frappe sur le moyeu de chaque roue.
const _HitZone := preload("res://scenes/props/foret/heart_wheel_hit.gd")


func _process(delta: float) -> void:
	_busy -= delta
	if _state != 0:
		return
	var inside := _player_inside()
	_highlight_near(inside)
	if inside and not _intro_done:
		# à l'arrivée, la sève coule une première fois sous les yeux du joueur : on voit d'où
		# elle vient et où elle s'arrête
		_intro_done = true
		_lit_count = 0
		for item in [_grooves[0], _channels[0], _grooves[1], _channels[1], _grooves[2], _channels[2], _grooves[3]]:
			item.set("default_color" if item is Line2D else "modulate", CARVED)
		_refresh(true)
	if _calm > 0.0:
		_calm -= delta
		# le cœur dort : les racines grises respirent lentement ; elles rougissent avant le réveil
		var waking: bool = _calm < 2.5
		_red.energy = (0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)) * 0.6 if waking else 0.08
		_roots.modulate = Color(1.0, 0.55, 0.5) if waking and fmod(_calm, 0.5) < 0.25 else Color(0.55, 0.55, 0.62)
		if _calm <= 0.0:
			_roots.modulate = Color.WHITE
			_pulse_t = pulse_period
		return
	if not inside:
		_red.energy = 0.3
		return
	_pulse_t -= delta
	# l'annonce du battement
	var warn: float = clampf(1.0 - _pulse_t / WARN_TIME, 0.0, 1.0)
	_red.energy = 0.3 + 1.1 * warn * warn
	_roots.scale = Vector2.ONE * (1.0 + 0.08 * warn)
	var mid: Sprite2D = _wheels[1]
	mid.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (1.5 * warn) if warn > 0.0 else Vector2.ZERO
	if _pulse_t <= 0.0:
		_pulse_t = pulse_period
		mid.offset = Vector2.ZERO
		_heartbeat()


## Le moyeu d'une roue luit doucement quand un héros est assez près pour la frapper.
func _highlight_near(inside: bool) -> void:
	var level := Level.of(self)
	var px: float = INF
	if inside and level != null and level.player != null:
		px = to_local(level.player.global_position).x
	for k in 3:
		var near: bool = absf(px - WHEEL_X[k]) < 34.0
		var w: Sprite2D = _wheels[k]
		if w.modulate.g > 0.9:          # pas pendant le rougeoiement d'un battement
			w.modulate = Color(1.18, 1.12, 1.0) if near else Color.WHITE
	if _mural != null:
		var close: bool = inside and px < 120.0
		_mural.modulate.a = move_toward(_mural.modulate.a, 1.0 if close else 0.45, get_process_delta_time() * 2.0)


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
	t.tween_property(_roots, "scale", Vector2(1.18, 1.18), 0.06)
	t.tween_property(_roots, "scale", Vector2.ONE, 0.35)
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
		_gear_arrow(k, step, by_heart)
		var w: Sprite2D = _wheels[k]
		var tw := w.create_tween()
		tw.tween_property(w, "rotation_degrees", w.rotation_degrees + 90.0 * step, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if by_heart:
		var w1: Sprite2D = _wheels[1]
		w1.modulate = Color(1.0, 0.5, 0.45)
		w1.create_tween().tween_property(w1, "modulate", Color.WHITE, 0.6)
	_refresh(true)


func _open_sides(k: int) -> Array:
	return [posmod(OPEN[k][0] + turns[k], 4), posmod(OPEN[k][1] + turns[k], 4)]


## Jusqu'où la sève descend-elle ? Elle tombe du ciel dans le sillon d'entrée, entre dans la
## première roue par le haut, suit son sillon, passe aux suivantes… et s'arrête au premier
## raccord manqué. Renvoie [éléments allumés (0 entrée, 1 roue 1, 2 raccord, 3 roue 2,
## 4 raccord, 5 roue 3, 6 sillon des racines), point où elle s'arrête].
func _sap_flow() -> Array:
	var lit := 1
	var enter_side := [0, 3, 3]           # par où la sève entre dans chaque roue
	var exit_want := [1, 1, 0]            # par où elle doit en sortir pour continuer
	var stop: Vector2 = Vector2(WHEEL_X[0], WHEEL_Y - 28.0)
	for k in 3:
		var sides := _open_sides(k)
		var center := Vector2(WHEEL_X[k], WHEEL_Y)
		if not enter_side[k] in sides:
			stop = center + SIDE_DIR[enter_side[k]] * 28.0
			return [lit, stop]
		lit += 1                           # la roue se remplit
		var out: int = sides[0] if sides[1] == enter_side[k] else sides[1]
		if out != exit_want[k]:
			stop = center + SIDE_DIR[out] * 27.0
			return [lit, stop]
		lit += 1                           # le raccord suivant (ou le sillon des racines)
	return [lit, CLAMP]


func is_aligned() -> bool:
	return _sap_flow()[0] >= 7


func _refresh(animate: bool) -> void:
	var flow := _sap_flow()
	var lit: int = flow[0]
	var aligned: bool = lit >= 7
	# éléments, dans l'ordre où la sève les traverse
	var items: Array = [_grooves[0], _channels[0], _grooves[1], _channels[1], _grooves[2], _channels[2], _grooves[3]]
	for i in items.size():
		var node: CanvasItem = items[i]
		var on: bool = i < lit
		var target: Color = (SAP if aligned else SAP_DIM) if on else CARVED
		var prop := "default_color" if node is Line2D else "modulate"
		if animate and on and i >= _lit_count:
			# la sève avance : chaque morceau s'allume un peu après le précédent
			var tw := node.create_tween()
			tw.tween_interval(0.12 * (i - maxi(_lit_count - 1, 0)))
			tw.tween_property(node, prop, target, 0.15)
		else:
			node.set(prop, target)
	_lit_count = lit
	# là où elle s'arrête, la sève goutte
	_drip.position = flow[1]
	_drip.emitting = not aligned
	if aligned and not _was_aligned:
		Audio.play(&"lightning_ready", -4.0)
		var t := _roots.create_tween()
		for n in 3:
			t.tween_property(_roots, "position:x", CLAMP.x + 2.0, 0.04)
			t.tween_property(_roots, "position:x", CLAMP.x - 2.0, 0.04)
		t.tween_property(_roots, "position:x", CLAMP.x, 0.04)
		if not _said.has(&"seve"):
			_hint(&"foret_coeur_seve")
	_was_aligned = aligned


## Une flèche courbe, brève, autour d'une roue qui tourne : on voit le sens de l'engrenage.
func _gear_arrow(k: int, step: int, by_heart: bool) -> void:
	var arc := Line2D.new()
	arc.width = 1.5
	arc.default_color = Color(1.0, 0.45, 0.35, 0.9) if by_heart else Color(1.0, 0.92, 0.7, 0.85)
	var pts := PackedVector2Array()
	var a0: float = -PI * 0.8
	var span: float = PI * 0.45 * step
	for j in 13:
		var a: float = a0 + span * j / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 37.0)
	arc.points = pts
	var tip: Vector2 = pts[12]
	var tangent: Vector2 = (pts[12] - pts[11]).normalized()
	var head := Line2D.new()
	head.width = 1.5
	head.default_color = arc.default_color
	head.points = PackedVector2Array([tip - tangent.rotated(0.6) * 5.0, tip, tip - tangent.rotated(-0.6) * 5.0])
	arc.add_child(head)
	arc.position = Vector2(WHEEL_X[k], WHEEL_Y)
	add_child(arc)
	var t := arc.create_tween()
	t.tween_interval(0.25)
	t.tween_property(arc, "modulate:a", 0.0, 0.45)
	t.tween_callback(arc.queue_free)


## La fresque gravée près de l'entrée : trois roues qui se tiennent par les dents. Celle du
## milieu tourne dans un sens, ses voisines dans l'autre ; l'éclair au-dessus de la première,
## les racines au-dessus de la dernière. Elle s'éclaire quand on s'en approche.
func _build_mural() -> void:
	_mural = Node2D.new()
	_mural.position = Vector2(66.0, -104.0)
	_mural.scale = Vector2(1.5, 1.5)
	_mural.modulate.a = 0.45
	add_child(_mural)
	var ink := Color(0.78, 0.6, 0.4)
	for k in 3:
		var c := Vector2(-18.0 + 18.0 * k, 0.0)
		var ring := Line2D.new()
		ring.width = 1.0
		ring.default_color = ink
		var pts := PackedVector2Array()
		for j in 25:
			var a: float = TAU * j / 24.0
			pts.append(c + Vector2(cos(a), sin(a)) * 8.0)
		ring.points = pts
		_mural.add_child(ring)
		# la flèche : sens horaire au milieu, l'autre sens sur les côtés
		var dir: float = 1.0 if k == 1 else -1.0
		var arc := Line2D.new()
		arc.width = 1.0
		arc.default_color = ink
		var ap := PackedVector2Array()
		for j in 9:
			var a: float = -PI / 2.0 + dir * PI * 0.6 * j / 8.0
			ap.append(c + Vector2(cos(a), sin(a)) * 4.5)
		arc.points = ap
		_mural.add_child(arc)
		var tip: Vector2 = ap[8]
		var tg: Vector2 = (ap[8] - ap[7]).normalized()
		var hd := Line2D.new()
		hd.width = 1.0
		hd.default_color = ink
		hd.points = PackedVector2Array([tip - tg.rotated(0.7) * 3.0, tip, tip - tg.rotated(-0.7) * 3.0])
		_mural.add_child(hd)
	# l'éclair au-dessus de la première roue, et le chemin jusqu'aux racines au-dessus de la dernière
	var bolt := Line2D.new()
	bolt.width = 1.0
	bolt.default_color = Color(0.7, 0.85, 1.0)
	bolt.points = PackedVector2Array([Vector2(-16, -22), Vector2(-20, -16), Vector2(-15, -15), Vector2(-18, -9)])
	_mural.add_child(bolt)
	var root := Line2D.new()
	root.width = 1.0
	root.default_color = Color(0.85, 0.35, 0.25)
	root.points = PackedVector2Array([Vector2(18, -9), Vector2(18, -15), Vector2(22, -19), Vector2(26, -18), Vector2(24, -22)])
	_mural.add_child(root)


func _build_grooves() -> void:
	var paths := [
		[Vector2(WHEEL_X[0], -330.0), Vector2(WHEEL_X[0], WHEEL_Y - 28.0)],
		[Vector2(WHEEL_X[0] + 28.0, WHEEL_Y), Vector2(WHEEL_X[1] - 28.0, WHEEL_Y)],
		[Vector2(WHEEL_X[1] + 28.0, WHEEL_Y), Vector2(WHEEL_X[2] - 28.0, WHEEL_Y)],
		[Vector2(WHEEL_X[2], WHEEL_Y - 28.0), Vector2(WHEEL_X[2] + 6.0, -82.0), Vector2(WHEEL_X[2] + 30.0, -94.0), CLAMP + Vector2(-18.0, 2.0)],
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
		_roots.scale = Vector2.ONE
		_wheels[1].offset = Vector2.ZERO
		if not _said.has(&"calme"):
			_hint(&"foret_coeur_calme")


func _call_lightning() -> void:
	_state = 1
	solved.emit()
	_drip.emitting = false
	_roots.modulate = Color.WHITE
	var level := Level.of(self)
	var pts := [Vector2(WHEEL_X[0] + randf_range(-20, 20), -520.0), Vector2(WHEEL_X[0], WHEEL_Y), Vector2(WHEEL_X[1], WHEEL_Y),
		Vector2(WHEEL_X[2], WHEEL_Y), Vector2(WHEEL_X[2] + 6.0, -82.0), CLAMP]
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
