extends GutTest
## Énergie par parcours dans les vrais écrans (ADR-049) : un nouveau parcours
## coûte un ticket, l'énergie vide bloque le départ avec un message, un parcours
## réussi se rejoue gratuitement, l'arrivée rend le ticket, « Recommencer »
## garde le même ticket, la sauvegarde conserve l'énergie. Horloge fixe et
## sauvegarde isolée (jamais celle du joueur).

const DIR: String = "user://test_saves/energy"
const LOME: String = "res://data/cities/lome.tres"
const T0: int = 1_800_000_000

var _save: SaveServiceNode
var _profile: ProfileServiceNode
var _attempts: AttemptServiceNode
var _router: SceneRouterNode
var _now: int = T0


func before_all() -> void:
	_save = get_node(^"/root/SaveService") as SaveServiceNode
	_profile = get_node(^"/root/ProfileService") as ProfileServiceNode
	_attempts = get_node(^"/root/AttemptService") as AttemptServiceNode
	_router = get_node(^"/root/SceneRouter") as SceneRouterNode


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	_save.use_store(SaveStore.new(DIR, "save.json"))
	_profile.reload()
	_profile.progression.routes = {}
	_now = T0
	_attempts.clock = func() -> int: return _now
	_attempts.reload()


func after_all() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	_attempts.clock = func() -> int: return int(Time.get_unix_time_from_system())
	_save.reload()
	_profile.reload()
	_attempts.reload()


func _city_screen() -> CityScreen:
	var screen: CityScreen = (load(MenuScreen.CITY_SCREEN) as PackedScene).instantiate() as CityScreen
	screen.use_router = false
	screen.city_id = &"lome"
	add_child_autofree(screen)
	return screen


func test_new_route_costs_a_ticket_and_empty_blocks_with_a_message() -> void:
	var screen: CityScreen = _city_screen()
	var launches: Array[Dictionary] = []
	screen.navigation_requested.connect(func(_path: String, params: Dictionary) -> void: launches.append(params))
	assert_eq(screen.energy_label.text, "Énergie 5/5")
	for i: int in 5:
		screen.play_route(0)
	assert_eq(launches.size(), 5)
	assert_true(bool(launches[0][AttemptServiceNode.TICKET_PARAM]), "ticket dépensé")
	assert_eq(_attempts.tickets(), 0)
	screen.play_route(0)
	assert_eq(launches.size(), 5, "plus d'énergie : pas de départ")
	assert_string_contains(screen.energy_message.text, "1 h 12")
	_now += EnergyMeter.REGEN_SECONDS
	screen.play_route(0)
	assert_eq(launches.size(), 6, "un ticket revenu après 72 min")


func test_completed_route_replays_for_free() -> void:
	var route: CityRoute = (load(LOME) as CityDefinition).routes[0]
	_profile.progression.record_finish(route.id, 30.0, 1, route.par_time)
	for i: int in 5:
		_attempts.request_start(false)
	var screen: CityScreen = _city_screen()
	var launches: Array[Dictionary] = []
	screen.navigation_requested.connect(func(_path: String, params: Dictionary) -> void: launches.append(params))
	screen.play_route(0)
	assert_eq(launches.size(), 1, "parcours réussi : gratuit même sans énergie")
	assert_false(bool(launches[0][AttemptServiceNode.TICKET_PARAM]))
	screen.play_route(1)
	assert_eq(launches.size(), 1, "nouveau parcours : il faut un ticket")


func test_finish_refunds_once_and_energy_survives_reload() -> void:
	assert_eq(_attempts.request_start(false), AttemptServiceNode.Start.TICKET)
	assert_eq(_attempts.tickets(), 4)
	_router._params = {"route_index": 0, AttemptServiceNode.TICKET_PARAM: true}
	var session: RouteSession = RouteSession.new()
	add_child_autofree(session)
	assert_true(session.refund_ticket(), "arrivée : ticket rendu")
	assert_false(session.refund_ticket(), "une seule fois")
	assert_eq(_attempts.tickets(), 5)
	_attempts.request_start(false)
	_attempts.request_start(false)
	await wait_process_frames(2)
	_save.reload()
	_attempts.reload()
	assert_eq(_attempts.tickets(), 3, "énergie sauvegardée")
	_router._params = {}


func test_free_run_is_not_refunded_and_restart_keeps_the_ticket() -> void:
	_router._params = {"route_index": 2, AttemptServiceNode.TICKET_PARAM: false}
	var session: RouteSession = RouteSession.new()
	add_child_autofree(session)
	assert_false(session.refund_ticket(), "parcours gratuit : rien à rendre")
	_router._params = {"route_index": 2, AttemptServiceNode.TICKET_PARAM: true}
	var pause: PauseMenu = PauseMenu.new()
	pause.use_router = false
	add_child_autofree(pause)
	var sent: Array[Dictionary] = []
	pause.navigation_requested.connect(func(_path: String, params: Dictionary) -> void: sent.append(params))
	pause.restart()
	assert_true(bool(sent[0][AttemptServiceNode.TICKET_PARAM]), "Recommencer : même ticket")
	assert_eq(_attempts.tickets(), 5, "Recommencer ne coûte rien")
	_router._params = {}
