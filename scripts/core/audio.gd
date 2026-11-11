extends Node
## L'audio du jeu : musiques, ambiances et bruitages (tous originaux, calculés ; voir le README).
##
## Trois bus sous « Master » : Musique, Effets et Ambiance, réglables séparément
## (menu pause) ; les réglages sont gardés dans user://reglages.cfg (pas dans la sauvegarde :
## une nouvelle partie ne les efface pas).
##
##   Audio.play(&"jump")                    bruitage (une variante tirée au hasard, hauteur variée)
##   Audio.play_at(&"enemy_hit", position)  bruitage placé dans le monde (s'atténue avec la distance)
##   Audio.loop_on(noeud, &"locust_buzz")   boucle attachée à un nœud (s'arrête avec lui)
##   Audio.music(&"village")                musique en boucle, fondu enchaîné avec la précédente
##   Audio.jingle(&"victoire")              jingle : la musique s'efface pendant qu'il joue
##   Audio.ambience([&"wind_dry"])          ambiances en boucle (celles qui ne sont plus listées s'éteignent)

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMB_DIR := "res://assets/audio/amb/"
const SETTINGS_PATH := "user://reglages.cfg"

## Nombre de variantes des bruitages qui en ont (fichiers nom_1 ... nom_n).
const VARIANTS := {
	&"step": 4, &"jump": 2, &"land": 2, &"throw": 2, &"hurt": 2, &"enemy_hit": 2,
	&"thunder_far": 2, &"thunder_close": 2, &"chicken": 3,
}

## Volume de base de chaque bruitage, en dB (équilibre du mixage).
const SFX_DB := {
	&"step": -15.0, &"jump": -9.0, &"land": -10.0, &"land_hard": -6.0, &"throw": -7.0,
	&"axe_whirr": -16.0, &"axe_hit": -4.0, &"axe_fizzle": -9.0, &"dash": -3.0,
	&"glide_open": -6.0, &"glide_loop": -14.0, &"glide_close": -8.0, &"hurt": -3.0,
	&"death": -2.0, &"fall_void": -5.0, &"respawn": -6.0, &"switch": -6.0,
	&"lightning_cast": 0.0, &"lightning_ready": -5.0, &"sokpe": -4.0, &"checkpoint": -4.0,
	&"hero_unlock": -3.0, &"hammer_slam": -2.0, &"grapple_throw": -6.0, &"grapple_attach": -6.0,
	&"wave": -3.0, &"enemy_hit": -6.0, &"crawler_die": -5.0, &"locust_buzz": -14.0,
	&"locust_die": -6.0, &"spitter_spit": -7.0, &"clod_splat": -8.0, &"spitter_die": -4.0,
	&"enemy_poof": -8.0, &"crumble_crack": -6.0, &"crumble_fall": -6.0, &"block_smash": -3.0,
	&"gate_open": -5.0, &"drum_target": -3.0, &"bloom": -2.0, &"thunder_far": -5.0,
	&"thunder_close": -2.0, &"wrath": 0.0, &"ui_click": -8.0, &"ui_move": -12.0,
	&"ui_back": -9.0, &"pause_open": -8.0, &"pause_close": -8.0, &"dialogue_open": -8.0,
	&"dialogue_next": -10.0, &"text_tick": -22.0, &"caption_next": -12.0, &"game_start": -3.0,
	&"stone_shatter": 0.0, &"adaka_appear": -3.0, &"adaka_inhale": -2.0, &"adaka_laugh": -3.0,
	&"wind_stop": -6.0, &"emblem_appear": -2.0, &"designate": -1.0, &"chicken": -12.0,
	&"chicken_flap": -10.0, &"drum_roll": -4.0, &"heartbeat": -4.0, &"bounce": -4.0, &"vine_swish": -3.0, &"tree_groan": -5.0, &"fire": -10.0, &"stone_hum": -16.0,
}

## Volume de base de chaque ambiance (dB).
const AMB_DB := {
	&"wind_dry": -14.0, &"storm_wind": -11.0, &"village_day": -12.0, &"rain": -9.0,
	&"night": -14.0, &"fire": -12.0,
}

## Volume de base de chaque musique (dB) : elles sont déjà égalisées à l'écoute (-16 LUFS).
const MUSIC_DB := -6.0

var _pool: Array[AudioStreamPlayer] = []
var _pool_next: int = 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_current: int = 0
var _music_name: StringName = &""
var _ambiences: Dictionary = {}          # nom -> AudioStreamPlayer
var _cache: Dictionary = {}              # chemin -> AudioStream
var _volumes := {"Musique": 0.8, "Effets": 0.9, "Ambiance": 0.8}
var _last_played: Dictionary = {}        # nom -> instant (évite les doublons dans la même image)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # la musique et l'interface continuent en pause
	# Les bus sont décrits dans res://default_bus_layout.tres, chargé au démarrage : les créer
	# en cours de jeu désorganise le graphe audio du navigateur (export web) et tout se tait.
	for bus in ["Musique", "Effets", "Ambiance"]:
		if AudioServer.get_bus_index(bus) == -1:
			push_warning("Bus audio manquant : " + bus)
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = &"Effets"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Musique"
		add_child(m)
		_music_players.append(m)
	_load_settings()
	if OS.has_feature("web"):
		_unlock_web_audio()
	# Tous les boutons du jeu (menus, écrans de fin) font un petit bruit de calebasse.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node is TouchScreenButton:
		var born := Time.get_ticks_msec()
		node.pressed.connect(func() -> void: play(&"ui_click", 0.0, 0.04))
		node.focus_entered.connect(func() -> void:
			# Pas de bruit pour le bouton sélectionné d'office à l'ouverture d'un écran.
			if Time.get_ticks_msec() - born > 250:
				play(&"ui_move", 0.0, 0.05))


# ---------------------------------------------------------------------------
# Bruitages
# ---------------------------------------------------------------------------

## Joue un bruitage (non placé dans le monde). « pitch » : variation aléatoire de hauteur.
func play(sound: StringName, volume_db: float = 0.0, pitch: float = 0.06) -> AudioStreamPlayer:
	var stream := _sfx_stream(sound)
	if stream == null or _too_soon(sound):
		return null
	var p := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = SFX_DB.get(sound, -6.0) + volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch, pitch)
	p.play()
	return p


## Joue un bruitage placé dans le monde : plus faible quand il est loin de la caméra.
func play_at(sound: StringName, where: Vector2, volume_db: float = 0.0, pitch: float = 0.08) -> AudioStreamPlayer2D:
	var stream := _sfx_stream(sound)
	var scene := get_tree().current_scene
	if stream == null or scene == null or _too_soon(sound):
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = &"Effets"
	p.volume_db = SFX_DB.get(sound, -6.0) + volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch, pitch)
	p.max_distance = 720.0
	p.attenuation = 1.6
	p.panning_strength = 0.6
	scene.add_child(p)
	p.global_position = where
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Boucle sonore attachée à un nœud du monde (bourdonnement, feu...) ; elle disparaît avec lui.
func loop_on(node: Node2D, sound: StringName, volume_db: float = 0.0, distance: float = 420.0) -> AudioStreamPlayer2D:
	var path := SFX_DIR + String(sound) + ".ogg"
	if not ResourceLoader.exists(path):
		path = AMB_DIR + String(sound) + ".ogg"
	var stream := _stream(path, true)
	if stream == null:
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = &"Effets"
	p.volume_db = SFX_DB.get(sound, -10.0) + volume_db
	p.max_distance = distance
	p.attenuation = 2.0
	p.panning_strength = 0.6
	# Démarre dès que le nœud est dans l'arbre (tout de suite s'il y est déjà).
	p.ready.connect(func() -> void: p.play(_loop_start(stream)), CONNECT_ONE_SHOT)
	node.add_child(p)
	return p


## Où démarrer une boucle : au hasard sur ordinateur (deux boucles identiques ne jouent pas
## la même chose en même temps) ; au début sur le web, qui reprend chaque tour de boucle
## à l'endroit du premier départ (un départ au milieu couperait le début de la boucle).
func _loop_start(stream: AudioStream) -> float:
	return 0.0 if OS.has_feature("web") else randf() * stream.get_length()


func _sfx_stream(sound: StringName) -> AudioStream:
	var file := String(sound)
	if VARIANTS.has(sound):
		file += "_%d" % randi_range(1, VARIANTS[sound])
	return _stream(SFX_DIR + file + ".ogg", false)


## Le même bruitage deux fois dans la même image (deux ennemis touchés ensemble) : un seul suffit.
func _too_soon(sound: StringName) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 30:
		return true
	_last_played[sound] = now
	return false


func _stream(path: String, loop: bool) -> AudioStream:
	var key := path + ("#loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(path):
		push_warning("Son introuvable : " + path)
		_cache[key] = null
		return null
	# Les boucles (musiques, ambiances, vrombissements) sont réglées dans les fichiers .import
	# (loop=true) : sur le web, le son est joué d'après ce réglage d'import ; une copie
	# modifiée en cours de jeu n'y changerait rien.
	var stream: AudioStream = load(path)
	if loop and stream is AudioStreamOggVorbis and not stream.loop:
		push_warning("Boucle non réglée à l'import : " + path)
	_cache[key] = stream
	return stream


# ---------------------------------------------------------------------------
# Musique
# ---------------------------------------------------------------------------

## Lance une musique en boucle avec un fondu enchaîné. La même musique déjà en cours continue.
func music(track: StringName, fade: float = 1.5) -> void:
	if track == _music_name and _music_players[_music_current].playing:
		return
	_music_name = track
	var stream := _stream(MUSIC_DIR + String(track) + ".ogg", true)
	var old := _music_players[_music_current]
	_music_current = 1 - _music_current
	var fresh := _music_players[_music_current]
	_fade_out(old, fade)
	if stream == null:
		return
	fresh.stream = stream
	fresh.volume_db = -40.0
	fresh.play()
	_tween_volume(fresh, MUSIC_DB, fade)


## Arrête la musique en fondu.
func stop_music(fade: float = 1.5) -> void:
	_music_name = &""
	for p in _music_players:
		_fade_out(p, fade)


## Un jingle (victoire, fin de partie) : la musique en cours s'efface, le jingle passe, et
## « then » (facultatif) prend la suite.
func jingle(track: StringName, then: StringName = &"") -> void:
	stop_music(0.4)
	var stream := _stream(MUSIC_DIR + String(track) + ".ogg", false)
	if stream == null:
		return
	var p := _music_players[_music_current]
	p.stream = stream
	p.volume_db = MUSIC_DB + 2.0
	p.play()
	if then != &"":
		await get_tree().create_timer(stream.get_length() - 0.5, true, false, true).timeout
		music(then, 2.0)


func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	if not p.playing:
		return
	var tween := create_tween()
	tween.tween_property(p, "volume_db", -50.0, maxf(fade, 0.05))
	tween.tween_callback(p.stop)


func _tween_volume(p: Node, db: float, fade: float) -> void:
	create_tween().tween_property(p, "volume_db", db, maxf(fade, 0.05))


# ---------------------------------------------------------------------------
# Ambiances
# ---------------------------------------------------------------------------

## Fait jouer exactement ces ambiances (fondu d'entrée ; les autres s'éteignent en fondu).
func ambience(names: Array, fade: float = 2.0) -> void:
	for amb_name in _ambiences.keys():
		if not amb_name in names:
			var p: AudioStreamPlayer = _ambiences[amb_name]
			_ambiences.erase(amb_name)
			var tween := create_tween()
			tween.tween_property(p, "volume_db", -50.0, fade)
			tween.tween_callback(p.queue_free)
	for amb_name in names:
		if _ambiences.has(amb_name):
			continue
		var stream := _stream(AMB_DIR + String(amb_name) + ".ogg", true)
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.bus = &"Ambiance"
		p.stream = stream
		p.volume_db = -40.0
		add_child(p)
		p.play(_loop_start(stream))
		_tween_volume(p, AMB_DB.get(amb_name, -12.0), fade)
		_ambiences[amb_name] = p


# ---------------------------------------------------------------------------
# Réglages de volume
# ---------------------------------------------------------------------------

## Volume d'un bus (« Musique », « Effets », « Ambiance »), de 0 à 1.
func get_volume(bus: String) -> float:
	return _volumes.get(bus, 1.0)


func set_volume(bus: String, value: float, save: bool = true) -> void:
	value = clampf(value, 0.0, 1.0)
	_volumes[bus] = value
	var i := AudioServer.get_bus_index(bus)
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(value, 0.0001)))
		AudioServer.set_bus_mute(i, value <= 0.001)
	if save:
		_save_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for bus in _volumes:
			_volumes[bus] = float(cfg.get_value("audio", bus, _volumes[bus]))
	for bus in _volumes:
		set_volume(bus, _volumes[bus], false)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in _volumes:
		cfg.set_value("audio", bus, _volumes[bus])
	cfg.save(SETTINGS_PATH)


# ---------------------------------------------------------------------------
# Navigateurs mobiles
# ---------------------------------------------------------------------------

## Sur iPhone, le son d'une page web est coupé tant que le téléphone est en mode silencieux,
## et il n'est autorisé qu'après un geste du joueur. Au premier toucher (dans le geste
## lui-même, côté navigateur), on déclare la page comme lecteur de média : un petit fichier
## silencieux joué en boucle, et la « session audio » de Safari mise en lecture.
## Le son du jeu passe alors même en mode silencieux, comme une vidéo.
func _unlock_web_audio() -> void:
	JavaScriptBridge.eval("""
	(function () {
		if (window.__xevAudioUnlock) { return; }
		window.__xevAudioUnlock = true;
		var unlock = function () {
			try { if (navigator.audioSession) { navigator.audioSession.type = 'playback'; } } catch (e) {}
			try {
				var a = document.createElement('audio');
				a.setAttribute('x-webkit-airplay', 'deny');
				a.setAttribute('playsinline', '');
				a.loop = true;
				a.src = 'data:audio/mpeg;base64,SILENCE';
				a.play().catch(function () {});
			} catch (e) {}
			['touchend', 'click', 'keydown'].forEach(function (t) { document.removeEventListener(t, unlock, true); });
		};
		['touchend', 'click', 'keydown'].forEach(function (t) { document.addEventListener(t, unlock, true); });
	})();
	""".replace("SILENCE", "SUQzBAAAAAAAI1RTU0UAAAAPAAADTGF2ZjYwLjE2LjEwMAAAAAAAAAAAAAAA//NwwAAAAAAAAAAAAEluZm8AAAAPAAAAFgAABTQALCwsLDc3Nzc3QUFBQUtLS0tLVVVVVV9fX19faWlpaXNzc3NzfX19fYeHh4eHkZGRkZubm5ubpaWlpaWvr6+vubm5ubnDw8PDzc3Nzc3X19fX4eHh4eHr6+vr9fX19fX/////AAAAAExhdmM2MC4zMQAAAAAAAAAAAAAAACQELwAAAAAAAAU0bbRwgwAAAAAAAAAAAAAAAAD/8yDEAAAAA0gAAAAATEFNRTMuMTAwVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV//MixCcAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVTEFNRTMuMTAwVVVVVVVVVVVVVVX/8yDETwAAA0gAAAAAVVVVVVVVVVVVVVVVVVVVVVVVVUxBTUUzLjEwMFVVVVVVVVVVVVVV//MgxHYAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVTEFNRTMuMTAwVVVVVVVVVVVVVf/zIMSdAAADSAAAAABVVVVVVVVVVVVVVVVVVVVVVVVVVUxBTUUzLjEwMFVVVVVVVVVVVVX/8yLExAAAA0gAAAAAVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVVVf/zIMTYAAADSAAAAABVVVVVVVVVVVVVVVVVVVVVVVVVTEFNRTMuMTAwVVVVVVVVVVVVVVX/8yDE2AAAA0gAAAAAVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV//MgxNgAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVTEFNRTMuMTAwVVVVVVVVVVVVVf/zIsTXAAADSAAAAABVVVVVVVVVVVVVVVVVVVVVVVVVVUxBTUUzLjEwMFVVVVVVVVVVVVVV//MgxNgAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVVVf/zIMTYAAADSAAAAABVVVVVVVVVVVVVVVVVVVVVVVVVVUxBTUUzLjEwMFVVVVVVVVVVVVX/8yDE2AAAA0gAAAAAVVVVVVVVVVVVVVVVVVVVVVVVVVVMQU1FMy4xMDBVVVVVVVVVVVVV//MixNcAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVTEFNRTMuMTAwVVVVVVVVVVVVVVX/8yDE2AAAA0gAAAAAVVVVVVVVVVVVVVVVVVVVVVVVVUxBTUUzLjEwMFVVVVVVVVVVVVVV//MgxNgAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVTEFNRTMuMTAwVVVVVVVVVVVVVf/zIMTYAAADSAAAAABVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVX/8yLE1wAAA0gAAAAAVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVf/zIMTYAAADSAAAAABVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVX/8yDE2AAAA0gAAAAAVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//MgxNgAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVf/zIsTXAAADSAAAAABVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"), true)
