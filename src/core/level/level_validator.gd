class_name LevelValidator
extends RefCounted
## Vérifie qu'un tronçon respecte les conventions et reste franchissable avec
## les réglages de mouvement du coureur.
##
## Chaque bloc offre une surface (son dessus). Deux surfaces sont reliées si la
## trajectoire de saut réelle (montée à gravité réduite, descente à gravité
## normale) ou l'escalade murale permet de passer de l'une à l'autre. Le
## tronçon est valide s'il existe un chemin de l'entrée à la sortie.
## Les marges (*_SAFETY) rendent ces calculs prudents ; le test de jouabilité
## (pilote automatique) complète cette vérification en conditions réelles.

## Hauteur de la forme de glissade (player.tscn) + marge.
const SLIDE_CLEARANCE: float = 34.0
## Distance max entre les pieds et le haut d'un rebord saisissable (ParkourSensors).
const LEDGE_REACH: float = 88.0
## Part de la vitesse de sprint retenue pour les sauts (le joueur n'est pas toujours lancé).
const SPEED_SAFETY: float = 0.7
## Part de la hauteur maximale de saut considérée comme sûre.
const HEIGHT_SAFETY: float = 0.85
const CLIMB_SAFETY: float = 0.9
## Un toit plus haut se rejoint par sa paroi si le trou fait au plus cette part de la portée.
const CLIMB_GAP_FACTOR: float = 0.6
## Début de tronçon sans obstacle : zone où le coureur est replacé après une chute.
const RESPAWN_CLEAR: float = 140.0
## En dessous de cette épaisseur, un bloc est une poutre : pas de paroi où courir.
const THIN_BLOCK: float = 40.0


## Hauteur atteinte par un saut maintenu (px).
static func jump_apex(tuning: MoveTuning) -> float:
	return tuning.jump_velocity * tuning.jump_velocity / (2.0 * tuning.gravity_up)


## Distance horizontale sûre d'un saut qui atterrit `height` px plus haut
## (négatif = plus bas). -1 si cette hauteur est hors d'atteinte.
static func jump_reach(height: float, tuning: MoveTuning) -> float:
	var apex: float = jump_apex(tuning)
	if height > apex:
		return -1.0
	var rise_time: float = tuning.jump_velocity / tuning.gravity_up
	var fall_time: float = sqrt(2.0 * (apex - height) / tuning.gravity_down)
	return tuning.sprint_speed * SPEED_SAFETY * (rise_time + fall_time)


## Largeur maximale d'un trou franchissable entre deux toits de même hauteur.
static func max_gap(tuning: MoveTuning) -> float:
	return jump_reach(0.0, tuning)


## Hauteur maximale d'un mur escaladable (course murale + escalade + rebord).
static func max_climb(tuning: MoveTuning) -> float:
	var v0: float = maxf(tuning.sprint_speed * tuning.wall_run_conversion, tuning.wall_run_min_up)
	var t: float = tuning.wall_run_duration
	var wall_run_rise: float = v0 * t - 0.5 * tuning.wall_run_gravity * t * t
	var climb_rise: float = tuning.wall_climb_speed * tuning.wall_climb_max_time
	return (wall_run_rise + climb_rise + LEDGE_REACH) * CLIMB_SAFETY


## Vrai si l'on peut passer du dessus de `from` au dessus de `to`.
static func can_reach(from: Rect2, to: Rect2, tuning: MoveTuning) -> bool:
	var gap: float = maxf(0.0, maxf(to.position.x - from.end.x, from.position.x - to.end.x))
	var rise: float = from.position.y - to.position.y
	var safe_apex: float = jump_apex(tuning) * HEIGHT_SAFETY
	if rise <= safe_apex:
		return gap <= jump_reach(rise, tuning)
	var thin: bool = to.size.y < THIN_BLOCK
	if not thin:
		# Paroi qui descend au moins jusqu'au niveau de départ : course murale + escalade.
		var wall_reaches_down: bool = to.end.y >= from.position.y
		return (
			wall_reaches_down
			and rise <= max_climb(tuning)
			and gap <= CLIMB_GAP_FACTOR * max_gap(tuning)
		)
	# Poutre : saut puis saisie du rebord.
	return rise <= safe_apex + LEDGE_REACH * 0.7 and gap <= 0.5 * max_gap(tuning)


## Liste des problèmes trouvés ; vide si le tronçon est valide.
static func validate(layout: ChunkLayout, tuning: MoveTuning) -> Array[String]:
	var errors: Array[String] = []
	if layout.id == &"":
		errors.append("identifiant vide")
	if layout.width <= 0.0:
		errors.append("largeur nulle ou négative")
		return errors
	for rect: Rect2 in layout.blocks:
		if rect.position.x < 0.0 or rect.end.x > layout.width:
			errors.append("bloc %s hors du tronçon" % rect)
	var start: int = _surface_at(layout, 1.0, 0.0)
	var goal: int = _surface_at(layout, layout.width - 1.0, layout.exit_y)
	if start < 0:
		errors.append("pas de toit à l'entrée (y = 0)")
	if goal < 0:
		errors.append("pas de toit à la sortie (y = %.0f)" % layout.exit_y)
	_check_respawn_zone(layout, start, errors)
	_check_obstacles(layout, tuning, errors)
	_check_ceilings(layout, errors)
	if start >= 0 and goal >= 0 and not _path_exists(layout, start, goal, tuning):
		errors.append("aucun chemin franchissable de l'entrée à la sortie")
	return errors


static func _surface_at(layout: ChunkLayout, x: float, top: float) -> int:
	for i: int in layout.blocks.size():
		var rect: Rect2 = layout.blocks[i]
		if is_equal_approx(rect.position.y, top) and rect.position.x <= x and rect.end.x >= x:
			return i
	return -1


## Parcours en largeur sur le graphe des surfaces.
static func _path_exists(layout: ChunkLayout, start: int, goal: int, tuning: MoveTuning) -> bool:
	var visited: Dictionary[int, bool] = {start: true}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == goal:
			return true
		for next: int in layout.blocks.size():
			if visited.has(next):
				continue
			if can_reach(layout.blocks[current], layout.blocks[next], tuning):
				visited[next] = true
				queue.append(next)
	return false


static func _check_respawn_zone(layout: ChunkLayout, start: int, errors: Array[String]) -> void:
	for i: int in layout.blocks.size():
		var rect: Rect2 = layout.blocks[i]
		if i != start and rect.position.x < RESPAWN_CLEAR and rect.position.y < 0.0:
			errors.append("obstacle à x = %.0f dans la zone de réapparition (< %.0f)" % [rect.position.x, RESPAWN_CLEAR])


static func _overlaps_x(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x - 1.0 and b.position.x < a.end.x - 1.0


## Obstacles posés sur une surface : pas plus hauts que ce qui s'escalade.
static func _check_obstacles(layout: ChunkLayout, tuning: MoveTuning, errors: Array[String]) -> void:
	var climb_limit: float = max_climb(tuning)
	for obstacle: Rect2 in layout.blocks:
		for base: Rect2 in layout.blocks:
			if base == obstacle or not _overlaps_x(obstacle, base):
				continue
			if is_equal_approx(obstacle.end.y, base.position.y) and obstacle.size.y > climb_limit:
				errors.append("mur de %.0f px à x = %.0f (max %.0f)" % [obstacle.size.y, obstacle.position.x, climb_limit])


## Plafonds au-dessus d'une surface : au moins la hauteur d'une glissade.
static func _check_ceilings(layout: ChunkLayout, errors: Array[String]) -> void:
	for ceiling: Rect2 in layout.blocks:
		for ground: Rect2 in layout.blocks:
			if ground == ceiling or not _overlaps_x(ceiling, ground):
				continue
			var clearance: float = ground.position.y - ceiling.end.y
			if clearance > 0.0 and clearance < SLIDE_CLEARANCE:
				errors.append("plafond à %.0f px de la surface à x = %.0f : même en glissade" % [clearance, ceiling.position.x])
