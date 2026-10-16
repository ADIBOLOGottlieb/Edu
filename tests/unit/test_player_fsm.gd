extends GutTest
## Machine à états et table de transitions (PlayerFSM, PlayerFsmRules).

const M1_STATES: Array[int] = [
	PlayerState.State.IDLE,
	PlayerState.State.RUN,
	PlayerState.State.SPRINT,
	PlayerState.State.JUMP,
	PlayerState.State.FALL,
	PlayerState.State.LANDING,
	PlayerState.State.SLIDE,
]


func test_starts_idle() -> void:
	var fsm: PlayerFSM = PlayerFSM.new()
	assert_eq(fsm.current, PlayerState.State.IDLE)


func test_allowed_transition_changes_state_and_emits_once() -> void:
	var fsm: PlayerFSM = PlayerFSM.new()
	watch_signals(fsm)
	assert_true(fsm.request(PlayerState.State.RUN))
	assert_eq(fsm.current, PlayerState.State.RUN)
	assert_signal_emit_count(fsm, "state_changed", 1)
	assert_signal_emitted_with_parameters(
		fsm, "state_changed", [PlayerState.State.IDLE, PlayerState.State.RUN]
	)


func test_requesting_the_current_state_does_nothing() -> void:
	var fsm: PlayerFSM = PlayerFSM.new()
	watch_signals(fsm)
	assert_false(fsm.request(PlayerState.State.IDLE))
	assert_signal_not_emitted(fsm, "state_changed")


func test_transition_absent_from_table_is_refused() -> void:
	var fsm: PlayerFSM = PlayerFSM.new()
	assert_false(fsm.request(PlayerState.State.LANDING), "IDLE → LANDING n'existe pas")
	assert_false(fsm.request(PlayerState.State.WALL_RUN), "état du jalon M2")
	assert_false(fsm.request(PlayerState.State.DOUBLE_JUMP), "non débloqué en M1")
	assert_false(fsm.request(PlayerState.State.ATTACK), "état du jalon M4")
	assert_eq(fsm.current, PlayerState.State.IDLE)


func test_lower_priority_state_cannot_interrupt_until_exit_is_allowed() -> void:
	var fsm: PlayerFSM = PlayerFSM.new(PlayerState.State.SLIDE)
	assert_false(fsm.request(PlayerState.State.RUN), "une glissade en cours ne s'interrompt pas")
	assert_eq(fsm.current, PlayerState.State.SLIDE)
	fsm.exit_allowed = true
	assert_true(fsm.request(PlayerState.State.RUN))


func test_equal_priority_needs_no_exit_permission() -> void:
	var fsm: PlayerFSM = PlayerFSM.new(PlayerState.State.JUMP)
	assert_true(fsm.request(PlayerState.State.FALL))


func test_transition_resets_ticks_and_exit_flag() -> void:
	var fsm: PlayerFSM = PlayerFSM.new()
	fsm.tick()
	fsm.tick()
	fsm.exit_allowed = true
	fsm.request(PlayerState.State.RUN)
	assert_eq(fsm.ticks_in_state, 0)
	assert_false(fsm.exit_allowed)


func test_every_m1_state_is_reachable_from_idle() -> void:
	var reached: Dictionary[int, bool] = {PlayerState.State.IDLE: true}
	var queue: Array[int] = [PlayerState.State.IDLE]
	while not queue.is_empty():
		var from: int = queue.pop_front()
		for to: int in PlayerFsmRules.TRANSITIONS.get(from, []):
			if not reached.has(to):
				reached[to] = true
				queue.append(to)
	for state: int in M1_STATES:
		assert_true(reached.has(state), "inaccessible : %s" % PlayerState.name_of(state as PlayerState.State))


func test_every_m1_state_has_a_way_out() -> void:
	for state: int in M1_STATES:
		var targets: Array = PlayerFsmRules.TRANSITIONS.get(state, [])
		assert_gt(targets.size(), 0, "état sans sortie : %s" % PlayerState.name_of(state as PlayerState.State))


func test_table_only_targets_m1_states() -> void:
	for from: int in PlayerFsmRules.TRANSITIONS:
		assert_true(M1_STATES.has(from))
		for to: int in PlayerFsmRules.TRANSITIONS[from]:
			assert_true(M1_STATES.has(to), "cible hors M1 : %s" % PlayerState.name_of(to as PlayerState.State))
