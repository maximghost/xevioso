class_name XeviosoStrike
extends RefCounted
## La foudre de Xɛvioso : le pouvoir de circonstance des Envoyés.
##
## Quatre pierres sokpe chargent la jauge. Déclenchée (touche L ou bouton violet), la foudre
## tombe du ciel sur les deux ennemis les plus proches à portée et les foudroie d'un coup.
## S'il n'y a personne à portée, rien ne se passe et la charge est gardée.

## Nombre maximal d'ennemis frappés.
const MAX_TARGETS := 2
## Portée autour du héros, en pixels (les cibles doivent aussi être à l'écran).
const RANGE := 260.0
## Dégâts : de quoi vaincre n'importe quel ennemi du village.
const DAMAGE := 20


## Les ennemis à foudroyer : vivants, à l'écran, à portée, les plus proches d'abord.
static func find_targets(player: Node2D) -> Array[Node2D]:
	var camera := player.get_viewport().get_camera_2d()
	var view := Rect2()
	if camera != null:
		var size: Vector2 = player.get_viewport().get_visible_rect().size / camera.zoom
		view = Rect2(camera.get_screen_center_position() - size / 2.0, size)
	var found: Array[Node2D] = []
	for node in player.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if camera != null and not view.has_point(enemy.global_position):
			continue
		if enemy.global_position.distance_to(player.global_position) <= RANGE:
			found.append(enemy)
	found.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) \
			< b.global_position.distance_squared_to(player.global_position))
	return found.slice(0, MAX_TARGETS)


## Le spectacle et les coups : le ciel s'assombrit, le héros lève la main, puis la foudre.
static func cast(player: Player, targets: Array[Node2D]) -> void:
	var level := player.get_parent() as Node2D
	var tree: SceneTree = player.get_tree()
	var camera := player.get_viewport().get_camera_2d()
	var sky_top: float = camera.get_screen_center_position().y - 200.0 if camera != null else player.global_position.y - 200.0

	# 1. L'appel : le héros brandit la main, une onde violette, le ciel se couvre.
	player.cast_pose()
	Audio.play(&"lightning_cast")
	Fx.ring(level, player.global_position, Color(0.78, 0.6, 1.0), 30.0, 0.3, 2.5)
	Fx.sparks(level, player.global_position + Vector2(0, -22), Color(0.85, 0.75, 1.0), 10)
	var mood: Color = level.modulate
	var darken := level.create_tween()
	darken.tween_property(level, "modulate", mood * Color(0.55, 0.55, 0.72), 0.12)
	await tree.create_timer(0.16, true, false, true).timeout

	# 2. La foudre : un éclair par cible, depuis le haut de l'écran.
	for enemy in targets:
		if not is_instance_valid(enemy):
			continue
		var at: Vector2 = enemy.global_position
		LightningBolt.strike(level, Vector2(at.x + randf_range(-24.0, 24.0), sky_top), at, 3.0, 0.45, 4)
		Fx.ring(level, at, Color(1.0, 0.92, 0.6), 34.0, 0.35, 3.0)
		Fx.ring(level, at + Vector2(0, 8), Color(1.0, 0.85, 0.5), 46.0, 0.4, 2.0, 0.3)
		Fx.sparks(level, at, Color(1.0, 0.9, 0.5), 18)
		Fx.dust(level, at + Vector2(0, 10), Color(0.72, 0.44, 0.24), 16, 120.0, 70.0)
		var side: float = signf(at.x - player.global_position.x)
		enemy.take_hit(DAMAGE, side if side != 0.0 else 1.0)
	if level is Level:
		(level as Level).flash(0.55)
	player.shake_camera(5.0, 0.35)
	Fx.hit_stop(tree, 0.1)

	# 3. Le ciel se dégage.
	await tree.create_timer(0.3, true, false, true).timeout
	if is_instance_valid(level):
		level.create_tween().tween_property(level, "modulate", mood, 0.4)
