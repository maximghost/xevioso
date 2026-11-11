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
	# Le village vivant, à la saison des pluies
	&"avant": [
		"Il y a bien des saisons, au pays des collines rouges, vivait un village que le ciel aimait.",
		"On y semait le mil quand l'harmattan s'en allait. On y pilait le grain au son des rires, et les jarres ne restaient jamais vides.",
		"Car la pluie venait à son heure. Et quand tombaient les premières gouttes, les enfants dansaient, le tambour répondait au tonnerre, et les anciens remerciaient le ciel.",
	],
	# Le sanctuaire, au crépuscule
	&"sanctuaire": [
		"Au bout du village, un petit sanctuaire gardait un trésor : la Pierre de foudre, don de Xɛvioso, maître du tonnerre.",
		"Tant qu'elle brillait sur son autel, le ciel tenait parole.",
	],
	# La nuit du vol
	&"vol": [
		"Mais une nuit sans lune, le vent tomba d'un coup. Même les lucioles s'éteignirent.",
		"Une ombre glissa jusqu'au sanctuaire. Adaka, le Mangeur de pluie.",
		"Un corps d'argile craquelée, une soif sans fond, et dans la poitrine, un gouffre que rien ne remplit.",
		"Il arracha la Pierre de foudre. Elle se brisa dans un éclair, et ses éclats s'envolèrent aux quatre vents.",
		"Puis il ouvrit sa gueule immense et avala les nuages, jusqu'au dernier.",
		"Et il s'effaça dans la poussière, emportant la pluie avec lui.",
	],
	# Fin de la partie 1 : la nuit après la pluie, la carte, l'iroko malade, le tambour
	&"fin1": [
		"Cette nuit-là, pour la première fois depuis bien des lunes, le village s'endormit bercé par la pluie.",
		"Les jarres débordaient, le mil buvait, et le tambour avait retrouvé sa voix.",
		"Mais à l'est, au-dessus de la forêt, une lueur rouge battait entre les arbres.",
		"Le chemin des Envoyés quitte le village et s'enfonce vers l'est, dans la forêt des irokos.",
		"Là-bas se dressent les arbres sacrés, les plus vieux du pays. Depuis le vol, ils n'entendent plus Xɛvioso.",
		"Au cœur de la forêt, le plus vieil iroko gémit. Ses feuilles grisent et tombent, une à une.",
		"Dans son tronc, un éclat de la Pierre de foudre a été planté. Quelque chose s'en nourrit, qui bat comme un cœur en colère.",
		"Pourtant, cette nuit-là, quelque part sous les grands arbres, un tambour se mit à gronder…",
	],
	# Les malheurs
	&"malheurs": [
		"Depuis, le ciel est muet.",
		"La terre se fend, le mil meurt sur pied, les jarres sonnent creux. Le tambour s'est tu.",
		"Les malheurs s'enchaînent, et chaque soir, les anciens interrogent un ciel qui ne répond plus.",
		"Jusqu'à cette nuit où, sans un nuage, le tonnerre se mit à gronder.",
	],
}

const LINES := {
	# Scène d'ouverture : l'appel de Xɛvioso, en quatre temps (la scène joue ses effets entre chaque).
	&"intro_appel": [
		{"text": "Enfants du village… levez les yeux."},
		{"text": "Je suis Xɛvioso. Le tonnerre est ma voix, l'éclair est ma hache."},
		{"text": "Adaka a brisé ma pierre et bu mes nuages. Sans elle, ma pluie ne peut plus descendre."},
		{"text": "Je ne descends pas parmi les hommes. Je frappe, et ma foudre désigne."},
	],
	&"intro_kodjo": [
		{"text": "Kodjo, enfant du lundi. Toi qui cours plus vite que le vent du soir."},
		{"text": "Je te donne la Ruée. Quand tu t'élances, ni l'épine ni le bec ne peuvent te blesser."},
		{"text": "Et tes pieds seront les plus rapides de tous les Envoyés."},
	],
	&"intro_afi": [
		{"text": "Afi, enfant du vendredi. Toi qui regardes longtemps avant d'agir."},
		{"text": "Je te donne le pagne volant. Il te portera au-dessus des gouffres, aussi loin que porte le vent."},
		{"text": "Et je te donne la sagesse : vois ce que les autres ne voient pas, et montre-leur le chemin."},
	],
	&"intro_mission": [
		{"text": "Vous êtes mes Envoyés. Ma hache vole avec vous : qu'elle fende ce qui se dresse.",
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
	# Partie 2 : la forêt des irokos.
	&"foret_depart": [
		{"text": "Voici la forêt des irokos. Jadis, chaque arbre ici était un sanctuaire."},
		{"text": "La poussière d'Adaka l'étouffe. Marchez doucement : la forêt a des yeux."},
	],
	&"foret_liane": [
		{"text": "La liane frappe qui se tient droit. Baisse la tête, et laisse passer sa colère.",
			"pc": "S ou ↓ maintenu : s'accroupir",
			"mobile": "Flèche bas maintenue : s'accroupir"},
	],
	&"foret_champi": [
		{"text": "Ce qui est mou rend ce qu'on lui donne. Tombe sur lui, il te rendra le ciel.",
			"pc": "Retombez sur le champignon pour bondir très haut",
			"mobile": "Retombez sur le champignon pour bondir très haut"},
	],
	&"foret_ronces": [
		{"text": "La ronce ne pardonne pas l'hésitation. Prends ton élan, et laisse le champignon te porter."},
	],
	&"foret_suite": [
		{"text": "Plus loin, le sous-bois s'enfonce dans l'ombre. Le chemin s'ouvrira bientôt."},
	],
	&"village_fin": [
		{"text": "Vous avez entendu. Vous avez marché."},
		{"text": "Maintenant… écoutez la pluie."},
	],
	# Fin de la partie 1 : Xɛvioso tourne les Envoyés vers la forêt des irokos.
	&"fin1_xevioso": [
		{"text": "Envoyés. Vous avez rendu la pluie au village : c'est le premier pas du chemin."},
		{"text": "Mais regardez vers l'est. La forêt des irokos souffre, et ses arbres sacrés ne m'entendent plus."},
		{"text": "Un éclat de ma pierre y a été planté, et une colère s'en nourrit. Allez. Rendez-moi la forêt."},
	],
}


## Les répliques d'une scène (liste vide si l'identifiant est inconnu).
static func lines(id: StringName) -> Array:
	return LINES.get(id, [])
