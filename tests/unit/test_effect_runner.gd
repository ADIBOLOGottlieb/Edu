extends GutTest
## Effets d'équipement (§7.3–7.4) : chronos, REFRESH / REPLACE / REJECT,
## incompatibilités, charges, expirations simultanées, pause, fin de parcours.


func _effect(id: StringName, category: EquipmentData.Category, rule: EquipmentData.StackRule,
		duration: float, charges: int = 0) -> EquipmentData:
	var data: EquipmentData = EquipmentData.new()
	data.id = id
	data.category = category
	data.stack_rule = rule
	data.duration = duration
	data.charges = charges
	data.power = 1.5
	return data


func test_start_tick_and_timeout() -> void:
	var runner: EffectRunner = EffectRunner.new()
	watch_signals(runner)
	var data: EquipmentData = _effect(&"x", EquipmentData.Category.MOBILITY, EquipmentData.StackRule.REPLACE, 2.0)
	assert_eq(runner.activate(data), EffectRunner.ActivateResult.STARTED)
	assert_true(runner.is_active(&"x"))
	assert_eq(runner.power(&"x"), 1.5)
	runner.tick(1.5)
	assert_almost_eq(runner.remaining(&"x"), 0.5, 0.001)
	assert_eq(runner.tick(0.5), [&"x"] as Array[StringName])
	assert_false(runner.is_active(&"x"))
	assert_signal_emitted_with_parameters(runner, "effect_expired", [&"x", &"timeout"])
	assert_eq(runner.remaining(&"x"), 0.0)
	assert_eq(runner.power(&"x"), 0.0)


func test_refresh_resets_timer() -> void:
	var runner: EffectRunner = EffectRunner.new()
	var data: EquipmentData = _effect(&"x", EquipmentData.Category.STEALTH, EquipmentData.StackRule.REFRESH, 8.0, 1)
	runner.activate(data)
	runner.tick(6.0)
	runner.consume_charge(&"x")
	assert_false(runner.is_active(&"x"), "dernière charge utilisée")
	runner.activate(data)
	runner.tick(6.0)
	assert_eq(runner.activate(data), EffectRunner.ActivateResult.REFRESHED)
	assert_almost_eq(runner.remaining(&"x"), 8.0, 0.001, "pas de cumul, le chrono repart")
	assert_eq(runner.charges_left(&"x"), 1)
	assert_eq(runner.active_ids().size(), 1)


func test_replace_same_category() -> void:
	var runner: EffectRunner = EffectRunner.new()
	watch_signals(runner)
	runner.activate(_effect(&"a", EquipmentData.Category.MOBILITY, EquipmentData.StackRule.REPLACE, 5.0))
	var result: EffectRunner.ActivateResult = runner.activate(
			_effect(&"b", EquipmentData.Category.MOBILITY, EquipmentData.StackRule.REPLACE, 5.0))
	assert_eq(result, EffectRunner.ActivateResult.REPLACED)
	assert_false(runner.is_active(&"a"))
	assert_true(runner.is_active(&"b"))
	assert_signal_emitted_with_parameters(runner, "effect_expired", [&"a", &"replaced"])


func test_reject_rule() -> void:
	var runner: EffectRunner = EffectRunner.new()
	var data: EquipmentData = _effect(&"r", EquipmentData.Category.RANGED, EquipmentData.StackRule.REJECT, 4.0)
	runner.activate(data)
	assert_eq(runner.activate(data), EffectRunner.ActivateResult.REJECTED)
	assert_eq(runner.last_reject_reason, &"already_active")
	var other: EquipmentData = _effect(&"s", EquipmentData.Category.RANGED, EquipmentData.StackRule.REJECT, 1.0)
	assert_eq(runner.activate(other), EffectRunner.ActivateResult.REJECTED)
	assert_eq(runner.last_reject_reason, &"category_busy")
	assert_false(runner.is_active(&"s"))


func test_different_categories_stack() -> void:
	var runner: EffectRunner = EffectRunner.new()
	runner.activate(_effect(&"a", EquipmentData.Category.MOBILITY, EquipmentData.StackRule.REPLACE, 5.0))
	assert_eq(runner.activate(_effect(&"d", EquipmentData.Category.DEFENSE, EquipmentData.StackRule.REFRESH, 5.0)),
			EffectRunner.ActivateResult.STARTED)
	assert_eq(runner.active_ids().size(), 2)


func test_incompatibility_both_ways() -> void:
	var runner: EffectRunner = EffectRunner.new()
	var fast: EquipmentData = _effect(&"fast", EquipmentData.Category.MOBILITY, EquipmentData.StackRule.REPLACE, 5.0)
	var hide: EquipmentData = _effect(&"hide", EquipmentData.Category.STEALTH, EquipmentData.StackRule.REPLACE, 5.0)
	fast.incompatible_with = [&"hide"] as Array[StringName]
	runner.activate(hide)
	assert_eq(runner.activate(fast), EffectRunner.ActivateResult.REJECTED)
	assert_eq(runner.last_reject_reason, &"incompatible")
	runner.cancel(&"hide")
	runner.activate(fast)
	assert_eq(runner.activate(hide), EffectRunner.ActivateResult.REJECTED, "déclaré d'un seul côté, vaut dans les deux sens")
	assert_eq(runner.last_reject_reason, &"incompatible")


func test_simultaneous_expirations() -> void:
	var runner: EffectRunner = EffectRunner.new()
	runner.activate(_effect(&"a", EquipmentData.Category.MOBILITY, EquipmentData.StackRule.REPLACE, 1.0))
	runner.activate(_effect(&"b", EquipmentData.Category.DEFENSE, EquipmentData.StackRule.REFRESH, 1.0))
	runner.activate(_effect(&"c", EquipmentData.Category.TECH, EquipmentData.StackRule.REFRESH, 3.0))
	var expired: Array[StringName] = runner.tick(1.2)
	expired.sort()
	assert_eq(expired, [&"a", &"b"] as Array[StringName])
	assert_eq(runner.active_ids(), [&"c"] as Array[StringName])


func test_pause_freezes_timers() -> void:
	# Pendant la pause, l'appelant n'appelle pas tick : rien ne bouge.
	var runner: EffectRunner = EffectRunner.new()
	runner.activate(_effect(&"a", EquipmentData.Category.MOBILITY, EquipmentData.StackRule.REPLACE, 3.0))
	runner.tick(1.0)
	var before: float = runner.remaining(&"a")
	runner.tick(0.0)
	assert_eq(runner.remaining(&"a"), before)


func test_charges_and_cancel() -> void:
	var runner: EffectRunner = EffectRunner.new()
	watch_signals(runner)
	runner.activate(_effect(&"sh", EquipmentData.Category.DEFENSE, EquipmentData.StackRule.REPLACE, 15.0, 2))
	assert_true(runner.consume_charge(&"sh"))
	assert_eq(runner.charges_left(&"sh"), 1)
	assert_true(runner.consume_charge(&"sh"))
	assert_false(runner.is_active(&"sh"))
	assert_signal_emitted_with_parameters(runner, "effect_expired", [&"sh", &"used_up"])
	assert_false(runner.consume_charge(&"sh"), "plus actif")
	runner.activate(_effect(&"h", EquipmentData.Category.STEALTH, EquipmentData.StackRule.REPLACE, 10.0))
	runner.cancel(&"h", &"moved")
	assert_signal_emitted_with_parameters(runner, "effect_expired", [&"h", &"moved"])
	runner.cancel(&"inconnu")


func test_end_mission_expires_everything() -> void:
	var runner: EffectRunner = EffectRunner.new()
	runner.activate(_effect(&"a", EquipmentData.Category.MOBILITY, EquipmentData.StackRule.REPLACE, 9.0))
	runner.activate(_effect(&"b", EquipmentData.Category.DEFENSE, EquipmentData.StackRule.REFRESH, 9.0))
	runner.end_mission()
	assert_eq(runner.active_ids().size(), 0)
