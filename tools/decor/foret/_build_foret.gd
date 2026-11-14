extends SceneTree
## Outil (à copier à la racine du projet pour l'exécuter) : construit les ressources de la
## forêt (images animées, TileSet, ennemis) et la scène du niveau 2 à partir du tracé
## _foret_1.json produit et vérifié par layout_foret.py.
##   godot --headless --path . -s res://_build_foret.gd

const TILE := 16
## Décors qui balancent (fougères, palmes, colocases) : amplitude en pixels.
const SWAY := {"fougere": 1.2, "grande_fougere": 1.8, "colocase": 2.0, "raphia": 2.4, "buisson_foret": 0.8}
## Décors « arbres » : enfoncés de 8 px sous la ligne du sol (la terre recouvre le pied).
const SINK := {"iroko": 8, "fromager": 8, "raphia": 8, "arbre_mort": 8, "figuier": 8, "termitiere": 8}
## Décors de la v1 encore utilisés (souche, tronc couché, buisson, fougère, champignons).
const OLD := ["fougere", "champignons", "souche", "tronc_couche", "buisson_foret"]


func _initialize() -> void:
	_build_frames()
	_build_enemy_scenes()
	ResourceSaver.save(_build_tileset(), "res://assets/tiles/forest_tileset.tres")
	var tileset: TileSet = load("res://assets/tiles/forest_tileset.tres")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://_foret_1.json"))
	var root := _build_level(data, tileset)
	var packed := PackedScene.new()
	print("pack: ", error_string(packed.pack(root)))
	print("save: ", error_string(ResourceSaver.save(packed, "res://scenes/levels/foret/foret_1.tscn")))
	quit()


# ---------------------------------------------------------------- images animées
func _frames(sheet_path: String, size: Vector2i, anims: Array, out_path: String) -> void:
	## anims : [[nom, ligne, nombre, fps, boucle], ...]
	var sheet: Texture2D = load(sheet_path)
	var f := SpriteFrames.new()
	f.remove_animation(&"default")
	for a in anims:
		f.add_animation(a[0])
		f.set_animation_speed(a[0], a[3])
		f.set_animation_loop(a[0], a[4])
		for i in a[2]:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * size.x, a[1] * size.y, size.x, size.y)
			f.add_frame(a[0], at)
	print(out_path, ": ", error_string(ResourceSaver.save(f, out_path)))


func _build_frames() -> void:
	_frames("res://assets/enemies/ant/ant.png", Vector2i(24, 20), [[&"walk", 0, 4, 9.0, true]], "res://assets/enemies/ant/ant_frames.tres")
	_frames("res://assets/enemies/bat/bat.png", Vector2i(24, 16), [[&"fly", 0, 4, 12.0, true]], "res://assets/enemies/bat/bat_frames.tres")
	_frames("res://assets/enemies/bat/bat_eyes.png", Vector2i(24, 16), [[&"fly", 0, 4, 12.0, true]], "res://assets/enemies/bat/bat_eyes_frames.tres")
	_frames("res://assets/enemies/rat/rat.png", Vector2i(16, 10), [[&"run", 0, 2, 14.0, true]], "res://assets/enemies/rat/rat_frames.tres")
	_frames("res://assets/enemies/golem/golem.png", Vector2i(34, 38), [[&"walk", 0, 4, 5.0, true], [&"sleep", 1, 2, 1.5, true]], "res://assets/enemies/golem/golem_frames.tres")
	_frames("res://assets/props/foret/bird.png", Vector2i(14, 12), [[&"fly", 0, 2, 10.0, true], [&"perch", 0, 0, 1.0, true]], "res://assets/props/foret/bird_frames.tres")
	var bird: SpriteFrames = load("res://assets/props/foret/bird_frames.tres")
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/props/foret/bird.png")
	at.region = Rect2(28, 0, 14, 12)
	bird.add_frame(&"perch", at)
	ResourceSaver.save(bird, "res://assets/props/foret/bird_frames.tres")
	_frames("res://assets/enemies/adan/adan.png", Vector2i(144, 136), [
		[&"idle", 0, 2, 3.0, true], [&"walk", 1, 4, 6.0, true], [&"charge", 2, 2, 10.0, true], [&"throw", 3, 3, 8.0, false],
		[&"slam", 4, 3, 8.0, false], [&"hurt", 5, 1, 1.0, true], [&"fury", 6, 2, 8.0, true], [&"dead", 7, 1, 1.0, false]],
		"res://assets/enemies/adan/adan_frames.tres")


func _build_enemy_scenes() -> void:
	# La fourmi corrompue
	var ant: Node = load("res://scenes/enemies/crawler/crawler.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	ant.name = "Ant"
	ant.set("speed", 50.0)
	ant.set("dust_color", Color(0.55, 0.52, 0.48))
	ant.get_node("Sprite").sprite_frames = load("res://assets/enemies/ant/ant_frames.tres")
	_save_scene(ant, "res://scenes/enemies/ant/ant.tscn")
	# La chauve-souris de poussière : le criquet, autre corps, yeux qui luisent dans le noir
	var bat: Node = load("res://scenes/enemies/locust/locust.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	bat.name = "Bat"
	bat.get_node("Sprite").sprite_frames = load("res://assets/enemies/bat/bat_frames.tres")
	bat.set("eyes_frames", load("res://assets/enemies/bat/bat_eyes_frames.tres"))
	bat.set("wing_sound", &"bat_flutter")
	bat.set("dust_color", Color(0.45, 0.43, 0.4))
	bat.set("detect_range", 135.0)
	bat.set("patrol_range", 40.0)
	_save_scene(bat, "res://scenes/enemies/bat/bat.tscn")
	# Le Poussiéreux : la motte, en colosse carapacé
	var golem: Node = load("res://scenes/enemies/crawler/crawler.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	golem.name = "Golem"
	golem.set("speed", 24.0)
	golem.set("armored", true)
	golem.set("dust_color", Color(0.6, 0.56, 0.5))
	var spr: AnimatedSprite2D = golem.get_node("Sprite")
	spr.sprite_frames = load("res://assets/enemies/golem/golem_frames.tres")
	spr.position = Vector2(0, -19)
	for path in ["CollisionShape2D", "Hurtbox/CollisionShape2D", "Hitbox/CollisionShape2D"]:
		var cs: CollisionShape2D = golem.get_node(path)
		var r := RectangleShape2D.new()
		r.size = Vector2(26, 34) if path != "Hurtbox/CollisionShape2D" else Vector2(22, 30)
		cs.shape = r
		cs.position = Vector2(0, -17)
	golem.get_node("LedgeRay").position = Vector2(14, -2)
	_save_scene(golem, "res://scenes/enemies/golem/golem.tscn")


func _save_scene(node: Node, path: String) -> void:
	var ps := PackedScene.new()
	ps.pack(node)
	print(path, ": ", error_string(ResourceSaver.save(ps, path)))


# ---------------------------------------------------------------- tuiles
func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/forest_tiles.png")
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var h := TILE / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var plank := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 6), Vector2(-h, -h + 6)])
	for row in 8:
		for col in 6:
			var c := Vector2i(col, row)
			src.create_tile(c)
			if row == 3 and col == 5:
				continue
			var td := src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, plank if (row == 3 and col >= 2) else full)
	return ts


func _own(node: Node, root: Node) -> void:
	node.owner = root
	for c in node.get_children():
		if c.owner == null:
			pass


func _scripted(base: Node, path: String) -> Node:
	base.set_script(load(path))
	return base


# ---------------------------------------------------------------- le niveau
func _build_level(data: Dictionary, tileset: TileSet) -> Node2D:
	var root := Node2D.new()
	root.name = "Foret1"
	root.set_script(load("res://scenes/levels/level.gd"))
	root.set("level_id", &"foret_1")
	root.set("use_weather", false)
	root.set("requires_boss", true)
	root.set("green_tiles", load("res://assets/tiles/forest_tiles_green.png"))
	root.set("dry_color", Color(0.86, 0.88, 0.86))
	root.set("rain_color", Color(1.02, 1.06, 0.98))
	root.set("music_track", &"foret")
	var amb: Array[StringName] = [&"forest"]
	root.set("ambiences", amb)
	root.set("victory_title", "La forêt respire !")
	root.set("victory_subtitle", "Deuxième étape : les irokos sont redevenus sacrés")
	var flowers: Array[Texture2D] = []
	for f in ["flower_yellow", "flower_red", "flower_white"]:
		flowers.append(load("res://assets/decor/village/%s.png" % f))
	root.set("flowers", flowers)
	root.set("flower_density", 0.3)

	# Arrière-plans : ils montent un peu avec la caméra (la canopée est haute).
	var bg := Node2D.new(); bg.name = "Background"; root.add_child(bg); _own(bg, root)
	var ground_cam_y: float = 42 * 16 - 140.0
	for layer in [["Sky", "bg_sky", 0.0, 0.0, 0], ["Far", "bg_far", 0.12, 0.06, -26], ["Mid", "bg_mid", 0.3, 0.15, -34], ["Near", "bg_near", 0.5, 0.3, -44]]:
		var p := Parallax2D.new()
		p.name = layer[0]
		p.scroll_scale = Vector2(layer[2], layer[3])
		p.repeat_size = Vector2(640, 0)
		p.repeat_times = 3
		# au niveau du sol, l'image est à sa place habituelle
		p.scroll_offset = Vector2(0, ground_cam_y * layer[3])
		bg.add_child(p); _own(p, root)
		var s := Sprite2D.new()
		s.name = "Image"
		s.centered = false
		s.texture = load("res://assets/backgrounds/foret/%s.png" % layer[1])
		s.position = Vector2(0, layer[4])
		p.add_child(s); _own(s, root)

	var back := Node2D.new(); back.name = "DecorBack"; root.add_child(back); _own(back, root)
	var front_nodes := []
	var counts := {}
	var sway: Shader = load("res://assets/shaders/sway.gdshader")
	for d in data.decor:
		var s := Sprite2D.new()
		counts[d.name] = counts.get(d.name, 0) + 1
		s.name = "%s%d" % [String(d.name).to_pascal_case(), counts[d.name]]
		var folder: String = "res://assets/decor/foret/"
		s.texture = load(folder + "%s.png" % d.name)
		s.flip_h = d.get("flip", false)
		var sink: int = SINK.get(d.name, 0)
		s.position = Vector2(d.x, d.y + 2 + sink - s.texture.get_height() / 2.0)
		if SWAY.has(d.name):
			var m := ShaderMaterial.new()
			m.shader = sway
			m.set_shader_parameter("amount", SWAY[d.name])
			s.material = m
		if d.get("light") != null:
			var l := PointLight2D.new()
			l.name = "Lueur"
			l.texture = Fx.light_texture()
			l.texture_scale = 1.1
			l.color = Color(d.light[0], d.light[1], d.light[2])
			l.energy = 0.9
			l.position = Vector2(0, s.texture.get_height() / 2.0 - 8)
			s.add_child(l)
			var unshaded := CanvasItemMaterial.new()
			unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
			s.material = unshaded
		if d.front:
			front_nodes.append(s)
		else:
			back.add_child(s); _own(s, root)
			for c in s.get_children(): _own(c, root)

	var tm := TileMapLayer.new(); tm.name = "Terrain"; tm.tile_set = tileset
	root.add_child(tm); _own(tm, root)
	for c in data.cells:
		tm.set_cell(Vector2i(c[0], c[1]), 0, Vector2i(c[2], c[3]))
	root.set("terrain", tm)
	# Habillages : les masses de terre qui sont en vrai des troncs, un tronc couché, des racines
	var covers := Node2D.new(); covers.name = "Habillages"; root.add_child(covers); _own(covers, root)
	for e in data.entities:
		if e.kind != "cover":
			continue
		var c := Sprite2D.new()
		c.texture = load("res://assets/decor/foret/%s.png" % e.texture)
		c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		c.region_enabled = true
		c.region_rect = Rect2(0, 0, e.w, e.h)
		c.centered = false
		c.position = Vector2(e.x, e.y)
		covers.add_child(c); _own(c, root)

	var dark := _scripted(Node2D.new(), "res://scenes/props/foret/darkness.gd")
	dark.name = "Ombre"
	var ranges := PackedVector2Array()
	for r in data.dark:
		ranges.append(Vector2(r[0], r[1]))
	dark.set("ranges", ranges)
	root.add_child(dark); _own(dark, root)

	var props := Node2D.new(); props.name = "Props"; root.add_child(props); _own(props, root)
	var enemies := Node2D.new(); enemies.name = "Enemies"; root.add_child(enemies); _own(enemies, root)
	var voices := Node2D.new(); voices.name = "Voices"; root.add_child(voices); _own(voices, root)
	var scenes := {
		"checkpoint": load("res://scenes/props/checkpoint.tscn"),
		"sokpe": load("res://scenes/props/sokpe_stone.tscn"),
		"ant": load("res://scenes/enemies/ant/ant.tscn"),
		"bat": load("res://scenes/enemies/bat/bat.tscn"),
		"golem": load("res://scenes/enemies/golem/golem.tscn"),
		"end": load("res://scenes/props/end_shrine.tscn"),
		"shrine": load("res://scenes/props/hero_shrine.tscn"),
	}
	var player: Node2D
	var n := {}
	var late := []           # nœuds qui référencent d'autres nœuds : réglés à la fin
	for e in data.entities:
		var kind: String = e.kind
		if kind == "cover":
			continue
		if kind == "player":
			player = load("res://scenes/heroes/player.tscn").instantiate()
			player.name = "Player"
			player.position = Vector2(e.x, e.y - 20)
			player.set("max_speed", 200.0)
			player.set("time_to_apex", 0.3)
			player.set("fall_gravity_multiplier", 1.0)
			var heroes: Array[HeroData] = []
			for id in ["kodjo", "afi", "yawa", "abla", "kokou"]:
				heroes.append(load("res://assets/heroes/%s/%s_data.tres" % [id, id]))
			player.set("heroes", heroes)
			continue
		var node: Node2D
		match kind:
			"crumble":
				node = _scripted(StaticBody2D.new(), "res://scenes/props/crumbling_platform.gd")
				node.set("width_tiles", int(e.w))
				node.set("texture", load("res://assets/props/branche_morte.png"))
			"mushroom":
				node = _scripted(StaticBody2D.new(), "res://scenes/props/bounce_mushroom.gd")
			"thorns":
				node = _scripted(Area2D.new(), "res://scenes/props/thorns.gd")
				node.set("width_tiles", int(e.w))
				node.set("texture", load("res://assets/props/ronces.png"))
			"vine":
				node = _scripted(Node2D.new(), "res://scenes/props/swinging_vine.gd")
				for k in ["length", "amplitude", "period", "phase"]:
					node.set(k, float(e[k]))
			"voice":
				node = _scripted(Area2D.new(), "res://scenes/props/voice_trigger.gd")
				node.set("voice_id", StringName(e.id))
			"fireflies":
				node = _scripted(Area2D.new(), "res://scenes/props/foret/fireflies.gd")
			"rat":
				node = _scripted(Node2D.new(), "res://scenes/props/foret/rat_critter.gd")
			"drum":
				node = _scripted(Area2D.new(), "res://scenes/props/foret/voice_drum.gd")
				node.set("voice", int(e.voice))
			"bird":
				node = _scripted(Node2D.new(), "res://scenes/props/foret/messenger_bird.gd")
			"puzzle":
				node = _scripted(Node2D.new(), "res://scenes/props/foret/drum_puzzle.gd")
				node.set("sequence", PackedInt32Array(e.sequence))
				node.set("start_x", float(e.start_x))
				late.append([node, e])
			"rootgate":
				node = _scripted(AnimatableBody2D.new(), "res://scenes/props/foret/root_gate.gd")
				node.set("height_tiles", int(e.h))
				node.set("start_open", e.get("open", false))
			"root":
				node = _scripted(AnimatableBody2D.new(), "res://scenes/props/foret/sacred_root.gd")
				node.set("size_tiles", Vector2i(int(e.w), int(e.h)))
				node.set("grow", e.grow)
				node.set("stay_time", float(e.stay))
			"updraft":
				node = _scripted(Area2D.new(), "res://scenes/props/foret/updraft.gd")
				node.set("size", Vector2(e.w, e.h))
			"gust":
				node = _scripted(Area2D.new(), "res://scenes/props/foret/wind_gust.gd")
				node.set("size", Vector2(e.w, e.h))
				node.set("direction", int(e.dir))
				node.set("period", float(e.period))
				node.set("phase", float(e.phase))
				node.set("strength", float(e.strength))
			"firefloor":
				node = _scripted(Area2D.new(), "res://scenes/enemies/adan/fire_floor.gd")
				node.set("width", float(e.w))
			"adan":
				node = _scripted(CharacterBody2D.new(), "res://scenes/enemies/adan/adan.gd")
				node.set("arena_left", float(e.left))
				node.set("arena_right", float(e.right))
				node.set("floor_y", float(e.y))
				node.set("bat_scene", scenes["bat"])
				late.append([node, e])
			"arena":
				node = _scripted(Area2D.new(), "res://scenes/enemies/adan/boss_arena.gd")
				late.append([node, e])
			"shrine":
				node = scenes["shrine"].instantiate()
				node.set("hero", load("res://assets/heroes/%s/%s_data.tres" % [e.hero, e.hero]))
			_:
				node = scenes[kind].instantiate()
		n[kind] = n.get(kind, 0) + 1
		node.name = e.get("name", "%s%d" % [kind.capitalize().replace(" ", ""), n[kind]])
		if kind == "voice":
			node.name = "Voix_" + String(e.id).trim_prefix("foret_")
		var pos := Vector2(e.x + e.get("dx", 0), e.y)
		match kind:
			"sokpe": pos = Vector2(e.x + e.get("dx", 0), e.y - 8)
			"ant", "golem": node.set("start_direction", int(e.dir))
			"firefloor": pos = Vector2(e.x - 8, e.y)
		node.position = pos
		var parent: Node = enemies if kind in ["ant", "bat", "golem", "adan"] else (voices if kind == "voice" else props)
		parent.add_child(node); _own(node, root)
	# Les liens entre nœuds (chemins relatifs, une fois tout le monde en place)
	for item in late:
		var node: Node = item[0]
		var e: Dictionary = item[1]
		match e.kind:
			"puzzle":
				var paths: Array[NodePath] = []
				for d in e.drums:
					paths.append(node.get_path_to(props.get_node(String(d))))
				node.set("drum_paths", paths)
				node.set("gate_path", node.get_path_to(props.get_node(String(e.gate))))
				node.set("bird_path", node.get_path_to(props.get_node(String(e.bird))))
			"adan":
				node.set("fire_floor_path", node.get_path_to(props.get_node("SolBrulant")))
			"arena":
				node.set("adan_path", node.get_path_to(enemies.get_node("Adan")))
				node.set("gate_behind_path", node.get_path_to(props.get_node("PorteArene")))
				node.set("gate_ahead_path", node.get_path_to(props.get_node("PorteCoeur")))
	root.add_child(player); _own(player, root)
	root.set("player", player)

	var front := Node2D.new(); front.name = "DecorFront"; front.z_index = 5
	front.modulate = Color(0.55, 0.6, 0.55)
	root.add_child(front); _own(front, root)
	for s in front_nodes:
		front.add_child(s); _own(s, root)

	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate(); hud.name = "HUD"
	root.add_child(hud); _own(hud, root)
	hud.set("player", player)
	for path in ["res://scenes/ui/touch_controls.tscn", "res://scenes/ui/pause_menu.tscn"]:
		var ui: Node = load(path).instantiate()
		root.add_child(ui); _own(ui, root)
	return root
