extends GutTest
## Écrans de menu (M7) instanciés sans fenêtre : menu principal, carte du
## monde, ville, résultat, réglages, crédits, et menu pause. La navigation est
## vérifiée par le signal navigation_requested (use_router = false : aucune
## scène n'est changée). Sauvegarde isolée dans user://test_saves/menus.

const SAVE_DIR: String = "user://test_saves/menus"
const LOME: String = "res://data/cities/lome.tres"

var _save: SaveServiceNode
var _profile: ProfileServiceNode
var _settings: SettingsServiceNode


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)
	_save = get_node(^"/root/SaveService") as SaveServiceNode
	_profile = get_node(^"/root/ProfileService") as ProfileServiceNode
	_settings = get_node(^"/root/SettingsService") as SettingsServiceNode
	_save.use_store(SaveStore.new(SAVE_DIR, "save.json"))
	_profile.reload()
	_settings.reload()
	(get_node(^"/root/AttemptService") as AttemptServiceNode).reload()


func before_each() -> void:
	_profile.progression.routes = {}
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false


func after_all() -> void:
	_profile.progression.routes = {}
	_save.use_store(SaveStore.new())
	_profile.reload()
	_settings.reload()
	(get_node(^"/root/AttemptService") as AttemptServiceNode).reload()


func _screen(path: String) -> MenuScreen:
	var screen: MenuScreen = (load(path) as PackedScene).instantiate() as MenuScreen
	screen.use_router = false
	return screen


func _lome() -> CityDefinition:
	return load(LOME) as CityDefinition


# --- Menu principal ---------------------------------------------------------

func test_main_menu_has_its_buttons_and_play_opens_the_world_map() -> void:
	var menu: MainMenu = _screen(MenuScreen.MAIN_MENU) as MainMenu
	add_child_autofree(menu)
	for button_name: String in ["PlayButton", "SettingsButton", "CreditsButton", "QuitButton", "DeveloperButton"]:
		assert_not_null(menu.find_child(button_name, true, false), button_name)
	assert_eq(menu.quit_button.visible, not MainMenu.is_mobile(), "Quitter seulement sur PC")
	watch_signals(menu)
	menu.play_button.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "navigation_requested", [MenuScreen.WORLD_MAP, {}])
	menu.settings_button.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "navigation_requested", [MenuScreen.SETTINGS_SCREEN, {}])
	menu.developer_button.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "navigation_requested", [MenuScreen.DEV_SCREEN, {}])
	menu.credits_button.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "navigation_requested", [MenuScreen.CREDITS_SCREEN, {}])


func test_main_menu_title_and_animated_backdrop() -> void:
	var menu: MainMenu = _screen(MenuScreen.MAIN_MENU) as MainMenu
	add_child_autofree(menu)
	assert_eq((menu.find_child("Title", true, false) as Label).text, "EDU")
	assert_not_null(menu.backdrop, "décor de Lomé derrière le menu")
	assert_not_null(menu.backdrop.backdrop.theme, "thème de ville")
	var x0: float = menu.backdrop.camera.position.x
	menu.backdrop._process(1.0)
	assert_gt(menu.backdrop.camera.position.x, x0, "la caméra dérive")


func test_every_menu_scene_path_exists() -> void:
	for path: String in [MenuScreen.MAIN_MENU, MenuScreen.WORLD_MAP, MenuScreen.CITY_SCREEN, MenuScreen.RESULT_SCREEN,
			MenuScreen.SETTINGS_SCREEN, MenuScreen.CREDITS_SCREEN, MenuScreen.DEV_SCREEN, MenuScreen.LOME_RUN]:
		assert_true(ResourceLoader.exists(path), path)
	assert_eq(MenuScreen.RESULT_SCREEN, RouteSession.RESULT_SCENE, "chemin attendu par RouteSession")
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), MenuScreen.MAIN_MENU)


# --- Carte du monde ---------------------------------------------------------

func test_world_map_opens_lome_and_announces_the_other_cities() -> void:
	var map: WorldMapScreen = _screen(MenuScreen.WORLD_MAP) as WorldMapScreen
	add_child_autofree(map)
	assert_eq(map.markers.size(), map.world.cities.size())
	assert_true(map.is_city_open(&"lome"), "Lomé ouverte")
	assert_true(bool(map.markers[&"lome"].get_meta(&"open")))
	for entry: WorldCity in map.world.cities:
		if entry.id != &"lome":
			assert_false(map.is_city_open(entry.id), "%s fermée" % entry.id)
			assert_not_null(map.markers[entry.id].find_child("Soon", true, false), "%s : Bientôt" % entry.id)
	assert_eq((map.markers[&"lome"].find_child("Stars", true, false) as Label).text, "0 / 15")


func test_world_map_tap_lome_opens_the_city_and_locked_city_does_not() -> void:
	var map: WorldMapScreen = _screen(MenuScreen.WORLD_MAP) as WorldMapScreen
	add_child_autofree(map)
	watch_signals(map)
	map.markers[&"cotonou"].pressed.emit()
	assert_signal_not_emitted(map, "navigation_requested")
	map.markers[&"lome"].pressed.emit()
	assert_signal_emitted_with_parameters(map, "navigation_requested", [MenuScreen.CITY_SCREEN, {"city_id": "lome"}])
	assert_signal_emitted_with_parameters(map, "city_selected", [&"lome"])


func test_world_map_markers_sit_inside_the_screen() -> void:
	var map: WorldMapScreen = _screen(MenuScreen.WORLD_MAP) as WorldMapScreen
	add_child_autofree(map)
	map._layout()
	var screen: Rect2 = Rect2(Vector2.ZERO, map.ui.size)
	for id: StringName in map.markers:
		var marker: Button = map.markers[id]
		assert_true(screen.encloses(Rect2(marker.position, marker.size)), "%s dans l'écran" % id)


# --- Ville ------------------------------------------------------------------

func test_city_screen_lists_the_five_lome_routes_first_one_open() -> void:
	var screen: CityScreen = _screen(MenuScreen.CITY_SCREEN) as CityScreen
	screen.city_id = &"lome"
	add_child_autofree(screen)
	assert_eq(screen.route_cards.size(), 5)
	assert_false(screen.route_cards[0].disabled, "parcours 1 ouvert")
	for i: int in range(1, 5):
		assert_true(screen.route_cards[i].disabled, "parcours %d verrouillé" % (i + 1))
		assert_not_null(screen.route_cards[i].find_child("Lock", true, false))
	var city: CityDefinition = _lome()
	for i: int in 5:
		var name_label: Label = screen.route_cards[i].find_child("RouteName", true, false) as Label
		assert_eq(name_label.text, city.routes[i].display_name)
		assert_eq(screen.route_cards[i].find_child("Pursuit", true, false) != null, city.routes[i].pursuit, "icône vigile %d" % i)
		var filled: int = 0
		for dot: Node in screen.route_cards[i].find_child("Difficulty", true, false).get_children():
			if dot is CityScreen.Dot and (dot as CityScreen.Dot).filled:
				filled += 1
		assert_eq(filled, city.routes[i].difficulty + 1, "points de difficulté %d" % i)
	watch_signals(screen)
	screen.play_route(2)
	assert_signal_not_emitted(screen, "navigation_requested", "parcours verrouillé")
	screen.route_cards[0].pressed.emit()
	# Nouveau parcours : un ticket d'énergie est dépensé (ADR-049).
	assert_signal_emitted_with_parameters(screen, "navigation_requested", [MenuScreen.LOME_RUN, {"route_index": 0, "ticket": true}])


func test_city_screen_unlocks_the_next_route_after_a_finish() -> void:
	var city: CityDefinition = _lome()
	var route: CityRoute = city.routes[0]
	_profile.progression.record_finish(route.id, route.par_time - 1.0, 0, route.par_time)
	var screen: CityScreen = _screen(MenuScreen.CITY_SCREEN) as CityScreen
	screen.city_id = &"lome"
	add_child_autofree(screen)
	assert_false(screen.route_cards[1].disabled, "parcours 2 débloqué")
	assert_true(screen.route_cards[2].disabled, "parcours 3 encore verrouillé")
	assert_eq(int(screen.route_cards[0].find_child("Stars", true, false).get_meta(&"earned")), 3)
	assert_eq((screen.route_cards[0].find_child("BestTime", true, false) as Label).text, MenuStyle.format_time(route.par_time - 1.0))
	assert_eq((screen.find_child("StarsTotal", true, false) as Label).text, "3 / 15")


# --- Résultat ---------------------------------------------------------------

func _result(next_index: int) -> Dictionary:
	return {
		"city_id": "lome", "route_index": 0, "route_id": "lome_grand_marche", "route_name": "Grand Marché",
		"time": 18.42, "deaths": 2, "captures": 1, "stars": 2, "best_time": 18.42, "new_best": true,
		"par_time": 17.0, "next_route_index": next_index,
	}


func test_result_screen_shows_the_result_values() -> void:
	var route: CityRoute = _lome().routes[0]
	_profile.progression.record_finish(route.id, 18.42, 2, route.par_time)
	var screen: ResultScreen = _screen(MenuScreen.RESULT_SCREEN) as ResultScreen
	screen.result = _result(1)
	add_child_autofree(screen)
	assert_string_contains(screen.route_label.text, "Grand Marché")
	assert_eq(screen.time_label.text, MenuStyle.format_time(18.42))
	assert_eq(screen.par_label.text, MenuStyle.format_time(17.0))
	assert_eq(screen.deaths_label.text, "2")
	assert_eq(screen.captures_label.text, "1")
	assert_true(screen.record_badge.visible, "badge Nouveau record")
	var shown: int = 0
	for star: MenuIcon in screen.star_icons:
		if star.visible:
			shown += 1
	assert_eq(shown, 2, "2 étoiles")
	assert_true(screen.next_button.visible, "parcours suivant débloqué")
	watch_signals(screen)
	screen.replay_button.pressed.emit()
	# Parcours réussi : rejoué gratuitement ; parcours suivant : un ticket (ADR-049).
	assert_signal_emitted_with_parameters(screen, "navigation_requested", [MenuScreen.LOME_RUN, {"route_index": 0, "ticket": false}])
	screen.next_button.pressed.emit()
	assert_signal_emitted_with_parameters(screen, "navigation_requested", [MenuScreen.LOME_RUN, {"route_index": 1, "ticket": true}])
	screen.map_button.pressed.emit()
	assert_signal_emitted_with_parameters(screen, "navigation_requested", [MenuScreen.WORLD_MAP, {}])


func test_result_screen_hides_next_when_locked_or_last() -> void:
	var screen: ResultScreen = _screen(MenuScreen.RESULT_SCREEN) as ResultScreen
	var result: Dictionary = _result(-1)
	result["new_best"] = false
	screen.result = result
	add_child_autofree(screen)
	assert_false(screen.next_button.visible, "dernier parcours")
	assert_false(screen.record_badge.visible)
	var locked: ResultScreen = _screen(MenuScreen.RESULT_SCREEN) as ResultScreen
	locked.result = _result(3)
	add_child_autofree(locked)
	assert_false(locked.next_button.visible, "parcours 4 encore verrouillé")


# --- Réglages ---------------------------------------------------------------

func test_settings_changes_are_written_and_saved() -> void:
	var screen: SettingsScreen = _screen(MenuScreen.SETTINGS_SCREEN) as SettingsScreen
	add_child_autofree(screen)
	var s: GameSettings = _settings.settings
	screen.music_slider.value = 0.3
	assert_almost_eq(s.music_volume, 0.3, 0.001)
	screen.sfx_slider.value = 0.55
	assert_almost_eq(s.sfx_volume, 0.55, 0.001)
	screen.opacity_slider.value = 0.4
	assert_almost_eq(s.touch_opacity, 0.4, 0.001)
	screen.scale_slider.value = 1.2
	assert_almost_eq(s.touch_scale, 1.2, 0.001)
	var vibrations: bool = s.vibrations
	screen.vibrations_toggle.button_pressed = not vibrations
	assert_eq(s.vibrations, not vibrations)
	screen.quality_option.select(0)
	screen.quality_option.item_selected.emit(0)
	assert_eq(s.quality, &"low")
	screen.language_option.select(1)
	screen.language_option.item_selected.emit(1)
	assert_eq(s.language, &"en")
	var saved: Dictionary = _save.section("settings")
	assert_almost_eq(float(saved.get("music_volume", -1.0)), 0.3, 0.001, "section settings sauvegardée")
	assert_eq(str(saved.get("quality", "")), "low")
	# Remet les valeurs par défaut pour les autres tests.
	_settings.settings = GameSettings.new()
	_settings.save()


# --- Crédits ----------------------------------------------------------------

func test_credits_list_third_party_licenses() -> void:
	var screen: CreditsScreen = _screen(MenuScreen.CREDITS_SCREEN) as CreditsScreen
	add_child_autofree(screen)
	var text: String = screen.all_text()
	assert_string_contains(text, "Quaternius — Universal Animation Library 1 & 2 (CC0)")
	assert_string_contains(text, "Godot Engine (MIT)")
	assert_string_contains(text, "GUT")
	assert_string_contains(text, "évocations stylisées originales")


# --- Pause ------------------------------------------------------------------

func test_pause_menu_pauses_and_resumes() -> void:
	var pause: PauseMenu = PauseMenu.new()
	pause.use_router = false
	add_child_autofree(pause)
	assert_eq(pause.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_false(pause.panel.visible)
	pause.pause_button.pressed.emit()
	assert_true(get_tree().paused, "pause")
	assert_true(pause.panel.visible)
	pause.resume_button.pressed.emit()
	assert_false(get_tree().paused, "reprise")
	assert_false(pause.panel.visible)


func test_pause_key_toggles_and_menu_buttons_navigate() -> void:
	var pause: PauseMenu = PauseMenu.new()
	pause.use_router = false
	add_child_autofree(pause)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.keycode = KEY_ESCAPE
	key.pressed = true
	pause._unhandled_input(key)
	assert_true(pause.is_open() and get_tree().paused, "Échap ouvre")
	pause._unhandled_input(key)
	assert_false(pause.is_open() or get_tree().paused, "Échap referme")
	watch_signals(pause)
	pause.open()
	pause.map_button.pressed.emit()
	assert_signal_emitted_with_parameters(pause, "navigation_requested", [PauseMenu.WORLD_MAP, {}])
	assert_false(get_tree().paused)
	pause.open()
	pause.restart_button.pressed.emit()
	var params: Array = get_signal_parameters(pause, "navigation_requested")
	assert_eq(params[1], {"route_index": 0, "ticket": false}, "même tentative, même ticket (ADR-049)")
	assert_false(get_tree().paused)


func test_lome_run_contains_the_pause_menu() -> void:
	var state: SceneState = (load(MenuScreen.LOME_RUN) as PackedScene).get_state()
	var found: bool = false
	for i: int in state.get_node_count():
		if state.get_node_name(i) == &"PauseMenu":
			found = true
	assert_true(found, "PauseMenu dans lome_run.tscn")
