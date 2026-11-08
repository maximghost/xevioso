class_name EndShrine
extends Area2D
## Autel de la foudre : la fin du niveau.
##
## Quand un héros l'atteint, le niveau est réussi : Xɛvioso répond, la pluie revient
## (voir Level.complete). L'autel montre la hache double, emblème de la foudre.
## (Forme et symboles à valider avec la personne ressource culturelle.)


var _done: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _done or not body is Player:
		return
	_done = true
	var level := Level.of(self)
	if level != null:
		level.complete()
