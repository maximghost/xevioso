extends CanvasLayer
## Interface en jeu : les cœurs, le nom du héros joué, le compteur de pierres sokpe,
## la jauge de la foudre de Xɛvioso, et les messages brefs (point de contrôle, nouveau héros).
##
## Le HUD ne fait qu'afficher : il écoute les signaux du Player et de sa Health,
## il ne modifie rien. On peut donc le retirer ou le refaire sans toucher au jeu.


## Le héros à suivre.
@export var player: Player

## Cœur plein et cœur vide.
@export var heart_full: Texture2D = preload("res://assets/ui/hud/heart_full.png")
@export var heart_empty: Texture2D = preload("res://assets/ui/hud/heart_empty.png")

@onready var _hearts: HBoxContainer = $Margin/Box/Top/Hearts
@onready var _hero_name: Label = $Margin/Box/HeroName
@onready var _sokpe_count: Label = $Margin/Box/Sokpe/Count
@onready var _toast: Label = $Toast
@onready var _lives: HBoxContainer = $Margin/Box/Top/Lives

const LIFE_FULL := preload("res://assets/ui/xevioso/vie.png")
const LIFE_LOST := preload("res://assets/ui/xevioso/vie_perdue.png")

# L'animation du message en cours (pour l'interrompre si un autre arrive).
var _toast_tween: Tween

# Dernier cœur : un voile rouge palpite sur les bords de l'écran, comme un cœur qui bat.
var _vignette: TextureRect
var _danger: bool = false
var _beat_time: float = 0.0


func _ready() -> void:
	# Pierres sokpe et messages : ils viennent de Game, même sans héros.
	Game.sokpe_changed.connect(_on_sokpe_changed)
	Game.message.connect(show_message)
	Game.lives_changed.connect(_on_lives_changed)
	_on_lives_changed(Game.lives)
	_on_sokpe_changed(Game.total_sokpe())
	_toast.modulate.a = 0.0
	_vignette = TextureRect.new()
	_vignette.texture = preload("res://assets/ui/hud/vignette.png")
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	move_child(_vignette, 0)   # sous les cœurs et les messages
	# Jauge de la foudre, juste sous le compteur de pierres.
	var gauge := LightningGauge.new()
	var box: Node = $Margin/Box
	box.add_child(gauge)
	box.move_child(gauge, $Margin/Box/Sokpe.get_index() + 1)
	if player == null:
		push_warning("HUD : aucun Player renseigné dans l'inspecteur.")
		return
	player.health.changed.connect(_on_health_changed)
	player.hero_changed.connect(_on_hero_changed)
	# Affichage initial (le Player est peut-être prêt avant le HUD).
	_on_health_changed(player.health.current, player.health.max_health)
	if player.current_hero() != null:
		_on_hero_changed(player.current_hero())


## Redessine la rangée de cœurs : pleins d'abord, puis vides.
func _on_health_changed(current: int, maximum: int) -> void:
	_danger = current == 1 and maximum > 1
	# Ajuste le nombre de cœurs au maximum (il pourra augmenter en cours de jeu).
	while _hearts.get_child_count() < maximum:
		var heart := TextureRect.new()
		heart.stretch_mode = TextureRect.STRETCH_KEEP
		_hearts.add_child(heart)
	while _hearts.get_child_count() > maximum:
		var extra := _hearts.get_child(_hearts.get_child_count() - 1)
		_hearts.remove_child(extra)
		extra.queue_free()

	for i in maximum:
		var heart: TextureRect = _hearts.get_child(i)
		var was_full: bool = heart.texture == heart_full
		heart.texture = heart_full if i < current else heart_empty
		# Le cœur qui vient d'être perdu sursaute : on voit tout de suite le coup.
		if was_full and i >= current:
			heart.pivot_offset = heart.size / 2.0
			heart.scale = Vector2(1.6, 1.6)
			create_tween().tween_property(heart, "scale", Vector2.ONE, 0.2)


func _on_hero_changed(hero: HeroData) -> void:
	_hero_name.text = hero.display_name


## Les vies : une petite hache double par vie, éteinte quand elle est perdue.
func _on_lives_changed(lives: int) -> void:
	for child in _lives.get_children():
		child.queue_free()
	for i in Game.LIVES_PER_LEVEL:
		var icon := TextureRect.new()
		icon.texture = LIFE_FULL if i < lives else LIFE_LOST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_lives.add_child(icon)


func _on_sokpe_changed(total: int) -> void:
	var was: String = _sokpe_count.text
	_sokpe_count.text = str(total)
	# Le compteur sursaute quand on ramasse une pierre.
	if was != "" and was != str(total):
		_sokpe_count.pivot_offset = _sokpe_count.size / 2.0
		_sokpe_count.scale = Vector2(1.5, 1.5)
		create_tween().tween_property(_sokpe_count, "scale", Vector2.ONE, 0.2)


## Affiche un message en haut de l'écran pendant deux secondes, puis l'efface.
## Battement du dernier cœur : deux pulsations rapprochées par seconde (« boum-boum »).
func _process(delta: float) -> void:
	if _vignette == null:
		return
	if not _danger:
		_vignette.modulate.a = move_toward(_vignette.modulate.a, 0.0, delta * 2.0)
		if _hearts.get_child_count() > 0:
			(_hearts.get_child(0) as TextureRect).scale = Vector2.ONE
		return
	_beat_time = fmod(_beat_time + delta, 1.0)
	var beat: float = maxf(exp(-pow((_beat_time - 0.1) * 14.0, 2.0)), 0.7 * exp(-pow((_beat_time - 0.32) * 14.0, 2.0)))
	_vignette.modulate.a = 0.15 + 0.3 * beat
	if _hearts.get_child_count() > 0:
		var heart: TextureRect = _hearts.get_child(0)
		heart.pivot_offset = heart.size / 2.0
		heart.scale = Vector2.ONE * (1.0 + 0.25 * beat)


func show_message(text: String) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
