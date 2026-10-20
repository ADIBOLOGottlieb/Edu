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

## Pièges : distance d'analyse, distance d'appel avant des pics,
## horizon et pas de la prédiction de traversée (arrêt devant un piège rythmé).
const HAZARD_LOOKAHEAD: float = 260.0
const SPIKE_JUMP_DISTANCE: float = 46.0
const CROSSING_HORIZON: float = 1.4
const CROSSING_STEP: float = 0.04
const CROSSING_MARGIN: float = 8.0

enum HazardDecision { NONE, JUMP, WAIT }

## 1 = vers la droite, -1 = vers la gauche.
@export var direction: int = 1

var _body: RunnerBody
var _space: PhysicsDirectSpaceState2D
var _exclude: Array[RID] = []
## Requête de rayon réutilisée (pas d'allocation par rayon, ADR-053).
var _query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()


func _ready() -> void:
	_body = get_parent() as RunnerBody


func fill(intent: IntentFrame) -> void:
	intent.move_axis = float(direction)
	intent.sprint_held = true
	intent.jump_held = true
	if _body == null:
		return
	_space = _body.get_world_2d().direct_space_state
	if _exclude.is_empty():
		_exclude = [_body.get_rid()]
	var origin: Vector2 = _body.global_position
	var forward: float = float(direction)

	if _body.is_on_floor():
		# Atterrissage étroit en vue : vitesse de course, pas de sprint.
		intent.sprint_held = _upcoming_landing_width(origin, forward) >= NARROW_LANDING
		# Pièges : sauter par-dessus les pics, attendre le bon moment devant un piège
		# rythmé (écraseur, flamme, scie) comme le ferait un joueur.
		match _hazard_decision(origin, forward):
			HazardDecision.JUMP:
				intent.jump_pressed = true
			HazardDecision.WAIT:
				intent.move_axis = 0.0
				intent.sprint_held = false
				return
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


## Que faire face aux pièges devant (le plus proche qui demande une action).
func _hazard_decision(origin: Vector2, forward: float) -> HazardDecision:
	var front: float = origin.x + forward * _body.half_width
	var speed: float = maxf(absf(_body.velocity.x), _body.tuning.run_speed * 0.8)
	var body_height: float = 72.0
	for node: Node in _body.get_tree().get_nodes_in_group(LevelChunk.HAZARD_GROUP):
		var hazard: Hazard = node as Hazard
		if hazard == null or hazard.spec.kind == Hazard.CRUMBLE:
			continue
		var offset: Vector2 = hazard.global_position
		# Étendue horizontale balayée par le piège sur tout son cycle.
		var reach: Rect2 = hazard.spec.rect
		reach = reach.merge(Rect2(reach.position + hazard.spec.path_to, reach.size))
		reach.position += offset
		var distance: float = (reach.position.x - front) if forward > 0.0 else (front - reach.end.x)
		if distance < -reach.size.x - _body.half_width * 2.0 or distance > HAZARD_LOOKAHEAD:
			continue
		# Piège hors de la hauteur du corps (au-dessus de la tête, sous les pieds).
		if reach.position.y > origin.y + 2.0 or reach.end.y < origin.y - body_height - 10.0:
			continue
		if hazard.spec.kind == Hazard.SPIKES:
			if distance > 0.0 and distance <= SPIKE_JUMP_DISTANCE:
				return HazardDecision.JUMP
			continue
		if distance > 0.0 and not _crossing_is_safe(hazard, origin, forward, speed, body_height):
			return HazardDecision.WAIT
	return HazardDecision.NONE


## Vrai si le corps traverserait la zone du piège sans jamais la toucher, en courant
## à `speed` à partir de maintenant (prédiction sur le cycle du piège).
func _crossing_is_safe(hazard: Hazard, origin: Vector2, forward: float, speed: float, body_height: float) -> bool:
	var t: float = 0.0
	var now: float = hazard.get_time()
	while t <= CROSSING_HORIZON:
		var x: float = origin.x + forward * speed * t
		var body: Rect2 = Rect2(x - _body.half_width, origin.y - body_height, _body.half_width * 2.0, body_height)
		var danger: Rect2 = hazard.danger_rect_at(now + t)
		if danger.has_area():
			danger.position += hazard.global_position
			if danger.grow(CROSSING_MARGIN).intersects(body):
				return false
		t += CROSSING_STEP
	return true


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
	_query.from = from
	_query.to = to
	_query.collision_mask = _body.collision_mask
	_query.exclude = _exclude
	return _space.intersect_ray(_query)
