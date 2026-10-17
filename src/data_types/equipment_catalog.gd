class_name EquipmentCatalog
extends Resource
## Tous les équipements du jeu (data/equipment/catalog.tres).

@export var items: Array[EquipmentData] = []


func get_item(id: StringName) -> EquipmentData:
	for item: EquipmentData in items:
		if item.id == id:
			return item
	return null


func has_item(id: StringName) -> bool:
	return get_item(id) != null
