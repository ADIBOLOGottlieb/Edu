class_name ParkourSensors
extends RefCounted
## Lit la géométrie devant un acteur avec des rayons (aucun nœud à placer) :
## mur à hauteur de poitrine, obstacle bas franchissable, rebord saisissable.
## Repère : origine aux pieds, l'avant est donné par facing.

## Hauteurs des rayons, relatives aux pieds (négatif = au-dessus).
const CHEST_Y: float = -40.0
const KNEE_Y: float = -12.0
## Hauteur des mains tendues au-dessus de la tête.
const REACH_Y: float = -90.0
## Fenêtre verticale (relative aux pieds) où le haut d'un rebord est saisissable.
const LEDGE_HIGHEST_Y: float = -88.0
const LEDGE_LOWEST_Y: float = -44.0
## Normale minimale (composante x) pour considérer une surface comme un mur.
const WALL_NORMAL_MIN: float = 0.7

var wall_ahead: bool = false
## Position x de la face du mur détecté (globale).
var wall_x: float = 0.0
var obstacle_height: float = 0.0
var ledge_available: bool = false
## Position y du haut du rebord détecté (globale).
var ledge_top_y: float = 0.0


func reset() -> void:
	wall_ahead = false
	wall_x = 0.0
	obstacle_height = 0.0
	ledge_available = false
	ledge_top_y = 0.0


func scan(body: CharacterBody2D, facing: int, tuning: MoveTuning, half_width: float) -> void:
	reset()
	var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	var origin: Vector2 = body.global_position
	var forward: float = float(facing)
	var mask: int = body.collision_mask
	var exclude: Array[RID] = [body.get_rid()]

	# Mur à hauteur de poitrine.
	var wall_reach: float = half_width + tuning.wall_probe
	var chest: Dictionary = _ray(
		space, origin + Vector2(0, CHEST_Y), origin + Vector2(forward * wall_reach, CHEST_Y), mask, exclude
	)
	if not chest.is_empty() and absf((chest["normal"] as Vector2).x) >= WALL_NORMAL_MIN:
		wall_ahead = true
		wall_x = (chest["position"] as Vector2).x

	# Obstacle bas : touché au genou, libre au-dessus de la hauteur maximale de franchissement.
	var vault_reach: float = half_width + tuning.vault_reach
	var knee: Dictionary = _ray(
		space, origin + Vector2(0, KNEE_Y), origin + Vector2(forward * vault_reach, KNEE_Y), mask, exclude
	)
	if not knee.is_empty():
		var above_y: float = -(tuning.vault_max_height + 4.0)
		var above: Dictionary = _ray(
			space, origin + Vector2(0, above_y), origin + Vector2(forward * vault_reach, above_y), mask, exclude
		)
		if above.is_empty():
			var probe_x: float = (knee["position"] as Vector2).x + forward * 8.0
			var top: Dictionary = _ray(
				space, Vector2(probe_x, origin.y + above_y), Vector2(probe_x, origin.y - 1.0), mask, exclude
			)
			if not top.is_empty():
				obstacle_height = origin.y - (top["position"] as Vector2).y

	# Rebord : mur à la poitrine, vide à hauteur des mains tendues, haut du mur dans la fenêtre.
	if wall_ahead and not body.is_on_floor():
		var reach: Dictionary = _ray(
			space, origin + Vector2(0, REACH_Y), origin + Vector2(forward * wall_reach, REACH_Y), mask, exclude
		)
		if reach.is_empty():
			var ledge_x: float = wall_x + forward * 6.0
			var top: Dictionary = _ray(
				space, Vector2(ledge_x, origin.y + REACH_Y), Vector2(ledge_x, origin.y + CHEST_Y), mask, exclude
			)
			if not top.is_empty():
				var top_y: float = (top["position"] as Vector2).y
				var relative: float = top_y - origin.y
				if relative >= LEDGE_HIGHEST_Y and relative <= LEDGE_LOWEST_Y:
					ledge_available = true
					ledge_top_y = top_y


static func _ray(
	space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, mask: int, exclude: Array[RID]
) -> Dictionary:
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, mask, exclude)
	return space.intersect_ray(params)
