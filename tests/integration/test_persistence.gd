extends GutTest
## Persistance réelle par les services (autoloads) : une arrivée enregistrée et des
## réglages modifiés survivent à une relecture du disque. Sauvegarde isolée dans
## un dossier de test (jamais celle du joueur).

const DIR: String = "user://test_saves/persistence"

var _save: SaveServiceNode
var _profile: ProfileServiceNode
var _settings: SettingsServiceNode


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	_save = get_node("/root/SaveService") as SaveServiceNode
	_profile = get_node("/root/ProfileService") as ProfileServiceNode
	_settings = get_node("/root/SettingsService") as SettingsServiceNode
	_save.use_store(SaveStore.new(DIR, "save.json"))
	_profile.reload()
	_settings.reload()


func after_all() -> void:
	# Les services reviennent à une sauvegarde de test vide, pas à celle du joueur.
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	_save.reload()
	_profile.progression.routes = {}


func test_route_result_survives_a_reload_from_disk() -> void:
	var route: CityRoute = (load("res://data/cities/lome.tres") as CityDefinition).routes[0]
	var stars: int = _profile.record_route_result(route, route.par_time - 1.0, 0)
	assert_eq(stars, 3)
	await wait_process_frames(2)
	assert_true(FileAccess.file_exists(DIR.path_join("save.json")), "écrit sur le disque")
	_profile.progression.routes = {}
	_save.reload()
	_profile.reload()
	assert_eq(_profile.progression.stars(route.id), 3)
	assert_true(_profile.progression.is_completed(route.id))


func test_settings_survive_a_reload_from_disk() -> void:
	_settings.settings.music_volume = 0.25
	_settings.settings.touch_opacity = 0.9
	_settings.save()
	await wait_process_frames(2)
	_settings.settings = GameSettings.new()
	_save.reload()
	_settings.reload()
	assert_almost_eq(_settings.settings.music_volume, 0.25, 0.001)
	assert_almost_eq(_settings.settings.touch_opacity, 0.9, 0.001)


func test_several_changes_in_one_frame_write_once() -> void:
	var writes: Array[int] = []
	_save.saved.connect(func(_error: Error) -> void: writes.append(1))
	_save.set_section("narrative", {"a": 1})
	_save.set_section("inventory", {"b": 2})
	await wait_process_frames(2)
	assert_eq(writes.size(), 1, "écritures regroupées")


func test_route_session_records_the_finish_and_describes_the_result() -> void:
	var city: CityDefinition = load("res://data/cities/lome.tres") as CityDefinition
	var runner: LevelRunner = LevelRunner.new()
	runner.city = city
	runner.route_index = 1
	runner.elapsed = 18.5
	var session: RouteSession = RouteSession.new()
	session.runner = runner
	add_child_autofree(session)
	var result: Dictionary = session.build_result(city.routes[1])
	runner.free()
	assert_eq(int(result["stars"]), 3, "sans mort, sous le temps de reference")
	assert_true(bool(result["new_best"]))
	assert_eq(int(result["next_route_index"]), 2)
	assert_eq(str(result["route_name"]), city.routes[1].display_name)
	assert_true(_profile.progression.is_route_unlocked(city, 2), "parcours suivant debloque")


func test_inventory_starter_kit_and_survives_a_reload_from_disk() -> void:
	var inventory_service: InventoryServiceNode = get_node("/root/InventoryService") as InventoryServiceNode
	inventory_service.reload()
	for id: StringName in InventoryServiceNode.STARTER_KIT:
		assert_eq(inventory_service.inventory.quantity(id), 1, "kit de départ : %s" % id)
	inventory_service.inventory.remove(inventory_service.inventory.find(&"surcharge"))
	inventory_service.inventory.try_add(&"gilet", false)
	await wait_process_frames(2)
	_save.reload()
	inventory_service.reload()
	assert_eq(inventory_service.inventory.quantity(&"gilet"), 1)
	assert_eq(inventory_service.inventory.quantity(&"surcharge"), 0, "objet utilisé, pas de nouveau kit")
	assert_eq(inventory_service.inventory.quantity(&"accelerateur"), 1)
	_save.reload()
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	_save.reload()
	inventory_service.reload()
