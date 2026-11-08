extends CanvasLayer
## Interface en jeu : les cœurs (points de vie de l'équipe) et le nom du héros joué.
##
## Le HUD ne fait qu'afficher : il écoute les signaux du Player et de sa Health,
## il ne modifie rien. On peut donc le retirer ou le refaire sans toucher au jeu.


## Le héros à suivre.
@export var player: Player

## Cœur plein et cœur vide.
@export var heart_full: Texture2D = preload("res://assets/ui/hud/heart_full.png")
@export var heart_empty: Texture2D = preload("res://assets/ui/hud/heart_empty.png")

@onready var _hearts: HBoxContainer = $Margin/Box/Hearts
@onready var _hero_name: Label = $Margin/Box/HeroName


func _ready() -> void:
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
