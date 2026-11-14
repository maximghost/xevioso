class_name ForestDarkness
extends Node2D
## L'ombre du sous-bois : dans les tronçons du niveau listés ici, la canopée ne laisse plus
## passer le jour. Le monde s'assombrit progressivement à l'entrée (et s'éclaire à la sortie) ;
## le héros porte alors une petite lumière (la foudre de Xɛvioso qui l'accompagne), juste de
## quoi voir le sol autour de lui. Les lucioles, les champignons bleus et les yeux des
## chauves-souris percent le noir : ce sont eux qu'il faut lire.

## Tronçons sombres : (x de début, x de fin), en pixels.
@export var ranges: PackedVector2Array = PackedVector2Array()
## Couleur du monde au plus noir (multipliée à tout ce qui n'est pas éclairé).
@export var dark_color: Color = Color(0.13, 0.15, 0.2)
## Longueur du fondu à chaque bord, en pixels.
@export var fade: float = 96.0
## Rayon de la lumière du héros (échelle de la texture de 128 px).
@export var hero_light_scale: float = 2.2

var _modulate: CanvasModulate
var _light: PointLight2D
var _player: Node2D


func _ready() -> void:
	_modulate = CanvasModulate.new()
	_modulate.color = Color.WHITE
	add_child(_modulate)


func _process(_delta: float) -> void:
	if _player == null:
		var level := Level.of(self)
		if level == null or level.player == null:
			return
		_player = level.player
		_light = PointLight2D.new()
		_light.texture = Fx.light_texture()
		_light.texture_scale = hero_light_scale
		_light.color = Color(1.0, 0.93, 0.8)
		_light.position = Vector2(0, -16)
		_light.enabled = false
		_player.add_child(_light)
	var t: float = darkness_at(_player.global_position.x)
	_modulate.color = Color.WHITE.lerp(dark_color, t)
	_light.enabled = t > 0.02
	_light.energy = 1.1 * t
	# La lumière vacille à peine (une flamme, pas une lampe).
	_light.texture_scale = hero_light_scale * (1.0 + 0.03 * sin(Time.get_ticks_msec() / 90.0))


## Noirceur (0 = plein jour, 1 = nuit du sous-bois) à cette abscisse.
func darkness_at(x: float) -> float:
	var t := 0.0
	for r in ranges:
		if x > r.x - fade and x < r.y + fade:
			var inside: float = minf(x - (r.x - fade), (r.y + fade) - x) / fade
			t = maxf(t, clampf(inside, 0.0, 1.0))
	return smoothstep(0.0, 1.0, t)
