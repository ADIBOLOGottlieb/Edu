extends SceneTree
## Rend chaque écran de menu (M7) en PNG pour contrôle visuel : menu principal,
## carte du monde, ville (neuve et avec progression), résultat, réglages,
## crédits, course avec bouton pause, puis menu pause ouvert.
## Mode « phone » : fenêtre 1200×540 (rapport 20:9 d'un téléphone 2400×1080).
## Sauvegarde isolée (user://capture_saves/menus) : la vraie n'est pas touchée.
## Contrôle visuel (nécessite une fenêtre, pas --headless).
## Usage : godot --path . --resolution 1280x720 -s tools/capture_menus.gd -- <dossier_absolu> [phone]

const SHOTS: Array[String] = [
	"main_menu", "world_map", "world_map_progress", "city_screen", "city_screen_progress",
	"result_screen", "settings_screen", "credits_screen", "lome_run", "pause_menu",
]
## Images attendues avant la capture (animations, fondus, révélation des étoiles).
const WAIT_FRAMES: int = 100

var _out: String = ""
var _suffix: String = ""
var _index: int = -1
var _frame: int = 0
var _current: Node


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	if args.size() > 1 and args[1] == "phone":
		_suffix = "_phone"
		DisplayServer.window_set_size(Vector2i(1200, 540))
	process_frame.connect(_tick)


func _tick() -> void:
	if _index < 0:
		# Premier passage : les autoloads sont prêts, on isole la sauvegarde.
		var save: SaveServiceNode = root.get_node_or_null(^"SaveService") as SaveServiceNode
		if save != null:
			DirAccess.make_dir_recursive_absolute("user://capture_saves/menus")
			save.use_store(SaveStore.new("user://capture_saves/menus", "save.json"))
		_next()
		return
	_frame += 1
	if _index < SHOTS.size() and SHOTS[_index] == "pause_menu" and _frame == 40:
		var pause: PauseMenu = _current.get_node_or_null(^"PauseMenu") as PauseMenu
		if pause != null:
			pause.open()
	if _frame < WAIT_FRAMES:
		return
	await RenderingServer.frame_post_draw
	if _frame != WAIT_FRAMES:
		return
	_frame += 1
	var img: Image = root.get_texture().get_image()
	var path: String = _out.path_join("%s%s.png" % [SHOTS[_index], _suffix])
	img.save_png(path)
	print("capture : ", path, " ", img.get_size())
	_next()


func _next() -> void:
	paused = false
	if _current != null:
		_current.queue_free()
		_current = null
	_index += 1
	_frame = 0
	if _index >= SHOTS.size():
		quit()
		return
	var shot: String = SHOTS[_index]
	_set_progress(shot.ends_with("_progress") or shot == "result_screen")
	match shot:
		"main_menu":
			_current = _screen(MenuScreen.MAIN_MENU)
		"world_map", "world_map_progress":
			_current = _screen(MenuScreen.WORLD_MAP)
		"city_screen", "city_screen_progress":
			var city: CityScreen = _screen(MenuScreen.CITY_SCREEN) as CityScreen
			city.city_id = &"lome"
			_current = city
		"result_screen":
			var result: ResultScreen = _screen(MenuScreen.RESULT_SCREEN) as ResultScreen
			result.result = {
				"city_id": "lome", "route_index": 1, "route_id": "lome_boulevard", "route_name": "Boulevard du 13-Janvier",
				"time": 19.37, "deaths": 0, "captures": 0, "stars": 3, "best_time": 19.37, "new_best": true,
				"par_time": 20.0, "next_route_index": 2,
			}
			_current = result
		"settings_screen":
			_current = _screen(MenuScreen.SETTINGS_SCREEN)
		"credits_screen":
			_current = _screen(MenuScreen.CREDITS_SCREEN)
		"lome_run", "pause_menu":
			_current = (load(MenuScreen.LOME_RUN) as PackedScene).instantiate()
	root.add_child(_current)


func _screen(path: String) -> MenuScreen:
	var screen: MenuScreen = (load(path) as PackedScene).instantiate() as MenuScreen
	screen.use_router = false
	return screen


## Progression de démonstration : parcours 1 (3 étoiles) et 2 (2 étoiles) terminés.
func _set_progress(enabled: bool) -> void:
	var profile: ProfileServiceNode = root.get_node_or_null(^"ProfileService") as ProfileServiceNode
	if profile == null:
		return
	profile.progression.routes = {}
	if not enabled:
		return
	var city: CityDefinition = load("res://data/cities/lome.tres") as CityDefinition
	profile.progression.record_finish(city.routes[0].id, 15.84, 0, city.routes[0].par_time)
	profile.progression.record_finish(city.routes[1].id, 24.1, 1, city.routes[1].par_time)
