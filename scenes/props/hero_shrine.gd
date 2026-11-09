class_name HeroShrine
extends Area2D
## Autel d'un Envoyé : le toucher fait rejoindre ce héros à l'équipe.
##
## Dans le jeu, Yawa, Abla et Kokou se gagnent dans les régions 3, 4 et 5 : on posera
## leur autel à l'endroit de leur rencontre. L'autel montre la silhouette du héros,
## dorée et flottante ; une fois le héros débloqué (même lors d'une partie précédente),
## l'autel disparaît.


## La fiche du héros à débloquer.
@export var hero: HeroData

var _time: float = 0.0

@onready var _figure: AnimatedSprite2D = $Figure


func _ready() -> void:
	if hero == null or Game.is_hero_unlocked(hero.id):
		queue_free()
		return
	_figure.sprite_frames = hero.frames
	_figure.play(&"idle")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_figure.position.y = -24.0 + sin(_time * 2.5) * 2.0


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	set_deferred("monitoring", false)
	Game.unlock_hero(hero.id, hero.display_name)
	Fx.dust(get_parent(), global_position + Vector2(0.0, -20.0), Color(1.0, 0.85, 0.4), 24, 110.0, 180.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_figure, "modulate", Color(4.0, 4.0, 2.5, 0.0), 0.4)
	tween.tween_property(_figure, "scale", Vector2(1.3, 1.3), 0.4)
	tween.chain().tween_callback(queue_free)
