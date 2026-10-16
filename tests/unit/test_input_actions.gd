extends GutTest
## Vérifie l'enregistrement des actions de jeu (src/core/input/input_actions.gd).

var _saved_events: Array[InputEvent] = []


func before_each() -> void:
	_saved_events = InputMap.action_get_events(InputActions.JUMP)


func after_each() -> void:
	# Remet l'action JUMP dans son état d'origine quoi qu'il arrive dans le test.
	if not InputMap.has_action(InputActions.JUMP):
		InputMap.add_action(InputActions.JUMP, InputActions.DEADZONE)
	InputMap.action_erase_events(InputActions.JUMP)
	for event: InputEvent in _saved_events:
		InputMap.action_add_event(InputActions.JUMP, event)


func test_every_action_is_registered_with_at_least_one_key() -> void:
	for action: StringName in InputActions.all():
		assert_true(InputMap.has_action(action), "action absente : %s" % action)
		assert_gt(InputMap.action_get_events(action).size(), 0, "aucune touche : %s" % action)


func test_register_defaults_is_idempotent() -> void:
	assert_eq(InputActions.register_defaults(), 0, "aucune action ne doit être réajoutée")


func test_register_defaults_never_overrides_an_existing_binding() -> void:
	InputMap.action_erase_events(InputActions.JUMP)
	var custom: InputEventKey = InputEventKey.new()
	custom.physical_keycode = KEY_X
	InputMap.action_add_event(InputActions.JUMP, custom)

	assert_eq(InputActions.register_defaults(), 0)

	var events: Array[InputEvent] = InputMap.action_get_events(InputActions.JUMP)
	assert_eq(events.size(), 1, "la touche personnalisée doit rester seule")
	assert_eq((events[0] as InputEventKey).physical_keycode, KEY_X)


func test_missing_action_is_recreated_with_default_keys() -> void:
	InputMap.erase_action(InputActions.JUMP)

	assert_eq(InputActions.register_defaults(), 1)

	var expected: int = InputActions.DEFAULT_KEYS[InputActions.JUMP].size()
	assert_eq(InputMap.action_get_events(InputActions.JUMP).size(), expected)
