class_name CityDefinition
extends Resource
## Une ville de la carte du monde : son ambiance (CityTheme) et ses parcours,
## du plus facile au plus difficile (docs/PROPOSITION_TOUR_DU_MONDE.md §2).

@export var id: StringName = &""
@export var display_name: String = ""
@export var country: String = ""
@export var theme: CityTheme
@export var routes: Array[CityRoute] = []


func route(index: int) -> CityRoute:
	if index < 0 or index >= routes.size():
		return null
	return routes[index]
