extends Node
## Réglages d'affichage appliqués au démarrage (chargé automatiquement : Projet → Autoload).
##
## Le jeu est dessiné en 640 × 360 puis agrandi. Sur ordinateur, on garde un agrandissement
## par facteur entier (×2, ×3...) : les pixels sont parfaitement nets.
## Sur téléphone, la hauteur de l'écran est rarement un multiple de 360 : un facteur entier
## laisserait de grandes bandes noires. On passe donc à un agrandissement libre, qui remplit
## tout l'écran au prix de pixels très légèrement inégaux, invisibles à cette taille.


func _ready() -> void:
	if DisplayServer.is_touchscreen_available():
		get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
