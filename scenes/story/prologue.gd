extends Control
## Le prologue de Xɛvioso (nouvelle partie) : « la guerre de la foudre » commence.
##
##   1. Noir. La voix de Xɛvioso dans l'orage : « Je suis la voix qui gronde… »
##   2. L'équilibre d'avant : le village au soleil couchant, jusqu'au sanctuaire où brille la
##      Pierre de foudre, d'où naissent les sokpe, les cartouches du dieu.
##   3. La fêlure : en ombres, un marchand qui triche, un menteur, un voleur. De chaque faute
##      monte une fumée noire ; les fumées s'assemblent dans la forêt. Deux yeux s'ouvrent.
##   4. Le vol : nuit d'orage. Adaka, la Méchanceté, se forme et glisse jusqu'à l'autel. L'éclair
##      le traverse sans le voir. La pierre éclate, les sokpe s'envolent ; il avale les nuages.
##   5. Le monde sans foudre : le couvercle noir veiné de rouge, la terre qui se fend.
##   6. Le signe : la foudre frappe Kodjo, qui se relève, indemne. Le prêtre consulte le Fa :
##      cinq enfants portent la marque du ciel.
##   7. L'appel : devant la hache double, Kodjo et Afi ; le bélier de Xɛvioso dans les nuages,
##      les trois autres Envoyés en vision. Xɛvioso parle. Titre.
##
## Tous les décors sont des peintures en couches (tools/story/prologue_art*.py). Le conteur
## parle dans le bandeau du bas (un toucher affiche la phrase, le suivant passe) ; Xɛvioso dans
## sa boîte. « Passer » reste disponible. Les textes sont dans Voices (PROLOGUE, prologue_*).

## Pour la mise au point : commencer à une scène donnée (1 à 7).
@export_range(1, 7) var start_at: int = 1

const ART := "res://assets/story/prologue/"
const GROUND := 286.0
const PAN := 960.0
const SANCT_X := 1390.0                       # le sanctuaire, dans la couche du village
const STOOL := Vector2(SANCT_X + 40.0, GROUND - 52.0)   # où repose la Pierre de foudre
const AXE_TOP := Vector2(SANCT_X + 40.0, GROUND - 104.0) # le sommet du mât de la hache double
const LAYERS := [["ciel", 0.1], ["collines", 0.3], ["arbres", 0.6], ["village", 1.0], ["premier_plan", 1.45]]
const VILLAGER_ANIMS := {
	&"pound": [0, 6, 7], &"walk_jar": [3, 8, 8], &"garcon_run": [6, 8, 13], &"fille_run": [9, 8, 13],
	&"hoe": [12, 6, 7], &"ancien_idle": [15, 4, 3], &"drum": [18, 4, 8],
	&"pileuse_sad": [2, 4, 2], &"porteuse_sad": [5, 4, 2], &"garcon_sad": [8, 4, 2], &"cultivateur_sad": [14, 4, 2],
}
const ADAKA_ANIMS := [[&"float", 0, 6, 6.0, true], [&"reach", 1, 5, 9.0, false],
	[&"inhale", 2, 6, 5.0, false], [&"gloat", 3, 4, 8.0, true]]
const ADD := preload("res://assets/shaders/silhouette.gdshader")

var _leaving := false
var _time := 0.0
var _cam_x := 0.0
var _ui: CanvasLayer
var _fade: ColorRect
var _flash: ColorRect
var _skip: Button
var _box: DialogueBox
var _tint: CanvasModulate
var _pano := {}                 # "or" / "nuit" -> Node2D (les couches)
var _layer_nodes := {}          # mode -> [[Sprite2D, profondeur], …]
var _village := {}              # mode -> la couche du village (on y pose les personnages)
var _screen: Node2D             # tableaux plein écran (orage, couvercle, terre, Fa)
var _villager_frames: SpriteFrames
var _stone: Node2D
var _axe: Node2D
var _add_mat := CanvasItemMaterial.new()
var _sil_mat: ShaderMaterial

var _caption: PanelContainer
var _caption_label: Label
var _caption_next: Label
var _advance := false
var _hurry := false
var _told := 0
var _hint: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sil_mat = ShaderMaterial.new()
	_sil_mat.shader = ADD
	_tint = CanvasModulate.new()
	add_child(_tint)
	for mode in ["or", "nuit"]:
		_build_panorama(mode)
	_screen = Node2D.new()
	add_child(_screen)
	_build_ui()
	_build_villager_frames()
	_run()


func _process(delta: float) -> void:
	_time += delta
	for mode in _layer_nodes:
		for pair in _layer_nodes[mode]:
			pair[0].position.x = roundf(-_cam_x * pair[1])
	if _stone != null and is_instance_valid(_stone) and _stone.has_meta("hover"):
		_stone.position.y = STOOL.y - 6.0 + 1.5 * sin(_time * 2.0)
		_stone.get_node("Glow").scale = Vector2.ONE * (0.9 + 0.12 * sin(_time * 3.1))


func _run() -> void:
	if start_at <= 1: await _scene_voix()
	if not _leaving and start_at <= 2: await _scene_equilibre()
	if not _leaving and start_at <= 3: await _scene_felure()
	if not _leaving and start_at <= 4: await _scene_vol()
	if not _leaving and start_at <= 5: await _scene_sans_foudre()
	if not _leaving and start_at <= 6: await _scene_signe()
	if not _leaving: await _scene_appel()
	if not _leaving: await _title_card()
	_leave()


# =========================================================================== les scènes

## 1. Noir. La voix dans l'orage.
func _scene_voix() -> void:
	_show_pano("")
	var dark := _full(ART + "orage.png", 0.0)
	var lit := _full(ART + "orage_eclair.png", 0.0)
	Audio.ambience([&"storm_wind"], 3.0)
	await _fade_in(0.1)
	await _pause(1.6)
	Audio.play(&"thunder_far", -4.0)
	await _pause(1.4)
	var lines: Array = Voices.PROLOGUE[&"voix"]
	for i in lines.size():
		if _leaving: return
		_lightning_reveal(dark, lit, 0.45 + 0.2 * i)
		Audio.play(&"thunder_close" if i == lines.size() - 1 else &"thunder_far", -6.0 + 3.0 * i)
		await _big_words(lines[i], 2.6 + i * 0.4)
	await _pause(1.2)
	await _fade_out(1.2)
	dark.queue_free(); lit.queue_free()


## 2. L'équilibre d'avant : le village au soleil couchant, jusqu'au sanctuaire.
func _scene_equilibre() -> void:
	_show_pano("or")
	_cam_x = 0.0
	var v: Node2D = _village["or"]
	_people_at_peace(v)
	_hut_smokes(v, false)
	_rams(v, false)
	_stone = _make_stone(v)
	_stone.set_meta("hover", true)
	_axe = _make_axe(v)
	Audio.ambience([&"village_day"], 2.0)
	Audio.music(&"intro_village", 3.0)
	await _fade_in(2.0)
	var pan := create_tween()
	pan.tween_property(self, "_cam_x", PAN, 26.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tell(Voices.PROLOGUE[&"equilibre"][0])
	await _tell(Voices.PROLOGUE[&"equilibre"][1])
	await _await_tween(pan)
	Audio.play(&"stone_hum", -6.0)
	await _tell(Voices.PROLOGUE[&"equilibre"][2])
	await _pause(1.0)
	await _fade_out(1.4)
	_clear_people(v)


## 3. La fêlure : trois fautes en ombres ; leurs fumées s'assemblent ; deux yeux s'ouvrent.
func _scene_felure() -> void:
	_show_pano("")
	Audio.music(&"intro_drame", 2.0)
	Audio.ambience([&"wind_dry"], 2.0)
	var stage := Node2D.new()
	_screen.add_child(stage)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.36, 0.12, 0.1))
	grad.set_color(1, Color(0.95, 0.55, 0.28))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	gt.width = 4; gt.height = 64
	var bg := TextureRect.new()
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(640, 360)
	stage.add_child(bg)
	var ground_rect := ColorRect.new()
	ground_rect.color = Color(0.05, 0.03, 0.03)
	ground_rect.position = Vector2(0, 268); ground_rect.size = Vector2(640, 92)
	stage.add_child(ground_rect)
	await _fade_in(1.0)
	# a) le marchand triche sur sa balance (son pouce appuie sur le plateau)
	var merchant := _silhouette(stage, &"ancien_idle", Vector2(220, 248))
	var buyer := _silhouette(stage, &"walk_jar", Vector2(330, 248))
	buyer.flip_h = true; buyer.pause()
	var scale_beam := _balance(stage, Vector2(272, 214))
	var smoke1 := _black_smoke(stage, Vector2(250, 214))
	var tilt := create_tween()
	tilt.tween_property(scale_beam, "rotation", -0.22, 1.6).set_trans(Tween.TRANS_SINE)
	await _tell(Voices.PROLOGUE[&"felure"][0])
	# b) le menteur, la main levée pour un faux serment
	for n in [merchant, buyer, scale_beam, scale_beam.get_meta("post")]: n.create_tween().tween_property(n, "modulate:a", 0.0, 0.8)
	var liar := _silhouette(stage, &"ancien_idle", Vector2(300, 248))
	var listener := _silhouette(stage, &"porteuse_sad", Vector2(380, 248))
	listener.flip_h = true
	var smoke2 := _black_smoke(stage, Vector2(306, 206))
	await _pause(2.4)
	# c) le voleur, la nuit, une jarre sous le bras
	for n in [liar, listener]: n.create_tween().tween_property(n, "modulate:a", 0.0, 0.8)
	var night := create_tween()
	night.tween_property(bg, "modulate", Color(0.35, 0.3, 0.5), 1.4)
	var thief := _silhouette(stage, &"walk_jar", Vector2(120, 250))
	thief.speed_scale = 0.6
	thief.create_tween().tween_property(thief, "position:x", 520.0, 6.0)
	var smoke3 := _black_smoke(stage, Vector2(0, 0))
	smoke3.reparent(thief, false); smoke3.position = Vector2(0, -20)
	await _pause(3.0)
	# les fumées dérivent vers la forêt (à droite) et s'assemblent ; deux yeux rouges s'ouvrent
	for sm in [smoke1, smoke2, smoke3]:
		sm.gravity = Vector2(70, -6)
	var mass := _black_smoke(stage, Vector2(560, 180))
	mass.amount = 90; mass.emission_sphere_radius = 40.0; mass.gravity = Vector2(0, -2)
	mass.initial_velocity_max = 6.0; mass.lifetime = 3.0
	await _pause(2.0)
	var eyes := _red_eyes(stage, Vector2(560, 176))
	Audio.play(&"adaka_appear", -6.0)
	await _tell(Voices.PROLOGUE[&"felure"][1])
	await _fade_out(1.2)
	stage.queue_free()


## 4. Le vol : Adaka se forme, l'éclair le traverse, la pierre éclate, il avale les nuages.
func _scene_vol() -> void:
	_show_pano("nuit")
	_cam_x = PAN
	var v: Node2D = _village["nuit"]
	_rams(v, true)
	_stone = _make_stone(v)
	_stone.set_meta("hover", true)
	_axe = _make_axe(v)
	Audio.music(&"intro_drame", 1.0)
	Audio.ambience([&"storm_wind", &"night"], 2.0)
	await _fade_in(1.6)
	_storm_flash(0.35)
	await _tell(Voices.PROLOGUE[&"vol"][0])
	# la forme se rassemble : une fumée noire qui tourbillonne et se densifie
	var form_at := Vector2(SANCT_X - 170.0, GROUND - 70.0)
	var gather := _black_smoke(v, form_at)
	gather.amount = 120; gather.emission_sphere_radius = 70.0; gather.lifetime = 2.2
	gather.gravity = Vector2.ZERO; gather.radial_accel_min = -60.0; gather.radial_accel_max = -40.0
	await _pause(2.2)
	var adaka := _make_adaka()
	adaka.position = form_at
	adaka.modulate = Color(0.55, 0.45, 0.6, 0.0)
	v.add_child(adaka)
	adaka.play(&"float")
	Audio.play(&"adaka_appear", -2.0)
	var appear := adaka.create_tween()
	appear.tween_property(adaka, "modulate:a", 0.82, 1.6)
	await _await_tween(appear)
	gather.emitting = false
	var eyes := _red_eyes(adaka, Vector2(14, -34))
	# il glisse jusqu'à l'autel
	var glide := adaka.create_tween()
	glide.tween_property(adaka, "position", STOOL + Vector2(-46, -20), 4.0).set_trans(Tween.TRANS_SINE)
	await _pause(2.2)
	# l'éclair de Xɛvioso le frappe… et le traverse sans le voir
	var bolt_x: float = adaka.position.x - _cam_x + 4.0
	LightningBolt.strike(_screen, Vector2(bolt_x + 30, -10), Vector2(bolt_x, GROUND + 4), 3.0, 0.5, 4)
	_strike(0.9)
	Audio.play(&"thunder_close", 2.0)
	var ghost := adaka.create_tween()
	ghost.tween_property(adaka, "modulate:a", 0.15, 0.06)
	ghost.tween_property(adaka, "modulate:a", 0.82, 0.5)
	await _tell(Voices.PROLOGUE[&"vol"][1])
	await _await_tween(glide)
	# il arrache la pierre
	adaka.play(&"reach")
	await _pause(0.7)
	_stone.remove_meta("hover")
	var grab := _stone.create_tween()
	grab.tween_property(_stone, "position", adaka.position + Vector2(40, -16), 0.4).set_trans(Tween.TRANS_BACK)
	await _await_tween(grab)
	await _pause(0.6)
	# la pierre éclate : les sokpe s'envolent aux quatre vents
	Audio.play(&"stone_shatter", 0.0)
	_strike(1.0)
	_shatter(_stone.global_position)
	_stone.queue_free()
	await _pause(1.4)
	# il avale les nuages ; le tonnerre s'étrangle
	adaka.play(&"inhale")
	Audio.play(&"adaka_inhale", -1.0)
	_swallow_sky(adaka.global_position + Vector2(14, -24))
	await _tell(Voices.PROLOGUE[&"vol"][2])
	Audio.play(&"wind_stop", -2.0)
	Audio.ambience([], 1.5)
	adaka.play(&"gloat")
	Audio.play(&"adaka_laugh", -4.0)
	await _pause(1.4)
	await _fade_out(1.6)
	_clear_people(v)


## 5. Le monde sans foudre : le couvercle noir, la terre qui se fend.
func _scene_sans_foudre() -> void:
	_show_pano("")
	Audio.music(&"intro_malheurs", 2.0)
	Audio.ambience([&"wind_dry"], 2.0)
	var lid := _full(ART + "couvercle.png", 1.0)
	var veins := _full(ART + "veines.png", 1.0)
	veins.material = _add_mat
	var pulse := veins.create_tween().set_loops()
	pulse.tween_property(veins, "modulate:a", 0.35, 1.3).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(veins, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	var drift := lid.create_tween().set_loops()
	drift.tween_property(lid, "position:x", -60.0, 18.0)
	drift.tween_property(lid, "position:x", 0.0, 18.0)
	veins.reparent(lid, true)
	await _fade_in(1.4)
	await _tell(Voices.PROLOGUE[&"sans_foudre"][0])
	await _fade_out(0.9)
	lid.queue_free()
	var earth := _full(ART + "terre_craquelee.png", 1.0)
	var push := earth.create_tween()
	push.tween_property(earth, "scale", Vector2(1.08, 1.08), 9.0)
	push.parallel().tween_property(earth, "position", Vector2(-24, -14), 9.0)
	await _fade_in(1.0)
	Audio.play(&"crumble_crack", -6.0)
	await _tell(Voices.PROLOGUE[&"sans_foudre"][1])
	await _fade_out(0.8)
	earth.queue_free()
	await _big_words(Voices.PROLOGUE[&"carton"][0], 3.6, 18)
	await _pause(0.6)


## 6. Le signe : la foudre frappe Kodjo ; il se relève. Le prêtre consulte le Fa.
func _scene_signe() -> void:
	_show_pano("nuit")
	_cam_x = 120.0
	var v: Node2D = _village["nuit"]
	Audio.music(&"intro_appel", 2.0)
	Audio.ambience([&"storm_wind"], 2.0)
	var kodjo := _hero(v, "kodjo", Vector2(330, GROUND - 20))
	var kids: Array = []
	for i in 3:
		var w := _villager(v, [&"garcon_sad", &"pileuse_sad", &"porteuse_sad"][i], Vector2(470 + i * 26, GROUND - 19))
		w.flip_h = true
		kids.append(w)
	await _fade_in(1.4)
	_storm_flash(0.3)
	await _tell(Voices.PROLOGUE[&"signe"][0])
	await _pause(0.8)
	# la foudre tombe sur l'enfant
	var kx: float = kodjo.position.x - _cam_x
	LightningBolt.strike(_screen, Vector2(kx - 40, -10), Vector2(kx, GROUND - 30), 4.0, 0.6, 6)
	_strike(1.0)
	Audio.play(&"thunder_close", 4.0)
	_shake(6.0, 0.6)
	kodjo.play(&"hurt")
	for w in kids:
		w.create_tween().tween_property(w, "position:x", w.position.x + 40.0, 0.5)
	await _pause(1.6)
	kodjo.play(&"crouch")
	await _pause(1.2)
	# il se relève, indemne ; la lumière du ciel passe dans ses yeux
	kodjo.play(&"idle")
	var glow := _glow_on(kodjo, Vector2(2, -14), Color(0.7, 0.85, 1.0), 0.5)
	Audio.play(&"designate", -2.0)
	await _tell(Voices.PROLOGUE[&"signe"][1])
	await _fade_out(1.0)
	_clear_people(v)
	# le Fa : la natte, le chapelet, la lampe qui vacille ; les cinq signes paraissent
	var fa := _full(ART + "fa.png", 1.0)
	var flame := _flame(Vector2(558, 126))
	await _fade_in(1.0)
	await _tell(Voices.PROLOGUE[&"signe"][2])
	var heroes := ["kodjo", "afi", "kokou", "yawa", "abla"]
	var marks: Array = []
	for i in heroes.size():
		var m := _vision(heroes[i], Vector2(140 + i * 90, 190), i >= 2)
		m.modulate.a = 0.0
		marks.append(m)
		Audio.play(&"sokpe", -6.0 + i)
		var show := m.create_tween()
		show.tween_property(m, "modulate:a", 1.0, 0.6)
		await _await_tween(show)
		await _pause(0.25)
	await _tell(Voices.PROLOGUE[&"signe"][3])
	await _fade_out(1.0)
	fa.queue_free(); flame.queue_free()
	for m in marks: m.queue_free()


## 7. L'appel : devant la hache double, Kodjo et Afi ; le bélier dans les nuages ; Xɛvioso parle.
func _scene_appel() -> void:
	_show_pano("nuit")
	_cam_x = PAN
	var v: Node2D = _village["nuit"]
	_axe = _make_axe(v)
	var priest := _villager_sprite(v, ART + "pretre.png", Vector2(SANCT_X - 10, GROUND - 19))
	var kodjo := _hero(v, "kodjo", Vector2(SANCT_X - 64, GROUND - 20))
	var afi := _hero(v, "afi", Vector2(SANCT_X - 92, GROUND - 20))
	_glow_on(kodjo, Vector2(2, -14), Color(0.7, 0.85, 1.0), 0.35)
	Audio.ambience([&"storm_wind"], 2.0)
	await _fade_in(1.4)
	# le bélier de Xɛvioso se dessine dans les nuages, à la lueur des éclairs
	var ram := Sprite2D.new()
	ram.texture = load(ART + "belier_nuage.png")
	ram.position = Vector2(170, 92)
	ram.scale = Vector2(0.55, 0.55)
	ram.modulate.a = 0.0
	_screen.add_child(ram)
	for i in 3:
		_storm_flash(0.25 + 0.15 * i)
		var t := ram.create_tween()
		t.tween_property(ram, "modulate:a", 0.95, 0.08)
		t.tween_property(ram, "modulate:a", 0.2 + 0.1 * i, 0.9)
		await _pause(1.1)
	Audio.play(&"emblem_appear", 0.0)
	# l'emblème s'embrase au-dessus de la hache
	var emblem := _emblem(Vector2(480, 76))
	# les trois autres Envoyés, en vision, au loin
	var visions: Array = []
	for i in 3:
		var vis := _vision(["kokou", "yawa", "abla"][i], Vector2(392 + i * 88, 186 + (i % 2) * 8), true)
		vis.modulate.a = 0.0
		vis.create_tween().tween_property(vis, "modulate:a", 0.7, 1.4)
		visions.append(vis)
	await _xevioso(&"prologue_appel")
	await _pause(0.6)
	await _fade_out(1.2)
	ram.queue_free(); emblem.queue_free()
	for vv in visions: vv.queue_free()
	_clear_people(v)


func _title_card() -> void:
	_show_pano("")
	var holder := Node2D.new()
	_screen.add_child(holder)
	var em := Sprite2D.new()
	em.texture = preload("res://assets/ui/xevioso/emblem.png")
	em.position = Vector2(320, 120)
	holder.add_child(em)
	var g := Sprite2D.new()
	g.texture = preload("res://assets/ui/xevioso/emblem_glow.png")
	g.material = _add_mat
	g.position = em.position
	holder.add_child(g)
	var title := _label("Xɛvioso", 34, Color(1.0, 0.92, 0.76))
	title.position = Vector2(0, 168); title.size = Vector2(640, 40)
	holder.add_child(title)
	var sub := _label("Les Envoyés de la foudre", 13, Color(0.86, 0.64, 0.32))
	sub.position = Vector2(0, 212); sub.size = Vector2(640, 20)
	holder.add_child(sub)
	_strike(1.0)
	Audio.play(&"thunder_close", 0.0)
	await _fade_in(0.6)
	await _pause(3.4)


# =========================================================================== décors

func _build_panorama(mode: String) -> void:
	var root := Node2D.new()
	root.visible = false
	add_child(root)
	var list := []
	for spec in LAYERS:
		var s := Sprite2D.new()
		s.texture = load(ART + "%s_%s.png" % [spec[0], mode])
		s.centered = false
		root.add_child(s)
		list.append([s, spec[1]])
		if spec[0] == "village":
			_village[mode] = s
	_pano[mode] = root
	_layer_nodes[mode] = list


## La nuit, on éclaircit un peu la peinture (sinon tout se perd dans le noir à l'écran).
func _base_tint(mode: String) -> Color:
	return Color(1.35, 1.32, 1.45) if mode == "nuit" else Color.WHITE


func _show_pano(mode: String) -> void:
	for m in _pano:
		_pano[m].visible = (m == mode)
	_tint.color = _base_tint(mode)


## Un tableau plein écran (orage, couvercle, terre craquelée, Fa).
func _full(path: String, alpha: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.modulate.a = alpha
	_screen.add_child(s)
	return s


func _lightning_reveal(dark: Sprite2D, lit: Sprite2D, strength: float) -> void:
	var t := create_tween()
	t.tween_property(dark, "modulate:a", 1.0, 0.05)
	t.parallel().tween_property(lit, "modulate:a", strength + 0.3, 0.05)
	t.tween_property(lit, "modulate:a", 0.0, 0.5)
	t.parallel().tween_property(dark, "modulate:a", 0.35, 1.6)
	_strike(strength * 0.5)


func _storm_flash(strength: float) -> void:
	_strike(strength)
	Audio.play(&"thunder_far", -6.0)
	var t := create_tween()
	t.tween_property(_tint, "color", Color(1.6, 1.6, 1.9), 0.05)
	t.tween_property(_tint, "color", _base_tint("nuit"), 0.6)


func _hut_smokes(v: Node2D, dry: bool) -> void:
	for x in [395.0, 610.0, 800.0, 1050.0, SANCT_X - 55.0]:
		var p := CPUParticles2D.new()
		p.amount = 14
		p.lifetime = 4.5
		p.position = Vector2(x, GROUND - 46.0)
		p.direction = Vector2(0, -1)
		p.spread = 12.0
		p.gravity = Vector2(-6, -4)
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 11.0
		p.texture = Fx.light_texture()
		p.scale_amount_min = 0.05
		p.scale_amount_max = 0.11
		var g := Gradient.new()
		g.set_color(0, Color(0.9, 0.82, 0.72, 0.35))
		g.set_color(1, Color(0.7, 0.6, 0.6, 0.0))
		p.color_ramp = g
		v.add_child(p)
		v.set_meta("fx", v.get_meta("fx", []) + [p])


func _rams(v: Node2D, night: bool) -> void:
	var sheet: Texture2D = load(ART + "belier.png")
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"graze")
	frames.set_animation_speed(&"graze", 1.6)
	for c in [0, 1, 0, 1, 2, 3]:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(c * 24, 0, 24, 20)
		frames.add_frame(&"graze", at)
	for i in 3:
		var r := AnimatedSprite2D.new()
		r.sprite_frames = frames
		r.play(&"graze")
		r.frame = i * 2
		r.position = Vector2(SANCT_X - 190.0 + i * 34.0, GROUND - 9.0 + (i % 2))
		r.flip_h = i == 1
		if night:
			r.modulate = Color(0.45, 0.45, 0.6)
		v.add_child(r)
		v.set_meta("fx", v.get_meta("fx", []) + [r])


func _make_stone(v: Node2D) -> Node2D:
	var stone := Node2D.new()
	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = preload("res://assets/story/thunder_glow.png")
	glow.material = _add_mat
	stone.add_child(glow)
	var body := Sprite2D.new()
	body.texture = preload("res://assets/story/thunder_stone.png")
	stone.add_child(body)
	stone.position = STOOL + Vector2(0, -6)
	v.add_child(stone)
	v.set_meta("fx", v.get_meta("fx", []) + [stone])
	return stone


## La hache double de Xɛvioso, au sommet de son mât (elle luit doucement).
func _make_axe(v: Node2D) -> Node2D:
	var holder := Node2D.new()
	holder.position = AXE_TOP
	var axe := Sprite2D.new()
	axe.texture = preload("res://assets/ui/xevioso/emblem_small.png")
	axe.scale = Vector2(1.6, 1.6)
	holder.add_child(axe)
	v.add_child(holder)
	v.set_meta("fx", v.get_meta("fx", []) + [holder])
	return holder


func _clear_people(v: Node2D) -> void:
	for n in v.get_meta("fx", []):
		if is_instance_valid(n):
			n.queue_free()
	v.set_meta("fx", [])
	for c in v.get_children():
		c.queue_free()


# =========================================================================== personnages

func _build_villager_frames() -> void:
	var sheet: Texture2D = load("res://assets/story/villagers.png")
	_villager_frames = SpriteFrames.new()
	_villager_frames.remove_animation(&"default")
	for anim in VILLAGER_ANIMS:
		var spec: Array = VILLAGER_ANIMS[anim]
		_villager_frames.add_animation(anim)
		_villager_frames.set_animation_speed(anim, spec[2])
		for c in spec[1]:
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(c * 40, spec[0] * 60, 40, 60)
			_villager_frames.add_frame(anim, region)


func _villager(parent: Node2D, anim: StringName, at: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _villager_frames
	s.position = at
	s.play(anim)
	s.frame = randi() % _villager_frames.get_frame_count(anim)
	parent.add_child(s)
	return s


func _villager_sprite(parent: Node2D, path: String, at: Vector2) -> AnimatedSprite2D:
	var sheet: Texture2D = load(path)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 3.0)
	for c in 4:
		var region := AtlasTexture.new()
		region.atlas = sheet
		region.region = Rect2(c * 40, 0, 40, 60)
		frames.add_frame(&"idle", region)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.position = at
	s.play(&"idle")
	parent.add_child(s)
	return s


func _people_at_peace(v: Node2D) -> void:
	_villager(v, &"hoe", Vector2(150, GROUND - 19))
	_villager(v, &"hoe", Vector2(260, GROUND - 19)).flip_h = true
	_villager(v, &"pound", Vector2(560, GROUND - 19))
	var porteuse := _villager(v, &"walk_jar", Vector2(640, GROUND - 19))
	porteuse.create_tween().tween_property(porteuse, "position:x", 980.0, 22.0)
	_villager(v, &"drum", Vector2(860, GROUND - 19))
	var kids := [_villager(v, &"garcon_run", Vector2(700, GROUND - 19)), _villager(v, &"fille_run", Vector2(730, GROUND - 19))]
	for k: AnimatedSprite2D in kids:
		var t: Tween = k.create_tween().set_loops()
		t.tween_property(k, "position:x", k.position.x + 140.0, 3.0)
		t.tween_callback(func() -> void: k.flip_h = true)
		t.tween_property(k, "position:x", k.position.x, 3.0)
		t.tween_callback(func() -> void: k.flip_h = false)
	_villager_sprite(v, ART + "pretre.png", Vector2(SANCT_X - 10, GROUND - 19))


func _hero(parent: Node2D, name: String, at: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = load("res://assets/heroes/%s/%s_frames.tres" % [name, name])
	s.position = at
	s.play(&"idle")
	parent.add_child(s)
	return s


func _make_adaka() -> AnimatedSprite2D:
	var sheet: Texture2D = preload("res://assets/story/adaka.png")
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in ADAKA_ANIMS:
		frames.add_animation(anim[0])
		frames.set_animation_speed(anim[0], anim[3])
		frames.set_animation_loop(anim[0], anim[4])
		for c in anim[2]:
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(c * 96, anim[1] * 128, 96, 128)
			frames.add_frame(anim[0], region)
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	return a


## Une silhouette noire (théâtre d'ombres) d'un villageois.
func _silhouette(parent: Node, anim: StringName, at: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _villager_frames
	s.position = at
	s.scale = Vector2(1.4, 1.4)
	s.play(anim)
	s.modulate = Color(0.02, 0.01, 0.01)
	parent.add_child(s)
	return s


## La balance du marchand : un fléau et deux plateaux, en ombre.
func _balance(parent: Node, at: Vector2) -> Node2D:
	var pivot := Node2D.new()
	pivot.position = at
	parent.add_child(pivot)
	var post := Line2D.new()
	post.points = PackedVector2Array([Vector2(0, 0), Vector2(0, 34)])
	post.width = 2.0
	post.default_color = Color(0.02, 0.01, 0.01)
	parent.add_child(post)
	post.position = at
	pivot.set_meta("post", post)
	var beam := Line2D.new()
	beam.points = PackedVector2Array([Vector2(-26, 0), Vector2(26, 0)])
	beam.width = 2.0
	beam.default_color = Color(0.02, 0.01, 0.01)
	pivot.add_child(beam)
	for side in [-1, 1]:
		var pan := Polygon2D.new()
		pan.polygon = PackedVector2Array([Vector2(-8, 12), Vector2(8, 12), Vector2(5, 15), Vector2(-5, 15)])
		pan.color = Color(0.02, 0.01, 0.01)
		pan.position = Vector2(26 * side, 0)
		var cord := Line2D.new()
		cord.points = PackedVector2Array([Vector2(0, 0), Vector2(-7, 12), Vector2(0, 0), Vector2(7, 12)])
		cord.width = 1.0
		cord.default_color = Color(0.02, 0.01, 0.01)
		pan.add_child(cord)
		pivot.add_child(pan)
	return pivot


## La fumée noire d'une faute : elle monte, puis dérive.
func _black_smoke(parent: Node, at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 3.2
	p.position = at
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 4.0
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(4, -10)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 16.0
	p.texture = Fx.light_texture()
	p.scale_amount_min = 0.09
	p.scale_amount_max = 0.2
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.02, 0.04, 0.0))
	g.set_color(1, Color(0.05, 0.02, 0.04, 0.0))
	g.add_point(0.15, Color(0.06, 0.02, 0.05, 0.85))
	g.add_point(0.7, Color(0.1, 0.04, 0.08, 0.5))
	p.color_ramp = g
	parent.add_child(p)
	return p


func _red_eyes(parent: Node, at: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.position = at
	for dx in [-5.0, 5.0]:
		var e := Sprite2D.new()
		e.texture = Fx.light_texture()
		e.scale = Vector2(0.05, 0.03)
		e.modulate = Color(1.0, 0.15, 0.05)
		e.material = _add_mat
		e.position = Vector2(dx, 0)
		holder.add_child(e)
		var dot := ColorRect.new()
		dot.color = Color(1.0, 0.4, 0.2)
		dot.size = Vector2(2, 1)
		dot.position = Vector2(dx - 1, 0)
		holder.add_child(dot)
	holder.scale = Vector2(1, 0.1)
	parent.add_child(holder)
	holder.create_tween().tween_property(holder, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK)
	return holder


func _glow_on(parent: Node2D, at: Vector2, color: Color, energy: float) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = Fx.light_texture()
	g.scale = Vector2(0.18, 0.18)
	g.modulate = Color(color.r, color.g, color.b, energy)
	g.material = _add_mat
	g.position = at
	parent.add_child(g)
	var t := g.create_tween().set_loops()
	t.tween_property(g, "modulate:a", energy * 0.5, 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(g, "modulate:a", energy, 1.1).set_trans(Tween.TRANS_SINE)
	return g


## Un Envoyé « vu » par le Fa ou en vision : une silhouette de lumière.
func _vision(name: String, at: Vector2, far: bool) -> Node2D:
	var holder := Node2D.new()
	holder.position = at
	var glow := Sprite2D.new()
	glow.texture = Fx.light_texture()
	glow.scale = Vector2(0.5, 0.5)
	glow.modulate = Color(0.6, 0.75, 1.0, 0.45)
	glow.material = _add_mat
	holder.add_child(glow)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = load("res://assets/heroes/%s/%s_frames.tres" % [name, name])
	s.play(&"idle")
	s.modulate = Color(0.75, 0.85, 1.0, 0.9) if not far else Color(0.45, 0.55, 0.85, 0.75)
	holder.add_child(s)
	_screen.add_child(holder)
	return holder


func _emblem(at: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.position = at
	var g := Sprite2D.new()
	g.texture = preload("res://assets/ui/xevioso/emblem_glow.png")
	g.material = _add_mat
	holder.add_child(g)
	var e := Sprite2D.new()
	e.texture = preload("res://assets/ui/xevioso/emblem.png")
	holder.add_child(e)
	holder.scale = Vector2.ZERO
	_screen.add_child(holder)
	holder.create_tween().tween_property(holder, "scale", Vector2(0.8, 0.8), 0.8).set_trans(Tween.TRANS_BACK)
	_strike(0.8)
	return holder


func _flame(at: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.position = at
	var g := Sprite2D.new()
	g.texture = Fx.light_texture()
	g.scale = Vector2(0.7, 0.7)
	g.modulate = Color(1.0, 0.7, 0.35, 0.55)
	g.material = _add_mat
	holder.add_child(g)
	var f := Polygon2D.new()
	f.polygon = PackedVector2Array([Vector2(0, -10), Vector2(3, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(-3, -2)])
	f.color = Color(1.0, 0.85, 0.45)
	holder.add_child(f)
	_screen.add_child(holder)
	var t := holder.create_tween().set_loops()
	t.tween_property(f, "scale", Vector2(0.85, 1.2), 0.18)
	t.parallel().tween_property(g, "modulate:a", 0.45, 0.18)
	t.tween_property(f, "scale", Vector2(1.1, 0.9), 0.22)
	t.parallel().tween_property(g, "modulate:a", 0.6, 0.22)
	return holder


func _shatter(at: Vector2) -> void:
	# quatre éclats partent vers les quatre vents, avec une traînée ; d'autres, plus petits, suivent
	var dirs := [Vector2(-1, -0.6), Vector2(1, -0.7), Vector2(-1, 0.2), Vector2(1, 0.1)]
	for i in 12:
		var shard := Sprite2D.new()
		shard.texture = preload("res://assets/props/sokpe.png")
		shard.position = at
		shard.scale = Vector2.ONE * (1.0 if i < 4 else 0.6)
		_screen.add_child(shard)
		var trail := _glow_on(shard, Vector2.ZERO, Color(0.6, 0.8, 1.0), 0.6)
		var d: Vector2 = dirs[i % 4].rotated(randf_range(-0.25, 0.25))
		var target: Vector2 = at + d.normalized() * randf_range(420.0, 620.0)
		var t := shard.create_tween().set_parallel(true)
		t.tween_property(shard, "position", target, randf_range(1.0, 1.6)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(shard, "rotation", randf_range(-9.0, 9.0), 1.6)
		t.chain().tween_callback(shard.queue_free)


## Les nuages du ciel nocturne sont aspirés dans la gueule d'Adaka.
func _swallow_sky(mouth: Vector2) -> void:
	var sky: Sprite2D = _layer_nodes["nuit"][0][0]
	var tex: Texture2D = load(ART + "orage.png")
	for i in 5:
		var c := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 150, 20, 150, 110)
		c.texture = at
		c.position = Vector2(60 + i * 130, 60 + (i % 2) * 20)
		c.modulate = Color(0.9, 0.9, 1.1, 0.0)
		_screen.add_child(c)
		var t := c.create_tween()
		t.tween_property(c, "modulate:a", 0.85, 0.4)
		t.tween_property(c, "position", mouth, 2.0 + i * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(c, "scale", Vector2(0.03, 0.03), 2.0 + i * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(c.queue_free)
	# le ciel s'éteint : plus aucun nuage, plus aucun éclair
	sky.create_tween().tween_property(sky, "modulate", Color(0.35, 0.3, 0.35), 3.0)


# =========================================================================== interface

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_flash)
	_build_caption()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)
	_skip = Button.new()
	_skip.text = "Passer ▶"
	_skip.add_theme_font_size_override("font_size", 10)
	_skip.anchor_left = 1.0; _skip.anchor_right = 1.0
	_skip.offset_left = -84; _skip.offset_right = -10; _skip.offset_top = 8; _skip.offset_bottom = 32
	_skip.pressed.connect(_leave)
	_ui.add_child(_skip)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	return l


## De grandes paroles au milieu de l'écran (la voix, le carton), qui paraissent et s'effacent.
func _big_words(text: String, hold: float, size: int = 15) -> void:
	if _leaving:
		return
	var l := _label(text, size, Color(1.0, 0.93, 0.8))
	l.size = Vector2(600, 60)
	l.position = Vector2(20, 150)
	l.modulate.a = 0.0
	_ui.add_child(l)
	_ui.move_child(l, _fade.get_index() + 1)
	await create_tween().tween_property(l, "modulate:a", 1.0, 0.9).finished
	await _pause(hold)
	await create_tween().tween_property(l, "modulate:a", 0.0, 0.9).finished
	l.queue_free()


func _build_caption() -> void:
	_caption = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.07, 0.8)
	style.border_color = Color(0.85, 0.66, 0.32, 0.85)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 16; style.content_margin_right = 16
	style.content_margin_top = 6; style.content_margin_bottom = 6
	_caption.add_theme_stylebox_override("panel", style)
	_caption.anchor_left = 0.0; _caption.anchor_right = 1.0
	_caption.anchor_top = 1.0; _caption.anchor_bottom = 1.0
	_caption.offset_left = 40; _caption.offset_right = -40
	_caption.offset_top = -64; _caption.offset_bottom = -8
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_label = Label.new()
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_label.add_theme_font_size_override("font_size", 11)
	_caption_label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.8))
	_caption_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_caption_label.add_theme_constant_override("outline_size", 2)
	_caption.add_child(_caption_label)
	_caption.visible = false
	_ui.add_child(_caption)
	_caption_next = Label.new()
	_caption_next.text = "▼"
	_caption_next.add_theme_font_size_override("font_size", 8)
	_caption_next.add_theme_color_override("font_color", Color(0.85, 0.66, 0.32))
	_caption_next.anchor_left = 1.0; _caption_next.anchor_right = 1.0
	_caption_next.anchor_top = 1.0; _caption_next.anchor_bottom = 1.0
	_caption_next.offset_left = -54; _caption_next.offset_top = -22
	_caption_next.offset_right = -44; _caption_next.offset_bottom = -10
	_caption_next.visible = false
	_ui.add_child(_caption_next)
	_hint = Label.new()
	_hint.text = "Touchez l'écran pour avancer" if DisplayServer.is_touchscreen_available() else "Une touche ou un clic pour avancer"
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.66, 0.32, 0.85))
	_hint.anchor_left = 1.0; _hint.anchor_right = 1.0; _hint.anchor_top = 1.0; _hint.anchor_bottom = 1.0
	_hint.offset_left = -240; _hint.offset_right = -60; _hint.offset_top = -21; _hint.offset_bottom = -9
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.visible = false
	_ui.add_child(_hint)


## Le conteur dit une phrase, lentement, puis laisse le temps de la lire.
func _tell(text: String) -> void:
	if _leaving:
		return
	_caption.visible = true
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.4)
	_caption_label.text = text
	_caption_label.visible_ratio = 0.0
	_caption_next.visible = false
	_hint.visible = _told < 2
	_told += 1
	_advance = false
	var shown := 0.0
	while shown < 1.0 and not _leaving:
		await get_tree().process_frame
		if _advance:
			break
		shown += get_process_delta_time() * 24.0 / text.length()
		_caption_label.visible_ratio = shown
	_caption_label.visible_ratio = 1.0
	_advance = false
	_caption_next.visible = true
	var reading: float = clampf(1.6 + text.length() * 0.05, 4.0, 9.0)
	var waited := 0.0
	while waited < reading and not _advance and not _leaving:
		await get_tree().process_frame
		waited += get_process_delta_time()
		_caption_next.modulate.a = 0.5 + 0.5 * sin(_time * 5.0)
	_advance = false
	_caption_next.visible = false
	_hint.visible = false
	if _leaving:
		return
	await create_tween().tween_property(_caption, "modulate:a", 0.0, 0.35).finished
	_caption.visible = false
	await _pause(0.4)


func _xevioso(key: StringName) -> void:
	if _leaving:
		return
	if _box == null:
		_box = preload("res://scenes/ui/dialogue_box.tscn").instantiate()
		_box.chars_per_second = 24.0
		add_child(_box)
	_skip.offset_top = 330; _skip.offset_bottom = 354      # « Passer » descend : la boîte est en haut
	await _box.play(Voices.lines(key), false)
	_skip.offset_top = 8; _skip.offset_bottom = 32


func _input(event: InputEvent) -> void:
	if _caption == null or _leaving or (_box != null and _box._panel.visible):
		return
	var pressed := false
	var where := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		pressed = true; where = event.position
	elif event is InputEventMouseButton and event.pressed:
		pressed = event.device != InputEvent.DEVICE_ID_EMULATION; where = event.position
	elif event is InputEventKey and event.pressed and not event.echo:
		pressed = event.physical_keycode != KEY_ESCAPE
	elif event is InputEventJoypadButton and event.pressed:
		pressed = true
	if not pressed:
		return
	if where.x >= 0.0 and _skip.get_global_rect().has_point(where):
		return
	if not _caption.visible:
		_hurry = true
		return
	_advance = true
	Audio.play(&"caption_next")
	get_viewport().set_input_as_handled()


func _pause(seconds: float) -> void:
	if _leaving:
		return
	_hurry = false
	var waited := 0.0
	while waited < seconds and not _hurry and not _leaving:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _await_tween(tween: Tween) -> void:
	_hurry = false
	while tween != null and tween.is_valid() and tween.is_running() and not _leaving:
		if _hurry:
			tween.set_speed_scale(4.0)
		await get_tree().process_frame


func _fade_in(duration: float = 1.0) -> void:
	await create_tween().tween_property(_fade, "color:a", 0.0, duration).finished


func _fade_out(duration: float = 1.0) -> void:
	await create_tween().tween_property(_fade, "color:a", 1.0, duration).finished
	_caption.visible = false


func _strike(strength: float) -> void:
	_flash.color.a = strength
	create_tween().tween_property(_flash, "color:a", 0.0, 0.4)


func _shake(strength: float, duration: float) -> void:
	var t := create_tween()
	var steps := int(duration / 0.04)
	for i in steps:
		var k: float = 1.0 - float(i) / steps
		t.tween_property(self, "position", (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k).round(), 0.04)
	t.tween_property(self, "position", Vector2.ZERO, 0.04)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_skip.disabled = true
	if _box != null:
		_box.queue_free()
		_box = null
	_strike(1.0)
	Audio.play(&"thunder_close", -3.0)
	Audio.stop_music(1.0)
	Audio.ambience([], 1.0)
	await create_tween().tween_property(_fade, "color:a", 1.0, 1.0).finished
	Game.go_to_level(Game.FIRST_LEVEL)
