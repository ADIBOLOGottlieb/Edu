class_name WorldMap
extends Resource
## Carte du monde : villes dans l'ordre de déblocage (Lomé d'abord).

@export var cities: Array[WorldCity] = []


## Villes jouables, dans l'ordre (pour Progression.is_city_unlocked).
func playable_cities() -> Array[CityDefinition]:
	var result: Array[CityDefinition] = []
	for entry: WorldCity in cities:
		if entry.is_playable():
			result.append(entry.city)
	return result


func find(id: StringName) -> WorldCity:
	for entry: WorldCity in cities:
		if entry.id == id:
			return entry
	return null
