class_name SacredReclaim
extends Node
## Fin de la partie 2 : Xɛvioso reprend les arbres.
##
## La caméra quitte le héros et remonte la forêt. Arbre après arbre, la foudre tombe sur la
## cime : l'arbre s'illumine d'or, reverdit, s'incline vers l'autel comme pour saluer, puis
## se redresse ; un pagne blanc se déroule autour de son tronc et des offrandes apparaissent
## à son pied. La caméra revient au héros, et l'emblème de Xɛvioso se lève dans le ciel.

const CLOTH := preload("res://assets/props/foret/sacred_cloth.png")
const OFFERINGS := preload("res://assets/props/foret/offrandes.png")
const EMBLEM := preload("res://assets/ui/xevioso/emblem.png")
const EMBLEM_GLOW := preload("res://assets/ui/xevioso/emblem_glow.png")
const MIN_TREE_HEIGHT := 140          # en dessous, ce n'est pas un arbre (buisson, fougère…)
const MAX_TREES := 12
const REACH_BACK := 1500.0            # jusqu'où la caméra remonte la forêt (px)

var level: Node2D
var _cam: Camera2D
var _player_cam: Camera2D
var _add := CanvasItemMaterial.new()


static func play(lvl: Node2D) -> void:
	var r := SacredReclaim.new()
	r.level = lvl
	lvl.add_child(r)
	await r._run()


func _run() -> void:
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_player_cam = get_viewport().get_camera_2d()
	if _player_cam == null or level.player == null:
		return
	var origin: Vector2 = level.player.global_position
	var trees := _trees(origin)
	# une caméra à nous, aux mêmes limites que celle du héros
	_cam = Camera2D.new()
	for p in ["limit_left", "limit_right", "limit_top", "limit_bottom", "zoom"]:
		_cam.set(p, _player_cam.get(p))
	_cam.position_smoothing_enabled = false
	level.add_child(_cam)
	_cam.global_position = _player_cam.get_screen_center_position()
	_cam.make_current()
	var start: Vector2 = _cam.global_position
	var far_x: float = start.x - REACH_BACK
	if not trees.is_empty():
		far_x = minf(start.x, trees[-1].global_position.x + 120.0)
	var span: float = absf(start.x - far_x)
	var travel: float = clampf(span / 260.0, 2.5, 6.0)
	Audio.play(&"thunder_far")
	var pan := create_tween()
	pan.tween_property(_cam, "global_position:x", far_x, travel).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# chaque arbre est frappé quand la caméra passe dessus
	for tree in trees:
		var tx: float = tree.global_position.x
		var k: float = clampf(absf(start.x - tx) / maxf(span, 1.0), 0.0, 1.0)
		_strike_later(tree, origin, 0.25 + k * travel * 0.92)
	await get_tree().create_timer(travel + 0.9).timeout
	# retour au héros, plus vite
	var back := create_tween()
	back.tween_property(_cam, "global_position:x", start.x, minf(travel * 0.5, 2.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	_player_cam.make_current()
	_cam.queue_free()
	await _emblem_in_sky()


func _trees(origin: Vector2) -> Array:
	var out: Array = []
	for group_name in ["DecorBack", "DecorFront"]:
		var group := level.get_node_or_null(group_name)
		if group == null:
			continue
		for s in group.get_children():
			if s is Sprite2D and s.texture != null and s.texture.get_height() >= MIN_TREE_HEIGHT:
				var dx: float = origin.x - s.global_position.x
				if dx > -360.0 and dx < REACH_BACK:
					out.append(s)
	out.sort_custom(func(a, b): return a.global_position.x > b.global_position.x)
	if out.size() > MAX_TREES:
		# on en garde un sur deux, régulièrement, pour couvrir toute la remontée
		var kept: Array = []
		var step: float = float(out.size()) / MAX_TREES
		for i in MAX_TREES:
			kept.append(out[int(i * step)])
		out = kept
	return out


func _strike_later(tree: Sprite2D, origin: Vector2, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(tree):
		return
	var h: float = tree.texture.get_height()
	var base := Vector2(tree.global_position.x, tree.global_position.y + h / 2.0)
	var top := Vector2(tree.global_position.x, tree.global_position.y - h / 2.0 + h * 0.15)
	var sky_y: float = _cam.get_screen_center_position().y - 200.0
	LightningBolt.strike(level, Vector2(top.x + randf_range(-40.0, 40.0), sky_y), top, 2.6, 0.45, 4)
	Audio.play_at(&"thunder_close", top, -6.0, 0.15)
	level.flash(0.22)
	Fx.sparks(level, top, Color(1.0, 0.9, 0.5), 18)
	# l'arbre reverdit
	var green_path: String = tree.texture.resource_path.replace(".png", "_green.png")
	if ResourceLoader.exists(green_path):
		tree.texture = load(green_path)
	# il s'illumine d'or (une copie additive, qui pulse ensuite doucement)
	var glow := Sprite2D.new()
	glow.texture = tree.texture
	glow.flip_h = tree.flip_h
	glow.material = _add
	glow.modulate = Color(1.0, 0.8, 0.35, 0.0)
	tree.add_child(glow)
	var g := glow.create_tween()
	g.tween_property(glow, "modulate:a", 0.85, 0.12)
	g.tween_property(glow, "modulate:a", 0.18, 1.4).set_trans(Tween.TRANS_SINE)
	var pulse := glow.create_tween().set_loops()
	pulse.tween_interval(1.6)
	pulse.tween_property(glow, "modulate:a", 0.3, 1.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "modulate:a", 0.12, 1.8).set_trans(Tween.TRANS_SINE)
	# il s'incline vers l'autel, puis se redresse : la forêt obéit de nouveau à Xɛvioso.
	# (le cisaillement pivote autour du centre : on recale la position pour garder le pied au sol)
	var dir: float = signf(origin.x - tree.global_position.x)
	var x0: float = tree.position.x
	var bow := tree.create_tween()
	bow.tween_method(func(a: float) -> void:
		tree.skew = a
		tree.position.x = x0 + sin(a) * h / 2.0, 0.0, 0.11 * dir, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bow.tween_interval(0.25)
	bow.tween_method(func(a: float) -> void:
		tree.skew = a
		tree.position.x = x0 + sin(a) * h / 2.0, 0.11 * dir, 0.0, 1.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# le pagne blanc se déroule autour du tronc, les offrandes apparaissent au pied
	# au-dessus des contreforts : là où le fût est le plus mince, dans le bas de l'arbre
	var frac: float = 0.5
	var trunk: Vector2 = Vector2(0, 9999)
	for f in [0.45, 0.52, 0.6, 0.68]:
		var span: Vector2 = _trunk_span(tree, f)
		if span.y < trunk.y:
			trunk = span
			frac = f
	var cloth := Sprite2D.new()
	cloth.texture = CLOTH
	cloth.position = Vector2(trunk.x, (frac - 0.5) * h)
	var sx: float = clampf((trunk.y + 2.0) / 40.0, 0.5, 1.5)
	cloth.scale = Vector2(sx, 0.0)
	tree.add_child(cloth)
	var c := cloth.create_tween()
	c.tween_interval(0.6)
	c.tween_property(cloth, "scale:y", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var gifts := Sprite2D.new()
	gifts.texture = OFFERINGS
	gifts.global_position = base + Vector2(trunk.x + (minf(trunk.y, 60.0) * 0.5 + 26.0) * (-dir), -9.0)
	gifts.modulate.a = 0.0
	level.add_child(gifts)
	var o := gifts.create_tween()
	o.tween_interval(0.9)
	o.tween_property(gifts, "modulate:a", 1.0, 0.6)
	Fx.puff(level, gifts.global_position, Color(1.0, 0.95, 0.8), 4, Vector2.ZERO, 30.0, 0.8)


## Où est le tronc à cette hauteur (fraction de la hauteur de l'image, depuis le haut) ?
## Renvoie (centre local en x, largeur), lus dans les pixels opaques de l'image.
func _trunk_span(tree: Sprite2D, frac: float) -> Vector2:
	var img: Image = tree.texture.get_image()
	if img == null:
		return Vector2(0, 30)
	if img.is_compressed():
		img.decompress()
	var w: int = img.get_width()
	var y: int = clampi(int(img.get_height() * frac), 0, img.get_height() - 1)
	var mid: int = w / 2
	# on part du milieu et on cherche le bloc opaque le plus proche
	var best := -1
	for d in w / 2:
		for x in [mid - d, mid + d]:
			if x >= 0 and x < w and img.get_pixel(x, y).a > 0.5:
				best = x
				break
		if best >= 0:
			break
	if best < 0:
		return Vector2(0, 30)
	var x0: int = best
	var x1: int = best
	while x0 > 0 and img.get_pixel(x0 - 1, y).a > 0.5: x0 -= 1
	while x1 < w - 1 and img.get_pixel(x1 + 1, y).a > 0.5: x1 += 1
	var cx: float = (x0 + x1) / 2.0 - w / 2.0
	if tree.flip_h:
		cx = -cx
	return Vector2(cx, float(x1 - x0 + 1))


## L'emblème de Xɛvioso se lève dans le ciel, auréolé de rayons qui tournent.
func _emblem_in_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	level.add_child(layer)
	var holder := Node2D.new()
	holder.position = Vector2(320, 96)
	layer.add_child(holder)
	var rays := Node2D.new()
	holder.add_child(rays)
	for i in 12:
		var ray := Polygon2D.new()
		var a: float = TAU * i / 12.0
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * 7.0
		ray.polygon = PackedVector2Array([side, -side, dir * 150.0 - side * 3.0, dir * 150.0 + side * 3.0])
		var c0 := Color(1.0, 0.85, 0.45, 0.45)
		var c1 := Color(1.0, 0.85, 0.45, 0.0)
		ray.vertex_colors = PackedColorArray([c0, c0, c1, c1])
		ray.material = _add
		rays.add_child(ray)
	var glow := Sprite2D.new()
	glow.texture = EMBLEM_GLOW
	glow.material = _add
	holder.add_child(glow)
	var emblem := Sprite2D.new()
	emblem.texture = EMBLEM
	holder.add_child(emblem)
	var fit: float = 72.0 / maxf(EMBLEM.get_height(), 1.0)
	glow.scale = Vector2.ONE * fit * 1.1
	emblem.scale = Vector2.ONE * fit
	holder.scale = Vector2.ZERO
	holder.modulate.a = 0.0
	Audio.play(&"thunder_close", -2.0)
	level.flash(0.5)
	var t := holder.create_tween().set_parallel()
	t.tween_property(holder, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(holder, "modulate:a", 1.0, 0.4)
	var spin := rays.create_tween().set_loops()
	spin.tween_property(rays, "rotation", TAU, 24.0).from(0.0)
	await get_tree().create_timer(2.4).timeout
	# il reste, en plus discret, derrière la bannière de victoire
	holder.create_tween().tween_property(holder, "modulate:a", 0.35, 1.2)
