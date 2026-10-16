extends GutTest
## Règles de parkour du jalon M2 (MovementDecider, LocomotionMotor), sans physique.

const DT: float = 1.0 / 60.0

var _tuning: MoveTuning
var _intent: IntentFrame
var _ctx: MovementContext


func before_each() -> void:
	_tuning = MoveTuning.new()
	_intent = IntentFrame.new()
	_ctx = MovementContext.new()
	_ctx.on_floor = true
	_ctx.facing = 1
	_ctx.wall_climb_left = _tuning.wall_climb_max_time


func _next(state: PlayerState.State) -> PlayerState.State:
	return MovementDecider.next_state(state, _intent, _ctx, _tuning)


func _can_exit(state: PlayerState.State) -> bool:
	return MovementDecider.can_exit(state, _intent, _ctx, _tuning)


func _airborne(vertical_speed: float) -> void:
	_ctx.on_floor = false
	_ctx.coyote_left = 0.0
	_ctx.velocity.y = vertical_speed


# --- Double saut ---------------------------------------------------------------------

func test_double_jump_is_refused_while_locked() -> void:
	_airborne(-200.0)
	_ctx.jump_buffer_left = 0.05
	_ctx.can_double_jump = false
	assert_eq(_next(PlayerState.State.JUMP), PlayerState.State.JUMP)
	_ctx.velocity.y = 50.0
	assert_eq(_next(PlayerState.State.FALL), PlayerState.State.FALL)


func test_double_jump_from_jump_or_fall_once_unlocked() -> void:
	_airborne(-200.0)
	_ctx.jump_buffer_left = 0.05
	_ctx.can_double_jump = true
	assert_eq(_next(PlayerState.State.JUMP), PlayerState.State.DOUBLE_JUMP)
	_ctx.velocity.y = 50.0
	assert_eq(_next(PlayerState.State.FALL), PlayerState.State.DOUBLE_JUMP)


func test_double_jump_cannot_chain_into_another() -> void:
	_airborne(-200.0)
	_ctx.jump_buffer_left = 0.05
	_ctx.can_double_jump = true
	assert_eq(_next(PlayerState.State.DOUBLE_JUMP), PlayerState.State.DOUBLE_JUMP)


func test_coyote_jump_has_priority_over_double_jump() -> void:
	_ctx.on_floor = false
	_ctx.coyote_left = 0.05
	_ctx.jump_buffer_left = 0.05
	_ctx.can_double_jump = true
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.JUMP)


func test_double_jump_impulse() -> void:
	var v: Vector2 = LocomotionMotor.on_enter(
		PlayerState.State.FALL, PlayerState.State.DOUBLE_JUMP, Vector2(200, 300), _ctx, _tuning
	)
	assert_eq(v, Vector2(200, -_tuning.double_jump_velocity))


# --- Franchissement --------------------------------------------------------------------

func test_running_into_a_low_obstacle_vaults() -> void:
	_intent.move_axis = 1.0
	_ctx.velocity = Vector2(400, 0)
	_ctx.obstacle_height = 40.0
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.VAULT)
	assert_eq(_next(PlayerState.State.SPRINT), PlayerState.State.VAULT)


func test_vault_needs_height_window_speed_and_pushing_forward() -> void:
	_intent.move_axis = 1.0
	_ctx.velocity = Vector2(400, 0)
	_ctx.obstacle_height = _tuning.vault_min_height - 1.0
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.RUN, "trop bas")
	_ctx.obstacle_height = _tuning.vault_max_height + 1.0
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.RUN, "trop haut")
	_ctx.obstacle_height = 40.0
	_ctx.velocity = Vector2(_tuning.vault_min_speed - 1.0, 0)
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.RUN, "trop lent")
	_ctx.velocity = Vector2(400, 0)
	_intent.move_axis = -1.0
	assert_ne(_next(PlayerState.State.RUN), PlayerState.State.VAULT, "on s'éloigne de l'obstacle")


func test_jump_has_priority_over_vault() -> void:
	_intent.move_axis = 1.0
	_ctx.velocity = Vector2(400, 0)
	_ctx.obstacle_height = 40.0
	_ctx.jump_buffer_left = 0.05
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.JUMP)


func test_vault_ends_on_the_ground_without_a_landing_stun() -> void:
	_intent.move_axis = 1.0
	_ctx.time_in_state = _tuning.vault_min_time * 0.5
	assert_eq(_next(PlayerState.State.VAULT), PlayerState.State.VAULT)
	_ctx.time_in_state = _tuning.vault_min_time
	assert_eq(_next(PlayerState.State.VAULT), PlayerState.State.RUN)


func test_vault_still_airborne_after_max_time_becomes_a_fall() -> void:
	_airborne(200.0)
	_ctx.time_in_state = _tuning.vault_max_time * 0.5
	assert_eq(_next(PlayerState.State.VAULT), PlayerState.State.VAULT)
	_ctx.time_in_state = _tuning.vault_max_time
	assert_eq(_next(PlayerState.State.VAULT), PlayerState.State.FALL)


func test_vault_impulse_clears_the_measured_obstacle() -> void:
	_ctx.obstacle_height = 40.0
	var v: Vector2 = LocomotionMotor.on_enter(
		PlayerState.State.SPRINT, PlayerState.State.VAULT, Vector2(480, 0), _ctx, _tuning
	)
	var apex: float = v.y * v.y / (2.0 * _tuning.gravity_down)
	assert_almost_eq(apex, 40.0 + _tuning.vault_clearance, 0.01)
	assert_eq(v.x, 480.0, "l'élan est conservé")


# --- Course murale et escalade -----------------------------------------------------------

func test_sprinting_into_a_wall_starts_a_wall_run() -> void:
	_intent.move_axis = 1.0
	_ctx.wall_ahead = true
	_ctx.velocity = Vector2(480, 0)
	assert_eq(_next(PlayerState.State.SPRINT), PlayerState.State.WALL_RUN)


func test_wall_run_needs_speed_and_happens_once_per_air_phase() -> void:
	_intent.move_axis = 1.0
	_ctx.wall_ahead = true
	_ctx.velocity = Vector2(_tuning.wall_run_min_speed - 1.0, 0)
	assert_ne(_next(PlayerState.State.RUN), PlayerState.State.WALL_RUN, "trop lent")
	_ctx.velocity = Vector2(480, 0)
	_ctx.can_wall_run = false
	assert_ne(_next(PlayerState.State.RUN), PlayerState.State.WALL_RUN, "déjà utilisée")


func test_jumping_into_a_wall_while_rising_starts_a_wall_run() -> void:
	_airborne(-300.0)
	_intent.move_axis = 1.0
	_ctx.wall_ahead = true
	_ctx.velocity.x = 480.0
	assert_eq(_next(PlayerState.State.JUMP), PlayerState.State.WALL_RUN)


func test_wall_run_converts_horizontal_speed_into_climb() -> void:
	var v: Vector2 = LocomotionMotor.on_enter(
		PlayerState.State.SPRINT, PlayerState.State.WALL_RUN, Vector2(480, 0), _ctx, _tuning
	)
	assert_almost_eq(v.y, -480.0 * _tuning.wall_run_conversion, 0.01)
	assert_eq(v.x, _tuning.wall_stick_speed)


func test_wall_run_becomes_climb_then_falls_when_stamina_runs_out() -> void:
	_airborne(-50.0)
	_intent.move_axis = 1.0
	_ctx.wall_ahead = true
	_ctx.time_in_state = _tuning.wall_run_duration
	assert_eq(_next(PlayerState.State.WALL_RUN), PlayerState.State.WALL_CLIMB)
	assert_eq(_next(PlayerState.State.WALL_CLIMB), PlayerState.State.WALL_CLIMB)
	_ctx.wall_climb_left = 0.0
	assert_true(_can_exit(PlayerState.State.WALL_CLIMB))
	assert_eq(_next(PlayerState.State.WALL_CLIMB), PlayerState.State.FALL)


func test_wall_run_without_pushing_ends_in_a_fall() -> void:
	_airborne(-50.0)
	_ctx.wall_ahead = true
	_ctx.time_in_state = _tuning.wall_run_duration
	assert_eq(_next(PlayerState.State.WALL_RUN), PlayerState.State.FALL)


func test_releasing_the_wall_stops_climbing() -> void:
	_airborne(-110.0)
	_ctx.wall_ahead = true
	_intent.move_axis = 0.0
	assert_eq(_next(PlayerState.State.WALL_CLIMB), PlayerState.State.FALL)


func test_falling_against_a_wall_while_pushing_climbs_until_stamina_is_gone() -> void:
	_airborne(200.0)
	_intent.move_axis = 1.0
	_ctx.wall_ahead = true
	assert_eq(_next(PlayerState.State.FALL), PlayerState.State.WALL_CLIMB)
	_ctx.wall_climb_left = 0.0
	assert_eq(_next(PlayerState.State.FALL), PlayerState.State.FALL)


func test_wall_jump_pushes_away_from_the_wall() -> void:
	_airborne(-100.0)
	_ctx.wall_ahead = true
	_ctx.jump_buffer_left = 0.05
	assert_eq(_next(PlayerState.State.WALL_RUN), PlayerState.State.JUMP)
	assert_eq(_next(PlayerState.State.WALL_CLIMB), PlayerState.State.JUMP)
	var v: Vector2 = LocomotionMotor.on_enter(
		PlayerState.State.WALL_CLIMB, PlayerState.State.JUMP, Vector2(120, -110), _ctx, _tuning
	)
	assert_eq(v, Vector2(-_tuning.wall_jump_push, -_tuning.wall_jump_velocity))


func test_wall_states_hold_against_the_wall() -> void:
	var climb: Vector2 = LocomotionMotor.step(
		PlayerState.State.WALL_CLIMB, Vector2(0, 300), _intent, _ctx, _tuning, DT
	)
	assert_eq(climb, Vector2(_tuning.wall_stick_speed, -_tuning.wall_climb_speed))
	var run: Vector2 = LocomotionMotor.step(
		PlayerState.State.WALL_RUN, Vector2(0, -400), _intent, _ctx, _tuning, DT
	)
	assert_almost_eq(run.y, -400.0 + _tuning.wall_run_gravity * DT, 0.01)


func test_air_control_is_ignored_right_after_a_wall_jump() -> void:
	_airborne(-500.0)
	_intent.move_axis = 1.0
	_ctx.air_control_lock_left = 0.1
	var v: Vector2 = LocomotionMotor.step(
		PlayerState.State.JUMP, Vector2(-360, -500), _intent, _ctx, _tuning, DT
	)
	assert_eq(v.x, -360.0)


# --- Rebord ---------------------------------------------------------------------------

func test_ledge_is_grabbed_from_every_air_and_wall_state() -> void:
	_airborne(-50.0)
	_ctx.wall_ahead = true
	_ctx.ledge_available = true
	for state: PlayerState.State in [
		PlayerState.State.JUMP,
		PlayerState.State.DOUBLE_JUMP,
		PlayerState.State.FALL,
		PlayerState.State.WALL_RUN,
		PlayerState.State.WALL_CLIMB,
	]:
		assert_eq(_next(state), PlayerState.State.LEDGE_HANG, PlayerState.name_of(state))


func test_ledge_is_not_grabbed_on_the_floor_or_during_cooldown() -> void:
	_ctx.ledge_available = true
	_intent.move_axis = 1.0
	assert_ne(_next(PlayerState.State.RUN), PlayerState.State.LEDGE_HANG)
	_airborne(50.0)
	_ctx.ledge_cooldown_left = 0.1
	assert_eq(_next(PlayerState.State.FALL), PlayerState.State.FALL)


func test_hang_lasts_a_minimum_time() -> void:
	_airborne(0.0)
	_intent.move_axis = 1.0
	_ctx.time_in_state = _tuning.ledge_min_hang * 0.5
	assert_false(_can_exit(PlayerState.State.LEDGE_HANG))
	assert_eq(_next(PlayerState.State.LEDGE_HANG), PlayerState.State.LEDGE_HANG)


func test_hang_climbs_with_jump_or_forward_and_drops_with_slide_or_backward() -> void:
	_airborne(0.0)
	_ctx.time_in_state = _tuning.ledge_min_hang
	assert_eq(_next(PlayerState.State.LEDGE_HANG), PlayerState.State.LEDGE_HANG, "sans entrée : reste suspendu")
	_intent.move_axis = 1.0
	assert_eq(_next(PlayerState.State.LEDGE_HANG), PlayerState.State.JUMP, "avant : se hisse")
	_intent.move_axis = -1.0
	assert_eq(_next(PlayerState.State.LEDGE_HANG), PlayerState.State.FALL, "arrière : lâche")
	_intent.move_axis = 0.0
	_ctx.slide_buffer_left = 0.05
	assert_eq(_next(PlayerState.State.LEDGE_HANG), PlayerState.State.FALL, "Glisse : lâche")
	_ctx.slide_buffer_left = 0.0
	_ctx.jump_buffer_left = 0.05
	assert_eq(_next(PlayerState.State.LEDGE_HANG), PlayerState.State.JUMP, "Saut : se hisse")


func test_climbing_up_from_a_ledge_rises_above_it() -> void:
	var v: Vector2 = LocomotionMotor.on_enter(
		PlayerState.State.LEDGE_HANG, PlayerState.State.JUMP, Vector2.ZERO, _ctx, _tuning
	)
	assert_gt(v.x, 0.0, "avance sur le rebord")
	var rise: float = v.y * v.y / (2.0 * _tuning.gravity_down)
	assert_gt(rise, _tuning.ledge_hang_offset, "les pieds dépassent le haut du rebord")


func test_hanging_does_not_move() -> void:
	var v: Vector2 = LocomotionMotor.step(
		PlayerState.State.LEDGE_HANG, Vector2(100, 400), _intent, _ctx, _tuning, DT
	)
	assert_eq(v, Vector2.ZERO)


# --- Roulade --------------------------------------------------------------------------

func test_slide_during_a_hard_landing_rolls_and_during_a_soft_landing_slides() -> void:
	_intent.move_axis = 1.0
	_ctx.velocity = Vector2(400, 0)
	_ctx.slide_buffer_left = 0.05
	_ctx.impact_speed = _tuning.landing_hard_speed + 1.0
	assert_eq(_next(PlayerState.State.LANDING), PlayerState.State.ROLL)
	_ctx.impact_speed = _tuning.landing_hard_speed - 1.0
	assert_eq(_next(PlayerState.State.LANDING), PlayerState.State.SLIDE)


func test_roll_lasts_its_duration_and_waits_for_headroom() -> void:
	_intent.move_axis = 1.0
	_ctx.time_in_state = _tuning.roll_duration * 0.5
	assert_eq(_next(PlayerState.State.ROLL), PlayerState.State.ROLL)
	_ctx.time_in_state = _tuning.roll_duration
	_ctx.can_stand = false
	assert_eq(_next(PlayerState.State.ROLL), PlayerState.State.ROLL, "plafond bas")
	_ctx.can_stand = true
	assert_eq(_next(PlayerState.State.ROLL), PlayerState.State.RUN)


func test_roll_keeps_at_least_running_speed() -> void:
	var v: Vector2 = LocomotionMotor.on_enter(
		PlayerState.State.LANDING, PlayerState.State.ROLL, Vector2(100, 0), _ctx, _tuning
	)
	assert_eq(v.x, _tuning.run_speed)
	v = Vector2(600, 0)
	for i: int in 120:
		v = LocomotionMotor.step(PlayerState.State.ROLL, v, _intent, _ctx, _tuning, DT)
	assert_almost_eq(v.x, _tuning.run_speed, 0.01)


func test_every_m2_decision_is_allowed_by_the_table() -> void:
	var pairs: Array[Array] = [
		[PlayerState.State.JUMP, PlayerState.State.DOUBLE_JUMP],
		[PlayerState.State.FALL, PlayerState.State.DOUBLE_JUMP],
		[PlayerState.State.SPRINT, PlayerState.State.VAULT],
		[PlayerState.State.VAULT, PlayerState.State.RUN],
		[PlayerState.State.SPRINT, PlayerState.State.WALL_RUN],
		[PlayerState.State.WALL_RUN, PlayerState.State.WALL_CLIMB],
		[PlayerState.State.WALL_CLIMB, PlayerState.State.LEDGE_HANG],
		[PlayerState.State.LEDGE_HANG, PlayerState.State.JUMP],
		[PlayerState.State.LEDGE_HANG, PlayerState.State.FALL],
		[PlayerState.State.LANDING, PlayerState.State.ROLL],
		[PlayerState.State.ROLL, PlayerState.State.RUN],
	]
	for pair: Array in pairs:
		assert_true(PlayerFsmRules.is_allowed(pair[0], pair[1]))
