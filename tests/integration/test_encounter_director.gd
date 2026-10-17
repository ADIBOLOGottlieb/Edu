extends GutTest
## Poursuite complète dans un vrai niveau : le vigile entre derrière le coureur,
## un coureur immobile est capturé (séquence de l'EncounterFSM), un coureur qui
## sprinte s'échappe, et un parcours sans poursuite n'a pas de vigile.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")
const LIBRARY_PATH: String = "res://data/levels/chunk_library.tres"
const LOME_PATH: String = "res://data/cities/lome.tres"

var _runner: LevelRunner
var _body: RunnerBody
var _ctrl: ScriptedController
var _director: EncounterDirector
var _states: Array[EncounterFSM.State] = []


func _build(city: CityDefinition = null, route_index: int = 0) -> void:
	_states.clear()
	var root: Node2D = Node2D.new()
	_runner = LevelRunner.new()
	_runner.library = load(LIBRARY_PATH) as ChunkLibrary
	_runner.mode = ChunkSequencer.Mode.ORDERED
	_runner.seed_value = 1
	_runner.ordered_ids = [&"flat_run", &"flat_run", &"flat_run", &"flat_run", &"flat_run", &"flat_run"] as Array[StringName]
	_runner.city = city
	_runner.route_index = route_index
	var streamer: ChunkStreamer = ChunkStreamer.new()
	streamer.name = "Streamer"
	_runner.add_child(streamer)
	_body = PLAYER_SCENE.instantiate() as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	_ctrl = ScriptedController.new()
	_ctrl.name = "Controller"
	_body.add_child(_ctrl)
	_body.position = Vector2(900, -2)
	_runner.player = _body
	_director = EncounterDirector.new()
	_director.runner = _runner
	_director.start_delay = 0.3
	_director.start_behind = 500.0
	root.add_child(_runner)
	root.add_child(_body)
	root.add_child(_director)
	add_child_autofree(root)
	_director.fsm.state_changed.connect(func(_from: EncounterFSM.State, to: EncounterFSM.State, _r: StringName) -> void:
		_states.append(to))


func _run_until(condition: Callable, max_frames: int) -> void:
	for i: int in max_frames:
		await wait_physics_frames(1)
		if condition.call():
			return


func test_still_runner_is_caught_through_the_encounter_states() -> void:
	_build()
	await _run_until(func() -> bool: return _director.captures > 0, 900)
	assert_eq(_director.captures, 1, "capturé")
	assert_eq(_states, [
		EncounterFSM.State.PURSUIT, EncounterFSM.State.COMBAT,
		EncounterFSM.State.CAPTURED, EncounterFSM.State.MISSION_FAILED,
	] as Array[EncounterFSM.State])
	assert_eq(_runner.death_count, 1, "la capture compte comme une mort (énergie, M9)")
	await _run_until(func() -> bool: return not _body.is_dead(), 120)
	await wait_physics_frames(5)
	assert_eq(_director.fsm.current, EncounterFSM.State.PURSUIT, "nouvelle tentative")
	assert_almost_eq(_director.gauge.value, 0.0, 0.05, "jauge remise à zéro")
	assert_gt(_director.pursuer_distance(), 200.0, "vigile replacé derrière")


func test_sprinting_runner_escapes() -> void:
	_build()
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	for i: int in 420:
		await wait_physics_frames(1)
	assert_eq(_director.captures, 0, "jamais capturé en sprintant")
	assert_false(_director.pursuer_ai().is_in_contact())
	assert_gt(_director.pursuer_distance(), 300.0, "le vigile est distancé")


func test_route_without_pursuit_has_no_guard() -> void:
	_build(load(LOME_PATH) as CityDefinition, 0)
	for i: int in 120:
		await wait_physics_frames(1)
	assert_false(_director.enabled)
	assert_null(_director.pursuer)
