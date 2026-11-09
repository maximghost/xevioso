class_name Level
extends Node2D
## Script commun à tous les niveaux.
##
## Il s'occupe de ce que chaque niveau partage :
##   - son identité (level_id), sous laquelle la sauvegarde range ses pierres et sa stèle ;
##   - le départ du héros (au dernier point de contrôle s'il y en a un) ;
##   - les limites : la caméra s'arrête aux bords du terrain, des murs invisibles
##     empêchent de sortir à gauche et à droite, tomber sous le terrain tue ;
##   - l'ambiance : couleur générale (teinte du niveau) et météo (poussière, pluie) ;
##   - le décor vivant (Ambience) : vent, herbes, fumée, nuages, oiseaux, poules ;
##   - la fin du niveau (complete) : l'éclair de Xɛvioso, le retour de la pluie,
##     puis la floraison (bon présage) : l'herbe reverdit, les arbres reprennent des feuilles,
##     et des fleurs éclosent en vague, depuis l'autel jusqu'au bout du village.


## Identifiant du niveau, unique et stable (ex. « village_1 »).
@export var level_id: StringName = &""

## Le héros du niveau.
@export var player: Player

## Le terrain (TileMapLayer) : il fixe les limites de la caméra et du monde.
## Vide = pas de limites (niveau de test).
@export var terrain: TileMapLayer

## Teinte générale du niveau pendant la saison sèche, et une fois la pluie revenue.
@export var dry_color: Color = Color(1.0, 0.97, 0.92)
@export var rain_color: Color = Color(0.86, 0.92, 1.0)

## Ajoute la poussière d'harmattan et permet le retour de la pluie.
@export var use_weather: bool = false

## Délai entre le retour de la pluie et l'écran de fin, en secondes.
@export var end_screen_delay: float = 7.0

## Tuiles « après la pluie » (herbe verte). Vide = pas de changement.
@export var green_tiles: Texture2D

## Fleurs qui éclosent à la fin (choisies au hasard) et leur densité (fleurs par case d'herbe).
@export var flowers: Array[Texture2D] = []
@export_range(0.0, 1.0) var flower_density: float = 0.55
## Vitesse de la vague de floraison, en pixels par seconde.
@export var bloom_speed: float = 420.0

var _weather: Weather
var _ambience: Ambience
var _completed: bool = false
var _dialogue: DialogueBox


func _ready() -> void:
	# Un niveau de développement (terrain d'essai) ne touche jamais à la vraie sauvegarde.
	Game.saving_enabled = not level_id in Game.DEV_LEVELS
	Game.reset_lives()
	# On entre par le début du niveau (pas de point de contrôle) : nouvelle tentative.
	if Game.checkpoint_for(level_id) == &"":
		Game.begin_attempt(level_id)
	if level_id == &"":
		push_warning("Niveau sans level_id : la sauvegarde ne pourra pas s'y retrouver.")
	if terrain != null and player != null:
		_setup_bounds()
	if use_weather:
		_setup_mood()
		_ambience = Ambience.new()
		_ambience.name = "Ambience"
		add_child(_ambience)
		_ambience.setup(self)
	_place_player_at_checkpoint()
	if player != null:
		player.died.connect(_on_player_died)


## Fait parler Xɛvioso (le jeu est figé pendant ce temps). À attendre avec « await ».
func say(lines: Array) -> void:
	if lines.is_empty():
		return
	if _dialogue == null:
		_dialogue = preload("res://scenes/ui/dialogue_box.tscn").instantiate()
		add_child(_dialogue)
	# Un petit éclair annonce la voix.
	_flash(0.25)
	await _dialogue.play(lines, true)


## Le héros a perdu tous ses cœurs : une vie de moins. S'il n'en reste plus, game over.
func _on_player_died() -> void:
	if Game.lose_life() > 0:
		return
	player.respawn_allowed = false
	await get_tree().create_timer(0.5).timeout
	await _xevioso_wrath()
	var screen: Node = preload("res://scenes/ui/game_over.tscn").instantiate()
	screen.set("level_id", level_id)
	add_child(screen)


## Game over : la colère de Xɛvioso. Le ciel s'assombrit, la terre tremble, et des éclairs
## secs frappent le sol l'un après l'autre — sans présage de pluie : ni nuage qui s'ouvre,
## ni goutte. Environ 2,6 secondes, puis l'écran de fin.
func _xevioso_wrath() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
	var center: Vector2 = camera.get_screen_center_position()
	var top: float = center.y - view.y / 2.0
	# Le ciel s'assombrit (teinte d'orage sec, rougeâtre).
	var mood: Color = modulate
	create_tween().tween_property(self, "modulate", mood * Color(0.5, 0.42, 0.5), 0.4)
	# La terre gronde : secousse continue qui enfle puis retombe.
	var rumble := create_tween()
	rumble.tween_method(func(k: float) -> void:
		if is_instance_valid(player):
			player.shake_camera(2.0 + 5.0 * k, 0.12),
		0.0, 1.0, 1.4)
	rumble.tween_method(func(k: float) -> void:
		if is_instance_valid(player):
			player.shake_camera(7.0 * (1.0 - k), 0.12),
		0.0, 1.0, 1.2)
	# Les éclairs : sept frappes, de part et d'autre de l'écran, de plus en plus serrées.
	var space := get_world_2d().direct_space_state
	for i in 7:
		var x: float = center.x + randf_range(-view.x * 0.45, view.x * 0.45)
		var ground: Vector2 = _ground_below(space, Vector2(x, top), center.y + view.y / 2.0)
		LightningBolt.strike(self, Vector2(x + randf_range(-30.0, 30.0), top - 10.0), ground, 2.5, 0.4, 3)
		Fx.sparks(self, ground, Color(1.0, 0.85, 0.45), 12)
		Fx.dust(self, ground, Color(0.72, 0.44, 0.24), 14, 120.0, 70.0)
		Fx.puff(self, ground, Color(0.86, 0.72, 0.56), 4, Vector2.ZERO, 40.0, 0.8)
		Fx.ring(self, ground, Color(1.0, 0.85, 0.5), 30.0, 0.35, 2.5, 0.3)
		_flash(0.35 if i < 6 else 0.8)
		await get_tree().create_timer(maxf(0.38 - i * 0.04, 0.14)).timeout
	await get_tree().create_timer(0.5).timeout
	modulate = mood


## Le premier sol sous un point (rayon vers le bas sur la couche « monde »), ou le bas de l'écran.
func _ground_below(space: PhysicsDirectSpaceState2D, from: Vector2, bottom: float) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(from, Vector2(from.x, bottom + 64.0), 1)
	var hit: Dictionary = space.intersect_ray(query)
	return hit.position if not hit.is_empty() else Vector2(from.x, bottom)


## Retrouve le niveau qui contient un nœud (pour les pierres, points de contrôle...).
static func of(node: Node) -> Level:
	var current: Node = node
	while current != null:
		if current is Level:
			return current
		current = current.get_parent()
	return null


# ---------------------------------------------------------------------------
# Limites du monde
# ---------------------------------------------------------------------------

func _setup_bounds() -> void:
	var cells: Rect2i = terrain.get_used_rect()
	var tile: Vector2 = Vector2(terrain.tile_set.tile_size)
	var left: float = cells.position.x * tile.x
	var right: float = cells.end.x * tile.x
	var top: float = cells.position.y * tile.y
	var bottom: float = cells.end.y * tile.y

	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = int(left)
	camera.limit_right = int(right)
	camera.limit_top = int(minf(top, bottom - 360.0))
	camera.limit_bottom = int(bottom)

	# Tomber sous le terrain : mort.
	player.death_height = bottom + 48.0

	# Murs invisibles à gauche et à droite (des « frontières » infinies).
	for side in [[left, Vector2.RIGHT], [right, Vector2.LEFT]]:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var boundary := WorldBoundaryShape2D.new()
		boundary.normal = side[1]
		shape.shape = boundary
		wall.position = Vector2(side[0], 0.0)
		wall.add_child(shape)
		add_child(wall)


# ---------------------------------------------------------------------------
# Ambiance et fin du niveau
# ---------------------------------------------------------------------------

## La teinte générale passe par « modulate », la couleur du niveau lui-même : elle s'applique
## à tout ce qu'il contient (décor, terrain, héros), mais pas à l'interface (HUD, boutons),
## qui vit sur des CanvasLayer à part. (Un nœud CanvasModulate ferait la même chose, mais
## Safari sur iPhone l'affiche mal : tout le monde disparaissait, sauf l'interface.)
func _setup_mood() -> void:
	modulate = dry_color
	if player != null:
		_weather = Weather.new()
		player.get_node("Camera2D").add_child(_weather)


## Le niveau est réussi : la foudre répond, la pluie revient, puis l'écran de fin.
func complete() -> void:
	if _completed:
		return
	_completed = true
	Game.complete_level(level_id)
	# Xɛvioso parle d'abord, puis la foudre répond.
	await say(Voices.lines(StringName(String(level_id).split("_")[0] + "_fin")))

	# L'éclair de Xɛvioso : deux flashs blancs et la terre qui tremble.
	_flash(0.9)
	if player != null:
		player.shake_camera(4.0, 0.5)
	await get_tree().create_timer(0.18).timeout
	_flash(0.6)

	# Sous le premier éclair, la végétation change d'un coup (l'éclat masque la bascule).
	_turn_green()
	if _ambience != null:
		_ambience.set_raining()
	# La pluie revient : les couleurs passent du chaud au frais.
	if _weather != null:
		_weather.start_rain()
	if use_weather:
		create_tween().tween_property(self, "modulate", rain_color, 3.0)
	Game.message.emit("La pluie revient sur le village !")
	_bloom()

	await get_tree().create_timer(end_screen_delay).timeout
	# La première étape est franchie, mais l'histoire continue (si le niveau a une suite).
	var suite: Array = Voices.lines(StringName(String(level_id).split("_")[0] + "_suite"))
	if not suite.is_empty():
		await say(suite)
	add_child(preload("res://scenes/ui/demo_end.tscn").instantiate())


## Herbe verte (on change l'image des tuiles : toutes les cases suivent), arbres et buissons
## remplacés par leur version « après la pluie » quand elle existe (image_green.png).
func _turn_green() -> void:
	if terrain != null and green_tiles != null:
		# Une copie du jeu de tuiles : l'original (partagé, gardé en mémoire par Godot)
		# reste sec pour la prochaine partie.
		var tiles: TileSet = terrain.tile_set.duplicate(true)
		(tiles.get_source(0) as TileSetAtlasSource).texture = green_tiles
		terrain.tile_set = tiles
		var back := get_node_or_null("TerrainBack") as TileMapLayer
		if back != null:
			back.tile_set = tiles
	for group_name in ["DecorBack", "DecorFront"]:
		var group := get_node_or_null(group_name)
		if group == null:
			continue
		for sprite in group.get_children():
			if sprite is Sprite2D and sprite.texture != null:
				var green_path: String = sprite.texture.resource_path.replace(".png", "_green.png")
				if ResourceLoader.exists(green_path):
					sprite.texture = load(green_path)


## Les fleurs éclosent sur l'herbe, en vague partant de l'autel (ou du héros).
func _bloom() -> void:
	if terrain == null or flowers.is_empty():
		return
	var origin: Vector2 = player.global_position if player != null else Vector2.ZERO
	var layer := Node2D.new()
	layer.name = "Flowers"
	add_child(layer)
	# Juste derrière le terrain : le pied des fleurs se cache dans l'herbe.
	move_child(layer, terrain.get_index())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for cell in terrain.get_used_cells():
		# Seulement les cases du dessus (première ligne de l'atlas : sommets herbeux).
		if terrain.get_cell_atlas_coords(cell).y != 0 or rng.randf() > flower_density:
			continue
		var flower := Sprite2D.new()
		flower.texture = flowers[rng.randi() % flowers.size()]
		flower.offset = Vector2(0, -6)                 # la base de la touffe au point de pose
		flower.position = Vector2(cell.x * 16 + rng.randi_range(2, 14), cell.y * 16 + 6)
		flower.scale = Vector2.ZERO
		if _ambience != null:
			flower.material = _ambience.sway_material("flower")   # elles ploient sous l'averse
		layer.add_child(flower)
		var delay: float = flower.position.distance_to(origin) / bloom_speed
		var tween := flower.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(flower, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Un flash blanc plein écran (public : la foudre de Xɛvioso s'en sert aussi).
func flash(strength: float) -> void:
	_flash(strength)


## Un flash blanc plein écran qui s'éteint aussitôt.
func _flash(strength: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	var rect := ColorRect.new()
	rect.color = Color(1.0, 1.0, 0.95, strength)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var tween := rect.create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.35)
	tween.tween_callback(layer.queue_free)


# ---------------------------------------------------------------------------
# Point de contrôle
# ---------------------------------------------------------------------------

## Si un point de contrôle de ce niveau est enregistré, le héros repart de là.
func _place_player_at_checkpoint() -> void:
	var point_name: StringName = Game.checkpoint_for(level_id)
	if point_name == &"" or player == null:
		return
	for node in get_tree().get_nodes_in_group(&"checkpoint"):
		var checkpoint := node as Checkpoint
		if checkpoint.name == point_name:
			checkpoint.light_up(false)  # allumée, sans fanfare : on la retrouve telle quelle
			player.global_position = checkpoint.spawn_position()
			player.set_respawn_point(checkpoint.spawn_position())
			player.get_node("Camera2D").reset_smoothing()
			return
