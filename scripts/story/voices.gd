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
##
## L'histoire (à valider avec la personne ressource culturelle) :
## au pays des collines rouges, un sanctuaire gardait la Pierre de foudre, don de Xɛvioso.
## Une nuit, Adaka (« la méchanceté », en fon), le Mangeur de pluie, l'a arrachée : elle s'est
## brisée en éclats, les sokpe, dispersés au vent ; puis il a avalé les nuages. Depuis, les
## malheurs s'enchaînent. Xɛvioso désigne ses Envoyés pour reprendre son pouvoir, étape par
## étape. Première étape : ramener la pluie au village, pour la population et les récoltes.

## Le nom de l'antagoniste (validé : « adaka » signifie « méchanceté » en fon).
const ADAKA := "Adaka"

## Narration de la scène d'ouverture, un tableau après l'autre (voix du conteur, pas de Xɛvioso).
const STORY := {
	&"avant": [
		"Au pays des collines rouges, la pluie venait à chaque saison. Elle remplissait les jarres, gonflait le mil, et les greniers ne connaissaient pas la faim.",
		"Au cœur du village, un sanctuaire gardait la Pierre de foudre, don de Xɛvioso, maître du tonnerre. Tant qu'elle brillait, le ciel tenait parole.",
	],
	&"vol": [
		"Mais une nuit, une ombre se glissa jusqu'au sanctuaire.",
		"Adaka. Le Mangeur de pluie. Un corps d'argile craquelée, qui a soif depuis toujours.",
		"Il arracha la Pierre de foudre. Elle se brisa, et ses éclats s'envolèrent aux quatre vents.",
		"Puis il ouvrit sa bouche immense et avala les nuages, jusqu'au dernier.",
	],
	&"malheurs": [
		"Depuis, le ciel est muet. La terre se fend, le mil meurt sur pied, les greniers sonnent creux.",
		"Les malheurs s'enchaînent, et les anciens lèvent les yeux vers un ciel qui ne répond plus.",
	],
}

const LINES := {
	# Scène d'ouverture (nouvelle partie)
	&"intro": [
		{"text": "Écoutez… Le ciel s'est tu."},
		{"text": "Adaka a brisé ma pierre et bu mes nuages. La terre se fend. Les greniers ont soif."},
		{"text": "Je ne descends pas parmi les hommes. Je frappe, et ma foudre désigne."},
		{"text": "Enfants du lundi, du mardi, du mercredi, du jeudi et du vendredi : vous êtes mes Envoyés."},
		{"text": "Deux marchent déjà. Les trois autres attendent là où l'eau dort, où le fer chante, où le tambour gronde."},
		{"text": "Ma hache vole avec vous. Qu'elle fende ce qui se dresse.",
			"pc": "J ou clic gauche : lancer la hache", "mobile": "Bouton rouge : lancer la hache"},
		{"text": "Le chemin sera long : on ne reprend pas la foudre d'un seul pas."},
		{"text": "D'abord, rendez la pluie à ce village. Que la terre boive, que le mil reverdisse, que les greniers se remplissent."},
		{"text": "Les éclats de ma pierre sont tombés sur votre route. Chaque sokpe garde un peu de mon souffle : réunis, ils rappellent ma foudre.",
			"pc": "4 sokpe : la foudre est prête (touche L)", "mobile": "4 sokpe : la foudre est prête (bouton violet)"},
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
	# Après la pluie et la floraison : la première étape est franchie, la route continue.
	&"village_suite": [
		{"text": "Le village boira. Mais Adaka garde encore ce qu'il a volé, et ma pierre reste en éclats."},
		{"text": "La route continue vers la forêt des irokos. Mes Envoyés, ne vous endormez pas sous la pluie."},
	],
}


## Les répliques d'une scène (liste vide si l'identifiant est inconnu).
static func lines(id: StringName) -> Array:
	return LINES.get(id, [])
