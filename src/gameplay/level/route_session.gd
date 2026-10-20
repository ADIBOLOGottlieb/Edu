class_name RouteSession
extends Node
## Session d'un parcours de ville : à l'arrivée, enregistre le résultat
## (ProfileService : étoiles, meilleur temps, déblocage du suivant) puis ouvre
## l'écran de résultat avec SceneRouter.
## Paramètre transmis : "result" = {
##   city_id, route_index, route_id, route_name, time, deaths, captures, stars,
##   best_time, new_best, par_time, next_route_index (-1 s'il n'y en a pas) }.

const RESULT_SCENE: String = "res://src/ui/menus/result_screen.tscn"
## Temps laissé pour voir l'arrivée avant l'écran de résultat (s).
const END_DELAY: float = 1.0

@export var runner: LevelRunner
@export var encounter: EncounterDirector

var last_result: Dictionary = {}

var _refunded: bool = false


func _ready() -> void:
	if runner != null:
		runner.level_completed.connect(_on_level_completed)


func _on_level_completed() -> void:
	var route: CityRoute = runner.current_route()
	if route == null:
		return
	last_result = build_result(route)
	refund_ticket()
	await get_tree().create_timer(END_DELAY).timeout
	var router: SceneRouterNode = get_node_or_null(^"/root/SceneRouter") as SceneRouterNode
	if router != null and ResourceLoader.exists(RESULT_SCENE):
		router.go_to(RESULT_SCENE, {"result": last_result})


## Arrivée : le ticket d'énergie dépensé au départ est rendu (ADR-049).
## Faux si le parcours était gratuit (déjà réussi) ou déjà remboursé.
func refund_ticket() -> bool:
	var router: SceneRouterNode = get_node_or_null(^"/root/SceneRouter") as SceneRouterNode
	var attempts: AttemptServiceNode = get_node_or_null(^"/root/AttemptService") as AttemptServiceNode
	if _refunded or router == null or attempts == null or not bool(router.param(AttemptServiceNode.TICKET_PARAM, false)):
		return false
	_refunded = true
	attempts.refund()
	return true


## Enregistre l'arrivée et décrit le résultat (testable sans changer de scène).
func build_result(route: CityRoute) -> Dictionary:
	var profile: ProfileServiceNode = get_node_or_null(^"/root/ProfileService") as ProfileServiceNode
	var previous_best: float = profile.progression.best_time(route.id) if profile != null else 0.0
	var deaths: int = runner.total_deaths()
	var stars: int = Progression.stars_for(runner.elapsed, deaths, route.par_time)
	if profile != null:
		stars = profile.record_route_result(route, runner.elapsed, deaths)
	var next_index: int = runner.route_index + 1
	if next_index >= runner.city.routes.size():
		next_index = -1
	return {
		"city_id": String(runner.city.id),
		"route_index": runner.route_index,
		"route_id": String(route.id),
		"route_name": route.display_name,
		"time": runner.elapsed,
		"deaths": deaths,
		"captures": encounter.captures if encounter != null else 0,
		"stars": stars,
		"best_time": profile.progression.best_time(route.id) if profile != null else runner.elapsed,
		"new_best": previous_best <= 0.0 or runner.elapsed < previous_best,
		"par_time": route.par_time,
		"next_route_index": next_index,
	}
