extends GutTest
## Niveau complet (LevelRunner + ChunkStreamer + vrai coureur) : arrivée et chute.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")
const LIBRARY_PATH: String = "res://data/levels/chunk_library.tres"

var _root: Node2D
var _runner: LevelRunner
var _body: RunnerBody
var _ctrl: ScriptedController


func _build(order: Array[StringName]) -> void:
	_root = Node2D.new()
	_runner = LevelRunner.new()
	_runner.library = load(LIBRARY_PATH) as ChunkLibrary
	_runner.mode = ChunkSequencer.Mode.ORDERED
	_runner.seed_value = 1
	_runner.ordered_ids = order
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
	_body.position = Vector2(60, -2)
	_runner.player = _body

	_root.add_child(_runner)
	_root.add_child(_body)
	add_child_autofree(_root)
	watch_signals(_runner)


func test_running_through_a_flat_course_reaches_the_finish_once() -> void:
	_build([&"flat_run", &"flat_run"] as Array[StringName])
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	for i: int in 300:
		await wait_physics_frames(1)
		if _runner.is_completed():
			break
	assert_signal_emit_count(_runner, "level_completed", 1)
	await wait_physics_frames(30)
	assert_signal_emit_count(_runner, "level_completed", 1, "jamais deux fois")
	assert_lt(_body.global_position.x, 1600.0, "arrêté par le mur de fin")
	assert_gt(_runner.distance_meters(), 30.0)


func test_falling_into_a_gap_respawns_at_the_start_of_that_chunk() -> void:
	_build([&"flat_run", &"small_gap", &"flat_run"] as Array[StringName])
	# Sans sauter, et en lâchant la direction au-dessus du trou : sinon le coureur
	# escalade la paroi du sol suivant et se hisse (comportement voulu du jalon M2).
	_ctrl.move_axis = 1.0
	_ctrl.policy = func(intent: IntentFrame) -> void:
		if _body.global_position.x > 800.0 + 380.0:
			intent.move_axis = 0.0
	for i: int in 300:
		await wait_physics_frames(1)
		if _runner.fall_count > 0:
			break
	assert_signal_emit_count(_runner, "player_fell", 1)
	var fell_x: float = get_signal_parameters(_runner, "player_fell")[0]
	assert_between(fell_x, 800.0 + 360.0, 800.0 + 520.0, "tombé dans le trou du 2e tronçon")
	assert_almost_eq(_body.global_position.x, 800.0 + _runner.respawn_offset_x, 1.0)
	_ctrl.move_axis = 0.0
	await wait_physics_frames(20)
	assert_true(_body.is_on_floor(), "replacé sur le sol")
