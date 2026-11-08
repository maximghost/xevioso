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
