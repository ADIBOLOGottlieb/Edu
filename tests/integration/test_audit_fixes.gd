extends GutTest
## Corrections de l'audit : boutons tactiles sans chevauchement à grande taille,
## capture pendant l'invulnérabilité, pause verrouillée après l'arrivée.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")

var _settings: SettingsServiceNode


func before_all() -> void:
	_settings = get_node(^"/root/SettingsService") as SettingsServiceNode


func after_each() -> void:
	_settings.settings.touch_scale = 1.0
	get_tree().paused = false


func test_large_touch_buttons_never_overlap() -> void:
	_settings.settings.touch_scale = 1.4
	var touch: TouchControls = TouchControls.new()
	touch.force_visible = true
	add_child_autofree(touch)
	await wait_process_frames(1)
	var buttons: Array[TouchScreenButton] = []
	for child: Node in touch.get_children():
		if child is TouchScreenButton:
			buttons.append(child as TouchScreenButton)
	var min_gap: float = TouchControls.RADIUS * 2.0 * 1.4
	for i: int in buttons.size():
		for j: int in range(i + 1, buttons.size()):
			var d: float = buttons[i].position.distance_to(buttons[j].position)
			assert_gte(d, min_gap - 0.5, "%s / %s" % [buttons[i].action, buttons[j].action])


func test_touch_buttons_released_while_paused() -> void:
	var touch: TouchControls = TouchControls.new()
	touch.force_visible = true
	add_child_autofree(touch)
	await wait_process_frames(1)
	get_tree().paused = true
	await wait_process_frames(1)
	for child: Node in touch.get_children():
		if child is TouchScreenButton:
			assert_false((child as TouchScreenButton).visible, "relâché pendant la pause")
	get_tree().paused = false
	await wait_process_frames(1)
	for child: Node in touch.get_children():
		if child is TouchScreenButton:
			assert_true((child as TouchScreenButton).visible)


func test_capture_ignores_revive_invulnerability() -> void:
	var world: Node2D = Node2D.new()
	world.add_child(LevelGeometry.make_block(Rect2(-500, 0, 1000, 100)))
	var body: RunnerBody = PLAYER_SCENE.instantiate() as RunnerBody
	body.position = Vector2(0, -2)
	world.add_child(body)
	add_child_autofree(world)
	await wait_physics_frames(2)
	body.revive(Vector2(0, -2))
	assert_false(body.kill(Hazard.SPIKES), "invulnérable juste après la réapparition")
	assert_true(body.force_kill(&"capture"), "la capture passe quand même")
	assert_true(body.is_dead())


func test_pause_locked_after_finish() -> void:
	var runner: LevelRunner = LevelRunner.new()
	var pause: PauseMenu = PauseMenu.new()
	pause.use_router = false
	pause.runner = runner
	add_child_autofree(pause)
	runner.level_completed.emit()
	pause.open()
	assert_false(pause.is_open(), "plus de pause après l'arrivée")
	assert_false(pause.pause_button.visible)
	runner.free()
