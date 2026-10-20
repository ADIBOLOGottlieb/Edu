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
## Tutoriel « Premiers pas » terminé ou passé (section « profile », ADR-051).
var tutorial_done: bool = false


func _ready() -> void:
	reload()


func reload() -> void:
	var save: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	if save != null:
		progression.from_dict(save.section("progress"))
		tutorial_done = bool(save.section("profile").get("tutorial_done", false))


## Premier JOUER d'un nouveau joueur : tutoriel pas encore fait et aucun
## parcours réussi (un joueur qui a déjà progressé n'y est pas renvoyé).
func needs_tutorial() -> bool:
	return not tutorial_done and progression.completed_count() == 0


func mark_tutorial_done() -> void:
	tutorial_done = true
	var save: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	if save != null:
		var profile: Dictionary = save.section("profile")
		profile["tutorial_done"] = true
		save.set_section("profile", profile)


## Enregistre une arrivée et sauvegarde ; retourne les étoiles de cette course.
func record_route_result(route: CityRoute, time_s: float, deaths: int) -> int:
	var stars: int = progression.record_finish(route.id, time_s, deaths, route.par_time)
	var save: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	if save != null:
		save.set_section("progress", progression.to_dict())
	progress_changed.emit()
	return stars
