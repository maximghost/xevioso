extends SceneTree
## Outil temporaire : construit le TileSet de la forêt, les images de la fourmi et la scène
## du niveau 2 à partir du tracé (_foret_1.json, produit et vérifié par layout_foret.py).

const TILE := 16

func _initialize() -> void:
	# --- la fourmi corrompue ---
	var frames := SpriteFrames.new()
	frames.rename_animation(&"default", &"walk")
	frames.set_animation_speed(&"walk", 9.0)
	var sheet: Texture2D = load("res://assets/enemies/ant/ant.png")
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 24, 0, 24, 20)
		frames.add_frame(&"walk", at)
	ResourceSaver.save(frames, "res://assets/enemies/ant/ant_frames.tres")
	var ant: Node = load("res://scenes/enemies/crawler/crawler.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	ant.name = "Ant"
	ant.set("speed", 50.0)
	ant.set("dust_color", Color(0.55, 0.52, 0.48))
	ant.get_node("Sprite").sprite_frames = load("res://assets/enemies/ant/ant_frames.tres")
	var ps := PackedScene.new()
	ps.pack(ant)
	print("ant: ", error_string(ResourceSaver.save(ps, "res://scenes/enemies/ant/ant.tscn")))
	# --- le jeu de tuiles ---
	ResourceSaver.save(_build_tileset(), "res://assets/tiles/forest_tileset.tres")
	var tileset: TileSet = load("res://assets/tiles/forest_tileset.tres")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://_foret_1.json"))
	var root := _build_level(data, tileset)
	var packed := PackedScene.new()
	print("pack: ", error_string(packed.pack(root)))
	print("save: ", error_string(ResourceSaver.save(packed, "res://scenes/levels/foret/foret_1.tscn")))
	quit()


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
			var td := src.get_tile_data(c, 0)
			if row == 3 and col == 5:
				continue
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, plank if (row == 3 and col >= 2) else full)
	return ts


func _own(node: Node, root: Node) -> void:
	node.owner = root


func _scripted(base: Node, path: String) -> Node:
	base.set_script(load(path))
	return base


func _build_level(data: Dictionary, tileset: TileSet) -> Node2D:
	var root := Node2D.new()
	root.name = "Foret1"
	root.set_script(load("res://scenes/levels/level.gd"))
	root.set("level_id", &"foret_1")
	root.set("use_weather", false)
	root.set("green_tiles", load("res://assets/tiles/forest_tiles_green.png"))
	root.set("dry_color", Color(0.86, 0.88, 0.86))
	root.set("rain_color", Color(1.0, 1.04, 0.98))
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

	var bg := Node2D.new(); bg.name = "Background"; root.add_child(bg); _own(bg, root)
	for layer in [["Sky", "bg_sky", 0.0, 0], ["Far", "bg_far", 0.12, -26], ["Mid", "bg_mid", 0.3, -34], ["Near", "bg_near", 0.5, -44]]:
		var p := Parallax2D.new()
		p.name = layer[0]
		p.scroll_scale = Vector2(layer[2], 0.0)
		p.repeat_size = Vector2(640, 0)
		p.repeat_times = 3
		bg.add_child(p); _own(p, root)
		var s := Sprite2D.new()
		s.name = "Image"
		s.centered = false
		s.texture = load("res://assets/backgrounds/foret/%s.png" % layer[1])
		s.position = Vector2(0, layer[3])
		p.add_child(s); _own(s, root)

	var back := Node2D.new(); back.name = "DecorBack"; root.add_child(back); _own(back, root)
	var front_nodes := []
	var counts := {}
	for d in data.decor:
		var s := Sprite2D.new()
		counts[d.name] = counts.get(d.name, 0) + 1
		s.name = "%s%d" % [String(d.name).capitalize().replace(" ", ""), counts[d.name]]
		s.texture = load("res://assets/decor/foret/%s.png" % d.name)
		s.position = Vector2(d.x, d.y + 2 - s.texture.get_height() / 2.0)
		if d.front:
			front_nodes.append(s)
		else:
			back.add_child(s); _own(s, root)

	var tb := TileMapLayer.new(); tb.name = "TerrainBack"; tb.tile_set = tileset
	root.add_child(tb); _own(tb, root)
	for c in data.back:
		tb.set_cell(Vector2i(c[0], c[1]), 0, Vector2i(5, 3))
	var tm := TileMapLayer.new(); tm.name = "Terrain"; tm.tile_set = tileset
	root.add_child(tm); _own(tm, root)
	for c in data.cells:
		tm.set_cell(Vector2i(c[0], c[1]), 0, Vector2i(c[2], c[3]))
	root.set("terrain", tm)

	var props := Node2D.new(); props.name = "Props"; root.add_child(props); _own(props, root)
	var enemies := Node2D.new(); enemies.name = "Enemies"; root.add_child(enemies); _own(enemies, root)
	var voices := Node2D.new(); voices.name = "Voices"; root.add_child(voices); _own(voices, root)
	var scenes := {
		"checkpoint": load("res://scenes/props/checkpoint.tscn"),
		"sokpe": load("res://scenes/props/sokpe_stone.tscn"),
		"ant": load("res://scenes/enemies/ant/ant.tscn"),
		"end": load("res://scenes/props/end_shrine.tscn"),
	}
	var player: Node2D
	var n := {}
	for e in data.entities:
		var kind: String = e.kind
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
				node.set("length", float(e.length))
				node.set("amplitude", float(e.amplitude))
				node.set("period", float(e.period))
				node.set("phase", float(e.phase))
			"voice":
				node = _scripted(Area2D.new(), "res://scenes/props/voice_trigger.gd")
				node.set("voice_id", StringName(e.id))
			_:
				node = scenes[kind].instantiate()
		n[kind] = n.get(kind, 0) + 1
		node.name = e.get("name", "%s%d" % [kind.capitalize(), n[kind]])
		if kind == "voice":
			node.name = "Voix_" + String(e.id).trim_prefix("foret_")
		var pos := Vector2(e.x + e.get("dx", 0), e.y)
		match kind:
			"sokpe": pos = Vector2(e.x + e.get("dx", 0), e.y - 8)
			"ant": node.set("start_direction", int(e.dir))
		node.position = pos
		var parent: Node = enemies if kind in ["ant"] else (voices if kind == "voice" else props)
		parent.add_child(node); _own(node, root)
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
