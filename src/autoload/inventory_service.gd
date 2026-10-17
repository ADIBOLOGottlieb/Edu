class_name InventoryServiceNode
extends Node
## Autoload « InventoryService » — inventaire persistant (20 emplacements +
## extensions), section « inventory » de la sauvegarde. Les effets actifs pendant
## une partie appartiennent à EquipmentRuntime (dans le niveau).

const CATALOG_PATH: String = "res://data/equipment/catalog.tres"
## Kit de départ d'une nouvelle partie (objets possédés, pas perdus en cas de défaite).
const STARTER_KIT: Array[StringName] = [&"accelerateur", &"surcharge"]

var catalog: EquipmentCatalog
var inventory: Inventory


func _ready() -> void:
	catalog = load(CATALOG_PATH) as EquipmentCatalog
	inventory = Inventory.new(catalog)
	reload()
	inventory.item_added.connect(func(_slot: int, _id: StringName) -> void: save())
	inventory.item_removed.connect(func(_slot: int, _id: StringName, _reason: StringName) -> void: save())


func reload() -> void:
	var save_service: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	var saved: Dictionary = save_service.section("inventory") if save_service != null else {}
	if saved.is_empty():
		inventory.from_dict({})
		for id: StringName in STARTER_KIT:
			inventory.try_add(id, false)
	else:
		inventory.from_dict(saved)


func save() -> void:
	var save_service: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	if save_service != null:
		save_service.set_section("inventory", inventory.to_dict())
