extends GutTest
## Capacités débloquées (src/core/player/ability_set.gd).


func test_nothing_is_unlocked_by_default() -> void:
	var abilities: AbilitySet = AbilitySet.new()
	assert_false(abilities.has(AbilitySet.DOUBLE_JUMP))
	assert_eq(abilities.to_array(), [] as Array[StringName])


func test_unlock_and_lock_emit_only_on_change() -> void:
	var abilities: AbilitySet = AbilitySet.new()
	watch_signals(abilities)
	assert_true(abilities.unlock(AbilitySet.DOUBLE_JUMP))
	assert_false(abilities.unlock(AbilitySet.DOUBLE_JUMP), "déjà débloqué")
	assert_true(abilities.has(AbilitySet.DOUBLE_JUMP))
	assert_true(abilities.lock(AbilitySet.DOUBLE_JUMP))
	assert_false(abilities.lock(AbilitySet.DOUBLE_JUMP), "déjà verrouillé")
	assert_signal_emit_count(abilities, "changed", 2)


func test_unknown_ability_is_refused() -> void:
	var abilities: AbilitySet = AbilitySet.new()
	assert_false(abilities.unlock(&"vol_libre"))
	assert_false(abilities.has(&"vol_libre"))


func test_load_array_ignores_unknown_entries() -> void:
	var abilities: AbilitySet = AbilitySet.new()
	abilities.load_array(["double_jump", "triche_infinie", 42])
	assert_eq(abilities.to_array(), [AbilitySet.DOUBLE_JUMP] as Array[StringName])
