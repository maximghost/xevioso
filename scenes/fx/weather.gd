class_name Weather
extends Node2D
## La météo du niveau, accrochée à la caméra (elle couvre toujours l'écran).
##
## Saison sèche : de fins grains de poussière d'harmattan dérivent lentement.
## Quand la pluie revient (start_rain), la poussière retombe et une pluie oblique
## se met à tomber, de plus en plus dense.


## Densité finale de la pluie (gouttes simultanées à l'écran).
@export var rain_amount: int = 260

var _dust: CPUParticles2D
var _rain: CPUParticles2D


func _ready() -> void:
	# On reste au centre de la caméra, mais dessiné au-dessus du décor.
	z_index = 20
	_dust = _make_dust()
	add_child(_dust)


## Fait tomber la pluie : elle s'installe en « fade_time » secondes.
func start_rain(fade_time: float = 2.5) -> void:
	_dust.emitting = false
	_rain = _make_rain()
	add_child(_rain)
	# La pluie commence clairsemée et s'intensifie : on fait monter l'opacité.
	_rain.modulate.a = 0.0
	create_tween().tween_property(_rain, "modulate:a", 1.0, fade_time)


func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = preload("res://assets/fx/dust_mote.png")
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 7.0                      # déjà présente à l'apparition du niveau
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(420.0, 200.0)
	p.direction = Vector2(-1.0, -0.15)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	# Les grains apparaissent et s'effacent en douceur.
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 0.7))
	fade.add_point(0.8, Color(1, 1, 1, 0.7))
	p.color_ramp = fade
	return p


func _make_rain() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = preload("res://assets/fx/raindrop.png")
	p.amount = rain_amount
	p.lifetime = 0.7
	p.preprocess = 0.7
	p.position = Vector2(60.0, -230.0)      # au-dessus de l'écran, décalée contre le vent
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(460.0, 8.0)
	p.direction = Vector2(-0.25, 1.0)       # pluie légèrement oblique
	p.spread = 3.0
	p.gravity = Vector2(0.0, 300.0)
	p.initial_velocity_min = 520.0
	p.initial_velocity_max = 640.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.6
	return p
