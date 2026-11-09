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
}

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


func _exit_tree() -> void:
	# Le héros n'est plus là : l'herbe des autres scènes ne doit plus s'écarter.
	RenderingServer.global_shader_parameter_set(&"player_world", Vector2(0, -10000))
