class_name PursuerAIController
extends AutopilotController
## IA d'un gardien qui poursuit le coureur (jalon M5, ARCHITECTURE §5.2).
##
## Le gardien n'est jamais combattu : il court, le coureur s'échappe. Le contact
## (ENGAGE) remplit la jauge de capture, gérée par l'EncounterDirector qui écoute
## contact_changed.
##
## Même corps physique que le joueur (RunnerBody) : cette IA ne produit que des
## intentions. Le parkour (vides, plafonds bas, murs, pics, pièges rythmés) est
## celui de l'AutopilotController, orienté vers la cible à chaque tick. Aucune
## téléportation, aucune traversée : le rubber-banding ne fait que choisir entre
## course et sprint, dans les bornes du MoveTuning. Seul reset() replace le corps,
## entre deux tentatives (après une capture ou une réapparition).
##
## États :
## - CHASE   : court vers l'abscisse de la cible ;
## - ENGAGE  : au contact (portée de saisie), reste collé et calque la vitesse ;
## - RECOVER : contact rompu, court trébuchement plus lent (RECOVER_TIME) ;
## - SEARCH  : cible perdue dans une StealthZone, fouille la dernière position vue
##             pendant search_time ;
## - GIVE_UP : abandon (fouille vaine, cible trop loin ou gardien tombé) : immobile
##             jusqu'au prochain reset().

signal contact_changed(in_contact: bool)
signal lost_track()
signal gave_up()

enum AIState { CHASE, ENGAGE, RECOVER, SEARCH, GIVE_UP }

const STATE_NAMES: Dictionary[AIState, StringName] = {
	AIState.CHASE: &"chase",
	AIState.ENGAGE: &"engage",
	AIState.RECOVER: &"recover",
	AIState.SEARCH: &"search",
	AIState.GIVE_UP: &"give_up",
}

## Écart vertical maximal pour saisir (px) ; le contact tient jusqu'à RELEASE_DY.
const GRAB_DY: float = 50.0
const RELEASE_DY: float = 80.0
## Le contact est rompu au-delà de grab_range × RELEASE_FACTOR.
const RELEASE_FACTOR: float = 1.6
## Trébuchement après un contact rompu (s) et allure pendant ce temps.
const RECOVER_TIME: float = 0.35
const RECOVER_AXIS: float = 0.55
## Rubber-banding : sprint par défaut ; simple course quand la cible
## est immobile à moins de NEAR_DISTANCE (une chance de repartir).
const NEAR_DISTANCE: float = 160.0
const TARGET_STILL_SPEED: float = 40.0
## Hystérésis du demi-tour : la cible doit être passée de l'autre côté de cette marge.
const TURN_MARGIN: float = 24.0
## En dessous de cet écart horizontal, inutile d'avancer (cible juste au-dessus).
const ARRIVE_DISTANCE: float = 10.0
## Fouille : arrivé à la dernière position vue à cette distance près.
const SEARCH_ARRIVE: float = 24.0
## Fouille qui n'arrive jamais à destination (mur infranchissable) : abandon après
## search_time × SEARCH_TIMEOUT_FACTOR.
const SEARCH_TIMEOUT_FACTOR: float = 3.0
## Gardien tombé loin sous la cible (dans la rue) : abandon.
const FALL_GIVE_UP: float = 900.0
## Contact : correction de position ajoutée à la vitesse calquée (fraction d'axe par px).
const GLUE_GAIN: float = 0.02

@export var target: RunnerBody
## Portée de saisie horizontale (px, entre les pieds).
@export var grab_range: float = 46.0
## Durée de fouille à la dernière position vue (s).
@export var search_time: float = 2.5
## Distance à la cible au-delà de laquelle le gardien abandonne (px).
@export var give_up_distance: float = 2200.0

var _state: AIState = AIState.CHASE
var _active: bool = true
var _in_contact: bool = false
var _recover_left: float = 0.0
var _search_elapsed: float = 0.0
var _search_waited: float = 0.0
var _last_seen: Vector2 = Vector2.ZERO
var _has_seen: bool = false


func ai_state() -> StringName:
	return STATE_NAMES[_state]


func is_in_contact() -> bool:
	return _in_contact


func is_active() -> bool:
	return _active


## Dernière position où la cible était visible (hors StealthZone).
func last_seen_position() -> Vector2:
	return _last_seen


## Inactif : reste immobile (et lâche le contact). Réactivé : reprend la poursuite
## (sauf après un abandon, qui dure jusqu'au prochain reset()).
func set_active(on: bool) -> void:
	_active = on
	if not on:
		_set_contact(false)


## Replace le gardien (derrière le coureur, entre deux tentatives) et efface son
## état : poursuite, sans contact. Remise en place scriptée, pas un déplacement de jeu.
func reset(at: Vector2) -> void:
	_set_contact(false)
	_state = AIState.CHASE
	_recover_left = 0.0
	_search_elapsed = 0.0
	_search_waited = 0.0
	_has_seen = false
	if _body != null:
		_body.revive(at)
		if target != null:
			direction = 1 if target.global_position.x >= at.x else -1
			_body.facing = direction


## Vrai si la cible est cachée dans une StealthZone (groupe « stealth_zones »).
func target_hidden() -> bool:
	if target == null or _body == null:
		return false
	for node: Node in _body.get_tree().get_nodes_in_group(StealthZone.GROUP):
		var zone: StealthZone = node as StealthZone
		if zone != null and zone.contains(target):
			return true
	return false


func fill(intent: IntentFrame) -> void:
	if _body == null or target == null or not _active or _state == AIState.GIVE_UP:
		return
	if target.is_dead():
		# Cible capturée ou morte : le gardien s'arrête et attend le reset().
		_set_contact(false)
		if _state == AIState.ENGAGE or _state == AIState.RECOVER:
			_state = AIState.CHASE
		return
	var delta: float = 1.0 / float(Engine.physics_ticks_per_second)
	var to_target: Vector2 = target.global_position - _body.global_position
	var seen: bool = _in_contact or not target_hidden()
	if seen:
		_last_seen = target.global_position
		_has_seen = true

	_update_state(to_target, seen, delta)
	match _state:
		AIState.GIVE_UP:
			return
		AIState.SEARCH:
			_fill_search(intent, delta)
		AIState.ENGAGE:
			_fill_engage(intent, to_target)
		AIState.RECOVER:
			_run_toward(intent, to_target.x)
			intent.sprint_held = false
			intent.move_axis *= RECOVER_AXIS
		_:
			_fill_chase(intent, to_target)


func _update_state(to_target: Vector2, seen: bool, delta: float) -> void:
	if to_target.length() > give_up_distance or _body.global_position.y > target.global_position.y + FALL_GIVE_UP:
		_give_up()
		return
	match _state:
		AIState.ENGAGE:
			if absf(to_target.x) > grab_range * RELEASE_FACTOR or absf(to_target.y) > RELEASE_DY:
				_set_contact(false)
				_state = AIState.RECOVER
				_recover_left = RECOVER_TIME
		AIState.RECOVER:
			_recover_left -= delta
			if _recover_left <= 0.0:
				_state = AIState.CHASE
		AIState.SEARCH:
			if seen:
				_state = AIState.CHASE
		_:
			if not seen:
				_state = AIState.SEARCH
				_search_elapsed = 0.0
				_search_waited = 0.0
				lost_track.emit()
				return
			if absf(to_target.x) <= grab_range and absf(to_target.y) < GRAB_DY:
				_state = AIState.ENGAGE
				_set_contact(true)


func _fill_chase(intent: IntentFrame, to_target: Vector2) -> void:
	# Sprint par défaut (l'autopilote ne lève le pied qu'avant un atterrissage
	# étroit) ; simple course tout près d'une cible immobile.
	_run_toward(intent, to_target.x)
	if to_target.length() < NEAR_DISTANCE and absf(target.velocity.x) < TARGET_STILL_SPEED:
		intent.sprint_held = false


## Au contact : calque la vitesse de la cible et corrige l'écart, sans dépasser
## l'allure maximale du MoveTuning (l'axe est borné à ±1).
func _fill_engage(intent: IntentFrame, to_target: Vector2) -> void:
	_run_toward(intent, to_target.x)
	if not _body.is_on_floor():
		return
	var mirror: float = target.velocity.x / _body.tuning.sprint_speed + to_target.x * GLUE_GAIN
	intent.move_axis = clampf(mirror, -1.0, 1.0)
	intent.sprint_held = true
	if absf(intent.move_axis) < MovementDecider.AXIS_DEADZONE:
		# À l'arrêt contre la cible : pas de saut ni de glissade intempestifs.
		intent.move_axis = 0.0
		intent.jump_pressed = false
		intent.slide_pressed = false


func _fill_search(intent: IntentFrame, delta: float) -> void:
	_search_elapsed += delta
	var dx: float = _last_seen.x - _body.global_position.x
	if not _has_seen or absf(dx) <= SEARCH_ARRIVE:
		_search_waited += delta
	else:
		_run_toward(intent, dx)
		intent.sprint_held = false
	if _search_waited >= search_time or _search_elapsed >= search_time * SEARCH_TIMEOUT_FACTOR:
		_give_up()


## Parkour de l'autopilote orienté vers un écart horizontal `dx`.
func _run_toward(intent: IntentFrame, dx: float) -> void:
	if dx > TURN_MARGIN:
		direction = 1
	elif dx < -TURN_MARGIN:
		direction = -1
	super.fill(intent)
	if absf(dx) < ARRIVE_DISTANCE and _body.is_on_floor():
		intent.move_axis = 0.0
		intent.jump_pressed = false
		intent.slide_pressed = false


func _give_up() -> void:
	if _state == AIState.GIVE_UP:
		return
	_set_contact(false)
	_state = AIState.GIVE_UP
	gave_up.emit()


func _set_contact(on: bool) -> void:
	if _in_contact == on:
		return
	_in_contact = on
	contact_changed.emit(on)
