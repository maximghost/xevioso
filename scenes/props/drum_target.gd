class_name DrumTarget
extends Area2D
## Tambour d'appel : une cible. Frappé par la hache (ou l'Onde de Kokou), il ouvre
## les portails qui lui sont reliés pendant quelques secondes.
##
## C'est le cœur des petites énigmes : trouver d'où lancer la hache pour l'atteindre,
## puis passer le portail avant qu'il se referme.


## Les portails à ouvrir.
@export var gates: Array[Gate] = []
## Durée d'ouverture, en secondes (0 = ouverts pour toujours).
@export var open_time: float = 4.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	collision_layer = 4      # couche 3 (« ennemis ») : la hache et l'Onde la détectent
	collision_mask = 0


## Appelée par la hache ou l'Onde, comme pour un ennemi.
func take_hit(_damage: int, _from_direction: float, _stun: float = -1.0) -> void:
	_sprite.texture = preload("res://assets/props/gong_hit.png")
	var tween := create_tween()
	tween.tween_property(_sprite, "rotation_degrees", 8.0, 0.06)
	tween.tween_property(_sprite, "rotation_degrees", -6.0, 0.1)
	tween.tween_property(_sprite, "rotation_degrees", 0.0, 0.1)
	tween.tween_callback(func() -> void: _sprite.texture = preload("res://assets/props/gong.png"))
	for gate in gates:
		if gate != null:
			gate.open_for(open_time)
