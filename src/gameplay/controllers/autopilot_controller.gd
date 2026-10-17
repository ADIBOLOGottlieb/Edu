class_name AutopilotController
extends Controller
## Pilote automatique : court dans une direction, saute au bord du vide, glisse
## sous les plafonds bas, roule à l'atterrissage dur, saute contre un mur
## abordé trop lentement, et lève le pied avant un atterrissage étroit
## (saut de précision). Murs, obstacles bas et rebords sont ensuite gérés par
## les mouvements automatiques du corps (jalon M2) tant qu'il pousse vers l'avant.
## Sert de testeur de jouabilité des tronçons et de base à l'IA des poursuivants (M5).

## Distance devant le corps où l'on vérifie qu'il reste du sol.
const EDGE_LOOKAHEAD: float = 10.0
## Un dénivelé plus faible que cela est une simple marche descendante, sans saut.
const STEP_DOWN_TOLERANCE: float = 40.0
## Hauteurs des rayons de détection (relatives aux pieds).
const HEAD_Y: float = -60.0
const CHEST_Y: float = -40.0
const CEILING_LOOKAHEAD: float = 90.0
## Mur collé devant à cette distance : on saute pour l'escalader.
const WALL_BUMP_DISTANCE: float = 12.0
## Distance au sol en dessous de laquelle on déclenche la roulade.
const ROLL_PROBE: float = 70.0
## Analyse de l'atterrissage : un vide à moins de GAP_SCAN_AHEAD déclenche la
## recherche du prochain sol jusqu'à LANDING_SCAN au-delà du bord.
const GAP_SCAN_AHEAD: float = 160.0
const LANDING_SCAN: float = 520.0
const SCAN_STEP: float = 12.0
## En dessous de cette largeur, l'atterrissage est « étroit » : pas de sprint.
const NARROW_LANDING: float = 200.0

## 1 = vers la droite, -1 = vers la gauche.
@export var direction: int = 1

var _body: RunnerBody
var _space: PhysicsDirectSpaceState2D
var _exclude: Array[RID] = []


func _ready() -> void:
	_body = get_parent() as RunnerBody


func fill(intent: IntentFrame) -> void:
	intent.move_axis = float(direction)
	intent.sprint_held = true
	intent.jump_held = true
	if _body == null:
		return
	_space = _body.get_world_2d().direct_space_state
	_exclude = [_body.get_rid()]
	var origin: Vector2 = _body.global_position
	var forward: float = float(direction)

	if _body.is_on_floor():
		# Atterrissage étroit en vue : vitesse de course, pas de sprint.
		intent.sprint_held = _upcoming_landing_width(origin, forward) >= NARROW_LANDING
		# Plus de sol juste devant les pieds : sauter au bord.
		if not _ground_at(origin, origin.x + forward * (_body.half_width + EDGE_LOOKAHEAD)):
			intent.jump_pressed = true
		var reach_x: float = origin.x + forward * (_body.half_width + CEILING_LOOKAHEAD)
		var head: bool = _hits(origin + Vector2(0.0, HEAD_Y), Vector2(reach_x, origin.y + HEAD_Y))
		var chest: bool = _hits(origin + Vector2(0.0, CHEST_Y), Vector2(reach_x, origin.y + CHEST_Y))
		# Plafond à hauteur de tête mais rien à la poitrine : glisser dessous.
		if head and not chest:
			intent.slide_pressed = true
		# Mur collé devant, trop lent pour une course murale : sauter pour l'escalader.
		var bump_x: float = origin.x + forward * (_body.half_width + WALL_BUMP_DISTANCE)
		var against_wall: bool = _hits(origin + Vector2(0.0, CHEST_Y), Vector2(bump_x, origin.y + CHEST_Y))
		if against_wall and absf(_body.velocity.x) < _body.tuning.wall_run_min_speed:
			intent.jump_pressed = true
	elif _body.velocity.y >= _body.tuning.landing_hard_speed:
		# Chute rapide, sol tout proche : Glisse pour rouler à l'impact.
		if _hits(origin, origin + Vector2(0.0, ROLL_PROBE)):
			intent.slide_pressed = true


## Sol sous l'abscisse x, au niveau des pieds (± marche).
func _ground_at(origin: Vector2, x: float) -> bool:
	return _hits(Vector2(x, origin.y - 4.0), Vector2(x, origin.y + STEP_DOWN_TOLERANCE))


## Largeur du prochain sol après un vide proche ; INF s'il n'y a pas de vide en vue.
func _upcoming_landing_width(origin: Vector2, forward: float) -> float:
	var offset: float = _body.half_width
	var gap_start: float = -1.0
	while offset <= GAP_SCAN_AHEAD:
		if not _ground_at(origin, origin.x + forward * offset):
			gap_start = offset
			break
		offset += SCAN_STEP
	if gap_start < 0.0:
		return INF
	var landing_top: float = 0.0
	var landing_found: bool = false
	offset = gap_start
	while offset <= gap_start + LANDING_SCAN:
		var x: float = origin.x + forward * offset
		var hit: Dictionary = _ray(Vector2(x, origin.y - 200.0), Vector2(x, origin.y + 300.0))
		if not hit.is_empty():
			landing_top = (hit["position"] as Vector2).y
			landing_found = true
			break
		offset += SCAN_STEP
	if not landing_found:
		return INF
	var width: float = 0.0
	while width < NARROW_LANDING:
		var x: float = origin.x + forward * (offset + width)
		if not _hits(Vector2(x, landing_top - 20.0), Vector2(x, landing_top + 20.0)):
			break
		width += SCAN_STEP
	return width


func _hits(from: Vector2, to: Vector2) -> bool:
	return not _ray(from, to).is_empty()


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	return _space.intersect_ray(
		PhysicsRayQueryParameters2D.create(from, to, _body.collision_mask, _exclude)
	)
