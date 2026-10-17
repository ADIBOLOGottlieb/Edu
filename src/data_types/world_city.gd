class_name WorldCity
extends Resource
## Une ville de la carte du monde : jouable (city renseignée) ou « bientôt ».

@export var id: StringName = &""
@export var display_name: String = ""
@export var country: String = ""
## Position sur la carte, normalisée 0..1 (projection équirectangulaire :
## x = (longitude + 180) / 360, y = (90 − latitude) / 180).
@export var map_position: Vector2 = Vector2.ZERO
## Contenu jouable ; null = ville annoncée, pas encore disponible.
@export var city: CityDefinition


func is_playable() -> bool:
	return city != null
