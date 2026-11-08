class_name Health
extends Node
## Points de vie, réutilisable par tout ce qui peut être blessé : héros, ennemis, boss.
##
## On l'ajoute comme nœud enfant (nommé « Health ») et on écoute ses signaux.
## Il gère aussi l'invincibilité temporaire après un coup : pendant ce temps,
## les nouveaux coups sont ignorés (le héros clignote, il a le temps de s'éloigner).


## Émis à chaque changement (coup, soin, remise à neuf) : pratique pour l'interface.
signal changed(current: int, maximum: int)
## Émis quand un coup porte réellement.
signal damaged(amount: int)
## Émis quand les points de vie tombent à zéro.
signal died

## Points de vie maximum.
@export var max_health: int = 3

## Durée d'invincibilité après un coup, en secondes (0 = aucune).
@export var invincibility_time: float = 0.0

## Points de vie actuels.
var current: int = 0

# Temps d'invincibilité restant.
var _invincible_timer: float = 0.0


func _ready() -> void:
	current = max_health


func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)


## Inflige « amount » points de dégâts. Renvoie vrai si le coup a porté.
func damage(amount: int) -> bool:
	if is_dead() or is_invincible() or amount <= 0:
		return false
	current = maxi(current - amount, 0)
	_invincible_timer = invincibility_time
	changed.emit(current, max_health)
	damaged.emit(amount)
	if current == 0:
		died.emit()
	return true


## Rend « amount » points de vie, sans dépasser le maximum.
func heal(amount: int) -> void:
	if is_dead():
		return
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)


## Remet les points de vie au maximum (réapparition, point de contrôle).
func refill() -> void:
	current = max_health
	_invincible_timer = 0.0
	changed.emit(current, max_health)


## Tue sur le coup, quelle que soit l'invincibilité (chute dans le vide).
func kill() -> void:
	if is_dead():
		return
	current = 0
	changed.emit(current, max_health)
	died.emit()


## Rend invincible pour « duration » secondes (ex. juste après la réapparition).
func make_invincible(duration: float) -> void:
	_invincible_timer = maxf(_invincible_timer, duration)


func is_invincible() -> bool:
	return _invincible_timer > 0.0


func is_dead() -> bool:
	return current <= 0
