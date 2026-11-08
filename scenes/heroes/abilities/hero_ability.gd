class_name HeroAbility
extends Node
## Modèle commun aux capacités des Envoyés (Ruée, Pagne-voile, Perche, Marteau, Onde).
##
## Chaque capacité hérite de cette classe et remplace les fonctions marquées « à redéfinir ».
## Le Player crée une capacité par héros au démarrage et la pilote lui-même :
##   - tick(delta) à chaque image, pour le temps de recharge (même pour un héros en réserve) ;
##   - try_activate() quand on appuie sur « ability » ;
##   - physics_update(delta) à chaque image tant que la capacité est active.
## Pendant qu'une capacité est active, elle peut prendre la main sur le mouvement
## (takes_control, ex. la Ruée) : le Player ne gère alors ni la gravité ni la course.
## Sinon (ex. le Pagne-voile), le héros bouge normalement et physics_update s'ajoute.


## Émis quand la capacité démarre.
signal started
## Émis quand elle se termine (normalement ou annulée).
signal ended

## Temps de recharge après la fin de la capacité, en secondes.
@export var cooldown: float = 0.5

## Le héros qui utilise la capacité (renseigné par le Player).
var player: Player

## Vrai tant que la capacité est en cours.
var active: bool = false

## Si vrai, le Player suspend gravité et course pendant la capacité : c'est elle qui
## décide de la vitesse. Si faux, le héros bouge normalement (ex. une onde lancée en courant).
var takes_control: bool = true

## Animation à jouer pendant la capacité (vide = l'animation normale continue).
var animation: StringName = &""

# Compte à rebours avant de pouvoir réutiliser la capacité.
var _cooldown_timer: float = 0.0


## Fait avancer le temps de recharge.
func tick(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)


## Démarre la capacité si c'est permis. Renvoie vrai si elle a démarré.
func try_activate() -> bool:
	if active or _cooldown_timer > 0.0 or not can_activate():
		return false
	active = true
	_activate()
	started.emit()
	return true


## Termine la capacité et lance le temps de recharge.
func finish() -> void:
	if not active:
		return
	active = false
	_cooldown_timer = cooldown
	_on_finish()
	ended.emit()


## Interrompt la capacité (changement de héros, coup reçu...).
## Même effet que finish() : la recharge est due, pour qu'on ne puisse pas tricher
## en changeant de héros pour la réinitialiser.
func cancel() -> void:
	finish()


# --- À redéfinir dans chaque capacité ---------------------------------------

## Le joueur demande-t-il la capacité ? Par défaut : un appui sur « ability ».
## Une capacité « à maintenir » (le Pagne-voile) répond aussi au bouton tenu.
func wants_activation() -> bool:
	return Input.is_action_just_pressed("ability")


## Permet à une capacité active de modifier la vitesse de chute maximale
## (le Pagne-voile ralentit la chute). Par défaut, aucune modification.
func limit_fall_speed(default_speed: float) -> float:
	return default_speed

## Conditions propres à la capacité (ex. la Ruée : une seule fois par saut).
func can_activate() -> bool:
	return true


## Appelée au démarrage.
func _activate() -> void:
	pass


## Appelée à chaque image tant que la capacité est active.
func physics_update(_delta: float) -> void:
	pass


## Appelée à la fin, pour remettre les choses en ordre.
func _on_finish() -> void:
	pass


## Appelée par le Player à chaque image, active ou non (ex. recharger la Ruée au sol).
func passive_update(_delta: float) -> void:
	pass


## Vrai si le héros ne peut pas être blessé en ce moment (servira avec les ennemis).
func grants_invulnerability() -> bool:
	return false
