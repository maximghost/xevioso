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
var _completed: bool = false


func _ready() -> void:
	# Un niveau de développement (terrain d'essai) ne touche jamais à la vraie sauvegarde.
	Game.saving_enabled = not level_id in Game.DEV_LEVELS
	if level_id == &"":
		push_warning("Niveau sans level_id : la sauvegarde ne pourra pas s'y retrouver.")
	if terrain != null and player != null:
		_setup_bounds()
	if use_weather:
		_setup_mood()
	_place_player_at_checkpoint()


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

	# L'éclair de Xɛvioso : deux flashs blancs et la terre qui tremble.
	_flash(0.9)
	if player != null:
		player.shake_camera(4.0, 0.5)
	await get_tree().create_timer(0.18).timeout
	_flash(0.6)

	# Sous le premier éclair, la végétation change d'un coup (l'éclat masque la bascule).
	_turn_green()
	# La pluie revient : les couleurs passent du chaud au frais.
	if _weather != null:
		_weather.start_rain()
	if use_weather:
		create_tween().tween_property(self, "modulate", rain_color, 3.0)
	Game.message.emit("La pluie revient sur le village !")
	_bloom()

	await get_tree().create_timer(end_screen_delay).timeout
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
		layer.add_child(flower)
		var delay: float = flower.position.distance_to(origin) / bloom_speed
		var tween := flower.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(flower, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
