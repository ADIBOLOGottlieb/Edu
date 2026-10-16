extends GutTest
## Décisions de locomotion, tick par tick, sans moteur physique (MovementDecider).

var _tuning: MoveTuning
var _intent: IntentFrame
var _ctx: MovementContext


func before_each() -> void:
	_tuning = MoveTuning.new()
	_intent = IntentFrame.new()
	_ctx = MovementContext.new()
	_ctx.on_floor = true


func _next(state: PlayerState.State) -> PlayerState.State:
	return MovementDecider.next_state(state, _intent, _ctx, _tuning)


func test_idle_stays_idle_without_input() -> void:
	assert_eq(_next(PlayerState.State.IDLE), PlayerState.State.IDLE)


func test_axis_starts_running_and_sprint_modifier_sprints() -> void:
	_intent.move_axis = 1.0
	assert_eq(_next(PlayerState.State.IDLE), PlayerState.State.RUN)
	_intent.sprint_held = true
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.SPRINT)


func test_tiny_axis_is_ignored() -> void:
	_intent.move_axis = 0.05
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.IDLE)


func test_buffered_jump_on_floor_jumps() -> void:
	_ctx.jump_buffer_left = 0.05
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.JUMP)


func test_coyote_time_allows_a_late_jump() -> void:
	_ctx.on_floor = false
	_ctx.coyote_left = 0.04
	_ctx.jump_buffer_left = 0.05
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.JUMP)


func test_leaving_the_floor_keeps_running_during_coyote_then_falls() -> void:
	_intent.move_axis = 1.0
	_ctx.on_floor = false
	_ctx.coyote_left = 0.04
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.RUN)
	_ctx.coyote_left = 0.0
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.FALL)


func test_jump_becomes_fall_at_apex() -> void:
	_ctx.on_floor = false
	_ctx.velocity = Vector2(0, -100)
	assert_eq(_next(PlayerState.State.JUMP), PlayerState.State.JUMP)
	_ctx.velocity = Vector2(0, 10)
	assert_eq(_next(PlayerState.State.JUMP), PlayerState.State.FALL)


func test_fall_lands_on_floor() -> void:
	_ctx.on_floor = false
	assert_eq(_next(PlayerState.State.FALL), PlayerState.State.FALL)
	_ctx.on_floor = true
	assert_eq(_next(PlayerState.State.FALL), PlayerState.State.LANDING)


func test_soft_landing_is_short_and_hard_landing_is_long() -> void:
	_intent.move_axis = 1.0
	_ctx.impact_speed = 400.0
	_ctx.time_in_state = _tuning.landing_soft_duration
	assert_eq(_next(PlayerState.State.LANDING), PlayerState.State.RUN)

	_ctx.impact_speed = _tuning.landing_hard_speed + 1.0
	_ctx.time_in_state = _tuning.landing_soft_duration
	assert_eq(_next(PlayerState.State.LANDING), PlayerState.State.LANDING, "réception dure en cours")
	_ctx.time_in_state = _tuning.landing_hard_duration
	assert_eq(_next(PlayerState.State.LANDING), PlayerState.State.RUN)


func test_jump_buffered_during_landing_jumps_immediately() -> void:
	_ctx.impact_speed = _tuning.landing_hard_speed + 1.0
	_ctx.jump_buffer_left = 0.05
	assert_eq(_next(PlayerState.State.LANDING), PlayerState.State.JUMP)


func test_slide_requires_speed_and_floor() -> void:
	_intent.move_axis = 1.0
	_ctx.slide_buffer_left = 0.05
	_ctx.velocity = Vector2(_tuning.slide_min_speed - 1.0, 0)
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.RUN, "trop lent pour glisser")
	_ctx.velocity = Vector2(_tuning.slide_min_speed, 0)
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.SLIDE)
	_ctx.on_floor = false
	_ctx.coyote_left = 0.05
	assert_ne(_next(PlayerState.State.RUN), PlayerState.State.SLIDE, "pas de glissade en l'air")


func test_expired_slide_buffer_does_nothing() -> void:
	_intent.move_axis = 1.0
	_ctx.velocity = Vector2(_tuning.sprint_speed, 0)
	_ctx.slide_buffer_left = 0.0
	assert_eq(_next(PlayerState.State.RUN), PlayerState.State.RUN)


func test_slide_pressed_just_before_touchdown_chains_from_landing() -> void:
	# Cas réel du bac à sable : on appuie sur Glisse pendant la réception.
	_intent.move_axis = 1.0
	_ctx.velocity = Vector2(_tuning.sprint_speed, 0)
	_ctx.impact_speed = _tuning.landing_hard_speed + 1.0
	_ctx.slide_buffer_left = 0.08
	assert_eq(_next(PlayerState.State.LANDING), PlayerState.State.SLIDE)


func test_slide_lasts_its_full_duration() -> void:
	_intent.move_axis = 1.0
	_ctx.time_in_state = _tuning.slide_duration * 0.5
	assert_eq(_next(PlayerState.State.SLIDE), PlayerState.State.SLIDE)
	_ctx.time_in_state = _tuning.slide_duration
	assert_eq(_next(PlayerState.State.SLIDE), PlayerState.State.RUN)


func test_slide_continues_under_a_low_ceiling() -> void:
	_intent.move_axis = 1.0
	_ctx.time_in_state = _tuning.slide_duration * 3.0
	_ctx.can_stand = false
	assert_eq(_next(PlayerState.State.SLIDE), PlayerState.State.SLIDE)
	assert_false(MovementDecider.can_exit(PlayerState.State.SLIDE, _ctx, _tuning))


func test_slide_can_be_cancelled_by_a_jump_when_there_is_headroom() -> void:
	_ctx.time_in_state = 0.1
	_ctx.jump_buffer_left = 0.05
	assert_eq(_next(PlayerState.State.SLIDE), PlayerState.State.JUMP)
	_ctx.can_stand = false
	assert_eq(_next(PlayerState.State.SLIDE), PlayerState.State.SLIDE, "pas de saut sous un plafond")


func test_sliding_off_a_ledge_falls() -> void:
	_ctx.on_floor = false
	assert_eq(_next(PlayerState.State.SLIDE), PlayerState.State.FALL)
	assert_true(MovementDecider.can_exit(PlayerState.State.SLIDE, _ctx, _tuning))


func test_decisions_are_all_accepted_by_the_fsm_table() -> void:
	# Chaque décision « naturelle » doit être une transition autorisée.
	var cases: Array[Array] = [
		[PlayerState.State.IDLE, PlayerState.State.RUN],
		[PlayerState.State.RUN, PlayerState.State.SLIDE],
		[PlayerState.State.SLIDE, PlayerState.State.RUN],
		[PlayerState.State.JUMP, PlayerState.State.FALL],
		[PlayerState.State.FALL, PlayerState.State.LANDING],
		[PlayerState.State.LANDING, PlayerState.State.JUMP],
		[PlayerState.State.LANDING, PlayerState.State.SLIDE],
	]
	for pair: Array in cases:
		assert_true(PlayerFsmRules.is_allowed(pair[0], pair[1]))
