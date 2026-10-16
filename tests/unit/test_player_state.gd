extends GutTest
## Catégories, priorités et noms des états (src/core/player/player_state.gd).


func test_all_22_states_are_declared() -> void:
	assert_eq(PlayerState.State.size(), 22)


func test_names_are_lowercase_enum_keys() -> void:
	assert_eq(PlayerState.name_of(PlayerState.State.IDLE), &"idle")
	assert_eq(PlayerState.name_of(PlayerState.State.WALL_RUN), &"wall_run")
	assert_eq(PlayerState.name_of(PlayerState.State.VICTORY), &"victory")


func test_priorities_follow_the_architecture_table() -> void:
	assert_eq(PlayerState.priority_of(PlayerState.State.RUN), 0)
	assert_eq(PlayerState.priority_of(PlayerState.State.FALL), 20)
	assert_eq(PlayerState.priority_of(PlayerState.State.SLIDE), 40)
	assert_eq(PlayerState.priority_of(PlayerState.State.ATTACK), 60)
	assert_eq(PlayerState.priority_of(PlayerState.State.HIT), 80)
	assert_eq(PlayerState.priority_of(PlayerState.State.ESCAPE), 90)
	assert_eq(PlayerState.priority_of(PlayerState.State.CAPTURE), 100)
	assert_eq(PlayerState.priority_of(PlayerState.State.DEATH), 100)
	assert_eq(PlayerState.priority_of(PlayerState.State.VICTORY), 100)


func test_every_state_has_a_category() -> void:
	for state: int in PlayerState.State.values():
		var category: PlayerState.Category = PlayerState.category_of(state as PlayerState.State)
		assert_true(category >= PlayerState.Category.GROUND and category <= PlayerState.Category.SYSTEM)
