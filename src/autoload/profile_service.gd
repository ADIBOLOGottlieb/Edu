class_name ProfileServiceNode
extends Node
## Autoload « ProfileService ». Le class_name (différent du nom d'autoload)
## permet un accès typé via /root/ProfileService, y compris depuis les outils
## et les tests lancés avec -s, où les identifiants d'autoload n'existent pas.
##
## ProfileService — capacités débloquées et progression sur la carte du monde
## (étoiles, meilleurs temps, déblocages), persistée dans la section « progress ».
## Ne gère ni l'énergie ni les achats. Refuges au jalon M11.

signal progress_changed()

## Capacités du protagoniste (ex. double saut), partagées avec son RunnerBody.
var abilities: AbilitySet = AbilitySet.new()
var progression: Progression = Progression.new()


func _ready() -> void:
	reload()


func reload() -> void:
	var save: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	if save != null:
		progression.from_dict(save.section("progress"))


## Enregistre une arrivée et sauvegarde ; retourne les étoiles de cette course.
func record_route_result(route: CityRoute, time_s: float, deaths: int) -> int:
	var stars: int = progression.record_finish(route.id, time_s, deaths, route.par_time)
	var save: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	if save != null:
		save.set_section("progress", progression.to_dict())
	progress_changed.emit()
	return stars
