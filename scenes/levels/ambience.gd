class_name Ambience
extends Node
## Le décor vivant d'un niveau : rien n'y est figé.
##
## Créée par le niveau (Level) au démarrage, elle ajoute et anime :
##   - le vent : une force qui monte et retombe en rafales, partagée par tout le décor
##     (shader « sway » : herbes, buissons, palmiers, arbres et fleurs se balancent,
##     la fumée et les nuages dérivent dans le même sens que la poussière) ;
##   - des touffes d'herbe sur tout le terrain, derrière et devant le héros,
##     qui s'écartent sur son passage ;
##   - la fumée des cases, les nuages qui passent, des vols d'oiseaux, des poules
##     qui picorent près des cases (et s'enfuient quand on s'approche) ;
##   - la vie du village : pagnes qui sèchent sur une corde, feux de cuisine
##     (flammes, braises, halo) ;
##   - des détails dans la terre (cailloux, racines, tessons, cauris) pour qu'elle
##     ne se répète pas ;
##   - le changement de saison à la fin : l'herbe reverdit et le vent forcit sous la pluie.

const SWAY_SHADER := preload("res://assets/shaders/sway.gdshader")

## Réglages du balancement par sorte de décor (nom de l'image, sans « _green ») :
## [amplitude en pixels, souplesse, balancement permanent].
## Ce qui n'est pas listé (cases, greniers, clôtures, poteries...) ne bouge pas.
const SWAY := {
	"bush": [1.5, 1.4, 0.5],
	"ronier": [2.0, 3.5, 0.6],
	"baobab": [1.0, 4.0, 0.4],
	"iroko": [1.5, 2.6, 0.5],
	"flower": [1.5, 1.2, 0.7],
	"grass": [2.5, 1.3, 0.7],
	"pagne": [2.5, 1.2, 0.8],
}

## Détails enfouis dans la terre : image et probabilité par case pleine (hors bords).
const GROUND_DETAILS := {
	"ground_pebbles_0": 0.035, "ground_pebbles_1": 0.035, "ground_pebbles_2": 0.035,
	"ground_stone": 0.018, "ground_shard": 0.008, "ground_cowrie": 0.005,
}
## Racines sous le bord herbeux : probabilité par case du dessus.
const ROOT_DENSITY := 0.14

## Touffes d'herbe : probabilité d'en poser une par case du dessus, derrière / devant le héros.
const GRASS_BACK_DENSITY := 0.75
const GRASS_FRONT_DENSITY := 0.2

## Le vent souffle vers la gauche (comme la poussière d'harmattan) : force de base et rafales.
const WIND_BASE := 0.25
const WIND_GUSTS := 0.75
const RAIN_WIND := 0.55

var level: Level
var terrain: TileMapLayer
var player: Node2D

var _materials: Dictionary = {}          # un ShaderMaterial partagé par sorte de décor
var _grass_layers: Array[Node2D] = []
var _smokes: Array[CPUParticles2D] = []
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _raining: bool = false
var _rng := RandomNumberGenerator.new()
var _bird_timer: float = 3.0
var _birds: Node2D
var _fires: Array[Node2D] = []   # feux de cuisine (flammes, halo, braises, fumée)
var _cleared: Array[Vector3] = [] # zones sans herbe (installations) : [gauche, droite, sol]


## Met tout en place. « level » doit avoir son terrain et son héros.
func setup(owner_level: Level) -> void:
	level = owner_level
	terrain = level.terrain
	player = level.player
	_rng.seed = hash(level.level_id)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.18
	_noise.seed = 11

	_apply_sway_to_decor()
	if terrain != null:
		_spawn_ground_details()
		_spawn_village_life()   # avant les poules : elles se placent ensuite autour
		_spawn_grass()
	_spawn_smoke()
	_add_clouds()
	_spawn_chickens()
	_birds = Node2D.new()
	_birds.name = "Birds"
	var background := level.get_node_or_null("Background")
	if background != null:
		background.add_child(_birds)  # devant le ciel, derrière les cases : les oiseaux sont loin


## Matériau de balancement pour une sorte de décor (créé une seule fois, puis partagé).
func sway_material(kind: String) -> ShaderMaterial:
	if not SWAY.has(kind):
		return null
	if not _materials.has(kind):
		var m := ShaderMaterial.new()
		m.shader = SWAY_SHADER
		var cfg: Array = SWAY[kind]
		m.set_shader_parameter("amplitude", cfg[0])
		m.set_shader_parameter("stiffness", cfg[1])
		m.set_shader_parameter("idle_sway", cfg[2])
		if kind == "grass":
			m.set_shader_parameter("push", 3.0)
			m.set_shader_parameter("pad", 4.0)
		if kind == "pagne":
			m.set_shader_parameter("hanging", true)
			m.set_shader_parameter("speed", 2.4)
		_materials[kind] = m
	return _materials[kind]


## La sorte de décor d'après le nom de l'image : « ronier_green.png » → « ronier ».
static func kind_of(texture: Texture2D) -> String:
	if texture == null:
		return ""
	var base: String = texture.resource_path.get_file().get_basename().replace("_green", "")
	for kind in SWAY:
		if base.begins_with(kind):
			return kind
	return base


func _apply_sway_to_decor() -> void:
	for group_name in ["DecorBack", "DecorFront"]:
		var group := level.get_node_or_null(group_name)
		if group == null:
			continue
		for sprite in group.get_children():
			if sprite is Sprite2D:
				var m := sway_material(kind_of(sprite.texture))
				if m != null:
					sprite.material = m


# ---------------------------------------------------------------------------
# Herbes
# ---------------------------------------------------------------------------

func _spawn_grass() -> void:
	var back := Node2D.new()
	back.name = "Grass"
	level.add_child(back)
	# Juste derrière le terrain : le pied des touffes se cache dans le bord herbeux des tuiles.
	level.move_child(back, terrain.get_index())
	var front := Node2D.new()
	front.name = "GrassFront"
	level.add_child(front)
	if player != null:
		level.move_child(front, player.get_index() + 1)  # devant les pieds du héros
	_grass_layers = [back, front]

	var textures: Array[Texture2D] = []
	for i in 4:
		textures.append(load("res://assets/decor/village/grass_%d.png" % i))
	var material := sway_material("grass")
	var blocked := _gameplay_spots()
	var thorns := _thorn_spans()
	for cell in terrain.get_used_cells():
		if terrain.get_cell_atlas_coords(cell).y != 0:
			continue  # seulement le dessus herbeux du terrain
		if _in_spans(cell.x * 16 + 8.0, cell.y * 16.0, thorns):
			continue  # les épines doivent rester bien visibles
		if _in_spans(cell.x * 16 + 8.0, cell.y * 16.0, _cleared):
			continue  # pas d'herbe devant une corde à linge ou un feu
		var surface: float = cell.y * 16 + 3.0
		if _rng.randf() < GRASS_BACK_DENSITY:
			# Basses touffes (0, 3) plus fréquentes que les hautes herbes (1, 2).
			var kind: int = [0, 0, 3, 3, 1, 1, 2][_rng.randi() % 7]
			_add_tuft(back, textures[kind], Vector2(cell.x * 16 + _rng.randi_range(2, 14), surface), material)
		if _rng.randf() < GRASS_FRONT_DENSITY:
			var x: float = cell.x * 16 + _rng.randi_range(2, 14)
			# Devant le héros : seulement des touffes basses, et jamais sur un piège ou un objet
			# (elles ne doivent rien cacher d'important).
			if _is_clear(x, surface, blocked):
				_add_tuft(front, textures[[0, 3][_rng.randi() % 2]], Vector2(x, surface + 2.0), material)


func _add_tuft(layer: Node2D, texture: Texture2D, base: Vector2, material: ShaderMaterial) -> void:
	var tuft := Sprite2D.new()
	tuft.texture = texture
	tuft.material = material
	tuft.offset = Vector2(0, -texture.get_height() / 2.0)   # le point de pose est le pied
	tuft.position = base
	tuft.flip_h = _rng.randf() < 0.5
	layer.add_child(tuft)


## Les positions des objets de jeu (pièges, pierres, ennemis...) à ne pas masquer.
func _gameplay_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for group_name in ["Props", "Enemies"]:
		var group := level.get_node_or_null(group_name)
		if group == null:
			continue
		for node in group.get_children():
			if node is Node2D:
				spots.append(node.global_position)
	return spots


## Les zones d'épines : [gauche, droite, hauteur du sol] de chaque piège, avec une marge.
func _thorn_spans() -> Array[Vector3]:
	var spans: Array[Vector3] = []
	var props := level.get_node_or_null("Props")
	if props == null:
		return spans
	for node in props.get_children():
		if node is Thorns:
			var half: float = node.width_tiles * 8.0 + 10.0
			spans.append(Vector3(node.global_position.x - half, node.global_position.x + half, node.global_position.y))
	return spans


func _in_spans(x: float, y: float, spans: Array[Vector3]) -> bool:
	for span in spans:
		if x > span.x and x < span.y and absf(y - span.z) < 24.0:
			return true
	return false


func _is_clear(x: float, y: float, spots: Array[Vector2]) -> bool:
	for p in spots:
		if absf(p.x - x) < 40.0 and absf(p.y - y) < 48.0:
			return false
	return true


# ---------------------------------------------------------------------------
# Détails du sol
# ---------------------------------------------------------------------------

func _spawn_ground_details() -> void:
	var layer := Node2D.new()
	layer.name = "GroundDetails"
	level.add_child(layer)
	level.move_child(layer, terrain.get_index() + 1)   # sur la terre, sous les objets de jeu
	var textures := {}
	for key in GROUND_DETAILS:
		textures[key] = load("res://assets/decor/village/%s.png" % key)
	var roots: Array[Texture2D] = [load("res://assets/decor/village/ground_root_0.png"),
		load("res://assets/decor/village/ground_root_1.png")]
	for cell in terrain.get_used_cells():
		var atlas: Vector2i = terrain.get_cell_atlas_coords(cell)
		if atlas.y == 0:
			# Racines qui pendent sous l'herbe, dans la terre de la case du dessus.
			if _rng.randf() < ROOT_DENSITY and _filled(cell + Vector2i.DOWN):
				var r := Sprite2D.new()
				r.texture = roots[_rng.randi() % 2]
				r.centered = false
				r.position = Vector2(cell.x * 16 + _rng.randi_range(0, 4), cell.y * 16 + 5)
				r.flip_h = _rng.randf() < 0.5
				layer.add_child(r)
			continue
		if atlas.y == 3 or not _interior(cell):
			continue  # ni planches, ni bords (le contour des tuiles doit rester net)
		for key in GROUND_DETAILS:
			if _rng.randf() < GROUND_DETAILS[key]:
				var d := Sprite2D.new()
				d.texture = textures[key]
				d.position = Vector2(cell.x * 16 + _rng.randi_range(4, 12), cell.y * 16 + _rng.randi_range(4, 12))
				d.flip_h = _rng.randf() < 0.5
				# Plus on s'enfonce, plus c'est sombre (comme la terre elle-même).
				var depth: int = _depth_of(cell)
				d.modulate = Color(1, 1, 1) if depth < 3 else (Color(0.86, 0.84, 0.84) if depth < 5 else Color(0.72, 0.7, 0.7))
				layer.add_child(d)
				break


func _filled(cell: Vector2i) -> bool:
	return terrain.get_cell_source_id(cell) != -1


func _interior(cell: Vector2i) -> bool:
	for n in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if not _filled(cell + n):
			return false
	return true


## Nombre de cases pleines au-dessus (profondeur sous la surface), jusqu'à 6.
func _depth_of(cell: Vector2i) -> int:
	var depth := 0
	while depth < 6 and _filled(cell + Vector2i(0, -(depth + 1))):
		depth += 1
	return depth


# ---------------------------------------------------------------------------
# La vie du village : cordes à linge et feux de cuisine
# ---------------------------------------------------------------------------

## Près des cases, là où le sol est plat et libre : une corde à linge ou un feu de cuisine.
func _spawn_village_life() -> void:
	var group := level.get_node_or_null("DecorBack")
	if group == null:
		return
	# Ce qui occupe déjà le sol : le décor (sauf le ciel et les grands arbres en fond) et le jeu.
	var taken: Array[Vector2] = []
	var low: Array[Vector2] = []     # petits objets : une corde peut passer devant, pas un feu
	for sprite in group.get_children():
		if sprite is Sprite2D and sprite.texture != null:
			if sprite.texture.get_height() < 24:
				var h: float = sprite.texture.get_width() / 2.0
				low.append(Vector2(sprite.position.x - h, sprite.position.x + h))
				continue
			var half: float = sprite.texture.get_width() / 2.0
			# Les grands arbres ne prennent au sol que la place de leur tronc.
			if kind_of(sprite.texture) in ["baobab", "iroko", "ronier"]:
				half *= 0.3
			taken.append(Vector2(sprite.position.x - half, sprite.position.x + half))
	# Les buissons du premier plan (devant le héros) cacheraient un feu.
	var front := level.get_node_or_null("DecorFront")
	if front != null:
		for sprite in front.get_children():
			if sprite is Sprite2D and sprite.texture != null:
				var h: float = sprite.texture.get_width() / 2.0
				low.append(Vector2(sprite.position.x - h, sprite.position.x + h))
	var spots := _gameplay_spots()
	var huts: Array[Sprite2D] = []
	for sprite in group.get_children():
		if sprite is Sprite2D and sprite.texture != null and sprite.texture.resource_path.get_file().begins_with("hut"):
			huts.append(sprite)
	# Pour chaque case, on cherche du sol plat et libre tout près (c'est là que vit le
	# village) ; deux installations sont espacées d'au moins MIN_GAP pixels.
	const MIN_GAP := 200.0
	const NEAR_HUT := 200.0
	var placed_x: Array[float] = []
	var count := 0
	for hut in huts:
		var ground_y: float = hut.position.y + hut.texture.get_height() / 2.0 - 2.0
		# On alterne corde et feu ; si la place manque pour l'un autour de cette case,
		# on essaie l'autre.
		var kinds: Array = ["line", "fire"] if count % 2 == 0 else ["fire", "line"]
		for kind in kinds:
			var width: float = 50.0 if kind == "line" else 26.0
			var blocking: Array[Vector2] = taken if kind == "line" else taken + low
			var x: float = _find_spot(hut.position.x, NEAR_HUT, width, ground_y, blocking, spots, placed_x, MIN_GAP)
			if is_nan(x):
				continue
			var node: Node2D = _make_clothesline(count) if kind == "line" else _make_fire()
			node.name = "%s%d" % [node.name, count + 1]
			node.position = Vector2(x, ground_y)
			group.add_child(node)
			taken.append(Vector2(x - width / 2.0, x + width / 2.0))
			_cleared.append(Vector3(x - width / 2.0 - 6.0, x + width / 2.0 + 6.0, ground_y))
			placed_x.append(x)
			count += 1
			break


## Le point libre le plus proche de « center » (en alternant gauche et droite), ou NAN.
func _find_spot(center: float, reach: float, width: float, ground_y: float, taken: Array[Vector2],
		spots: Array[Vector2], placed_x: Array[float], gap: float) -> float:
	var dist := 0.0
	while dist <= reach:
		for side in [-1.0, 1.0]:
			var x: float = center + side * dist
			if not _too_close(x, placed_x, gap) and _spot_is_free(x, width, ground_y, taken, spots):
				return x
		dist += 8.0
	return NAN


func _too_close(x: float, others: Array[float], gap: float) -> bool:
	for o in others:
		if absf(o - x) < gap:
			return true
	return false


## Vrai si le sol est plat, sans rien dessus, et loin des objets de jeu.
func _spot_is_free(x: float, width: float, ground_y: float, taken: Array[Vector2], spots: Array[Vector2]) -> bool:
	var x0: float = x - width / 2.0
	var x1: float = x + width / 2.0
	for t in taken:
		if x1 > t.x and x0 < t.y:
			return false
	for p in spots:
		if p.x > x0 - 26.0 and p.x < x1 + 26.0 and absf(p.y - ground_y) < 40.0:
			return false
	var px_x: float = x0
	while px_x <= x1:
		var below: Vector2i = terrain.local_to_map(terrain.to_local(Vector2(px_x, ground_y + 6.0)))
		if not _filled(below):
			return false
		for k in 2:  # de la place au-dessus (pas sous un surplomb)
			if _filled(below + Vector2i(0, -1 - k)):
				return false
		px_x += 8.0
	return true


func _make_clothesline(seed_index: int) -> Node2D:
	var root := Node2D.new()
	root.name = "CordeALinge"
	var line := Sprite2D.new()
	line.texture = preload("res://assets/decor/village/clothesline.png")
	line.offset = Vector2(0, -15 + 2)          # pied des piquets 2 pixels dans l'herbe
	root.add_child(line)
	var material := sway_material("pagne")
	var order: Array = [[0, 1, 2], [1, 2, 0], [2, 0, 1]][seed_index % 3]
	for k in 3:
		var x: float = 11.0 + k * 13.0           # le long de la corde (repère de l'image)
		var rope: float = 6.0 + 3.0 * sin(PI * (x - 4.0) / 40.0)
		var cloth := Sprite2D.new()
		cloth.texture = load("res://assets/decor/village/pagne_%d.png" % order[k])
		cloth.material = material
		# Image de la corde : 48 x 30, coin haut gauche en (-24, -28) ; le pagne pend sous la corde.
		cloth.position = Vector2(-24.0 + x, -28.0 + rope + 7.5)
		root.add_child(cloth)
	return root


func _make_fire() -> Node2D:
	var root := Node2D.new()
	root.name = "FeuDeCuisine"
	# Halo de lumière au sol (additif), qui vacille.
	var halo := Sprite2D.new()
	halo.name = "Halo"
	halo.texture = preload("res://assets/fx/fire_glow.png")
	halo.position = Vector2(0, -7)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = add
	root.add_child(halo)
	var hearth := Sprite2D.new()
	hearth.texture = preload("res://assets/decor/village/hearth.png")
	hearth.offset = Vector2(0, -8 + 2)
	root.add_child(hearth)
	# Flammes animées, qui lèchent le bas du canari entre les pierres.
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 10.0)
	var sheet: Texture2D = preload("res://assets/decor/village/flames.png")
	for i in 4:
		var region := AtlasTexture.new()
		region.atlas = sheet
		region.region = Rect2(i * 12, 0, 12, 12)
		frames.add_frame(&"default", region)
	var flames := AnimatedSprite2D.new()
	flames.name = "Flammes"
	flames.sprite_frames = frames
	flames.position = Vector2(0, -6)
	flames.scale = Vector2(1, 0.85)
	flames.play()
	flames.frame = _rng.randi() % 4
	root.add_child(flames)
	# Braises qui s'envolent.
	var embers := CPUParticles2D.new()
	embers.name = "Braises"
	embers.texture = preload("res://assets/fx/ember.png")
	embers.amount = 5
	embers.lifetime = 1.4
	embers.local_coords = false
	embers.position = Vector2(0, -8)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(4, 1)
	embers.direction = Vector2(0, -1)
	embers.spread = 25.0
	embers.initial_velocity_min = 14.0
	embers.initial_velocity_max = 26.0
	embers.gravity = Vector2(-8, -4)
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 0.4, 0.2, 0))
	embers.color_ramp = fade
	root.add_child(embers)
	# Un filet de fumée au-dessus du canari.
	var smoke := _make_smoke()
	smoke.amount = 8
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 0.7
	smoke.position = Vector2(0, -18)
	root.add_child(smoke)
	_smokes.append(smoke)
	root.set_meta("phase", _rng.randf() * TAU)
	_fires.append(root)
	return root


func _update_fires() -> void:
	for fire in _fires:
		var halo := fire.get_node("Halo") as Sprite2D
		var ph: float = fire.get_meta("phase")
		# Vacillement irrégulier : deux sinus de fréquences différentes.
		var flicker: float = 0.75 + 0.15 * sin(_time * 11.0 + ph) + 0.1 * sin(_time * 23.0 + ph * 2.0)
		halo.modulate.a = flicker if not _raining else maxf(halo.modulate.a - 0.02, 0.0)
		halo.scale = Vector2.ONE * (0.95 + 0.05 * flicker)


# ---------------------------------------------------------------------------
# Fumée des cases
# ---------------------------------------------------------------------------

func _spawn_smoke() -> void:
	var group := level.get_node_or_null("DecorBack")
	if group == null:
		return
	var i := 0
	for sprite in group.get_children():
		if not (sprite is Sprite2D and sprite.texture != null):
			continue
		var base: String = sprite.texture.resource_path.get_file().get_basename()
		if not base.begins_with("hut"):
			continue
		i += 1
		if i % 3 == 2:
			continue  # pas de feu dans toutes les cases
		var smoke := _make_smoke()
		# Sortie au sommet du toit de chaume.
		smoke.position = sprite.position + Vector2(0, -sprite.texture.get_height() / 2.0 + 4.0)
		group.add_child(smoke)
		group.move_child(smoke, sprite.get_index())    # derrière la case : elle sort du chaume
		_smokes.append(smoke)


func _make_smoke() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = preload("res://assets/fx/smoke.png")
	p.amount = 16
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(2.0, 1.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 12.0
	p.initial_velocity_min = 9.0
	p.initial_velocity_max = 13.0
	p.gravity = Vector2(-4.0, -2.0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.1
	var grow := Curve.new()
	grow.max_value = 3.0
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 2.4))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	# Fumée de feu de bois : gris bleuté, assez dense au départ, qui pâlit en s'élevant.
	fade.set_color(0, Color(0.56, 0.55, 0.56, 0.0))
	fade.set_color(1, Color(0.8, 0.77, 0.74, 0.0))
	fade.add_point(0.12, Color(0.56, 0.55, 0.56, 0.8))
	fade.add_point(0.55, Color(0.7, 0.68, 0.67, 0.5))
	p.color_ramp = fade
	return p


# ---------------------------------------------------------------------------
# Nuages
# ---------------------------------------------------------------------------

func _add_clouds() -> void:
	var background := level.get_node_or_null("Background")
	if background == null or background.get_node_or_null("Sky") == null:
		return
	var layer := Parallax2D.new()
	layer.name = "Clouds"
	layer.scroll_scale = Vector2(0.05, 0.0)
	layer.repeat_size = Vector2(640, 0)
	layer.repeat_times = 3
	layer.autoscroll = Vector2(-5.0, 0.0)   # ils dérivent avec le vent
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = preload("res://assets/backgrounds/village/bg_clouds.png")
	sprite.position = Vector2(0, 14)
	layer.add_child(sprite)
	background.add_child(layer)
	background.move_child(layer, background.get_node("Sky").get_index() + 1)


# ---------------------------------------------------------------------------
# Oiseaux
# ---------------------------------------------------------------------------

## Un petit vol d'oiseaux traverse le ciel, de droite à gauche, en battant des ailes.
func _spawn_flock() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	if camera == null:
		return
	var center: Vector2 = camera.get_screen_center_position()
	var flock := Node2D.new()
	flock.position = Vector2(center.x + 360.0, center.y - _rng.randf_range(110.0, 150.0))
	flock.set_meta("speed", _rng.randf_range(34.0, 48.0))
	flock.set_meta("end_x", center.x - 420.0)
	var count: int = _rng.randi_range(3, 6)
	for i in count:
		var bird := Sprite2D.new()
		bird.texture = preload("res://assets/decor/village/bird.png")
		bird.hframes = 4
		var row: int = (i + 1) / 2
		var side: int = 1 if i % 2 == 1 else -1
		bird.position = Vector2(row * 9.0, row * 5.0 * side)    # en V
		bird.set_meta("phase", _rng.randf() * TAU)
		flock.add_child(bird)
	_birds.add_child(flock)


func _update_birds(delta: float) -> void:
	if _birds == null:
		return
	_bird_timer -= delta
	if _bird_timer <= 0.0 and not _raining:
		_bird_timer = _rng.randf_range(9.0, 16.0)
		_spawn_flock()
	for flock in _birds.get_children():
		flock.position.x -= float(flock.get_meta("speed")) * delta
		for bird in flock.get_children():
			var ph: float = bird.get_meta("phase")
			bird.frame = int(_time * 9.0 + ph * 2.0) % 4
			bird.offset.y = sin(_time * 2.0 + ph) * 1.5
		if flock.position.x < float(flock.get_meta("end_x")):
			flock.queue_free()


# ---------------------------------------------------------------------------
# Poules
# ---------------------------------------------------------------------------

func _spawn_chickens() -> void:
	var group := level.get_node_or_null("DecorBack")
	var props := level.get_node_or_null("Props")
	if group == null or props == null or terrain == null:
		return
	var i := 0
	for sprite in group.get_children():
		if not (sprite is Sprite2D and sprite.texture != null):
			continue
		if not sprite.texture.resource_path.get_file().begins_with("hut"):
			continue
		i += 1
		if i % 2 == 0:
			continue
		# Le sol au pied de la case (le décor est posé 2 pixels sous la surface).
		var ground_y: float = sprite.position.y + sprite.texture.get_height() / 2.0 - 2.0
		for k in (1 if i % 3 else 2):
			var hen := Chicken.new()
			hen.terrain = terrain
			hen.player = player
			hen.variant = (i + k) % 2
			hen.position = Vector2(sprite.position.x + 30.0 + k * 14.0, ground_y)
			if hen.can_stand_at(hen.position.x):
				props.add_child(hen)
			else:
				hen.free()


# ---------------------------------------------------------------------------
# Chaque image : le vent
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	# Le vent monte et retombe : bruit lissé (rafales), toujours vers la gauche.
	var n: float = (_noise.get_noise_1d(_time) + 1.0) * 0.5
	var gust: float = (RAIN_WIND if _raining else WIND_BASE) + WIND_GUSTS * n * n
	RenderingServer.global_shader_parameter_set(&"wind_gust", -gust)
	if player != null:
		RenderingServer.global_shader_parameter_set(&"player_world", player.global_position + Vector2(0, 20))
	for smoke in _smokes:
		smoke.gravity.x = -4.0 - 14.0 * gust
	_update_birds(delta)
	_update_fires()


## La pluie revient : l'herbe reverdit, le vent forcit, les oiseaux se mettent à l'abri.
func set_raining() -> void:
	_raining = true
	for layer in _grass_layers:
		for tuft in layer.get_children():
			var green: String = tuft.texture.resource_path.replace(".png", "_green.png")
			if ResourceLoader.exists(green):
				tuft.texture = load(green)
	for smoke in _smokes:
		smoke.emitting = false   # les feux s'éteignent sous l'averse
	for fire in _fires:
		fire.get_node("Flammes").hide()
		fire.get_node("Braises").emitting = false


func _exit_tree() -> void:
	# Le héros n'est plus là : l'herbe des autres scènes ne doit plus s'écarter.
	RenderingServer.global_shader_parameter_set(&"player_world", Vector2(0, -10000))
