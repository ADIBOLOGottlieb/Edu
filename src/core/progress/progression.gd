class_name Progression
extends RefCounted
## Progression du joueur sur la carte du monde (logique pure, sérialisée dans la
## section « progress »). docs/PROPOSITION_TOUR_DU_MONDE.md §2.
## - Étoiles d'un parcours : 1 = arrivée ; 2 = arrivée avec au plus
##   TWO_STAR_MAX_DEATHS morts ; 3 = arrivée sans mort et dans le temps de référence.
## - Un parcours est débloqué si c'est le premier de sa ville ou si le précédent
##   est terminé. Une ville est débloquée si elle est la première ou si la
##   précédente a tous ses parcours terminés.

const TWO_STAR_MAX_DEATHS: int = 2

## Identifiant de parcours → {completed: bool, best_time: float (s), stars: int, best_deaths: int}.
var routes: Dictionary = {}


## Résultat d'une arrivée ; retourne les étoiles obtenues sur cette course.
func record_finish(route_id: StringName, time_s: float, deaths: int, par_time_s: float) -> int:
	var stars_won: int = stars_for(time_s, deaths, par_time_s)
	var key: String = String(route_id)
	var entry: Dictionary = routes.get(key, {"completed": false, "best_time": 0.0, "stars": 0, "best_deaths": -1})
	entry["completed"] = true
	if float(entry["best_time"]) <= 0.0 or time_s < float(entry["best_time"]):
		entry["best_time"] = time_s
	if int(entry["best_deaths"]) < 0 or deaths < int(entry["best_deaths"]):
		entry["best_deaths"] = deaths
	entry["stars"] = maxi(int(entry["stars"]), stars_won)
	routes[key] = entry
	return stars_won


static func stars_for(time_s: float, deaths: int, par_time_s: float) -> int:
	if deaths == 0 and (par_time_s <= 0.0 or time_s <= par_time_s):
		return 3
	if deaths <= TWO_STAR_MAX_DEATHS:
		return 2
	return 1


func is_completed(route_id: StringName) -> bool:
	return bool(routes.get(String(route_id), {}).get("completed", false))


func stars(route_id: StringName) -> int:
	return int(routes.get(String(route_id), {}).get("stars", 0))


func best_time(route_id: StringName) -> float:
	return float(routes.get(String(route_id), {}).get("best_time", 0.0))


func city_stars(city: CityDefinition) -> int:
	var total: int = 0
	for route: CityRoute in city.routes:
		total += stars(route.id)
	return total


func is_route_unlocked(city: CityDefinition, index: int) -> bool:
	if index <= 0:
		return true
	if index >= city.routes.size():
		return false
	return is_completed(city.routes[index - 1].id)


func is_city_completed(city: CityDefinition) -> bool:
	for route: CityRoute in city.routes:
		if not is_completed(route.id):
			return false
	return not city.routes.is_empty()


## `cities` dans l'ordre de la carte : la première est toujours ouverte.
func is_city_unlocked(cities: Array[CityDefinition], index: int) -> bool:
	if index <= 0:
		return true
	if index >= cities.size():
		return false
	return is_city_completed(cities[index - 1])


func to_dict() -> Dictionary:
	return {"routes": routes.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	routes = {}
	var source: Dictionary = data.get("routes", {})
	for key: Variant in source:
		var entry: Dictionary = source[key]
		routes[str(key)] = {
			"completed": bool(entry.get("completed", false)),
			"best_time": maxf(0.0, float(entry.get("best_time", 0.0))),
			"stars": clampi(int(entry.get("stars", 0)), 0, 3),
			"best_deaths": int(entry.get("best_deaths", -1)),
		}
