class_name Voices
extends RefCounted
## Les paroles de Xɛvioso, réunies en un seul endroit pour être relues facilement
## (et validées avec la personne ressource culturelle).
##
## Xɛvioso n'apparaît jamais sous forme humaine : c'est une voix venue de l'orage,
## représentée par son emblème, la hache double. Il parle peu, par images ; l'aide
## concrète aux commandes est donnée à part, en petit (« pc » au clavier, « mobile » au tactile).
##
## Chaque réplique : { "text": parole de Xɛvioso, "pc": aide clavier, "mobile": aide tactile }.
## Les deux aides sont facultatives.

const LINES := {
	# Scène d'ouverture (nouvelle partie)
	&"intro": [
		{"text": "Écoutez… Le ciel s'est tu."},
		{"text": "Celui qui mange la pluie a vidé mes nuages. La terre se fend. Les greniers ont soif."},
		{"text": "Je ne descends pas parmi les hommes. Je frappe, et ma foudre désigne."},
		{"text": "Enfants du lundi, du mardi, du mercredi, du jeudi et du vendredi : vous êtes mes Envoyés."},
		{"text": "Deux marchent déjà. Les trois autres attendent là où l'eau dort, où le fer chante, où le tambour gronde."},
		{"text": "Ma hache vole avec vous. Qu'elle fende ce qui se dresse.",
			"pc": "J ou clic gauche : lancer la hache", "mobile": "Bouton rouge : lancer la hache"},
		{"text": "Ramassez les pierres tombées de mes mains. Chaque sokpe garde un peu de mon souffle."},
		{"text": "Marchez jusqu'à l'iroko. Là où mon signe est planté, la pluie se souviendra."},
	],
	# Village, niveau 1
	&"village_depart": [
		{"text": "Le vent porte la poussière. Avance, enfant du lundi.",
			"pc": "← → (ou Q / D) : marcher · Espace : sauter",
			"mobile": "Croix : marcher · Bouton doré ou flèche haut : sauter"},
		{"text": "Une seule foulée ne fait pas une route. Change de pas quand la route change.",
			"pc": "Tab : changer d'Envoyé · K : son pouvoir",
			"mobile": "Bouton vert : changer d'Envoyé · Bouton bleu : son pouvoir"},
	],
	&"village_dalles": [
		{"text": "La terre cuite par la soif ne porte pas longtemps. Ne t'attarde pas sur elle."},
	],
	&"village_champ": [
		{"text": "Ceux qui volent ont faim. Regarde le ciel autant que tes pieds."},
		{"text": "Plus loin, la termitière crache sa colère. Trois coups la font taire."},
	],
	&"village_cachette": [
		{"text": "Sous tes pieds, la terre retient un éclat. Une main de forge saura le libérer… plus tard."},
	],
	&"village_vide": [
		{"text": "Le gouffre se rit du saut ordinaire."},
		{"text": "Le coureur s'élance comme l'éclair. La tisseuse se fait aile.",
			"pc": "Tab pour choisir · K : Ruée de Kodjo, ou Pagne-voile d'Afi (maintenir K en l'air)",
			"mobile": "Bouton vert pour choisir · Bouton bleu (maintenu en l'air pour Afi)"},
	],
	&"village_portail": [
		{"text": "Ce que la main ne peut ouvrir, la voix l'ouvre. Fais parler le tambour."},
		{"text": "La pierre a un œil étroit. Monte sur le bois, et que ma hache passe par cet œil.",
			"pc": "Debout sur la planche, J vers la falaise · puis cours !",
			"mobile": "Debout sur la planche, bouton rouge vers la falaise · puis cours !"},
	],
	&"village_puits": [
		{"text": "Le bois suspendu danse au-dessus du vide. Danse avec lui, au bon moment."},
	],
	&"village_fin": [
		{"text": "Vous avez entendu. Vous avez marché."},
		{"text": "Maintenant… écoutez la pluie."},
	],
}


## Les répliques d'une scène (liste vide si l'identifiant est inconnu).
static func lines(id: StringName) -> Array:
	return LINES.get(id, [])
