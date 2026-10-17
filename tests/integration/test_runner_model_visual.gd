extends GutTest
## Silhouette 3D : l'AnimationTree suit l'état réel du corps (locomotion mélangée
## selon la vitesse, poses aériennes selon la vitesse verticale, glissade, escalade).

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
	_model = _body.get_node("ModelVisual") as RunnerModelVisual
	_body.position = Vector2(0, -2)
	world.add_child(_body)
	await wait_physics_frames(15)


func _run_until(condition: Callable, max_frames: int) -> void:
	for i: int in max_frames:
		await wait_physics_frames(1)
		if condition.call():
			return


func test_derived_clips_exist() -> void:
	var player: AnimationPlayer = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip: StringName in [
		&"Idle", &"Jog_Fwd", &"Sprint", &"parkour/Slide", &"gen/air_push", &"gen/air_apex",
		&"gen/air_reach", &"gen/land", &"gen/vault", &"gen/roll",
	]:
		assert_true(player.has_animation(clip), "clip %s" % clip)


func test_resample_keeps_length_and_freezes_poses() -> void:
	var player: AnimationPlayer = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var source: Animation = player.get_animation(&"Roll")
	assert_almost_eq(RunnerModelVisual.resample(source, 0.0, -2.0, 2.0).length, source.length / 2.0, 0.01)
	assert_lt(RunnerModelVisual.resample(source, 0.5, -1.0).length, 0.05, "pose figée")


func test_standing_still_is_locomotion_at_rest() -> void:
	await wait_process_frames(2)
	assert_eq(_model.current_clip(), &"loco")
	assert_almost_eq(_model.loco_blend(), 0.0, 0.05)


func test_sprinting_blends_to_the_sprint_cycle() -> void:
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	await _run_until(func() -> bool: return _body.current_state() == PlayerState.State.SPRINT, 120)
	await wait_physics_frames(30)
	await wait_process_frames(2)
	assert_eq(_model.current_clip(), &"loco")
	assert_gt(_model.loco_blend(), 0.95, "cycle de sprint")


func test_air_pose_follows_vertical_speed() -> void:
	_ctrl.jump_held = true
	_ctrl.press_jump()
	await _run_until(func() -> bool: return _body.current_state() == PlayerState.State.JUMP, 30)
	await wait_process_frames(2)
	assert_eq(_model.current_clip(), &"air")
	assert_lt(_model.air_blend(), 0.35, "pose d'appel / de montée")
	await _run_until(func() -> bool: return _body.velocity.y > 400.0, 120)
	await wait_process_frames(4)
	assert_gt(_model.air_blend(), 0.65, "pose de descente")


func test_sliding_plays_the_captured_slide() -> void:
	_ctrl.move_axis = 1.0
	await _run_until(func() -> bool: return _body.current_state() == PlayerState.State.RUN, 60)
	_ctrl.press_slide()
	await _run_until(func() -> bool: return _body.current_state() == PlayerState.State.SLIDE, 30)
	await wait_process_frames(2)
	assert_true(String(_model.current_clip()).begins_with("slide"), "glissade : %s" % _model.current_clip())


func test_climbing_a_wall_raises_the_arms() -> void:
	# Mur trop haut pour être franchi : course murale puis escalade.
	_body.get_parent().add_child(LevelGeometry.make_block(Rect2(300, -1000, 60, 1000)))
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	await _run_until(func() -> bool: return _body.current_state() == PlayerState.State.WALL_CLIMB, 200)
	assert_eq(_body.current_state(), PlayerState.State.WALL_CLIMB, "le corps escalade le mur")
	await wait_process_frames(10)
	assert_eq(_model.current_clip(), &"climb")
	assert_gt(_model.arm_weight(), 0.5, "les bras font les gestes d'escalade")
