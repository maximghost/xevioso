class_name FallingLeaves
extends CPUParticles2D
## Des feuilles tombent de la canopée tout autour de la caméra, en tournoyant. Sèches et
## grises tant que la forêt est malade ; quand Xɛvioso la reprend (heal), vertes et dorées.

const LEAF := preload("res://assets/props/foret/feuille.png")


func _ready() -> void:
	add_to_group(&"falling_leaves")
	texture = LEAF
	amount = 60
	lifetime = 10.0
	preprocess = 10.0
	local_coords = false
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(440.0, 230.0)
	direction = Vector2(0.25, 1.0)
	spread = 30.0
	gravity = Vector2(5.0, 16.0)
	initial_velocity_min = 6.0
	initial_velocity_max = 20.0
	damping_min = 2.0
	damping_max = 5.0
	angle_min = 0.0
	angle_max = 360.0
	angular_velocity_min = -170.0
	angular_velocity_max = 170.0
	scale_amount_min = 1.0
	scale_amount_max = 1.7
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.08, Color(1, 1, 1, 1))
	fade.add_point(0.85, Color(1, 1, 1, 1))
	color_ramp = fade
	_tint([Color(0.62, 0.55, 0.42), Color(0.72, 0.64, 0.48), Color(0.52, 0.47, 0.40)])
	z_index = 4
	_warm.call_deferred()


## Le pré-calcul (preprocess) se fait là où est le nœud : on le refait une fois placé
## sur la caméra, pour que les feuilles soient déjà là dès l'arrivée.
func _warm() -> void:
	_process(0.0)
	restart()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		global_position = cam.get_screen_center_position() + Vector2(-60.0, -60.0)


## La forêt guérie : feuilles vertes, quelques-unes dorées.
func heal() -> void:
	_tint([Color(0.30, 0.56, 0.24), Color(0.46, 0.70, 0.30), Color(0.95, 0.78, 0.30), Color(0.24, 0.46, 0.20)])


func _tint(colors: Array) -> void:
	var g := Gradient.new()
	g.set_color(0, colors[0])
	g.set_color(1, colors[-1])
	for i in range(1, colors.size() - 1):
		g.add_point(float(i) / (colors.size() - 1), colors[i])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	color_initial_ramp = g
