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
## Musique du niveau, et ses ambiances (boucles) tant qu'il fait sec.
@export var music_track: StringName = &"village"
@export var ambiences: Array[StringName] = [&"wind_dry", &"village_day"]
## Le titre et le sous-titre de la bannière de victoire.
@export var victory_title: String = "La pluie est revenue !"
@export var victory_subtitle: String = "Première étape accomplie : le village est sauvé"
## Scène jouée après la victoire (fin de partie : la suite de l'histoire). Vide : l'écran de fin.
@export_file("*.tscn") var outro_scene: String = ""

var _weather: Weather
var _ambience: Ambience
var _completed: bool = false
var _game_over: bool = false     # la dernière vie est perdue : plus de victoire possible
var _sokpe_total: int = 0        # pierres sokpe du niveau (pour le bilan de fin)
var _dialogue: DialogueBox


func _ready() -> void:
	# Un niveau de développement (terrain d'essai) ne touche jamais à la vraie sauvegarde.
	Game.saving_enabled = not level_id in Game.DEV_LEVELS and not Game.test_mode
	Game.reset_lives()
	# On entre par le début du niveau (pas de point de contrôle) : nouvelle tentative.
	if Game.checkpoint_for(level_id) == &"":
		Game.begin_attempt(level_id)
	if level_id == &"":
		push_warning("Niveau sans level_id : la sauvegarde ne pourra pas s'y retrouver.")
	if terrain != null and player != null:
		_setup_bounds()
	if not use_weather:
		modulate = dry_color         # (sans météo : la teinte seule)
	if use_weather:
		_setup_mood()
		_ambience = Ambience.new()
		_ambience.name = "Ambience"
		add_child(_ambience)
		_ambience.setup(self)
	_place_player_at_checkpoint()
	_sokpe_total = find_children("*", "SokpeStone", true, false).size()
	if player != null:
		player.died.connect(_on_player_died)
	Audio.music(music_track)
	Audio.ambience(ambiences)


## Fait parler Xɛvioso (le jeu est figé pendant ce temps). À attendre avec « await ».
func say(lines: Array) -> void:
	if lines.is_empty():
		return
	if _dialogue == null:
		_dialogue = preload("res://scenes/ui/dialogue_box.tscn").instantiate()
		add_child(_dialogue)
	# Un petit éclair et un grondement lointain annoncent la voix.
	_flash(0.25)
	Audio.play(&"thunder_far", -10.0, 0.1)
	await _dialogue.play(lines, true)


## Le héros a perdu tous ses cœurs : une vie de moins. S'il n'en reste plus, game over.
func _on_player_died() -> void:
	if _completed:
		return
	if Game.lose_life() > 0:
		return
	_game_over = true
	player.respawn_allowed = false
	Audio.stop_music(1.0)
	await get_tree().create_timer(0.5).timeout
	await _xevioso_wrath()
	Audio.jingle(&"game_over")
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
	Audio.play(&"wrath")
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
		Audio.play_at(&"thunder_close", ground, -4.0 if i < 6 else 2.0, 0.15)
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


## Vrai si le niveau peut encore être gagné (pas de fin de partie en cours, héros vivant).
func can_complete() -> bool:
	return not _completed and not _game_over and (player == null or not player.health.is_dead())


## Le niveau est réussi. Dès cet instant le héros ne craint plus rien et les ennemis se
## figent ; Xɛvioso parle ; un grand éclair frappe l'autel, la foudre balaie les ennemis
## restants, la pluie revient, l'herbe reverdit, les fleurs éclosent, un arc-en-ciel se lève ;
## la bannière de victoire donne le bilan ; puis la suite de l'histoire et l'écran de fin.
func complete(altar: Vector2 = Vector2.INF) -> void:
	if not can_complete():
		return
	_completed = true
	if player != null:
		player.protected = true
		if altar == Vector2.INF:
			altar = player.global_position
	_freeze_enemies()
	Game.complete_level(level_id)
	# Xɛvioso parle d'abord.
	await say(Voices.lines(StringName(String(level_id).split("_")[0] + "_fin")))

	# 1. La foudre répond : le ciel s'assombrit d'un coup, un grand éclair frappe l'autel.
	if player != null:
		player.cast_pose()
	var mood: Color = modulate
	create_tween().tween_property(self, "modulate", mood * Color(0.6, 0.6, 0.75), 0.15)
	await get_tree().create_timer(0.2).timeout
	var target: Vector2 = altar + Vector2(0, -18)
	LightningBolt.strike(self, target + Vector2(randf_range(-20.0, 20.0), -380.0), target, 4.5, 0.7, 6)
	_flash(1.0)
	Audio.play(&"thunder_close")
	Audio.jingle(&"victoire", &"fete")
	if use_weather:
		Audio.ambience([&"rain", &"village_day"], 3.0)
	Fx.ring(self, target, Color(1.0, 0.9, 0.55), 90.0, 0.7, 4.0)
	Fx.ring(self, target, Color(0.7, 0.85, 1.0), 140.0, 1.0, 2.0)
	Fx.sparks(self, target, Color(1.0, 0.9, 0.5), 30)
	Fx.dust(self, altar, Color(0.72, 0.44, 0.24), 26, 140.0, 80.0)
	if player != null:
		player.shake_camera(6.0, 0.6)
	await get_tree().create_timer(0.25).timeout
	modulate = mood

	# 2. La foudre balaie les ennemis restants, du plus proche au plus lointain.
	await _sweep_enemies(altar)

	# 3. La pluie revient : l'herbe reverdit, les couleurs fraîchissent, les fleurs éclosent.
	_flash(0.6)
	_turn_green()
	if _ambience != null:
		_ambience.set_raining()
	if _weather != null:
		_weather.start_rain()
	create_tween().tween_property(self, "modulate", rain_color, 3.0)
	_bloom()
	await get_tree().create_timer(1.6).timeout
	_rainbow()

	# 4. La bannière de victoire, avec le bilan.
	var banner := VictoryBanner.new()
	add_child(banner)
	var collected: int = Game.sokpe.get(level_id, []).size()
	await banner.play(victory_title, victory_subtitle,
		collected, _sokpe_total, Game.lives)
	await get_tree().create_timer(1.0).timeout

	# 5. L'histoire continue (scène de fin de partie, si le niveau en a une), sinon l'écran de fin.
	if outro_scene != "":
		Audio.stop_music(1.5)
		var fade := ColorRect.new()
		fade.color = Color(0, 0, 0, 0)
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		var layer := CanvasLayer.new()
		layer.layer = 30
		layer.add_child(fade)
		add_child(layer)
		await create_tween().tween_property(fade, "color:a", 1.0, 1.5).finished
		get_tree().change_scene_to_file(outro_scene)
		return
	var end: Node = preload("res://scenes/ui/demo_end.tscn").instantiate()
	end.set("level_id", level_id)
	add_child(end)


## Les ennemis se figent (et leurs projectiles s'éteignent) : plus rien ne bouge contre le héros.
func _freeze_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if is_instance_valid(enemy) and is_ancestor_of(enemy):
			enemy.set_physics_process(false)
	for clod in find_children("*", "Clod", true, false):
		clod.queue_free()


## Un éclair par ennemi encore debout : du plus proche de l'autel au plus lointain.
func _sweep_enemies(from: Vector2) -> void:
	var enemies: Array = get_tree().get_nodes_in_group(&"enemies").filter(func(e: Node) -> bool:
		return is_instance_valid(e) and is_ancestor_of(e) and not (e.has_method("is_dead") and e.is_dead()))
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_to(from) < b.global_position.distance_to(from))
	var camera := get_viewport().get_camera_2d()
	var top: float = (camera.get_screen_center_position().y if camera != null else from.y) - 220.0
	var sounds := 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var at: Vector2 = enemy.global_position
		var on_screen: bool = camera != null and absf(at.x - camera.get_screen_center_position().x) < 340.0
		if on_screen:
			LightningBolt.strike(self, Vector2(at.x + randf_range(-20.0, 20.0), top), at, 2.5, 0.4, 3)
			Fx.sparks(self, at, Color(1.0, 0.9, 0.5), 10)
			if sounds < 4:
				Audio.play_at(&"thunder_close", at, -6.0, 0.15)
				sounds += 1
		enemy.set_physics_process(true)    # (le temps de mourir)
		if enemy.has_method("take_hit"):
			enemy.take_hit(99, signf(at.x - from.x))
		if on_screen:
			await get_tree().create_timer(0.14).timeout


## Un arc-en-ciel se lève au-dessus du village, derrière le décor.
func _rainbow() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var arc := Rainbow.new()
	arc.position = camera.get_screen_center_position() + Vector2(40.0, 150.0)
	var background := get_node_or_null("Background")
	add_child(arc)
	if background != null:
		move_child(arc, background.get_index() + 1)
	arc.modulate.a = 0.0
	create_tween().tween_property(arc, "modulate:a", 1.0, 3.0)


## Les sept bandes de l'arc-en-ciel, en arcs concentriques translucides.
class Rainbow:
	extends Node2D
	const BANDS := [Color(0.9, 0.3, 0.3), Color(0.95, 0.6, 0.25), Color(0.98, 0.9, 0.35),
		Color(0.45, 0.85, 0.4), Color(0.35, 0.65, 0.95), Color(0.4, 0.4, 0.85), Color(0.6, 0.4, 0.8)]

	func _draw() -> void:
		for i in BANDS.size():
			var c: Color = BANDS[i]
			c.a = 0.32
			draw_arc(Vector2.ZERO, 300.0 - i * 4.0, PI * 1.08, PI * 1.92, 64, c, 4.0)


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
	Audio.play(&"bloom")
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
