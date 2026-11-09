class_name Fx
extends RefCounted
## Petits effets visuels réutilisables, appelables de partout : Fx.dust(...).


## Nuage de poussière (ou d'éclats) qui jaillit puis retombe, et se supprime tout seul.
##   parent    : le nœud qui accueille l'effet (en général le niveau) ;
##   at        : position globale ;
##   color     : couleur des grains ;
##   amount    : nombre de grains ;
##   speed_max : vitesse maximale des grains, en pixels par seconde ;
##   spread    : ouverture du jet autour de la verticale, en degrés (180 = dans tous les sens).
static func dust(parent: Node, at: Vector2, color: Color, amount: int = 14,
		speed_max: float = 80.0, spread: float = 80.0) -> void:
	var dust_fx := CPUParticles2D.new()
	dust_fx.one_shot = true
	dust_fx.explosiveness = 1.0
	dust_fx.amount = amount
	dust_fx.lifetime = 0.45
	dust_fx.direction = Vector2.UP
	dust_fx.spread = spread
	dust_fx.initial_velocity_min = speed_max * 0.4
	dust_fx.initial_velocity_max = speed_max
	dust_fx.gravity = Vector2(0.0, 220.0)
	dust_fx.scale_amount_min = 1.0
	dust_fx.scale_amount_max = 2.5
	dust_fx.color = color
	dust_fx.emitting = true
	parent.add_child(dust_fx)
	dust_fx.global_position = at
	dust_fx.finished.connect(dust_fx.queue_free)


## Gerbe d'étincelles (impact de la hache, éclair) : éclats vifs qui jaillissent en étoile.
static func sparks(parent: Node, at: Vector2, color: Color = Color(1.0, 0.92, 0.55), amount: int = 12) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.28
	p.spread = 180.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2(0.0, 120.0)
	p.damping_min = 120.0
	p.damping_max = 200.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	p.emitting = true
	parent.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)


## Micro-arrêt (« hit-stop ») : le jeu se fige une fraction de seconde au moment d'un coup,
## ce qui lui donne du poids. La minuterie ignore le ralenti, sinon elle durerait 20 fois plus.
static func hit_stop(tree: SceneTree, duration: float = 0.06) -> void:
	Engine.time_scale = 0.05
	await tree.create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


## Onde circulaire qui s'élargit et s'efface (changement de héros, pierre ramassée,
## impact du marteau, réception lourde...). « squash » < 1 l'aplatit (onde au sol).
static func ring(parent: Node, at: Vector2, color: Color, radius: float = 24.0,
		duration: float = 0.3, width: float = 2.0, squash: float = 1.0) -> void:
	var r := FxRing.new()
	r.color = color
	r.max_radius = radius
	r.duration = duration
	r.width = width
	r.scale = Vector2(1.0, squash)
	parent.add_child(r)
	r.global_position = at


## Bouffées de poussière douces (pas, saut, réception, dérapage) : de petits nuages
## qui gonflent, glissent et se dissipent. « direction » : sens du jet (x seul = au ras du sol).
static func puff(parent: Node, at: Vector2, color: Color = Color(0.86, 0.72, 0.56),
		amount: int = 4, direction: Vector2 = Vector2.ZERO, speed: float = 22.0, size: float = 0.5) -> void:
	var p := CPUParticles2D.new()
	p.texture = preload("res://assets/fx/smoke.png")
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.45
	p.local_coords = false
	if direction == Vector2.ZERO:
		p.direction = Vector2.UP
		p.spread = 80.0
	else:
		p.direction = direction.normalized()
		p.spread = 25.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.5
	p.damping_max = speed * 2.5
	p.gravity = Vector2(0.0, -10.0)
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size
	var grow := Curve.new()
	grow.max_value = 2.0
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.85))
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	p.emitting = true
	parent.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
