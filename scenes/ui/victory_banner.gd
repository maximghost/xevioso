class_name VictoryBanner
extends CanvasLayer
## Bannière de victoire, à la fin d'un niveau : un bandeau sombre bordé d'or s'ouvre au
## milieu de l'écran, l'emblème de Xɛvioso flamboie, le titre surgit lettre par lettre,
## puis le bilan (pierres sokpe ramassées, vies restantes). Elle se referme seule.
##
##   var banner := VictoryBanner.new()
##   add_child(banner)
##   await banner.play("La pluie est revenue !", "Première étape accomplie", sokpe, total, vies)

signal finished

const GOLD := Color(1.0, 0.86, 0.45)

var _band: Control
var _time: float = 0.0
var _emblem_glow: TextureRect


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_time += delta
	if _emblem_glow != null:
		_emblem_glow.modulate.a = 0.55 + 0.25 * sin(_time * 3.0)


## Montre la bannière ; « hold » : durée d'affichage complet, en secondes.
func play(title: String, subtitle: String, sokpe: int, sokpe_total: int, lives: int,
		hold: float = 5.0) -> Signal:
	_build(title, subtitle, sokpe, sokpe_total, lives)
	_animate(hold)
	return finished


func _build(title: String, subtitle: String, sokpe: int, sokpe_total: int, lives: int) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Le bandeau : bord doré en haut et en bas.
	_band = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.1, 0.86)
	style.border_color = GOLD
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_band.add_theme_stylebox_override("panel", style)
	_band.anchor_left = 0.0
	_band.anchor_right = 1.0
	_band.anchor_top = 0.5
	_band.anchor_bottom = 0.5
	_band.offset_top = -68
	_band.offset_bottom = 68
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.pivot_offset = Vector2(320, 68)
	root.add_child(_band)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	_band.add_child(box)
	# L'emblème, avec son halo qui palpite.
	var emblem_holder := Control.new()
	emblem_holder.custom_minimum_size = Vector2(0, 36)
	box.add_child(emblem_holder)
	_emblem_glow = TextureRect.new()
	_emblem_glow.texture = preload("res://assets/ui/xevioso/emblem_glow.png")
	_emblem_glow.size = Vector2(64, 64)
	_emblem_glow.position = Vector2(320 - 32, -28)
	emblem_holder.add_child(_emblem_glow)
	var emblem := TextureRect.new()
	emblem.texture = preload("res://assets/ui/xevioso/emblem.png")
	emblem.size = Vector2(26, 26)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.position = Vector2(320 - 13, -9)
	emblem_holder.add_child(emblem)
	# Le titre : chaque lettre est un Label, pour les faire surgir une à une.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	box.add_child(row)
	var settings := LabelSettings.new()
	settings.font_size = 24
	settings.font_color = GOLD
	settings.outline_size = 6
	settings.outline_color = Color(0.12, 0.06, 0.04)
	settings.shadow_size = 0
	for ch in title.to_upper():
		var letter := Label.new()
		letter.text = ch
		letter.label_settings = settings
		letter.modulate.a = 0.0
		row.add_child(letter)
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	sub.add_theme_constant_override("outline_size", 3)
	sub.modulate.a = 0.0
	sub.name = "Sub"
	box.add_child(sub)
	# Le bilan : pierres sokpe et vies.
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 6)
	stats.modulate.a = 0.0
	stats.name = "Stats"
	box.add_child(stats)
	_stat(stats, preload("res://assets/props/sokpe.png"), "%d / %d" % [sokpe, sokpe_total])
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(18, 0)
	stats.add_child(gap)
	_stat(stats, preload("res://assets/ui/xevioso/vie.png"), "Vies : %d" % lives)


func _stat(parent: Container, icon: Texture2D, text: String) -> void:
	var image := TextureRect.new()
	image.texture = icon
	image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	parent.add_child(image)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)


func _animate(hold: float) -> void:
	# Le bandeau s'ouvre depuis une ligne.
	_band.scale = Vector2(1.0, 0.0)
	var open := create_tween()
	open.tween_property(_band, "scale:y", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await open.finished
	Audio.play(&"hero_unlock")
	# Les lettres surgissent une à une (petit rebond).
	var row: HBoxContainer = _band.get_child(0).get_child(1)
	for letter in row.get_children():
		letter.pivot_offset = Vector2(6, 14)
		letter.scale = Vector2(1.8, 1.8)
		var pop := create_tween().set_parallel(true)
		pop.tween_property(letter, "modulate:a", 1.0, 0.12)
		pop.tween_property(letter, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.035, true, false, true).timeout
	# Étincelles dorées qui montent du bandeau.
	var sparks := CPUParticles2D.new()
	sparks.texture = preload("res://assets/fx/ember.png")
	sparks.amount = 40
	sparks.lifetime = 1.6
	sparks.position = Vector2(320, 180)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(300, 40)
	sparks.direction = Vector2(0, -1)
	sparks.spread = 25.0
	sparks.gravity = Vector2(0, -10)
	sparks.initial_velocity_min = 10.0
	sparks.initial_velocity_max = 30.0
	sparks.color = GOLD
	add_child(sparks)
	move_child(sparks, 0)
	var box := _band.get_child(0)
	create_tween().tween_property(box.get_node("Sub"), "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(0.4, true, false, true).timeout
	create_tween().tween_property(box.get_node("Stats"), "modulate:a", 1.0, 0.4)
	Audio.play(&"sokpe", -4.0)
	await get_tree().create_timer(hold, true, false, true).timeout
	sparks.emitting = false
	var close := create_tween()
	close.tween_property(_band, "modulate:a", 0.0, 0.5)
	await close.finished
	finished.emit()
	queue_free()
