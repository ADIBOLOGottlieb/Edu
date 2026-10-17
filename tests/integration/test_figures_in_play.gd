extends GutTest
## Figures déclenchées par le vrai corps sur une vraie géométrie, et rendues
## par le visuel (rotation réelle du salto, retour à la verticale).

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")

var _world: Node2D
var _body: RunnerBody
var _ctrl: ScriptedController
var _figures: Array[StringName] = []
var _states: Array[int] = []


func before_each() -> void:
	_figures.clear()
	_states.clear()
	_world = Node2D.new()
	add_child_autofree(_world)
	_body = PLAYER_SCENE.instantiate() as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	_ctrl = ScriptedController.new()
	_ctrl.name = "Controller"
	_body.add_child(_ctrl)


func _block(rect: Rect2) -> void:
	_world.add_child(LevelGeometry.make_block(rect))


func _spawn() -> void:
	_body.position = Vector2(0, -2)
	_world.add_child(_body)
	_body.figure_started.connect(func(figure_name: StringName) -> void: _figures.append(figure_name))
	_body.state_changed.connect(func(_from: PlayerState.State, to: PlayerState.State) -> void: _states.append(to))
	await wait_physics_frames(15)
	_figures.clear()
	_states.clear()


func _run_until(condition: Callable, max_frames: int) -> void:
	for i: int in max_frames:
		await wait_physics_frames(1)
		if condition.call():
			return


func _visual() -> RunnerVisual:
	return _body.get_node("Visual") as RunnerVisual


func test_sprinting_at_a_low_wall_tic_tacs_over_it() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_block(Rect2(300, -100, 120, 100))
	await _spawn()
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	await _run_until(func() -> bool: return _body.global_position.x > 520.0 and _body.is_on_floor(), 200)
	assert_has(_figures, &"tic_tac")
	assert_gt(_body.global_position.x, 520.0, "passé de l'autre côté")
	assert_false(_states.has(PlayerState.State.LEDGE_HANG), "sans s'accrocher")
	assert_false(_states.has(PlayerState.State.WALL_RUN), "sans course murale")


func test_kong_vault_at_full_speed_and_lazy_vault_when_slower() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_block(Rect2(300, -40, 100, 40))
	_block(Rect2(900, -40, 100, 40))
	await _spawn()
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	await _run_until(func() -> bool: return _body.global_position.x > 500.0, 200)
	assert_has(_figures, &"kong_vault")
	_ctrl.sprint_held = false
	await _run_until(func() -> bool: return _body.global_position.x > 1100.0, 300)
	assert_has(_figures, &"lazy_vault")


func test_sprint_jump_over_a_gap_is_a_front_flip_that_lands_upright() -> void:
	_block(Rect2(-1000, 0, 1400, 100))
	_block(Rect2(560, 0, 1400, 100))
	await _spawn()
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	_ctrl.jump_held = true
	var max_rotation: Array[float] = [0.0]
	_ctrl.policy = func(intent: IntentFrame) -> void:
		if _body.is_on_floor() and _body.global_position.x > 375.0 and _body.global_position.x < 400.0:
			intent.jump_pressed = true
		max_rotation[0] = maxf(max_rotation[0], _visual().pose_value(&"rotation"))
	await _run_until(func() -> bool: return _body.global_position.x > 650.0 and _body.is_on_floor(), 200)
	assert_has(_figures, &"front_flip")
	assert_gt(max_rotation[0], PI, "le corps a réellement tourné")
	_ctrl.move_axis = 0.0
	await wait_physics_frames(40)
	assert_lt(absf(wrapf(_visual().pose_value(&"rotation"), -PI, PI)), 0.3, "revenu à la verticale")


func test_jumping_off_a_wall_run_is_a_wall_flip() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_block(Rect2(300, -400, 60, 400))
	await _spawn()
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	await _run_until(func() -> bool: return _body.current_state() == PlayerState.State.WALL_RUN, 200)
	_ctrl.press_jump()
	await wait_physics_frames(5)
	assert_has(_figures, &"wall_flip")


func test_double_jump_is_a_corkscrew() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_body.abilities.unlock(AbilitySet.DOUBLE_JUMP)
	await _spawn()
	_ctrl.jump_held = true
	_ctrl.press_jump()
	await _run_until(func() -> bool: return _body.velocity.y > -150.0, 60)
	_ctrl.press_jump()
	await wait_physics_frames(5)
	assert_has(_figures, &"corkscrew")


func test_jumping_to_a_ledge_with_momentum_is_a_cat_leap() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_block(Rect2(300, -200, 60, 200))
	await _spawn()
	_ctrl.move_axis = 0.8  # 256 px/s : trop lent pour une course murale ou un tic-tac
	_ctrl.jump_held = true
	_ctrl.policy = func(intent: IntentFrame) -> void:
		if _body.is_on_floor() and _body.global_position.x > 200.0:
			intent.jump_pressed = true
	await _run_until(func() -> bool: return _body.current_state() == PlayerState.State.LEDGE_HANG, 200)
	assert_eq(_body.current_state(), PlayerState.State.LEDGE_HANG)
	assert_has(_figures, &"cat_leap")


func test_slide_at_a_hard_landing_is_a_parkour_roll() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_body.position = Vector2(0, -400)
	_world.add_child(_body)
	_body.figure_started.connect(func(figure_name: StringName) -> void: _figures.append(figure_name))
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	var pressed: Array[bool] = [false]
	_ctrl.policy = func(intent: IntentFrame) -> void:
		if not pressed[0] and _body.velocity.y > 0.0 and _body.global_position.y > -80.0:
			intent.slide_pressed = true
			pressed[0] = true
	await wait_physics_frames(90)
	assert_has(_figures, &"parkour_roll")
