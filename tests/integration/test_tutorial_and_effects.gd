extends GutTest
## Tutoriel « Premiers pas » (ADR-051), sang à la mort (ADR-052) et choix des
## objets, dans les vraies scènes. Sauvegarde isolée (jamais celle du joueur).

const DIR: String = "user://test_saves/tutorial"
const LOME: String = "res://data/cities/lome.tres"

var _save: SaveServiceNode
var _profile: ProfileServiceNode
var _settings: SettingsServiceNode
var _inventory: InventoryServiceNode


func before_all() -> void:
	_save = get_node(^"/root/SaveService") as SaveServiceNode
	_profile = get_node(^"/root/ProfileService") as ProfileServiceNode
	_settings = get_node(^"/root/SettingsService") as SettingsServiceNode
	_inventory = get_node(^"/root/InventoryService") as InventoryServiceNode


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	_save.use_store(SaveStore.new(DIR, "save.json"))
	_profile.progression.routes = {}
	_profile.reload()
	_settings.reload()
	_inventory.reload()
	get_tree().paused = false


func after_all() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	_save.reload()
	_profile.progression.routes = {}
	_profile.reload()
	_settings.reload()
	_inventory.reload()
	get_tree().paused = false


func _with_autopilot(level: Node) -> RunnerBody:
	var body: RunnerBody = level.get_node("Player") as RunnerBody
	var human: Node = body.get_node("Controller")
	body.remove_child(human)
	human.free()
	var pilot: AutopilotController = AutopilotController.new()
	pilot.name = "Controller"
	body.add_child(pilot)
	return body


func test_first_play_opens_the_tutorial_only_for_a_new_player() -> void:
	assert_true(_profile.needs_tutorial(), "nouveau joueur")
	var menu: MainMenu = (load(MenuScreen.MAIN_MENU) as PackedScene).instantiate() as MainMenu
	menu.use_router = false
	add_child_autofree(menu)
	watch_signals(menu)
	menu.play()
	assert_signal_emitted_with_parameters(menu, "navigation_requested", [MenuScreen.TUTORIAL_RUN, {}])
	_profile.mark_tutorial_done()
	menu.play()
	assert_signal_emitted_with_parameters(menu, "navigation_requested", [MenuScreen.WORLD_MAP, {}])
	await wait_process_frames(2)
	_save.reload()
	_profile.reload()
	assert_true(_profile.tutorial_done, "sauvegardé")
	_profile.tutorial_done = false
	var route: CityRoute = (load(LOME) as CityDefinition).routes[0]
	_profile.progression.record_finish(route.id, 30.0, 0, route.par_time)
	assert_false(_profile.needs_tutorial(), "un joueur qui a déjà progressé n'y est pas renvoyé")


func test_tutorial_route_is_crossable_and_marks_done() -> void:
	var level: Node = (load(MenuScreen.TUTORIAL_RUN) as PackedScene).instantiate()
	_with_autopilot(level)
	var director: TutorialDirector = level.get_node("Tutorial") as TutorialDirector
	director.use_router = false
	var runner: LevelRunner = level.get_node("LevelRunner") as LevelRunner
	add_child_autofree(level)
	var ends: Array[bool] = []
	director.finished.connect(func(skipped: bool) -> void: ends.append(skipped))
	for i: int in 2400:
		await wait_physics_frames(1)
		if not ends.is_empty():
			break
	assert_eq(ends, [false] as Array[bool], "arrivée du tutoriel")
	assert_eq(runner.fall_count, 0, "aucune chute")
	assert_gte(director.steps.done_count(), 6, "gestes vus : courir, sauter, glisser, franchir, grimper, sprint, pics")
	assert_true(_profile.tutorial_done)
	assert_string_contains(director.lesson.text, "Bravo")


func test_skip_button_ends_the_tutorial() -> void:
	var level: Node = (load(MenuScreen.TUTORIAL_RUN) as PackedScene).instantiate()
	var director: TutorialDirector = level.get_node("Tutorial") as TutorialDirector
	director.use_router = false
	add_child_autofree(level)
	await wait_physics_frames(5)
	assert_string_contains(director.lesson.text, "courir")
	director.skip_button.pressed.emit()
	assert_true(_profile.tutorial_done, "passé = terminé")
	assert_false(director.skip_button.visible)


func test_blood_on_trap_death_not_on_capture_and_setting_respected() -> void:
	var level: Node = (load(MenuScreen.LOME_RUN) as PackedScene).instantiate()
	level.remove_child(level.get_node("Session"))
	var runner: LevelRunner = level.get_node("LevelRunner") as LevelRunner
	var body: RunnerBody = level.get_node("Player") as RunnerBody
	add_child_autofree(level)
	await wait_physics_frames(3)
	assert_true(body.kill(Hazard.SAW))
	assert_not_null(runner.last_blood, "éclaboussure")
	assert_gt((runner.last_blood.get_node("Drops") as CPUParticles2D).amount, 40, "scie : forte")
	await wait_seconds(1.6)
	runner.last_blood = null
	body.revive(body.global_position)
	await wait_seconds(1.4)
	assert_true(body.kill(&"capture"))
	assert_null(runner.last_blood, "pas de sang à la capture")
	await wait_seconds(1.6)
	body.revive(body.global_position)
	await wait_seconds(1.4)
	_settings.settings.blood_effects = false
	assert_true(body.kill(Hazard.SPIKES))
	assert_null(runner.last_blood, "Effets de sang désactivés")
	_settings.settings.blood_effects = true


func test_item_picker_pauses_lists_and_chooses() -> void:
	_inventory.inventory.try_add(&"gilet", false)
	_inventory.inventory.try_add(&"gilet", false)
	var level: Node = (load(MenuScreen.LOME_RUN) as PackedScene).instantiate()
	level.remove_child(level.get_node("Session"))
	var hud: EquipmentHud = level.get_node("EquipmentHud") as EquipmentHud
	var runtime: EquipmentRuntime = level.get_node("Equipment") as EquipmentRuntime
	add_child_autofree(level)
	await wait_physics_frames(2)
	hud.slot_button.pressed.emit()
	assert_true(hud.picker.is_open())
	assert_true(get_tree().paused, "le jeu attend le choix")
	assert_eq(hud.picker.cards.size(), runtime.owned_items().size(), "une carte par objet possédé")
	var gilet: Button = null
	for card: Button in hud.picker.cards:
		if card.get_meta(&"item_id") == &"gilet":
			gilet = card
	assert_not_null(gilet)
	gilet.pressed.emit()
	assert_false(hud.picker.is_open())
	assert_false(get_tree().paused, "la course reprend")
	assert_eq(runtime.selected, &"gilet")
	assert_string_contains(hud.slot_button.text, "×2")
