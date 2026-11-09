extends Node
## Réglages d'affichage appliqués au démarrage (chargé automatiquement : Projet → Autoload).
##
## Le jeu est dessiné en 640 × 360 puis agrandi. Sur ordinateur, on garde un agrandissement
## par facteur entier (×2, ×3...) : les pixels sont parfaitement nets.
## Sur téléphone, la hauteur de l'écran est rarement un multiple de 360 : un facteur entier
## laisserait de grandes bandes noires. On passe donc à un agrandissement libre, qui remplit
## tout l'écran au prix de pixels très légèrement inégaux, invisibles à cette taille.
##
## Le jeu se joue en paysage. Un navigateur ne permet pas toujours d'imposer l'orientation
## (Safari sur iPhone l'interdit ; Chrome sur Android l'accepte seulement en plein écran).
## Donc, sur écran tactile, tant que l'appareil est tenu en portrait :
##   - le jeu se met en pause et un écran « Tourne ton téléphone » recouvre tout
##     (le décor n'est jamais affiché déformé) ;
##   - toucher cet écran demande le plein écran et le verrouillage en paysage (Android) ;
##   - dès que l'appareil est tourné, l'écran disparaît et le jeu reprend.
## Installé sur l'écran d'accueil (application web), le jeu s'ouvre directement en paysage.

var _overlay: CanvasLayer
var _phone: Control
var _portrait: bool = false
# Vrai si c'est nous qui avons mis le jeu en pause (on ne relance pas une pause du joueur).
var _paused_by_us: bool = false
var _time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # la surveillance continue pendant la pause
	if DisplayServer.is_touchscreen_available():
		get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		_build_overlay()
		get_window().size_changed.connect(_check_orientation)
		_check_orientation.call_deferred()


func _process(delta: float) -> void:
	if _overlay == null:
		return
	# Certains navigateurs signalent la rotation avec retard : on vérifie aussi ici.
	_check_orientation()
	if _portrait:
		_time += delta
		_phone.queue_redraw()


func _check_orientation() -> void:
	var size: Vector2i = get_window().size
	var portrait: bool = size.y > size.x
	if portrait == _portrait:
		return
	_portrait = portrait
	_overlay.visible = portrait
	if portrait:
		_time = 0.0
		if not get_tree().paused:
			get_tree().paused = true
			_paused_by_us = true
	elif _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 128                     # au-dessus de tout, menus compris
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.visible = false
	add_child(_overlay)

	var back := ColorRect.new()
	back.color = Color(0.07, 0.05, 0.09)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP   # les touchers ne traversent pas
	back.gui_input.connect(_on_overlay_input)
	_overlay.add_child(back)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(box)

	_phone = Control.new()
	_phone.custom_minimum_size = Vector2(220, 220)
	_phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.draw.connect(_draw_phone)
	box.add_child(_phone)

	var lines: Array = [["Tourne ton téléphone", 44, Color(1.0, 0.86, 0.45)],
			["Xɛvioso se joue en paysage", 28, Color(0.92, 0.88, 0.82)]]
	# Le plein écran n'existe que hors iPhone : inutile d'en parler à Safari.
	var ios: bool = OS.has_feature("web") and _is_ios()
	if OS.has_feature("web") and not ios:
		lines.append(["(touche l'écran pour passer en plein écran)", 22, Color(0.7, 0.66, 0.62)])
	for line in lines:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)


## Vrai sur iPhone ou iPad (Safari ne permet ni le plein écran ni le verrouillage).
func _is_ios() -> bool:
	var agent: Variant = JavaScriptBridge.eval("navigator.userAgent", true)
	if typeof(agent) != TYPE_STRING:
		return false
	if "iPhone" in agent or "iPad" in agent or "iPod" in agent:
		return true
	# Les iPad récents se présentent comme un Mac : on les reconnaît à leur écran tactile.
	return "Macintosh" in agent and DisplayServer.is_touchscreen_available()


## Un téléphone qui pivote du portrait au paysage, avec une flèche courbe, en boucle.
func _draw_phone() -> void:
	var c: Vector2 = _phone.size / 2.0
	var cycle: float = fmod(_time, 2.4) / 2.4
	# Pause en portrait, rotation douce, pause en paysage.
	var t: float = clampf((cycle - 0.25) / 0.4, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var angle: float = -PI / 2.0 * t
	var half := Vector2(42, 76)
	var corners: Array[Vector2] = [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	var body := PackedVector2Array()
	var screen := PackedVector2Array()
	for p in corners:
		body.append(c + p.rotated(angle))
		screen.append(c + (p * Vector2(0.78, 0.8)).rotated(angle))
	_phone.draw_colored_polygon(body, Color(0.92, 0.88, 0.82))
	_phone.draw_colored_polygon(screen, Color(0.18, 0.14, 0.22).lerp(Color(0.95, 0.7, 0.3), t * 0.6))
	_phone.draw_circle(c + Vector2(0, half.y - 8).rotated(angle), 4.0, Color(0.5, 0.46, 0.44))
	# Flèche courbe qui indique le sens de rotation.
	var arc_alpha: float = 1.0 - t * 0.7
	_phone.draw_arc(c, 104.0, -PI * 0.95, -PI * 0.6, 20, Color(1.0, 0.86, 0.45, arc_alpha), 6.0)
	var tip: Vector2 = c + Vector2.from_angle(-PI * 0.6) * 104.0
	_phone.draw_colored_polygon(PackedVector2Array([tip + Vector2(14, -6), tip + Vector2(-10, -12), tip + Vector2(2, 14)]),
		Color(1.0, 0.86, 0.45, arc_alpha))


## Un toucher sur l'écran de rotation : plein écran + verrouillage en paysage, si le
## navigateur l'accepte (Android). Sans effet ailleurs (Safari sur iPhone).
func _on_overlay_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not tapped or not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function () {
			var lock = function () {
				try {
					if (screen.orientation && screen.orientation.lock) {
						screen.orientation.lock('landscape').catch(function () {});
					}
				} catch (e) {}
			};
			var root = document.documentElement;
			if (!document.fullscreenElement && root.requestFullscreen) {
				root.requestFullscreen({ navigationUI: 'hide' }).then(lock).catch(lock);
			} else {
				lock();
			}
		})();
	""", true)
