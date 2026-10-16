extends GutTest
## Calcul de vitesse par état (LocomotionMotor), sans moteur physique.

const DT: float = 1.0 / 60.0

var _tuning: MoveTuning
var _intent: IntentFrame
var _ctx: MovementContext


func before_each() -> void:
	_tuning = MoveTuning.new()
	_intent = IntentFrame.new()
	_ctx = MovementContext.new()
	_ctx.on_floor = true


func _step(state: PlayerState.State, velocity: Vector2) -> Vector2:
	return LocomotionMotor.step(state, velocity, _intent, _ctx, _tuning, DT)


func _run_for(state: PlayerState.State, velocity: Vector2, ticks: int) -> Vector2:
	for i: int in ticks:
		velocity = _step(state, velocity)
	return velocity


func test_run_accelerates_to_run_speed_and_caps() -> void:
	_intent.move_axis = 1.0
	var v: Vector2 = _run_for(PlayerState.State.RUN, Vector2.ZERO, 60)
	assert_almost_eq(v.x, _tuning.run_speed, 0.01)


func test_sprint_is_faster_than_run() -> void:
	_intent.move_axis = 1.0
	var v: Vector2 = _run_for(PlayerState.State.SPRINT, Vector2.ZERO, 120)
	assert_almost_eq(v.x, _tuning.sprint_speed, 0.01)
	assert_gt(_tuning.sprint_speed, _tuning.run_speed)


func test_run_turns_around_instantly() -> void:
	_intent.move_axis = -1.0
	var v: Vector2 = _step(PlayerState.State.RUN, Vector2(_tuning.run_speed, 0))
	assert_lt(v.x, 0.0)


func test_sprint_decelerates_before_turning_around() -> void:
	_intent.move_axis = -1.0
	var v: Vector2 = _step(PlayerState.State.SPRINT, Vector2(_tuning.sprint_speed, 0))
	assert_almost_eq(v.x, _tuning.sprint_speed - _tuning.sprint_turn_decel * DT, 0.01)
	assert_gt(v.x, 0.0)


func test_idle_decelerates_to_a_stop() -> void:
	var v: Vector2 = _run_for(PlayerState.State.IDLE, Vector2(_tuning.run_speed, 0), 30)
	assert_eq(v.x, 0.0)


func test_gravity_applies_in_the_air_and_is_capped() -> void:
	_ctx.on_floor = false
	var v: Vector2 = _step(PlayerState.State.FALL, Vector2.ZERO)
	assert_almost_eq(v.y, _tuning.gravity_down * DT, 0.01)
	v = _run_for(PlayerState.State.FALL, Vector2.ZERO, 600)
	assert_eq(v.y, _tuning.max_fall_speed)


func test_holding_jump_gives_a_higher_jump() -> void:
	_ctx.on_floor = false
	var start: Vector2 = Vector2(0, -_tuning.jump_velocity)
	_intent.jump_held = true
	var held: Vector2 = _step(PlayerState.State.JUMP, start)
	_intent.jump_held = false
	var released: Vector2 = _step(PlayerState.State.JUMP, start)
	assert_lt(held.y, released.y, "maintenir Saut freine moins la montée")


func test_floor_cancels_downward_speed() -> void:
	var v: Vector2 = _step(PlayerState.State.RUN, Vector2(0, 300))
	assert_eq(v.y, 0.0)


func test_slide_ignores_steering() -> void:
	_intent.move_axis = -1.0
	var v: Vector2 = _step(PlayerState.State.SLIDE, Vector2(400, 0))
	assert_almost_eq(v.x, 400.0 - _tuning.slide_friction * DT, 0.01)


func test_slide_under_ceiling_never_drops_below_crawl_speed() -> void:
	_ctx.can_stand = false
	var v: Vector2 = _run_for(PlayerState.State.SLIDE, Vector2(500, 0), 600)
	assert_almost_eq(v.x, _tuning.slide_crawl_speed, 0.01)


func test_air_control_keeps_sprint_momentum() -> void:
	_ctx.on_floor = false
	_intent.move_axis = 1.0
	var v: Vector2 = _step(PlayerState.State.JUMP, Vector2(_tuning.sprint_speed, -300))
	assert_almost_eq(v.x, _tuning.sprint_speed, 0.01)


func test_entering_jump_sets_the_impulse() -> void:
	var v: Vector2 = LocomotionMotor.on_enter(PlayerState.State.IDLE, PlayerState.State.JUMP, Vector2(100, 0), _ctx, _tuning)
	assert_eq(v, Vector2(100, -_tuning.jump_velocity))


func test_entering_slide_boosts_in_the_direction_of_travel() -> void:
	var v: Vector2 = LocomotionMotor.on_enter(PlayerState.State.RUN, PlayerState.State.SLIDE, Vector2(-400, 0), _ctx, _tuning)
	assert_almost_eq(v.x, -400.0 * _tuning.slide_boost, 0.01)
	_ctx.facing = -1
	v = LocomotionMotor.on_enter(PlayerState.State.RUN, PlayerState.State.SLIDE, Vector2.ZERO, _ctx, _tuning)
	assert_eq(v.x, -_tuning.run_speed, "à l'arrêt : vitesse de course dans le sens du regard")
