extends GutTest
## Prototype de silhouette 3D : le mannequin joue l'animation capturée qui
## correspond à l'état réel du corps.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")

var _body: RunnerBody
var _ctrl: ScriptedController
var _model: RunnerModelVisual


func before_each() -> void:
	var world: Node2D = Node2D.new()
	add_child_autofree(world)
	world.add_child(LevelGeometry.make_block(Rect2(-4000, 0, 8000, 100)))
	_body = PLAYER_SCENE.instantiate() as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	_ctrl = ScriptedController.new()
	_ctrl.name = "Controller"
	_body.add_child(_ctrl)
	_model = RunnerModelVisual.new()
	_body.add_child(_model)
	_body.position = Vector2(0, -2)
	world.add_child(_body)
	await wait_physics_frames(15)


func _run_until(condition: Callable, max_frames: int) -> void:
	for i: int in max_frames:
		await wait_physics_frames(1)
		if condition.call():
			return


func test_model_has_the_captured_clips() -> void:
	var player: AnimationPlayer = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(player)
	for clip: StringName in [&"Idle", &"Jog_Fwd", &"Sprint", &"Jump_Start", &"Jump", &"Jump_Land", &"Roll"]:
		assert_true(player.has_animation(clip), "clip %s" % clip)


func test_standing_still_plays_idle() -> void:
	await wait_process_frames(2)
	assert_eq(_model.current_clip(), &"Idle")


func test_running_plays_the_jog_cycle() -> void:
	_ctrl.move_axis = 1.0
	await _run_until(func() -> bool: return _body.current_state() == PlayerState.State.RUN, 60)
	await wait_process_frames(2)
	assert_eq(_model.current_clip(), &"Jog_Fwd")


func test_jumping_starts_with_the_take_off_clip() -> void:
	_ctrl.jump_held = true
	_ctrl.press_jump()
	await _run_until(func() -> bool: return _body.current_state() == PlayerState.State.JUMP, 30)
	await wait_process_frames(1)
	assert_eq(_model.current_clip(), &"Jump_Start")
