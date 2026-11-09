extends Control
## Scène d'ouverture (nouvelle partie) : l'histoire, en cinq tableaux.
##
##   1. Avant        : le village vert, sous une pluie de saison. Le conteur pose le cadre.
##   2. Le sanctuaire, la nuit : la Pierre de foudre, don de Xɛvioso, flotte au-dessus de l'autel.
##   3. Le vol       : Adaka, le Mangeur de pluie, glisse jusqu'à l'autel et arrache la pierre,
##                     qui se brise en éclats (les sokpe) ; puis il avale les nuages et s'efface.
##   4. Les malheurs : le même village, desséché, sous la poussière.
##   5. L'appel      : nuit d'orage ; la foudre frappe, l'emblème de Xɛvioso apparaît ; sa voix
##                     désigne Kodjo et Afi et donne la première étape : ramener la pluie.
##
## Le conteur parle dans un bandeau en bas de l'écran (le texte s'écrit ; toucher, Entrée ou
## Saut pour avancer ; il avance seul après un temps de lecture). « Passer » reste disponible.
## Les textes sont dans Voices (STORY pour le conteur, « intro » pour Xɛvioso).

const GROUND_Y := 302.0
const DECOR := "res://assets/decor/village/"
const NIGHT := Color(0.34, 0.36, 0.52)

@onready var _night: Node2D = $Night
@onready var _storm: Node2D = $Storm
@onready var _emblem: Node2D = $Emblem
@onready var _kodjo: AnimatedSprite2D = $Kodjo
@onready var _afi: AnimatedSprite2D = $Afi
@onready var _flash: ColorRect = $Flash
@onready var _fade: ColorRect = $Fade
@onready var _skip: Button = $Skip

var _leaving: bool = false
var _box: DialogueBox
var _stage: Node2D                # décor du tableau en cours (cases, arbres, autel...)
var _fx: Node2D                   # effets (pluie, poussière, éclats) devant le décor
var _caption: PanelContainer      # bandeau du conteur
var _caption_label: Label
var _advance_requested: bool = false
var _pending: String = ""
var _time: float = 0.0
var _stone: Node2D                # la Pierre de foudre (tableaux 2 et 3)
var _stone_hover: bool = false
var _clouds: Array[Sprite2D] = []  # les derniers nuages, au-dessus du sanctuaire


func _ready() -> void:
	_emblem.modulate.a = 0.0
	_flash.color.a = 0.0
	_fade.color.a = 1.0
	_storm.visible = false
	_kodjo.visible = false
	_afi.visible = false
	_skip.pressed.connect(_leave)
	# « Passer » en haut à droite : le bas de l'écran appartient au conteur.
	_skip.anchor_top = 0.0
	_skip.anchor_bottom = 0.0
	_skip.offset_top = 8.0
	_skip.offset_bottom = 32.0
	_build_caption()
	_run()


func _process(delta: float) -> void:
	_time += delta
	# L'emblème respire doucement, comme une braise.
	$Emblem/Glow.scale = Vector2.ONE * (1.0 + 0.06 * sin(_time * 2.4))
	_emblem.position.y = 150.0 + 2.0 * sin(_time * 1.3)
	# La Pierre de foudre flotte et pulse au-dessus de l'autel.
	if _stone_hover and is_instance_valid(_stone):
		_stone.position.y = 248.0 + 2.0 * sin(_time * 2.0)
		_stone.get_node("Glow").scale = Vector2.ONE * (0.9 + 0.14 * sin(_time * 3.1))


func _run() -> void:
	await _tableau_avant()
	if not _leaving:
		await _tableau_vol()
	if not _leaving:
		await _tableau_malheurs()
	if not _leaving:
		await _tableau_appel()


# ---------------------------------------------------------------------------
# Les tableaux
# ---------------------------------------------------------------------------

## 1. Le village vert, sous la pluie de saison.
func _tableau_avant() -> void:
	_new_stage(Color(0.95, 0.95, 1.0))
	_village(true)
	_rain()
	await _fade_in()
	await _tell(&"avant", 0)


## 2 et 3. Le sanctuaire la nuit, puis le vol de la Pierre de foudre.
func _tableau_vol() -> void:
	await _fade_out()
	if _leaving: return
	_new_stage(NIGHT)
	_place("baobab", 110)
	var shrine := _place("hut_a", 470)
	# Le signe de Xɛvioso peint sur le mur du sanctuaire.
	var mark := Sprite2D.new()
	mark.texture = preload("res://assets/ui/xevioso/emblem_small.png")
	mark.position = Vector2(0, 10)
	mark.modulate = Color(1.0, 0.92, 0.8, 0.9)
	shrine.add_child(mark)
	_place("granary", 575)
	_place("altar", 400)
	_stone = _make_stone()
	_stone.position = Vector2(400, 248)
	_stone_hover = true
	_stage.add_child(_stone)
	_spawn_clouds()
	await _fade_in()
	await _tell(&"avant", 1)
	if _leaving: return

	# Une ombre se glisse jusqu'au sanctuaire.
	var adaka := _make_adaka()
	adaka.position = Vector2(-50, GROUND_Y - 50)
	_stage.add_child(adaka)
	adaka.play(&"float")
	var hand_x: float = 400.0 - 33.0
	create_tween().tween_property(adaka, "position:x", hand_x, 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _tell(&"vol", 0)
	await _tell(&"vol", 1)
	if _leaving: return

	# Il tend son bras griffu et arrache la pierre.
	adaka.play(&"reach")
	await get_tree().create_timer(0.35).timeout
	_stone_hover = false
	var hand: Vector2 = adaka.position + Vector2(33, -14)
	await create_tween().tween_property(_stone, "position", hand, 0.22).finished
	# Elle se brise : éclair, secousse, éclats qui s'envolent aux quatre vents.
	var at: Vector2 = _stone.position
	_strike(0.9)
	_shake(_stage, 5.0, 0.45)
	Fx.sparks(_fx, at, Color(0.65, 0.8, 1.0), 24)
	Fx.ring(_fx, at, Color(0.7, 0.85, 1.0), 44.0, 0.45, 3.0)
	_shatter(at)
	_stone.queue_free()
	await _tell(&"vol", 2)
	if _leaving: return

	# Puis il avale les nuages, jusqu'au dernier.
	adaka.play(&"inhale")
	_swallow_clouds(adaka.position + Vector2(2, -30))
	create_tween().tween_property(_night, "modulate", Color(0.27, 0.24, 0.33), 2.4)
	await _tell(&"vol", 3)
	if _leaving: return
	# Il s'efface dans sa poussière.
	Fx.puff(_fx, adaka.position + Vector2(0, 30), Color(0.6, 0.45, 0.35), 10, Vector2(-1, -0.3), 40.0, 1.0)
	var away := create_tween().set_parallel(true)
	away.tween_property(adaka, "modulate:a", 0.0, 0.9)
	away.tween_property(adaka, "position:x", adaka.position.x - 50.0, 0.9)
	await away.finished


## 4. Les malheurs : le même village, desséché.
func _tableau_malheurs() -> void:
	await _fade_out()
	if _leaving: return
	_new_stage(Color(1.0, 0.8, 0.62))
	_village(false)
	_cracks()
	_dust()
	await _fade_in()
	await _tell(&"malheurs", 0)
	await _tell(&"malheurs", 1)


## 5. L'appel de Xɛvioso : la nuit d'orage, l'emblème, Kodjo et Afi.
func _tableau_appel() -> void:
	await _fade_out()
	if _leaving: return
	_clear_stage()
	# La boîte de Xɛvioso s'ouvre en haut : « Passer » retourne en bas à droite.
	_skip.anchor_top = 1.0
	_skip.anchor_bottom = 1.0
	_skip.offset_top = -34.0
	_skip.offset_bottom = -10.0
	_night.modulate = NIGHT
	_storm.visible = true
	_kodjo.visible = true
	_afi.visible = true
	await _fade_in(1.2)
	await get_tree().create_timer(0.6).timeout
	if _leaving: return
	# La foudre frappe : l'emblème apparaît.
	_strike(0.9)
	_emblem.modulate.a = 1.0
	await get_tree().create_timer(0.8).timeout
	if _leaving: return
	_box = preload("res://scenes/ui/dialogue_box.tscn").instantiate()
	add_child(_box)
	_box.finished.connect(_leave)
	_box.play(Voices.lines(&"intro"), false)
	_ambient_lightning()


# ---------------------------------------------------------------------------
# Le conteur
# ---------------------------------------------------------------------------

func _build_caption() -> void:
	_caption = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.07, 0.84)
	style.border_color = Color(0.85, 0.66, 0.32, 0.85)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_caption.add_theme_stylebox_override("panel", style)
	_caption.anchor_left = 0.0
	_caption.anchor_right = 1.0
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_left = 48
	_caption.offset_right = -48
	_caption.offset_top = -62
	_caption.offset_bottom = -10
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
	add_child(_caption)
	move_child(_caption, _flash.get_index())   # sous le flash, le fondu et « Passer »


## Le conteur dit une phrase et attend qu'elle soit lue (ou qu'on demande à avancer).
func _tell(part: StringName, index: int) -> void:
	if _leaving:
		return
	var text: String = Voices.STORY[part][index]
	_caption.visible = true
	_caption_label.text = text
	_caption_label.visible_ratio = 0.0
	_advance_requested = false
	# Le texte s'écrit ; une demande d'avance l'affiche en entier d'un coup.
	var shown := 0.0
	while shown < 1.0 and not _leaving:
		await get_tree().process_frame
		if _advance_requested:
			break
		shown += get_process_delta_time() * 45.0 / text.length()
		_caption_label.visible_ratio = shown
	_caption_label.visible_ratio = 1.0
	_advance_requested = false
	# Temps de lecture, sauf si on demande à avancer.
	var reading: float = clampf(text.length() * 0.035, 2.0, 4.5)
	var waited := 0.0
	while waited < reading and not _advance_requested and not _leaving:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_advance_requested = false


func _unhandled_input(event: InputEvent) -> void:
	if _caption == null or not _caption.visible:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump")
	if pressed:
		_advance_requested = true
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Décor des tableaux
# ---------------------------------------------------------------------------

func _new_stage(mood: Color) -> void:
	_clear_stage()
	_night.modulate = mood
	_stage = Node2D.new()
	add_child(_stage)
	move_child(_stage, _storm.get_index())       # devant le paysage, derrière l'orage
	_fx = Node2D.new()
	add_child(_fx)
	move_child(_fx, _stage.get_index() + 1)


func _clear_stage() -> void:
	for node in [_stage, _fx]:
		if is_instance_valid(node):
			node.queue_free()
	_stage = null
	_fx = null


## Le village : vert et fleuri (avant), ou sec (après le vol).
func _village(green: bool) -> void:
	var suffix := "_green" if green else ""
	_place("baobab" + suffix, 372)
	_place("hut_a", 118)
	_place("granary", 198)
	_place("hut_b", 530)
	for x in [262, 448, 610]:
		_place("bush" + suffix, x)
	if green:
		for i in 4:
			_place("flower_" + ["red", "yellow", "white", "red"][i], 60 + i * 150)
	for x in range(8, 640, 30 if green else 46):
		_place("grass_%d%s" % [(x / 7) % 4, suffix], x + randi_range(-5, 5), 1.0)


## Pose un élément du décor du village, le pied dans le sol.
func _place(file: String, x: float, sink: float = 2.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(DECOR + file + ".png")
	sprite.position = Vector2(x, GROUND_Y + sink - sprite.texture.get_height() / 2.0).round()
	_stage.add_child(sprite)
	return sprite


func _make_stone() -> Node2D:
	var stone := Node2D.new()
	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = preload("res://assets/story/thunder_glow.png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	stone.add_child(glow)
	var body := Sprite2D.new()
	body.texture = preload("res://assets/story/thunder_stone.png")
	stone.add_child(body)
	return stone


func _make_adaka() -> AnimatedSprite2D:
	var sheet: Texture2D = preload("res://assets/story/adaka.png")
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in [[&"float", 0, 4, true, 5.0], [&"reach", 1, 3, false, 8.0], [&"inhale", 2, 4, false, 4.0]]:
		frames.add_animation(anim[0])
		frames.set_animation_speed(anim[0], anim[4])
		frames.set_animation_loop(anim[0], anim[3])
		for c in anim[2]:
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(c * 72, anim[1] * 96, 72, 96)
			frames.add_frame(anim[0], region)
	var adaka := AnimatedSprite2D.new()
	adaka.sprite_frames = frames
	return adaka


## Les éclats de la Pierre de foudre s'envolent en arcs, hors de l'écran.
func _shatter(at: Vector2) -> void:
	for i in 9:
		var shard := Sprite2D.new()
		shard.texture = preload("res://assets/props/sokpe.png")
		shard.position = at
		_fx.add_child(shard)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var target := Vector2(at.x + side * randf_range(260.0, 460.0), randf_range(-40.0, 160.0))
		var lift: float = randf_range(50.0, 130.0)
		var duration: float = randf_range(1.0, 1.5)
		var tween := create_tween().set_parallel(true)
		tween.tween_method(func(t: float) -> void:
			shard.position = at.lerp(target, t) + Vector2(0, -sin(t * PI) * lift),
			0.0, 1.0, duration)
		tween.tween_property(shard, "rotation", side * randf_range(4.0, 9.0), duration)
		tween.chain().tween_callback(shard.queue_free)


## Les nuages de la nuit, qui dérivent doucement au-dessus du sanctuaire.
func _spawn_clouds() -> void:
	_clouds.clear()
	var sheet: Texture2D = preload("res://assets/backgrounds/village/bg_clouds.png")
	for i in 4:
		var cloud := Sprite2D.new()
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = Rect2(i * 160, 0, 160, 110)
		cloud.texture = tex
		cloud.position = Vector2(80 + i * 160, 55)
		cloud.modulate = Color(0.75, 0.78, 0.95)
		_fx.add_child(cloud)
		create_tween().tween_property(cloud, "offset:x", -24.0, 20.0)
		_clouds.append(cloud)


## Les nuages sont aspirés jusqu'à la bouche d'Adaka.
func _swallow_clouds(mouth: Vector2) -> void:
	for i in _clouds.size():
		var cloud := _clouds[i]
		if not is_instance_valid(cloud):
			continue
		var delay: float = 0.15 + i * 0.25
		var tween := create_tween().set_parallel(true)
		tween.tween_property(cloud, "position", mouth, 1.6).set_delay(delay) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(cloud, "scale", Vector2(0.05, 0.05), 1.6).set_delay(delay) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(cloud.queue_free)


## La pluie de saison (tableau 1).
func _rain() -> void:
	var rain := CPUParticles2D.new()
	rain.texture = preload("res://assets/fx/raindrop.png")
	rain.amount = 110
	rain.lifetime = 1.0
	rain.preprocess = 1.0
	rain.position = Vector2(360, -12)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(380, 4)
	rain.direction = Vector2(-0.22, 1.0)
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 320.0
	rain.initial_velocity_max = 370.0
	rain.angle_min = 12.0
	rain.angle_max = 12.0
	rain.color = Color(0.78, 0.86, 1.0, 0.6)
	_fx.add_child(rain)


## Le vent sec chasse la poussière (tableau 4).
func _dust() -> void:
	var dust := CPUParticles2D.new()
	dust.texture = preload("res://assets/fx/smoke.png")
	dust.amount = 30
	dust.lifetime = 3.5
	dust.preprocess = 3.5
	dust.position = Vector2(680, 270)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(10, 50)
	dust.direction = Vector2(-1, -0.05)
	dust.spread = 8.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 170.0
	dust.initial_velocity_max = 240.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.6
	dust.color = Color(0.85, 0.64, 0.45, 0.4)
	_fx.add_child(dust)


## La terre fendue par la soif (tableau 4).
func _cracks() -> void:
	for i in 10:
		var crack := Line2D.new()
		crack.width = 1.0
		crack.default_color = Color(0.22, 0.09, 0.05, 0.85)
		var p := Vector2(randf_range(20.0, 620.0), GROUND_Y + randf_range(8.0, 40.0)).round()
		crack.add_point(p)
		for k in randi_range(3, 6):
			p += Vector2(randi_range(-7, 7), randi_range(0, 4))
			crack.add_point(p)
		_stage.add_child(crack)


# ---------------------------------------------------------------------------
# Transitions et lumière
# ---------------------------------------------------------------------------

func _fade_in(duration: float = 0.8) -> void:
	await create_tween().tween_property(_fade, "color:a", 0.0, duration).finished


func _fade_out(duration: float = 0.6) -> void:
	await create_tween().tween_property(_fade, "color:a", 1.0, duration).finished
	_caption.visible = false


## Quelques éclairs lointains pendant que Xɛvioso parle.
func _ambient_lightning() -> void:
	while not _leaving and is_inside_tree():
		await get_tree().create_timer(randf_range(4.0, 8.0)).timeout
		if not _leaving:
			_strike(0.35)


func _strike(strength: float) -> void:
	_flash.color.a = strength
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)


## Secoue un nœud (le décor) un instant.
func _shake(node: Node2D, strength: float, duration: float) -> void:
	var tween := create_tween()
	var steps := int(duration / 0.04)
	for i in steps:
		var k: float = 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k
		tween.tween_property(node, "position", offset.round(), 0.04)
	tween.tween_property(node, "position", Vector2.ZERO, 0.04)


## Fin de la scène (ou « Passer ») : un dernier éclair, fondu au noir, premier niveau.
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_skip.disabled = true
	if _box != null:
		_box.queue_free()
	_strike(1.0)
	await create_tween().tween_property(_fade, "color:a", 1.0, 0.9).finished
	Game.go_to_level(Game.FIRST_LEVEL)
