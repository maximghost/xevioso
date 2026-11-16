extends Area2D
## La zone de frappe d'une roue du cœur de l'iroko : un coup (hache, onde) la fait tourner.

var lock: Node
var index: int = 0


func take_hit(_damage: int, _from_direction: float, _stun: float = -1.0) -> void:
	if lock != null:
		lock.strike_wheel(index)
