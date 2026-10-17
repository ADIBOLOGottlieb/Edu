extends GutTest
## Gardien poursuivant (pursuer.tscn + PursuerAIController) contre un vrai coureur
## (player.tscn + ScriptedController), sur une vraie géométrie et la vraie physique.
## Les conditions sont pilotées par l'état (wait_physics_frames peut sauter des ticks) ;
## les positions sont relevées à chaque tick via SceneTree.physics_frame.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")
const PURSUER_SCENE: PackedScene = preload("res://src/gameplay/actors/pursuer/pursuer.tscn")

var _world: Node2D
var _runner: RunnerBody
var _ctrl: ScriptedController
var _guard: RunnerBody
var _ai: PursuerAIController
var _contacts: Array[bool] = []
var _lost: int = 0
var _gave_up: int = 0
## Relevés par tick : position du gardien.
var _track: Array[Vector2] = []


func before_each() -> void:
	_contacts.clear()
	_lost = 0
	_gave_up = 0
	_track.clear()
	_world = Node2D.new()
	add_child_autofree(_world)
	_runner = PLAYER_SCENE.instantiate() as RunnerBody
	var human: Node = _runner.get_node("Controller")
	_runner.remove_child(human)
	human.free()
	_ctrl = ScriptedController.new()
	_ctrl.name = "Controller"
	_runner.add_child(_ctrl)
	_guard = PURSUER_SCENE.instantiate() as RunnerBody
	_ai = _guard.get_node("Controller") as PursuerAIController
	_ai.target = _runner
	_ai.contact_changed.connect(func(on: bool) -> void: _contacts.append(on))
	_ai.lost_track.connect(func() -> void: _lost += 1)
	_ai.gave_up.connect(func() -> void: _gave_up += 1)
	# Libérés même quand un test ne les ajoute pas à la scène.
	autofree(_runner)
	autofree(_guard)


func after_each() -> void:
	if get_tree().physics_frame.is_connected(_record):
		get_tree().physics_frame.disconnect(_record)


func _block(rect: Rect2) -> void:
	_world.add_child(LevelGeometry.make_block(rect))


func _zone(at: Vector2, size: Vector2) -> StealthZone:
	var zone: StealthZone = StealthZone.new()
	zone.size = size
	zone.position = at
	_world.add_child(zone)
	return zone


## Le gardien est désactivé pendant la mise en place (corps posés au sol).
func _spawn(runner_at: Vector2, guard_at: Vector2) -> void:
	_runner.position = runner_at
	_guard.position = guard_at
	_ai.set_active(false)
	_world.add_child(_runner)
	_world.add_child(_guard)
	await wait_physics_frames(10)
	get_tree().physics_frame.connect(_record)
	_ai.set_active(true)


func _record() -> void:
	if is_instance_valid(_guard):
		_track.append(_guard.global_position)


func _run_until(condition: Callable, max_frames: int) -> void:
	for i: int in max_frames:
		await wait_physics_frames(1)
		if condition.call():
			return


func _gap() -> float:
	return absf(_runner.global_position.x - _guard.global_position.x)


# --- Poursuite et contact ----------------------------------------------------------

func test_guard_body_is_an_enemy_that_only_collides_with_the_world() -> void:
	assert_eq(_guard.collision_layer, CollisionLayers.ENEMY)
	assert_eq(_guard.collision_mask, CollisionLayers.WORLD)
	assert_eq(_guard.tuning.sprint_speed, 455.0, "plus lent que le joueur (480)")
	assert_true(_ai is AutopilotController, "parkour de l'autopilote réutilisé")


func test_chases_and_closes_in_on_a_standing_target_without_teleporting() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	await _spawn(Vector2(900, -2), Vector2(0, -2))
	var start_gap: float = _gap()
	assert_eq(_ai.ai_state(), &"chase")
	await _run_until(func() -> bool: return _ai.is_in_contact(), 300)
	assert_true(_ai.is_in_contact(), "le gardien a rejoint la cible")
	assert_eq(_ai.ai_state(), &"engage")
	assert_lt(_gap(), start_gap)
	assert_lte(_gap(), _ai.grab_range * 1.6)
	assert_eq(_contacts, [true] as Array[bool])
	# Aucun saut de position : jamais plus que la vitesse maximale d'un tick.
	var step_max: float = _guard.tuning.sprint_speed / float(Engine.physics_ticks_per_second) + 0.5
	var worst: float = 0.0
	for i: int in range(1, _track.size()):
		worst = maxf(worst, absf(_track[i].x - _track[i - 1].x))
		assert_lt(absf(_track[i].y - _track[i - 1].y), 2.0, "reste au sol")
	assert_gt(_track.size(), 60)
	assert_lte(worst, step_max, "déplacement par tick borné par le MoveTuning")


func test_stays_glued_to_a_still_target_then_loses_contact_when_it_sprints_away() -> void:
	_block(Rect2(-1000, 0, 8000, 100))
	await _spawn(Vector2(400, -2), Vector2(0, -2))
	await _run_until(func() -> bool: return _ai.is_in_contact(), 200)
	assert_true(_ai.is_in_contact())
	# Contact tenu contre une cible immobile.
	await wait_physics_frames(40)
	assert_true(_ai.is_in_contact(), "reste collé")
	assert_lte(_gap(), _ai.grab_range * 1.6)
	assert_lt(absf(_guard.velocity.x), 60.0, "immobile contre la cible")
	# Le coureur sprinte (480 > 455) : il s'échappe.
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	await _run_until(func() -> bool: return not _ai.is_in_contact(), 400)
	assert_false(_ai.is_in_contact(), "contact rompu en sprintant")
	assert_eq(_contacts, [true, false] as Array[bool])
	assert_eq(_ai.ai_state(), &"recover", "trébuche brièvement")
	await _run_until(func() -> bool: return _ai.ai_state() == &"chase", 60)
	assert_eq(_ai.ai_state(), &"chase", "puis reprend la poursuite")
	var gap_after_recover: float = _gap()
	await wait_physics_frames(60)
	assert_gt(_gap(), gap_after_recover, "le coureur creuse l'écart")
	assert_false(_ai.is_in_contact())


func test_runs_instead_of_sprinting_when_close_to_a_still_target() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	await _spawn(Vector2(1200, -2), Vector2(0, -2))
	await _run_until(func() -> bool: return _guard.current_state() == PlayerState.State.SPRINT, 60)
	assert_eq(_guard.current_state(), PlayerState.State.SPRINT, "sprint de loin")
	await _run_until(func() -> bool: return _gap() < 140.0, 300)
	await wait_physics_frames(2)
	assert_false(_ai.is_in_contact(), "pas encore au contact")
	assert_eq(_guard.current_state(), PlayerState.State.RUN, "course tout près d'une cible immobile")
	assert_lte(absf(_guard.velocity.x), _guard.tuning.sprint_speed + 0.5)


func test_target_passes_through_the_guard_without_being_blocked() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	await _spawn(Vector2(0, -2), Vector2(300, -2))
	_ai.set_active(false)
	_ctrl.move_axis = 1.0
	await _run_until(func() -> bool: return _runner.global_position.x > 500.0, 200)
	assert_gt(_runner.global_position.x, 500.0, "le gardien ne bloque pas le coureur")
	assert_almost_eq(_guard.global_position.x, 300.0, 2.0, "et n'est pas poussé")


func test_follows_the_target_over_a_gap_and_up_a_wall() -> void:
	_block(Rect2(-1000, 0, 1400, 100))
	_block(Rect2(560, 0, 1600, 100))
	_block(Rect2(1100, -160, 1000, 160))
	await _spawn(Vector2(1500, -162), Vector2(0, -2))
	await _run_until(func() -> bool: return _ai.is_in_contact(), 600)
	assert_true(_ai.is_in_contact(), "rejoint la cible sur le toit")
	assert_lt(_guard.global_position.y, -150.0, "est monté sur le mur")
	assert_false(_guard.is_dead())


# --- Perte de trace -----------------------------------------------------------------

func test_hidden_target_is_searched_then_abandoned() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_zone(Vector2(900, 0), Vector2(200, 150))
	_ai.search_time = 1.0
	await _spawn(Vector2(500, -2), Vector2(0, -2))
	# Le coureur file se cacher dans l'ombre.
	_ctrl.move_axis = 1.0
	_ctrl.policy = func(intent: IntentFrame) -> void:
		if _runner.global_position.x > 900.0:
			intent.move_axis = 0.0
	await _run_until(func() -> bool: return _ai.ai_state() == &"search", 200)
	assert_eq(_ai.ai_state(), &"search")
	assert_eq(_lost, 1, "lost_track émis une fois")
	assert_true(_ai.target_hidden())
	var last_seen: Vector2 = _ai.last_seen_position()
	assert_between(last_seen.x, 700.0, 830.0, "dernière position vue : à l'entrée de l'ombre")
	var ticks_at_start: int = _track.size()
	await _run_until(func() -> bool: return _ai.ai_state() == &"give_up", 400)
	assert_eq(_ai.ai_state(), &"give_up")
	assert_eq(_gave_up, 1)
	var search_ticks: int = _track.size() - ticks_at_start
	assert_gte(float(search_ticks) / float(Engine.physics_ticks_per_second), _ai.search_time, "fouille au moins search_time")
	assert_almost_eq(_guard.global_position.x, last_seen.x, PursuerAIController.SEARCH_ARRIVE + 30.0, "fouille la dernière position vue")
	assert_false(_ai.is_in_contact())
	# Abandon : immobile, même si la cible ressort.
	_ctrl.policy = Callable()
	_ctrl.move_axis = -1.0
	await wait_physics_frames(30)
	assert_eq(_ai.ai_state(), &"give_up", "l'abandon dure jusqu'au reset")
	assert_lt(absf(_guard.velocity.x), 5.0)


func test_reappearing_target_is_chased_again() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_zone(Vector2(900, 0), Vector2(200, 150))
	_ai.search_time = 3.0
	await _spawn(Vector2(500, -2), Vector2(0, -2))
	_ctrl.move_axis = 1.0
	_ctrl.policy = func(intent: IntentFrame) -> void:
		if _runner.global_position.x > 900.0:
			intent.move_axis = 0.0
	await _run_until(func() -> bool: return _ai.ai_state() == &"search", 200)
	assert_eq(_ai.ai_state(), &"search")
	# Il ressort de l'ombre de l'autre côté.
	_ctrl.policy = Callable()
	await _run_until(func() -> bool: return _ai.ai_state() == &"chase", 120)
	assert_eq(_ai.ai_state(), &"chase", "cible revue : poursuite")
	assert_false(_ai.target_hidden())
	assert_eq(_gave_up, 0)


func test_contact_is_kept_inside_a_stealth_zone() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_zone(Vector2(400, 0), Vector2(240, 150))
	await _spawn(Vector2(200, -2), Vector2(0, -2))
	await _run_until(func() -> bool: return _ai.is_in_contact(), 200)
	assert_true(_ai.is_in_contact())
	_ctrl.move_axis = 1.0
	_ctrl.policy = func(intent: IntentFrame) -> void:
		if _runner.global_position.x > 400.0:
			intent.move_axis = 0.0
	await _run_until(func() -> bool: return _runner.global_position.x > 400.0 and absf(_runner.velocity.x) < 1.0, 200)
	assert_true(_ai.target_hidden(), "la cible est dans l'ombre")
	await wait_physics_frames(20)
	assert_true(_ai.is_in_contact(), "on ne se cache pas sous le nez du gardien")
	assert_eq(_lost, 0)


func test_gives_up_when_the_target_is_too_far() -> void:
	_block(Rect2(-1000, 0, 6000, 100))
	await _spawn(Vector2(3000, -2), Vector2(0, -2))
	await _run_until(func() -> bool: return _gave_up > 0, 30)
	assert_eq(_ai.ai_state(), &"give_up")
	assert_eq(_gave_up, 1)


# --- Cible morte, désactivation, remise en place ----------------------------------------

func test_dead_target_stops_the_guard() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	await _spawn(Vector2(300, -2), Vector2(0, -2))
	await _run_until(func() -> bool: return _ai.is_in_contact(), 200)
	assert_true(_ai.is_in_contact())
	_runner.kill(&"spikes")
	await wait_physics_frames(20)
	assert_false(_ai.is_in_contact(), "contact relâché")
	assert_eq(_contacts, [true, false] as Array[bool])
	assert_lt(absf(_guard.velocity.x), 5.0, "le gardien s'arrête")


func test_inactive_guard_stands_still() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	await _spawn(Vector2(800, -2), Vector2(0, -2))
	_ai.set_active(false)
	await wait_physics_frames(30)
	assert_false(_ai.is_active())
	assert_almost_eq(_guard.global_position.x, 0.0, 1.0)
	_ai.set_active(true)
	await _run_until(func() -> bool: return _guard.global_position.x > 50.0, 60)
	assert_gt(_guard.global_position.x, 50.0, "repart une fois réactivé")


func test_reset_places_the_guard_and_clears_its_state() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	await _spawn(Vector2(300, -2), Vector2(0, -2))
	await _run_until(func() -> bool: return _ai.is_in_contact(), 200)
	assert_true(_ai.is_in_contact())
	_ai.reset(Vector2(-400, -2))
	assert_eq(_guard.global_position, Vector2(-400, -2))
	assert_eq(_guard.velocity, Vector2.ZERO)
	assert_false(_ai.is_in_contact())
	assert_eq(_ai.ai_state(), &"chase")
	assert_eq(_contacts, [true, false] as Array[bool])
	assert_eq(_guard.facing, 1, "tourné vers la cible")
	await _run_until(func() -> bool: return _ai.is_in_contact(), 300)
	assert_true(_ai.is_in_contact(), "repart à la poursuite")


func test_reset_after_giving_up_resumes_the_chase() -> void:
	_block(Rect2(-1000, 0, 6000, 100))
	await _spawn(Vector2(3000, -2), Vector2(0, -2))
	await _run_until(func() -> bool: return _gave_up > 0, 30)
	_ai.reset(Vector2(2700, -2))
	await wait_physics_frames(5)
	assert_eq(_ai.ai_state(), &"chase")
	assert_gt(_guard.global_position.x, 2700.0, "repart vers la cible")


# --- Pièges ---------------------------------------------------------------------------

func test_traps_ignore_the_guard() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	var spec: HazardSpec = HazardSpec.new()
	spec.kind = Hazard.SPIKES
	spec.rect = Rect2(-24, -16, 48, 16)
	_world.add_child(Hazard.create(spec, null))
	# Le gardien se pose directement sur les pics.
	await _spawn(Vector2(900, -2), Vector2(0, -2))
	_ai.set_active(false)
	await wait_physics_frames(30)
	assert_false(_guard.is_dead(), "les pièges ne détectent que la couche PLAYER")
	_ai.set_active(true)
	await _run_until(func() -> bool: return _ai.is_in_contact(), 300)
	assert_false(_guard.is_dead())
	assert_true(_ai.is_in_contact())


# --- Allure ------------------------------------------------------------------------------

func test_guard_wears_its_gear_and_the_player_does_not() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	await _spawn(Vector2(900, -2), Vector2(0, -2))
	await wait_process_frames(3)
	var guard_model: RunnerModelVisual = _guard.get_node("ModelVisual") as RunnerModelVisual
	var runner_model: RunnerModelVisual = _runner.get_node("ModelVisual") as RunnerModelVisual
	assert_not_null(guard_model.torch_beam(), "lampe torche du gardien")
	assert_true(guard_model.torch_beam().visible)
	assert_null(runner_model.torch_beam(), "le coureur garde son allure")
	assert_eq(runner_model.body_scale, Vector3.ONE)
	assert_gt(guard_model.body_scale.y, 1.0, "gardien plus grand")
	assert_lt(guard_model.body_scale.z, 1.0, "et plus élancé")
	assert_ne(guard_model.ink, runner_model.ink, "encre distincte")
