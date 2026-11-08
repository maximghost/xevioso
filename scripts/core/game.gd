extends Node
## La progression du joueur, et sa sauvegarde. Autoload « Game » : accessible partout.
##
## Ce qui est retenu d'une partie à l'autre :
##   - les héros débloqués (Kodjo et Afi au départ ; Yawa, Abla, Kokou se gagnent) ;
##   - les pierres sokpe ramassées, niveau par niveau ;
##   - le dernier point de contrôle atteint (niveau + nom du point).
##
## La sauvegarde est un petit fichier JSON dans « user:// » : sur ordinateur, c'est un
## dossier de l'utilisateur ; dans le navigateur, Godot le range dans le stockage du site
## (IndexedDB). Elle est écrite à chaque événement important, jamais en continu.


## Émis quand le nombre total de pierres sokpe change.
signal sokpe_changed(total: int)
## Émis quand un héros rejoint l'équipe.
signal hero_unlocked(hero_id: StringName)
## Message à afficher brièvement à l'écran (« Point de contrôle », « Yawa rejoint... »).
signal message(text: String)

## Fichier de sauvegarde.
const SAVE_PATH := "user://sauvegarde.json"
## Version du format : si on le change un jour, on saura convertir les anciennes sauvegardes.
const SAVE_VERSION := 1
## Les niveaux du jeu : identifiant → scène. Le premier est celui d'une nouvelle partie.
const LEVELS := {
	&"village_1": "res://scenes/levels/village/village_1.tscn",
	&"test": "res://scenes/levels/test_level.tscn",
}
const FIRST_LEVEL: StringName = &"village_1"
## L'écran titre.
const TITLE_SCREEN := "res://scenes/ui/title_screen.tscn"

## Les héros disponibles dès le début.
const STARTING_HEROES: Array[StringName] = [&"kodjo", &"afi"]

## Héros débloqués (leurs identifiants, voir HeroData.id).
var unlocked_heroes: Array[StringName] = []
## Pierres sokpe ramassées : { identifiant du niveau : [noms des pierres] }.
var sokpe: Dictionary = {}
## Dernier point de contrôle : niveau et nom du point (vides = début du niveau).
var checkpoint_level: StringName = &""
var checkpoint_name: StringName = &""
## Niveaux terminés.
var completed_levels: Array[StringName] = []


func _ready() -> void:
	load_game()


# ---------------------------------------------------------------------------
# Héros
# ---------------------------------------------------------------------------

func is_hero_unlocked(hero_id: StringName) -> bool:
	return hero_id in unlocked_heroes


func unlock_hero(hero_id: StringName, display_name: String = "") -> void:
	if is_hero_unlocked(hero_id):
		return
	unlocked_heroes.append(hero_id)
	hero_unlocked.emit(hero_id)
	if display_name != "":
		message.emit("%s rejoint les Envoyés !" % display_name)
	save_game()


# ---------------------------------------------------------------------------
# Pierres sokpe
# ---------------------------------------------------------------------------

func has_sokpe(level_id: StringName, stone_name: StringName) -> bool:
	return sokpe.has(level_id) and stone_name in sokpe[level_id]


## Enregistre une pierre ramassée. Renvoie faux si elle l'était déjà.
func collect_sokpe(level_id: StringName, stone_name: StringName) -> bool:
	if has_sokpe(level_id, stone_name):
		return false
	if not sokpe.has(level_id):
		sokpe[level_id] = []
	sokpe[level_id].append(stone_name)
	sokpe_changed.emit(total_sokpe())
	save_game()
	return true


func total_sokpe() -> int:
	var total: int = 0
	for stones in sokpe.values():
		total += stones.size()
	return total


# ---------------------------------------------------------------------------
# Points de contrôle
# ---------------------------------------------------------------------------

func set_checkpoint(level_id: StringName, point_name: StringName) -> void:
	if checkpoint_level == level_id and checkpoint_name == point_name:
		return
	checkpoint_level = level_id
	checkpoint_name = point_name
	message.emit("Point de contrôle")
	save_game()


## Le point de contrôle enregistré pour ce niveau (vide s'il n'y en a pas).
func checkpoint_for(level_id: StringName) -> StringName:
	return checkpoint_name if checkpoint_level == level_id else &""


# ---------------------------------------------------------------------------
# Niveaux
# ---------------------------------------------------------------------------

func complete_level(level_id: StringName) -> void:
	if not level_id in completed_levels:
		completed_levels.append(level_id)
	# Le niveau est fini : on ne reprendra plus à son point de contrôle.
	if checkpoint_level == level_id:
		checkpoint_level = &""
		checkpoint_name = &""
	save_game()


## Vrai s'il existe une partie à continuer.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Le niveau où reprendre : celui du dernier point de contrôle, sinon le premier non terminé.
func level_to_continue() -> StringName:
	if checkpoint_level != &"" and LEVELS.has(checkpoint_level):
		return checkpoint_level
	return FIRST_LEVEL


func go_to_level(level_id: StringName) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVELS.get(level_id, LEVELS[FIRST_LEVEL]))


func go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCREEN)


# ---------------------------------------------------------------------------
# Sauvegarde
# ---------------------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"unlocked_heroes": unlocked_heroes.map(func(id): return String(id)),
		"sokpe": sokpe,
		"checkpoint": {"level": String(checkpoint_level), "name": String(checkpoint_name)},
		"completed_levels": completed_levels.map(func(id): return String(id)),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	_reset_state()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Sauvegarde illisible : on repart de zéro.")
		return
	for id in data.get("unlocked_heroes", []):
		if not StringName(id) in unlocked_heroes:
			unlocked_heroes.append(StringName(id))
	# Les noms de pierres sont relus comme StringName, pour comparer sans surprise.
	var stones: Dictionary = data.get("sokpe", {})
	for level_id in stones:
		sokpe[StringName(level_id)] = stones[level_id].map(func(n): return StringName(n))
	var point: Dictionary = data.get("checkpoint", {})
	checkpoint_level = StringName(point.get("level", ""))
	checkpoint_name = StringName(point.get("name", ""))
	for id in data.get("completed_levels", []):
		completed_levels.append(StringName(id))


## Efface toute la progression (bouton de test du menu pause, plus tard « Nouvelle partie »).
func reset_progress() -> void:
	_reset_state()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	sokpe_changed.emit(0)


func _reset_state() -> void:
	unlocked_heroes = STARTING_HEROES.duplicate()
	sokpe = {}
	checkpoint_level = &""
	checkpoint_name = &""
	completed_levels = []
