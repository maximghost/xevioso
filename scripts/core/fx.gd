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
