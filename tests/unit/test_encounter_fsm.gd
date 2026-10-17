extends GutTest
## Table de l'EncounterFSM (§5.1) : toutes les transitions autorisées passent,
## toutes les autres sont refusées et journalisées. Jauge de capture et jetons.


func _fsm_at(state: EncounterFSM.State) -> EncounterFSM:
	var fsm: EncounterFSM = EncounterFSM.new()
	fsm.current = state
	return fsm


func _all_states() -> Array[EncounterFSM.State]:
	var states: Array[EncounterFSM.State] = []
	for value: int in EncounterFSM.State.values():
		states.append(value as EncounterFSM.State)
	return states


func test_every_allowed_transition_is_accepted() -> void:
	var count: int = 0
	for from: EncounterFSM.State in EncounterFSM.TABLE:
		for to: Variant in EncounterFSM.TABLE[from]:
			var fsm: EncounterFSM = _fsm_at(from)
			assert_true(fsm.request(to as EncounterFSM.State, &"test"), "%s→%s" % [from, to])
			assert_eq(fsm.current, to as EncounterFSM.State)
			count += 1
	assert_eq(count, 15, "15 transitions dans la table §5.1")


func test_every_other_transition_is_refused_and_logged() -> void:
	for from: EncounterFSM.State in EncounterFSM.TABLE:
		for to: EncounterFSM.State in _all_states():
			if to == from or EncounterFSM.TABLE[from].has(to):
				continue
			var fsm: EncounterFSM = _fsm_at(from)
			assert_false(fsm.request(to, &"interdit"), "%s→%s refusée" % [from, to])
			assert_eq(fsm.current, from, "état inchangé")
			assert_eq(fsm.refused.size(), 1, "journalisée")


func test_terminal_states() -> void:
	assert_true(_fsm_at(EncounterFSM.State.MISSION_FAILED).is_terminal())
	assert_true(_fsm_at(EncounterFSM.State.MISSION_COMPLETED).is_terminal())
	assert_false(_fsm_at(EncounterFSM.State.PURSUIT).is_terminal())


func test_signal_carries_the_reason() -> void:
	var fsm: EncounterFSM = EncounterFSM.new()
	var seen: Array = []
	fsm.state_changed.connect(func(from: EncounterFSM.State, to: EncounterFSM.State, reason: StringName) -> void:
		seen.append([from, to, reason]))
	fsm.request(EncounterFSM.State.PURSUIT, &"vigile_actif")
	assert_eq(seen, [[EncounterFSM.State.RUNNING, EncounterFSM.State.PURSUIT, &"vigile_actif"]])


func test_typical_chase_capture_sequence() -> void:
	var fsm: EncounterFSM = EncounterFSM.new()
	var steps: Array[EncounterFSM.State] = [
		EncounterFSM.State.PURSUIT, EncounterFSM.State.COMBAT, EncounterFSM.State.ESCAPE_WINDOW,
		EncounterFSM.State.PURSUIT, EncounterFSM.State.COMBAT, EncounterFSM.State.CAPTURED,
		EncounterFSM.State.MISSION_FAILED,
	]
	for step: EncounterFSM.State in steps:
		assert_true(fsm.request(step), String(EncounterFSM.name_of(step)))
	assert_true(fsm.is_terminal())


func test_capture_gauge_fills_in_contact_and_drains_apart() -> void:
	var gauge: CaptureGauge = CaptureGauge.new()
	for i: int in 30:
		gauge.update(0.02, true)
	assert_almost_eq(gauge.value, 0.4, 0.01, "0,6 s sur 1,5 s")
	assert_false(gauge.is_full())
	for i: int in 50:
		gauge.update(0.02, false)
	assert_almost_eq(gauge.value, 0.0, 0.01, "vidée par 1 s de fuite")
	for i: int in 80:
		gauge.update(0.02, true)
	assert_true(gauge.is_full())
	gauge.reset()
	assert_eq(gauge.value, 0.0)


func test_token_pool_limits_simultaneous_holders() -> void:
	var pool: AttackTokenPool = AttackTokenPool.new(2)
	assert_true(pool.request(1))
	assert_true(pool.request(2))
	assert_false(pool.request(3), "au plus 2 à la fois")
	assert_true(pool.request(1), "déjà détenteur")
	pool.release(1)
	assert_true(pool.request(3))
	assert_eq(pool.in_use(), 2)
	assert_true(pool.holds(3))
