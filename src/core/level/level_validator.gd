class_name LevelValidator
extends RefCounted
## Vérifie qu'un tronçon respecte les conventions et reste franchissable avec
## les réglages de mouvement du coureur. Ce sont des **heuristiques** prudentes
## (marges de sécurité), pas une preuve : un tronçon validé se teste aussi en jeu.

## Hauteur de la forme de glissade (player.tscn) + marge.
const SLIDE_CLEARANCE: float = 34.0
## Distance max entre les pieds et le haut d'un rebord saisissable (ParkourSensors).
const LEDGE_REACH: float = 88.0
## Marges : un saut ou une escalade « juste possible » n'est pas jouable sur mobile.
const GAP_SAFETY: float = 0.6
const CLIMB_SAFETY: float = 0.9
## Début de tronçon sans obstacle : zone où le coureur est replacé après une chute.
const RESPAWN_CLEAR: float = 140.0


## Largeur maximale d'un trou franchissable par un saut en sprint.
static func max_gap(tuning: MoveTuning) -> float:
	var rise_time: float = tuning.jump_velocity / tuning.gravity_up
	var apex: float = tuning.jump_velocity * tuning.jump_velocity / (2.0 * tuning.gravity_up)
	var fall_time: float = sqrt(2.0 * apex / tuning.gravity_down)
	return tuning.sprint_speed * (rise_time + fall_time) * GAP_SAFETY


## Hauteur maximale d'un mur escaladable (course murale + escalade + rebord).
static func max_climb(tuning: MoveTuning) -> float:
	var v0: float = maxf(tuning.sprint_speed * tuning.wall_run_conversion, tuning.wall_run_min_up)
	var t: float = tuning.wall_run_duration
	var wall_run_rise: float = v0 * t - 0.5 * tuning.wall_run_gravity * t * t
	var climb_rise: float = tuning.wall_climb_speed * tuning.wall_climb_max_time
	return (wall_run_rise + climb_rise + LEDGE_REACH) * CLIMB_SAFETY


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
	if not _has_floor_at(layout, 1.0):
		errors.append("pas de sol à l'entrée (y = 0)")
	if not _has_floor_at(layout, layout.width - 1.0):
		errors.append("pas de sol à la sortie (y = 0)")
	_check_gaps(layout, tuning, errors)
	_check_obstacles(layout, tuning, errors)
	return errors


static func _is_floor(rect: Rect2) -> bool:
	return is_zero_approx(rect.position.y) and rect.size.y > 0.0


static func _has_floor_at(layout: ChunkLayout, x: float) -> bool:
	for rect: Rect2 in layout.blocks:
		if _is_floor(rect) and rect.position.x <= x and rect.end.x >= x:
			return true
	return false


## Trous dans le sol, entre x = 0 et x = width.
static func _check_gaps(layout: ChunkLayout, tuning: MoveTuning, errors: Array[String]) -> void:
	var floors: Array[Rect2] = []
	for rect: Rect2 in layout.blocks:
		if _is_floor(rect):
			floors.append(rect)
	floors.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var covered_to: float = 0.0
	var limit: float = max_gap(tuning)
	for rect: Rect2 in floors:
		var gap: float = rect.position.x - covered_to
		if gap > limit:
			errors.append("trou de %.0f px à x = %.0f (max %.0f)" % [gap, covered_to, limit])
		covered_to = maxf(covered_to, rect.end.x)


## Obstacles posés sur le sol (trop hauts ?) et plafonds (trop bas pour glisser ?).
static func _check_obstacles(layout: ChunkLayout, tuning: MoveTuning, errors: Array[String]) -> void:
	var climb_limit: float = max_climb(tuning)
	for rect: Rect2 in layout.blocks:
		if _is_floor(rect):
			continue
		if rect.position.x < RESPAWN_CLEAR:
			errors.append("obstacle à x = %.0f dans la zone de réapparition (< %.0f)" % [rect.position.x, RESPAWN_CLEAR])
		if is_zero_approx(rect.end.y) and rect.position.y < 0.0:
			var height: float = -rect.position.y
			if height > climb_limit:
				errors.append("mur de %.0f px à x = %.0f (max %.0f)" % [height, rect.position.x, climb_limit])
		elif rect.end.y < 0.0:
			var clearance: float = -rect.end.y
			if clearance < SLIDE_CLEARANCE:
				errors.append("plafond à %.0f px du sol à x = %.0f : même en glissade" % [clearance, rect.position.x])
