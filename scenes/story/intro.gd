extends Control
## Scène d'ouverture (nouvelle partie) : l'histoire, sans se presser.
##
##   1. Le village vivant : un matin de saison des pluies. La caméra glisse le long du village :
##      le cultivateur dans son champ de mil, l'ancien sous le baobab, la pileuse, la porteuse
##      d'eau, les enfants qui chassent les poules, le joueur de tambour. Puis l'averse arrive :
##      tout le monde danse sous la pluie.
##   2. Le sanctuaire, au crépuscule : la Pierre de foudre brille sur son autel.
##   3. La nuit du vol : le vent tombe, les lucioles s'éteignent. Adaka glisse jusqu'à l'autel,
##      arrache la pierre, qui se brise en éclats (les sokpe), ricane, avale les nuages, s'efface.
##   4. Les malheurs : le même village, desséché ; chacun a perdu sa joie.
##   5. L'appel, scène solennelle : nuit d'orage sans pluie. Le village se rassemble devant
##      l'autel vide ; l'emblème de Xɛvioso paraît. Sa foudre désigne Kodjo, à qui il donne la
##      Ruée et la vitesse, puis Afi, à qui il donne le pagne volant et la sagesse. Puis la mission.
##
## Le conteur parle dans un bandeau en bas de l'écran (le texte s'écrit lentement ; toucher,
## Entrée ou Saut pour avancer). Xɛvioso parle dans sa boîte de dialogue. « Passer » reste
## disponible tout du long. Les textes sont dans Voices (STORY, et intro_appel/kodjo/afi/mission).

## Pour la mise au point : commencer à un tableau donné (1 à 5).
@export_range(1, 5) var start_at: int = 1

const GROUND_Y := 302.0
const DECOR := "res://assets/decor/village/"
const STORY_DIR := "res://assets/story/"
const SILHOUETTE := preload("res://assets/shaders/silhouette.gdshader")

## Lieux (abscisses dans le monde) : le village s'étend de gauche à droite, le sanctuaire au bout.
const ALTAR_X := 1000.0
const STONE_Y := 248.0

## Ambiances (teinte de toute la scène).
const DAWN := Color(0.96, 0.86, 0.8)
const RAINY := Color(0.8, 0.85, 0.94)
const DUSK := Color(1.0, 0.74, 0.6)
const NIGHT := Color(0.27, 0.29, 0.46)
const DROUGHT := Color(1.0, 0.88, 0.72)
const STORM_NIGHT := Color(0.42, 0.42, 0.6)

## Villageois : animation -> [ligne de la planche, images, images/s] (planche villagers.png,
## cellules 40 x 60 ; générée par heroes/villagers.py).
const VILLAGER_ANIMS := {
	&"pound": [0, 6, 7], &"pileuse_joy": [1, 4, 5], &"pileuse_sad": [2, 4, 2],
	&"walk_jar": [3, 8, 8], &"porteuse_joy": [4, 4, 5], &"porteuse_sad": [5, 4, 2],
	&"garcon_run": [6, 8, 13], &"garcon_dance": [7, 6, 9], &"garcon_sad": [8, 4, 2],
	&"fille_run": [9, 8, 13], &"fille_dance": [10, 6, 9], &"fille_sad": [11, 4, 2],
	&"hoe": [12, 6, 7], &"cultivateur_joy": [13, 4, 5], &"cultivateur_sad": [14, 4, 2],
	&"ancien_idle": [15, 4, 3], &"ancien_joy": [16, 4, 4], &"ancien_sad": [17, 4, 2],
	&"drum": [18, 4, 8], &"tambour_sad": [19, 4, 2],
}

## Adaka (planche adaka.png, cellules 96 x 128 ; générée par decor/adaka2.py).
const ADAKA_ANIMS := [[&"float", 0, 6, 6.0, true], [&"reach", 1, 5, 9.0, false],
	[&"inhale", 2, 6, 5.0, false], [&"gloat", 3, 4, 8.0, true]]
const ADAKA_HAND := Vector2(41, -14)     # main fermée (saisit, dernière image), depuis le centre
const ADAKA_MOUTH := Vector2(14, -24)    # gueule ouverte (avale)
const ADAKA_Y := GROUND_Y - 60.0         # le bas du tourbillon frôle le sol

@onready var _night: Node2D = $Night
@onready var _storm: Parallax2D = $Storm
@onready var _emblem: Node2D = $Emblem
@onready var _kodjo: AnimatedSprite2D = $Kodjo
@onready var _afi: AnimatedSprite2D = $Afi
@onready var _flash: ColorRect = $Flash
@onready var _fade: ColorRect = $Fade
@onready var _skip: Button = $Skip

var _leaving: bool = false
var _box: DialogueBox
var _ui: CanvasLayer
var _lit: CanvasLayer                 # ce qui brille par soi-même (emblème, foudre, halos) : pas assombri
var _tint: CanvasModulate
var _camera: Camera2D
var _world: Node2D
var _amb: Ambience                    # pour ses fabriques (fumées, feux, cordes à linge, balancement)
var _villager_frames: SpriteFrames
var _v: Dictionary = {}               # rôle -> villageois
var _hens: Array = []
var _rain_light: CPUParticles2D
var _rain_heavy: CPUParticles2D
var _clouds_layer: Parallax2D
var _fireflies: CPUParticles2D
var _smokes: Array = []
var _fires: Array = []
var _stone: Node2D
var _stone_hover: bool = false
var _night_clouds: Array[Sprite2D] = []
var _kids_running: bool = false
var _kids_center: float = 600.0
var _wind: float = 0.6                # force du vent (multiplie les rafales)
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _emblem_y: float = 110.0
var _bird_timer: float = 4.0
var _birds_on: bool = false
var _porteuse_walk: Tween

var _caption: PanelContainer
var _caption_label: Label
var _caption_next: Label
var _advance_requested: bool = false


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.25
	# L'interface (fondu, éclair, « Passer », conteur) sur sa propre couche : la caméra ne la
	# déplace pas et la teinte de la scène ne l'assombrit pas.
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	for node in [_flash, _fade, _skip]:
		node.reparent(_ui, false)
	_flash.color.a = 0.0
	_fade.color.a = 1.0
	_skip.pressed.connect(_leave)
	_skip_at_top(true)
	_build_caption()
	# Ce qui brille par soi-même suit la caméra mais échappe à la teinte de la scène.
	_lit = CanvasLayer.new()
	_lit.layer = 1
	_lit.follow_viewport_enabled = true
	add_child(_lit)
	_emblem.reparent(_lit, false)
	# Teinte de toute la scène (matin, crépuscule, nuit...).
	_tint = CanvasModulate.new()
	_tint.color = DAWN
	add_child(_tint)
	# Profondeur : les couches lointaines glissent moins vite que le premier plan.
	_night.modulate = Color.WHITE
	var depth := {"Sky": 0.0, "Far": 0.12, "Mid": 0.28, "Near": 0.5, "Ground": 1.0}
	for layer in _night.get_children():
		if layer is Parallax2D:
			layer.scroll_scale = Vector2(depth.get(String(layer.name), 1.0), 1.0)
			layer.autoscroll = Vector2.ZERO
	_storm.scroll_scale = Vector2(0.08, 1.0)
	_storm.visible = false
	# Caméra rapprochée : le village occupe l'écran, le bandeau du conteur ne couvre que la terre.
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.4, 1.4)
	_camera.position = Vector2(220, 250)
	add_child(_camera)
	_camera.make_current()
	_amb = Ambience.new()
	_emblem.modulate.a = 0.0
	for hero in [_kodjo, _afi]:
		hero.visible = false
		hero.modulate = Color.WHITE
	_build_villager_frames()
	RenderingServer.global_shader_parameter_set(&"player_world", Vector2(0, -10000))
	_run()


func _exit_tree() -> void:
	if _amb != null:
		_amb.free()
	RenderingServer.global_shader_parameter_set(&"wind_gust", -0.3)


func _process(delta: float) -> void:
	_time += delta
	# Le vent : des rafales lissées, toujours vers la gauche ; « _wind » règle sa force.
	var n: float = (_noise.get_noise_1d(_time) + 1.0) * 0.5
	var gust: float = _wind * (0.35 + 0.9 * n * n)
	RenderingServer.global_shader_parameter_set(&"wind_gust", -gust)
	for smoke in _smokes:
		if is_instance_valid(smoke):
			smoke.gravity.x = -3.0 - 14.0 * gust
	# L'emblème respire doucement, comme une braise.
	_emblem.get_node("Glow").scale = Vector2.ONE * (1.0 + 0.06 * sin(_time * 2.4))
	_emblem.position.y = _emblem_y + 2.0 * sin(_time * 1.3)
	# La Pierre de foudre flotte et pulse au-dessus de l'autel.
	if _stone_hover and is_instance_valid(_stone):
		_stone.position.y = STONE_Y + 2.0 * sin(_time * 2.0)
		_stone.get_node("Glow").scale = Vector2.ONE * (0.9 + 0.14 * sin(_time * 3.1))
	_update_kids(delta)
	for hen in _hens:
		if is_instance_valid(hen):
			hen.tick(delta, [_v.get("garcon"), _v.get("fille")])
	if _birds_on:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = randf_range(7.0, 12.0)
			_spawn_flock()


func _run() -> void:
	if start_at in [2, 3]:   # (mise au point) commencer directement au sanctuaire
		_season(true)
		_build_village(false)
		_camera.position.x = ALTAR_X - 60.0
		_fade.color.a = 0.0
	elif start_at >= 4:      # (mise au point) commencer directement par un tableau sec
		_season(false)
		_build_village(true)
	if start_at <= 1: await _tableau_village()
	if not _leaving and start_at <= 2: await _tableau_sanctuaire()
	if not _leaving and start_at <= 3: await _tableau_vol()
	if not _leaving and start_at <= 4: await _tableau_malheurs()
	if not _leaving: await _tableau_appel()


# ---------------------------------------------------------------------------
# 1. Le village vivant, à la saison des pluies
# ---------------------------------------------------------------------------

func _tableau_village() -> void:
	_season(true)
	_build_village(false)
	_clouds(true)
	_rain_light.emitting = true
	_birds_on = true
	_kids_running = true
	var pan := create_tween()
	pan.tween_property(_camera, "position:x", 545.0, 32.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	create_tween().tween_property(_tint, "color", Color.WHITE, 10.0)
	await _fade_in(2.5)
	await _pause(1.5)
	await _tell(&"avant", 0)
	await _tell(&"avant", 1)
	# L'averse : le ciel s'assombrit un peu, la pluie forcit, tout le village danse.
	create_tween().tween_property(_tint, "color", RAINY, 3.0)
	await _pause(0.8)
	if _leaving: return
	_rain_heavy.emitting = true
	_birds_on = false
	_wind = 1.0
	_kids_running = false
	_kids_center = 600.0
	if _porteuse_walk != null:
		_porteuse_walk.kill()
	for role in ["pileuse", "porteuse", "garcon", "fille", "cultivateur", "ancien"]:
		_v[role].play(StringName(role + ("_dance" if role in ["garcon", "fille"] else "_joy")))
	if pan.is_running():
		await pan.finished
	await _tell(&"avant", 2)
	await _pause(2.0)


# ---------------------------------------------------------------------------
# 2. Le sanctuaire, au crépuscule
# ---------------------------------------------------------------------------

func _tableau_sanctuaire() -> void:
	_rain_heavy.emitting = false
	_rain_light.emitting = false
	_wind = 0.6
	create_tween().tween_property(_tint, "color", DUSK, 7.0)
	var pan := create_tween()
	pan.tween_property(_camera, "position:x", ALTAR_X - 60.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _pause(3.0)
	await _tell(&"sanctuaire", 0)
	if pan.is_running():
		await pan.finished
	# Le prêtre s'incline devant la pierre ; elle répond par un éclat.
	Fx.sparks(_lit, _stone.position, Color(0.6, 0.8, 1.0), 10)
	await _tell(&"sanctuaire", 1)
	await _pause(1.5)


# ---------------------------------------------------------------------------
# 3. La nuit du vol
# ---------------------------------------------------------------------------

func _tableau_vol() -> void:
	await _fade_out(1.5)
	if _leaving: return
	# La nuit : le village dort, les feux ne sont plus que des braises, les lucioles dansent.
	_tint.color = NIGHT
	_clouds(false)
	for role in _v:
		_v[role].visible = false
	for hen in _hens:
		hen.visible = false
	for smoke in _smokes:
		smoke.emitting = false
	for fire in _fires:
		fire.get_node("Flammes").hide()
		fire.get_node("Halo").modulate.a = 0.35
	_camera.position.x = ALTAR_X - 90.0
	_spawn_night_clouds()
	_fireflies.emitting = true
	_wind = 0.5
	await _fade_in(2.0)
	await _pause(2.0)
	# Le vent tombe d'un coup ; plus rien ne bouge ; les lucioles s'éteignent.
	create_tween().tween_property(self, "_wind", 0.0, 1.2)
	_set_idle_sway(false)
	_fireflies.emitting = false
	await _tell(&"vol", 0)
	await _pause(1.0)
	if _leaving: return

	# Une ombre glisse jusqu'au sanctuaire.
	var adaka := _make_adaka()
	adaka.position = Vector2(ALTAR_X - 380.0, ADAKA_Y)
	adaka.modulate.a = 0.0
	_world.add_child(adaka)
	adaka.play(&"float")
	Fx.puff(_world, adaka.position + Vector2(-10, 56), Color(0.5, 0.38, 0.3), 8, Vector2(1, -0.2), 30.0, 1.0)
	var glide := create_tween().set_parallel(true)
	glide.tween_property(adaka, "modulate:a", 1.0, 2.0)
	glide.tween_property(adaka, "position:x", ALTAR_X - ADAKA_HAND.x, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(_camera, "position:x", ALTAR_X - 40.0, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tell(&"vol", 1)
	if glide.is_running():
		await glide.finished
	await _tell(&"vol", 2)
	if _leaving: return

	# Il tend son bras griffu et arrache la pierre.
	adaka.play(&"reach")
	await adaka.animation_finished
	_stone_hover = false
	var hand: Vector2 = adaka.position + ADAKA_HAND
	await create_tween().tween_property(_stone, "position", hand, 0.18).finished
	await _pause(0.5)
	# Elle se brise : éclair, la terre tremble, les éclats s'envolent aux quatre vents.
	var at: Vector2 = _stone.position
	_strike(1.0)
	_shake(6.0, 0.6)
	Fx.sparks(_lit, at, Color(0.65, 0.8, 1.0), 28)
	Fx.ring(_lit, at, Color(0.7, 0.85, 1.0), 56.0, 0.5, 3.0)
	LightningBolt.strike(_lit, at + Vector2(0, -220), at, 2.5, 0.4, 3)
	_shatter(at)
	_stone.queue_free()
	adaka.play(&"gloat")
	await _tell(&"vol", 3)
	if _leaving: return

	# Puis il avale les nuages, jusqu'au dernier.
	adaka.play(&"inhale")
	_swallow_clouds(adaka.position + ADAKA_MOUTH)
	create_tween().tween_property(_tint, "color", Color(0.22, 0.2, 0.3), 3.0)
	await _tell(&"vol", 4)
	if _leaving: return
	# Il s'efface dans sa poussière.
	adaka.play(&"float")
	create_tween().tween_property(self, "_wind", 1.2, 0.6)
	Fx.puff(_world, adaka.position + Vector2(0, 40), Color(0.55, 0.42, 0.32), 14, Vector2(-1, -0.3), 50.0, 1.2)
	var away := create_tween().set_parallel(true)
	away.tween_property(adaka, "modulate:a", 0.0, 2.2)
	away.tween_property(adaka, "position:x", adaka.position.x - 120.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tell(&"vol", 5)
	await _pause(1.0)


# ---------------------------------------------------------------------------
# 4. Les malheurs
# ---------------------------------------------------------------------------

func _tableau_malheurs() -> void:
	await _fade_out(1.5)
	if _leaving: return
	_set_idle_sway(true)
	_season(false)
	_build_village(true)
	_tint.color = DROUGHT
	_wind = 0.9
	_camera.position.x = ALTAR_X - 120.0
	await _fade_in(2.0)
	var pan := create_tween()
	pan.tween_property(_camera, "position:x", 300.0, 36.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _pause(1.0)
	await _tell(&"malheurs", 0)
	await _tell(&"malheurs", 1)
	await _tell(&"malheurs", 2)
	# La nuit tombe, sans un nuage ; au loin, le tonnerre gronde.
	create_tween().tween_property(_tint, "color", STORM_NIGHT, 5.0)
	_storm.visible = true
	_storm.modulate.a = 0.0
	create_tween().tween_property(_storm, "modulate:a", 1.0, 5.0)
	await _pause(1.5)
	_strike(0.25)
	_shake(2.0, 0.8)
	await _tell(&"malheurs", 3)
	pan.kill()


# ---------------------------------------------------------------------------
# 5. L'appel : scène solennelle
# ---------------------------------------------------------------------------

func _tableau_appel() -> void:
	await _fade_out(1.5)
	if _leaving: return
	_caption.visible = false
	_skip_at_top(false)
	_tint.color = STORM_NIGHT
	_storm.modulate.a = 1.0
	_wind = 1.1
	# Plan plus large et plus haut : le ciel d'orage, l'emblème, et tout le village rassemblé.
	_camera.zoom = Vector2(1.3, 1.3)
	_camera.position = Vector2(ALTAR_X - 110.0, 225.0)
	# Le village s'est rassemblé devant l'autel vide ; les deux enfants s'avancent.
	var crowd := {"tambour": 690.0, "cultivateur": 712.0, "porteuse": 736.0, "pileuse": 760.0,
		"ancien": 786.0, "fille": 806.0, "garcon": 820.0}
	for role in crowd:
		var v: AnimatedSprite2D = _v[role]
		v.position.x = crowd[role]
		v.flip_h = false
		v.visible = true
		v.modulate = Color(0.85, 0.85, 0.9)
	if _v.has("pretre"):
		_v["pretre"].visible = false
	for hen in _hens:
		hen.visible = false
	_kodjo.position = Vector2(ALTAR_X - 330.0, GROUND_Y - 19.0)
	_afi.position = Vector2(ALTAR_X - 362.0, GROUND_Y - 19.0)
	_afi.scale.x = 1.0
	for hero in [_kodjo, _afi]:
		hero.visible = true
		hero.modulate = Color(1.3, 1.3, 1.3)   # les deux enfants se détachent de la foule
		hero.play(&"run")
		hero.speed_scale = 0.5
		move_child(hero, _world.get_index() + 1)
	await _fade_in(2.0)
	var walk := create_tween().set_parallel(true)
	walk.tween_property(_kodjo, "position:x", ALTAR_X - 88.0, 6.5)
	walk.tween_property(_afi, "position:x", ALTAR_X - 120.0, 6.5)
	await walk.finished
	for hero in [_kodjo, _afi]:
		hero.speed_scale = 1.0
		hero.play(&"idle")
	if _leaving: return
	# Le silence. Puis le tonnerre, de plus en plus proche ; l'emblème paraît dans le ciel.
	await _pause(2.0)
	_strike(0.2)
	_shake(1.5, 0.6)
	await _pause(1.8)
	_strike(0.4)
	_shake(3.0, 0.8)
	await _pause(1.2)
	if _leaving: return
	# L'emblème paraît au-dessus du sanctuaire, à droite (la parole de Xɛvioso s'affiche en haut).
	_emblem_y = 128.0
	_emblem.position = Vector2(ALTAR_X + 100.0, _emblem_y)
	_emblem.scale = Vector2.ONE * 0.6
	var appear := create_tween().set_parallel(true)
	appear.tween_property(_emblem, "modulate:a", 1.0, 3.0)
	appear.tween_property(_emblem, "scale", Vector2.ONE, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	LightningBolt.strike(_lit, Vector2(ALTAR_X + 100.0, 40.0), Vector2(ALTAR_X + 100.0, 110.0), 3.0, 0.5, 4)
	_strike(0.9)
	_v["ancien"].play(&"ancien_joy")          # l'ancien lève les bras vers le ciel
	await appear.finished
	# Les villageois lèvent les yeux et s'agenouillent... (ils baissent la tête, recueillis).
	await _pause(1.0)
	await _xevioso(&"intro_appel")
	if _leaving: return

	# Kodjo : la foudre le désigne ; la Ruée et la vitesse.
	await _designate(_kodjo, Color(1.0, 0.82, 0.3))
	await _xevioso(&"intro_kodjo")
	if _leaving: return
	await _demo_ruee()
	if _leaving: return

	# Afi : la foudre la désigne ; le pagne volant et la sagesse.
	await _designate(_afi, Color(0.35, 0.9, 0.85))
	await _xevioso(&"intro_afi")
	if _leaving: return
	await _demo_pagne()
	if _leaving: return

	# La mission.
	await _xevioso(&"intro_mission")
	if _leaving: return
	# Les Envoyés partent sur la route ; le village reprend espoir.
	for role in ["pileuse", "porteuse", "cultivateur", "ancien"]:
		_v[role].play(StringName(role + "_joy"))
	_v["garcon"].play(&"garcon_dance")
	_v["fille"].play(&"fille_dance")
	_v["tambour"].play(&"drum")
	await _pause(0.8)
	for hero in [_kodjo, _afi]:
		hero.play(&"run")
	var go := create_tween().set_parallel(true)
	go.tween_property(_kodjo, "position:x", _kodjo.position.x + 420.0, 3.0)
	go.tween_property(_afi, "position:x", _afi.position.x + 420.0, 3.2)
	await _pause(2.2)
	_leave()


## La foudre frappe un Envoyé : éclair, halo de sa couleur, étincelles qui montent.
func _designate(hero: AnimatedSprite2D, color: Color) -> void:
	await _pause(1.0)
	if _leaving: return
	var target: Vector2 = hero.position + Vector2(0, -6)
	LightningBolt.strike(_lit, _emblem.position + Vector2(-10, 20), target, 3.0, 0.55, 3)
	_strike(0.8)
	_shake(3.0, 0.4)
	Fx.ring(_lit, hero.position + Vector2(0, 18), color, 30.0, 0.5, 2.0, 0.35)
	Fx.sparks(_lit, target, color, 22)
	var aura := Sprite2D.new()
	aura.texture = preload("res://assets/ui/xevioso/emblem_glow.png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura.material = add
	aura.modulate = Color(color.r, color.g, color.b, 0.0)
	aura.scale = Vector2(0.5, 0.75)
	aura.position = hero.position + Vector2(0, -2)
	_lit.add_child(aura)
	aura.set_meta("hero", hero)
	var glow := create_tween()
	glow.tween_property(aura, "modulate:a", 0.6, 0.3)
	glow.tween_property(aura, "modulate:a", 0.25, 1.2)
	hero.play(&"jump")
	var lift := create_tween()
	lift.tween_property(hero, "position:y", hero.position.y - 6.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lift.tween_property(hero, "position:y", hero.position.y, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var tint := create_tween()
	tint.tween_property(hero, "modulate", color.lightened(0.4), 0.3)
	tint.tween_property(hero, "modulate", Color(1.3, 1.3, 1.3), 1.4)
	await lift.finished
	hero.play(&"idle")
	# Des étincelles continuent de monter autour de lui pendant qu'il reçoit son don.
	var motes := CPUParticles2D.new()
	motes.texture = preload("res://assets/fx/ember.png")
	motes.amount = 14
	motes.lifetime = 1.6
	motes.position = hero.position + Vector2(0, 14)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(8, 2)
	motes.direction = Vector2(0, -1)
	motes.spread = 10.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 14.0
	motes.initial_velocity_max = 24.0
	motes.color = color
	_lit.add_child(motes)
	get_tree().create_timer(9.0).timeout.connect(func() -> void:
		if is_instance_valid(motes): motes.emitting = false
		if is_instance_valid(aura): create_tween().tween_property(aura, "modulate:a", 0.0, 1.5))


## Kodjo montre sa Ruée : il file comme l'éclair, laissant des silhouettes dorées, et revient.
func _demo_ruee() -> void:
	await _pause(0.5)
	var start: Vector2 = _kodjo.position
	for leg in [[start.x + 170.0, false], [start.x - 60.0, true], [start.x, false]]:
		_kodjo.flip_h = leg[1]
		_kodjo.play(&"run")
		_kodjo.speed_scale = 1.6
		Fx.puff(_world, _kodjo.position + Vector2(0, 19), Color(0.8, 0.68, 0.5), 5,
			Vector2(-1 if not leg[1] else 1, -0.3), 26.0, 0.6)
		var dist: float = absf(leg[0] - _kodjo.position.x)
		var dash := create_tween()
		dash.tween_property(_kodjo, "position:x", leg[0], dist / 520.0)
		while dash.is_running() and not _leaving:
			_afterimage(_kodjo, Color(1.0, 0.82, 0.32, 0.9))
			await get_tree().create_timer(0.03).timeout
		await _pause(0.25)
	_kodjo.flip_h = false
	_kodjo.speed_scale = 1.0
	_kodjo.play(&"idle")
	await _pause(1.0)


## Afi montre son pagne volant : elle s'élève, déploie le voile et plane longuement.
func _demo_pagne() -> void:
	await _pause(0.5)
	var start: Vector2 = _afi.position
	var canopy := Sprite2D.new()
	canopy.texture = preload("res://assets/fx/pagne_voile.png")
	canopy.position = Vector2(2, -32)
	canopy.scale = Vector2(0.2, 0.2)
	_afi.add_child(canopy)
	_afi.play(&"jump")
	await create_tween().tween_property(_afi, "position:y", start.y - 70.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).finished
	# Le voile claque et s'ouvre.
	Fx.ring(_lit, _afi.position + Vector2(2, -30), Color(0.35, 0.9, 0.85), 20.0, 0.35, 2.0, 0.5)
	create_tween().tween_property(canopy, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_afi.play(&"fall")
	# Elle plane : une boucle au-dessus du village, puis elle se pose doucement à sa place.
	var glide := create_tween()
	glide.tween_method(func(k: float) -> void:
		_afi.position = start + Vector2(sin(k * TAU) * 120.0, -70.0 + 58.0 * k)
		_afi.flip_h = cos(k * TAU) < 0.0
		canopy.rotation = -0.15 * cos(k * TAU) + 0.05 * sin(_time * 3.0),
		0.0, 1.0, 6.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await glide.finished
	await create_tween().tween_property(_afi, "position:y", start.y, 0.4).finished
	_afi.flip_h = false
	_afi.play(&"land")
	Fx.puff(_world, _afi.position + Vector2(0, 19), Color(0.8, 0.68, 0.5), 5, Vector2.ZERO, 20.0, 0.6)
	await create_tween().tween_property(canopy, "scale", Vector2(0.1, 0.1), 0.25).finished
	canopy.queue_free()
	await _pause(0.4)
	_afi.play(&"idle")
	await _pause(1.0)


func _afterimage(hero: AnimatedSprite2D, color: Color) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = hero.sprite_frames.get_frame_texture(hero.animation, hero.frame)
	ghost.flip_h = hero.flip_h
	ghost.position = hero.position
	ghost.modulate = color
	var m := ShaderMaterial.new()
	m.shader = SILHOUETTE
	ghost.material = m
	add_child(ghost)
	move_child(ghost, hero.get_index())
	var fade := ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, 0.35)
	fade.tween_callback(ghost.queue_free)


## Xɛvioso parle (boîte de dialogue en haut), lentement ; on avance au toucher.
func _xevioso(key: StringName) -> void:
	if _leaving:
		return
	if _box == null:
		_box = preload("res://scenes/ui/dialogue_box.tscn").instantiate()
		_box.chars_per_second = 24.0
		add_child(_box)
	await _box.play(Voices.lines(key), false)
	await _pause(0.6)


# ---------------------------------------------------------------------------
# Le village (vert ou desséché)
# ---------------------------------------------------------------------------

func _build_village(dry: bool) -> void:
	if is_instance_valid(_world):
		_world.queue_free()
	_v.clear(); _hens.clear(); _smokes.clear(); _fires.clear()
	_world = Node2D.new()
	_world.name = "Village"
	add_child(_world)
	move_child(_world, _kodjo.get_index())
	var green := "" if dry else "_green"
	var grass := _amb.sway_material("grass")
	# Sous la bande de terre du sol, la terre continue (la caméra rapprochée la montre).
	var earth := ColorRect.new()
	earth.color = Color(0.4, 0.17, 0.1)
	earth.position = Vector2(-600, 362)
	earth.size = Vector2(2600, 240)
	earth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(earth)

	# Le champ de mil, avec le cultivateur au milieu (une rangée derrière lui, une devant).
	for row in 2:
		var x := -80.0 + row * 3.0
		while x < 232.0:
			var stalk := Sprite2D.new()
			stalk.texture = load(STORY_DIR + ("millet_dry_%d.png" if dry else "millet_%d.png") % randi_range(0, 3))
			stalk.position = Vector2(x, GROUND_Y + 3.0 + row * 2.0 - 18.0).round()
			stalk.material = grass
			stalk.modulate = Color(0.78, 0.8, 0.78) if row == 0 else Color.WHITE
			stalk.flip_h = randf() < 0.5
			_world.add_child(stalk)
			x += randf_range(4.0, 7.0) if not dry else randf_range(6.0, 11.0)
		if row == 0:
			_villager("cultivateur", &"cultivateur_sad" if dry else &"hoe", 110.0)

	_place("baobab" + green, 262, 2.0, "baobab")
	_villager("ancien", &"ancien_sad" if dry else &"ancien_idle", 322.0)
	var hut := _place("hut_a", 360)
	_smoke_from(hut, dry)
	var line := _amb._make_clothesline(1)
	line.position = Vector2(410, GROUND_Y)
	_world.add_child(line)
	if dry:
		line.visible = false
	_villager("pileuse", &"pileuse_sad" if dry else &"pound", 462.0)
	var fire := _amb._make_fire()
	fire.position = Vector2(500, GROUND_Y)
	_world.add_child(fire)
	_fires.append(fire)
	if dry:
		fire.get_node("Flammes").hide()
		fire.get_node("Braises").emitting = false
		fire.get_node("Halo").hide()
	_place("granary", 540)
	var hut_b := _place("hut_b", 610)
	_smoke_from(hut_b, dry)
	_place("bush" + green, 660, 2.0, "bush")
	_villager("tambour", &"tambour_sad" if dry else &"drum", 700.0)
	_place("hut_a", 745)
	_place("pots", 790)
	_place("bush" + green, 845, 2.0, "bush")
	_place("fence", 905)
	# Le sanctuaire : l'autel, la Pierre de foudre, la case peinte du signe de Xɛvioso, un rônier.
	var shrine := _place("hut_a", ALTAR_X + 62.0)
	var mark := Sprite2D.new()
	mark.texture = preload("res://assets/ui/xevioso/emblem_small.png")
	mark.position = Vector2(0, 10)
	mark.modulate = Color(1.0, 0.92, 0.8, 0.9)
	shrine.add_child(mark)
	_place("ronier" + ("" if dry else ""), ALTAR_X + 130.0, 2.0, "ronier")
	_place("altar", ALTAR_X)
	_stone_hover = false
	if not dry:
		_stone = _make_stone()
		_stone.position = Vector2(ALTAR_X, STONE_Y)
		_stone_hover = true
		_lit.add_child(_stone)
		_world.tree_exiting.connect(func() -> void:
			if is_instance_valid(_stone): _stone.queue_free())
		_villager("pretre", &"ancien_idle", ALTAR_X - 34.0)
	# Fleurs et touffes d'herbe tout du long ; la terre fendue s'il fait sec.
	if not dry:
		for i in 12:
			_place(["flower_red", "flower_yellow", "flower_white"][i % 3], randf_range(240.0, 1100.0), 1.0, "flower")
	var gx := -100.0
	while gx < 1250.0:
		_place("grass_%d%s" % [randi_range(0, 3), green], gx, 1.0, "grass")
		gx += randf_range(14.0, 26.0) if not dry else randf_range(26.0, 44.0)
	if dry:
		_cracks()
		_dust()
	# La porteuse d'eau descend le village ; les enfants courent après les poules.
	var porteuse := _villager("porteuse", &"porteuse_sad" if dry else &"walk_jar", 900.0 if not dry else 575.0)
	if not dry:
		porteuse.flip_h = true
		_porteuse_walk = create_tween()
		_porteuse_walk.tween_property(porteuse, "position:x", 575.0, 30.0)
	_villager("garcon", &"garcon_sad" if dry else &"garcon_run", 640.0 if not dry else 425.0)
	_villager("fille", &"fille_sad" if dry else &"fille_run", 610.0 if not dry else 437.0)
	if dry:
		_v["fille"].flip_h = true
	else:
		for i in 4:
			_hen(560.0 + i * 38.0, i % 2)
	# Rideaux de pluie et lucioles (suivent la caméra / restent au village).
	for old in [_rain_light, _rain_heavy]:
		if is_instance_valid(old):
			old.queue_free()
	_rain_light = _make_rain(45, 0.5)
	_rain_heavy = _make_rain(150, 0.75)
	_fireflies = _make_fireflies()


func _place(file: String, x: float, sink: float = 2.0, sway: String = "") -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(DECOR + file + ".png")
	sprite.position = Vector2(x, GROUND_Y + sink - sprite.texture.get_height() / 2.0).round()
	if sway != "":
		sprite.material = _amb.sway_material(sway)
	_world.add_child(sprite)
	return sprite


func _smoke_from(hut: Sprite2D, dry: bool) -> void:
	if dry:
		return
	var smoke: CPUParticles2D = _amb._make_smoke()
	smoke.position = hut.position + Vector2(0, -hut.texture.get_height() / 2.0 + 4.0)
	_world.add_child(smoke)
	_world.move_child(smoke, hut.get_index())
	_smokes.append(smoke)


func _build_villager_frames() -> void:
	var sheet: Texture2D = load(STORY_DIR + "villagers.png")
	_villager_frames = SpriteFrames.new()
	_villager_frames.remove_animation(&"default")
	for anim in VILLAGER_ANIMS:
		var spec: Array = VILLAGER_ANIMS[anim]
		_villager_frames.add_animation(anim)
		_villager_frames.set_animation_speed(anim, spec[2])
		_villager_frames.set_animation_loop(anim, true)
		for c in spec[1]:
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(c * 40, spec[0] * 60, 40, 60)
			_villager_frames.add_frame(anim, region)


func _villager(role: String, anim: StringName, x: float) -> AnimatedSprite2D:
	var v := AnimatedSprite2D.new()
	v.sprite_frames = _villager_frames
	v.position = Vector2(x, GROUND_Y - 19.0)
	v.offset = Vector2(4, 0)
	v.play(anim)
	v.frame = randi() % v.sprite_frames.get_frame_count(anim)
	_world.add_child(v)
	_v[role] = v
	return v


## Les enfants se courent après, d'un bout à l'autre de la cour.
func _update_kids(_delta: float) -> void:
	if not _kids_running or not _v.has("garcon"):
		return
	var k: float = _time * 0.55
	var boy: AnimatedSprite2D = _v["garcon"]
	var girl: AnimatedSprite2D = _v["fille"]
	var bx: float = _kids_center + sin(k) * 95.0
	var gx: float = _kids_center + sin(k + 0.35) * 95.0
	boy.flip_h = cos(k) < 0.0
	girl.flip_h = cos(k + 0.35) < 0.0
	boy.position.x = bx
	girl.position.x = gx


func _spawn_flock() -> void:
	var flock := Node2D.new()
	var y := randf_range(140.0, 175.0)
	flock.position = Vector2(_camera.position.x + 360.0, y)
	for i in randi_range(3, 6):
		var bird := Sprite2D.new()
		bird.texture = preload("res://assets/decor/village/bird.png")
		bird.hframes = 4
		var row: int = (i + 1) / 2
		bird.position = Vector2(row * 9.0, row * 5.0 * (1 if i % 2 else -1))
		flock.add_child(bird)
	_world.add_child(flock)
	var fly := create_tween()
	fly.tween_method(func(k: float) -> void:
		flock.position.x = _camera.position.x + 360.0 - k * 900.0
		for b in flock.get_children():
			b.frame = int(_time * 9.0 + b.position.x) % 4,
		0.0, 1.0, 22.0)
	fly.tween_callback(flock.queue_free)


func _clouds(on: bool) -> void:
	if on and _clouds_layer == null:
		_clouds_layer = Parallax2D.new()
		_clouds_layer.scroll_scale = Vector2(0.06, 1.0)
		_clouds_layer.repeat_size = Vector2(640, 0)
		_clouds_layer.repeat_times = 3
		_clouds_layer.autoscroll = Vector2(-6.0, 0.0)
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = preload("res://assets/backgrounds/village/bg_clouds.png")
		sprite.position = Vector2(0, 112)
		_clouds_layer.add_child(sprite)
		_night.add_child(_clouds_layer)
		_night.move_child(_clouds_layer, 1)
	elif not on and _clouds_layer != null:
		_clouds_layer.queue_free()
		_clouds_layer = null


func _make_rain(amount: int, alpha: float) -> CPUParticles2D:
	var rain := CPUParticles2D.new()
	rain.texture = preload("res://assets/fx/raindrop.png")
	rain.emitting = false
	rain.amount = amount
	rain.lifetime = 1.0
	rain.position = Vector2(30, -200)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(400, 4)
	rain.direction = Vector2(-0.22, 1.0)
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 330.0
	rain.initial_velocity_max = 380.0
	rain.angle_min = 12.0
	rain.angle_max = 12.0
	rain.color = Color(0.8, 0.88, 1.0, alpha)
	rain.local_coords = true
	_camera.add_child(rain)
	return rain


func _make_fireflies() -> CPUParticles2D:
	var flies := CPUParticles2D.new()
	flies.texture = preload("res://assets/fx/ember.png")
	flies.emitting = false
	flies.amount = 24
	flies.lifetime = 4.0
	flies.position = Vector2(ALTAR_X - 160.0, GROUND_Y - 22.0)
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(300, 18)
	flies.direction = Vector2(0, -1)
	flies.spread = 180.0
	flies.gravity = Vector2.ZERO
	flies.initial_velocity_min = 3.0
	flies.initial_velocity_max = 9.0
	flies.scale_amount_min = 0.5
	flies.scale_amount_max = 0.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.8, 1.0, 0.4, 0.0))
	ramp.set_color(1, Color(0.8, 1.0, 0.4, 0.0))
	ramp.add_point(0.3, Color(0.85, 1.0, 0.45, 1.0))
	ramp.add_point(0.7, Color(0.85, 1.0, 0.45, 0.8))
	flies.color_ramp = ramp
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flies.material = add
	_world.add_child(flies)
	return flies


## Saison des pluies (collines et sol verdis) ou saison sèche (le décor d'origine).
func _season(green: bool) -> void:
	var path := "res://assets/backgrounds/village/"
	$Night/Mid/Image.texture = load(path + ("bg_mid_green.png" if green else "bg_mid.png"))
	$Night/Near/Image.texture = load(path + ("bg_near_green.png" if green else "bg_near.png"))
	$Night/Ground/Image.texture = load(STORY_DIR + "ground_green.png") if green \
		else load("res://assets/ui/title/ground.png")


## Tout ce qui se balance s'immobilise (le vent est tombé), ou repart.
func _set_idle_sway(on: bool) -> void:
	for kind in Ambience.SWAY:
		var m := _amb.sway_material(kind)
		if m != null:
			m.set_shader_parameter("idle_sway", Ambience.SWAY[kind][2] if on else 0.0)


## La terre fendue par la soif.
func _cracks() -> void:
	for i in 26:
		var crack := Line2D.new()
		crack.width = 1.0
		crack.default_color = Color(0.22, 0.09, 0.05, 0.85)
		var p := Vector2(randf_range(-80.0, 1200.0), GROUND_Y + randf_range(8.0, 50.0)).round()
		crack.add_point(p)
		for k in randi_range(3, 6):
			p += Vector2(randi_range(-7, 7), randi_range(0, 4))
			crack.add_point(p)
		_world.add_child(crack)


## Le vent sec chasse la poussière.
func _dust() -> void:
	var dust := CPUParticles2D.new()
	dust.texture = preload("res://assets/fx/smoke.png")
	dust.amount = 34
	dust.lifetime = 4.0
	dust.preprocess = 4.0
	dust.position = Vector2(260, 0)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(10, 50)
	dust.direction = Vector2(-1, -0.05)
	dust.spread = 8.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 170.0
	dust.initial_velocity_max = 240.0
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.3
	dust.color = Color(0.85, 0.64, 0.45, 0.28)
	dust.local_coords = true
	_camera.add_child(dust)
	_world.tree_exiting.connect(dust.queue_free)


func _hen(x: float, variant: int) -> void:
	var hen := Hen.new()
	hen.sprite_frames = _hen_frames(variant)
	hen.position = Vector2(x, GROUND_Y - 5.0)
	hen.home = x
	hen.target = x
	hen.flip_h = randf() < 0.5
	hen.play(&"idle")
	_world.add_child(hen)
	_hens.append(hen)


func _hen_frames(variant: int) -> SpriteFrames:
	var sheet: Texture2D = load(DECOR + "chicken_%s.png" % ["white", "red"][variant])
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in [["idle", [0], 2.0, true], ["peck", [1, 2, 2, 1, 0], 10.0, false],
			["walk", [3, 4, 5, 6], 8.0, true], ["flap", [7, 8], 14.0, true]]:
		frames.add_animation(anim[0])
		frames.set_animation_speed(anim[0], anim[2])
		frames.set_animation_loop(anim[0], anim[3])
		for i in anim[1]:
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(i * 16, 0, 16, 12)
			frames.add_frame(anim[0], region)
	return frames


## Une poule de la cour : elle picore, fait quelques pas, et s'enfuit quand un enfant arrive.
class Hen:
	extends AnimatedSprite2D
	var home: float = 0.0
	var target: float = 0.0
	var timer: float = 1.0
	var fleeing: float = 0.0

	func tick(delta: float, threats: Array) -> void:
		if not visible:
			return
		if fleeing <= 0.0:
			for t in threats:
				if t is Node2D and t.visible and absf(t.position.x - position.x) < 26.0:
					var away: float = signf(position.x - t.position.x)
					if away == 0.0:
						away = 1.0
					target = clampf(position.x + away * 40.0, home - 70.0, home + 70.0)
					flip_h = away < 0.0
					fleeing = 0.7
					play(&"flap")
					break
		if fleeing > 0.0:
			fleeing -= delta
			position.x = move_toward(position.x, target, 90.0 * delta)
			offset.y = -absf(sin(fleeing * 14.0)) * 4.0
			if fleeing <= 0.0:
				offset.y = 0.0
				play(&"idle")
				timer = 0.6
			return
		if animation == &"walk":
			position.x = move_toward(position.x, target, 14.0 * delta)
			if absf(position.x - target) < 0.5:
				play(&"idle")
			return
		timer -= delta
		if timer <= 0.0:
			timer = randf_range(0.8, 2.2)
			var r := randf()
			if r < 0.45:
				play(&"peck")
			elif r < 0.8:
				target = clampf(position.x + randf_range(-24.0, 24.0), home - 50.0, home + 50.0)
				flip_h = target < position.x
				play(&"walk")


# ---------------------------------------------------------------------------
# Adaka, la pierre, les nuages
# ---------------------------------------------------------------------------

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
	for anim in ADAKA_ANIMS:
		frames.add_animation(anim[0])
		frames.set_animation_speed(anim[0], anim[3])
		frames.set_animation_loop(anim[0], anim[4])
		for c in anim[2]:
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(c * 96, anim[1] * 128, 96, 128)
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
		_lit.add_child(shard)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var target := Vector2(at.x + side * randf_range(280.0, 480.0), randf_range(-60.0, 140.0))
		var lift: float = randf_range(50.0, 130.0)
		var duration: float = randf_range(1.2, 1.8)
		var tween := create_tween().set_parallel(true)
		tween.tween_method(func(t: float) -> void:
			shard.position = at.lerp(target, t) + Vector2(0, -sin(t * PI) * lift),
			0.0, 1.0, duration)
		tween.tween_property(shard, "rotation", side * randf_range(4.0, 9.0), duration)
		tween.chain().tween_callback(shard.queue_free)


## Les derniers nuages, au-dessus du sanctuaire, la nuit du vol.
func _spawn_night_clouds() -> void:
	_night_clouds.clear()
	var sheet: Texture2D = preload("res://assets/backgrounds/village/bg_clouds.png")
	for i in 4:
		var cloud := Sprite2D.new()
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = Rect2(i * 160, 0, 160, 110)
		cloud.texture = tex
		cloud.position = Vector2(ALTAR_X - 300.0 + i * 160.0, 150.0 + (i % 2) * 10.0)
		cloud.modulate = Color(2.2, 2.2, 2.8)
		_world.add_child(cloud)
		_world.move_child(cloud, 0)
		create_tween().tween_property(cloud, "offset:x", -30.0, 30.0)
		_night_clouds.append(cloud)


## Les nuages sont aspirés, un à un, jusqu'à la gueule d'Adaka.
func _swallow_clouds(mouth: Vector2) -> void:
	for i in _night_clouds.size():
		var cloud := _night_clouds[i]
		if not is_instance_valid(cloud):
			continue
		_world.move_child(cloud, _world.get_child_count() - 1)
		var delay: float = 0.3 + i * 0.5
		var tween := create_tween().set_parallel(true)
		tween.tween_property(cloud, "position", mouth, 2.2).set_delay(delay) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(cloud, "scale", Vector2(0.04, 0.04), 2.2).set_delay(delay) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(cloud.queue_free)


# ---------------------------------------------------------------------------
# Le conteur
# ---------------------------------------------------------------------------

func _build_caption() -> void:
	_caption = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.07, 0.8)
	style.border_color = Color(0.85, 0.66, 0.32, 0.85)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_caption.add_theme_stylebox_override("panel", style)
	_caption.anchor_left = 0.0
	_caption.anchor_right = 1.0
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_left = 40
	_caption.offset_right = -40
	_caption.offset_top = -64
	_caption.offset_bottom = -8
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
	_ui.move_child(_caption, _flash.get_index())   # sous le flash, le fondu et « Passer »
	_caption_next = Label.new()
	_caption_next.text = "▼"
	_caption_next.add_theme_font_size_override("font_size", 8)
	_caption_next.add_theme_color_override("font_color", Color(0.85, 0.66, 0.32))
	_caption_next.anchor_left = 1.0
	_caption_next.anchor_right = 1.0
	_caption_next.anchor_top = 1.0
	_caption_next.anchor_bottom = 1.0
	_caption_next.offset_left = -54
	_caption_next.offset_top = -22
	_caption_next.offset_right = -44
	_caption_next.offset_bottom = -10
	_caption_next.visible = false
	_ui.add_child(_caption_next)


## Le conteur dit une phrase, lentement, puis laisse le temps de la lire.
func _tell(part: StringName, index: int) -> void:
	if _leaving:
		return
	var text: String = Voices.STORY[part][index]
	_caption.visible = true
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.4)
	_caption_label.text = text
	_caption_label.visible_ratio = 0.0
	_caption_next.visible = false
	_advance_requested = false
	# Le texte s'écrit (24 caractères par seconde) ; un toucher l'affiche en entier.
	var shown := 0.0
	while shown < 1.0 and not _leaving:
		await get_tree().process_frame
		if _advance_requested:
			break
		shown += get_process_delta_time() * 24.0 / text.length()
		_caption_label.visible_ratio = shown
	_caption_label.visible_ratio = 1.0
	_advance_requested = false
	_caption_next.visible = true
	# Temps de lecture généreux, sauf si on demande à avancer.
	var reading: float = clampf(1.6 + text.length() * 0.05, 4.0, 9.0)
	var waited := 0.0
	while waited < reading and not _advance_requested and not _leaving:
		await get_tree().process_frame
		waited += get_process_delta_time()
		_caption_next.modulate.a = 0.5 + 0.5 * sin(_time * 5.0)
	_advance_requested = false
	_caption_next.visible = false
	if _leaving:
		return
	await create_tween().tween_property(_caption, "modulate:a", 0.0, 0.35).finished
	_caption.visible = false
	await _pause(0.5)


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
# Transitions, lumière, caméra
# ---------------------------------------------------------------------------

func _pause(seconds: float) -> void:
	if _leaving:
		return
	await get_tree().create_timer(seconds).timeout


func _fade_in(duration: float = 1.0) -> void:
	await create_tween().tween_property(_fade, "color:a", 0.0, duration).finished


func _fade_out(duration: float = 1.0) -> void:
	await create_tween().tween_property(_fade, "color:a", 1.0, duration).finished
	_caption.visible = false


func _strike(strength: float) -> void:
	_flash.color.a = strength
	create_tween().tween_property(_flash, "color:a", 0.0, 0.4)


## La caméra tremble un instant (la terre gronde).
func _shake(strength: float, duration: float) -> void:
	var tween := create_tween()
	var steps := int(duration / 0.04)
	for i in steps:
		var k: float = 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k
		tween.tween_property(_camera, "offset", offset.round(), 0.04)
	tween.tween_property(_camera, "offset", Vector2.ZERO, 0.04)


## « Passer » en haut à droite pendant le conteur (le bas lui appartient),
## en bas à droite pendant que Xɛvioso parle (sa boîte est en haut).
func _skip_at_top(top: bool) -> void:
	_skip.anchor_top = 0.0 if top else 1.0
	_skip.anchor_bottom = _skip.anchor_top
	_skip.offset_top = 8.0 if top else -34.0
	_skip.offset_bottom = 32.0 if top else -10.0


## Fin de la scène (ou « Passer ») : un dernier éclair, fondu au noir, premier niveau.
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_skip.disabled = true
	if _box != null:
		_box.queue_free()
		_box = null
	_strike(1.0)
	await create_tween().tween_property(_fade, "color:a", 1.0, 1.0).finished
	Game.go_to_level(Game.FIRST_LEVEL)
