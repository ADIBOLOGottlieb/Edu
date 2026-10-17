extends GutTest
## Mort par piège ou ennemi : le corps s'immobilise, le niveau compte la mort puis le
## replace au début du tronçon, brièvement invulnérable.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")
const LIBRARY_PATH: String = "res://data/levels/chunk_library.tres"

var _runner: LevelRunner
var _body: RunnerBody
var _ctrl: ScriptedController
var _causes: Array[StringName] = []


func before_each() -> void:
	_causes.clear()
	var root: Node2D = Node2D.new()
	_runner = LevelRunner.new()
	_runner.library = load(LIBRARY_PATH) as ChunkLibrary
	_runner.mode = ChunkSequencer.Mode.ORDERED
	_runner.seed_value = 1
	_runner.ordered_ids = [&"flat_run", &"flat_run", &"flat_run"] as Array[StringName]
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
	root.add_child(_runner)
	root.add_child(_body)
	add_child_autofree(root)
	_runner.player_died.connect(func(cause: StringName) -> void: _causes.append(cause))
	await wait_physics_frames(10)


func _run_until(condition: Callable, max_frames: int) -> void:
	for i: int in max_frames:
		await wait_physics_frames(1)
		if condition.call():
			return


func test_death_freezes_the_body_and_is_counted() -> void:
	_ctrl.move_axis = 1.0
	await _run_until(func() -> bool: return _body.global_position.x > 900.0, 200)
	assert_true(_body.kill(&"spikes"))
	assert_true(_body.is_dead())
	assert_eq(_body.current_state(), PlayerState.State.DEATH)
	assert_eq(_runner.death_count, 1)
	assert_eq(_causes, [&"spikes"] as Array[StringName])
	var frozen_at: Vector2 = _body.global_position
	await wait_physics_frames(10)
	assert_true(_body.is_dead(), "immobile pendant la pause")
	assert_almost_eq(_body.global_position.x, frozen_at.x, 1.0)


func test_respawn_at_the_start_of_the_chunk_then_invulnerable() -> void:
	_ctrl.move_axis = 1.0
	await _run_until(func() -> bool: return _body.global_position.x > 1100.0, 200)
	_ctrl.move_axis = 0.0
	_body.kill(&"saw")
	await _run_until(func() -> bool: return not _body.is_dead(), 120)
	assert_false(_body.is_dead(), "réapparu après la pause")
	assert_almost_eq(_body.global_position.x, 800.0 + _runner.respawn_offset_x, 2.0, "début du 2e tronçon")
	assert_eq(_body.current_state(), PlayerState.State.IDLE)
	assert_false(_body.kill(&"saw"), "invulnérable juste après la réapparition")
	await wait_seconds(RunnerBody.INVULNERABLE_AFTER_REVIVE + 0.2)
	assert_true(_body.can_be_hurt(), "de nouveau vulnérable")
	assert_eq(_runner.total_deaths(), 1)
