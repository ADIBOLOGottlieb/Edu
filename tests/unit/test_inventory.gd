extends GutTest
## Inventaire (§7.1) : vide, plein (l'objet reste au sol), doublons, extensions,
## perte après défaite, sérialisation et catalogue réel.

const CATALOG_PATH: String = "res://data/equipment/catalog.tres"


func _item(id: StringName, lost: bool = true) -> EquipmentData:
	var data: EquipmentData = EquipmentData.new()
	data.id = id
	data.lost_on_defeat = lost
	return data


func _catalog() -> EquipmentCatalog:
	var catalog: EquipmentCatalog = EquipmentCatalog.new()
	var items: Array[EquipmentData] = [_item(&"a"), _item(&"b"), _item(&"garde", false)]
	catalog.items = items
	return catalog


func test_empty_inventory() -> void:
	var inventory: Inventory = Inventory.new(_catalog())
	assert_eq(inventory.capacity(), Inventory.BASE_CAPACITY)
	assert_eq(inventory.count(), 0)
	assert_false(inventory.is_full())
	assert_eq(inventory.id_at(0), &"")
	assert_eq(inventory.find(&"a"), -1)
	assert_eq(inventory.remove(0), &"", "retirer un emplacement vide ne fait rien")
	assert_eq(inventory.remove(-1), &"")
	assert_eq(inventory.remove(999), &"")


func test_add_and_duplicates() -> void:
	var inventory: Inventory = Inventory.new(_catalog())
	assert_eq(inventory.try_add(&"a"), Inventory.AddResult.OK)
	assert_eq(inventory.try_add(&"a"), Inventory.AddResult.OK, "1 objet = 1 emplacement")
	assert_eq(inventory.quantity(&"a"), 2)
	assert_eq(inventory.count(), 2)
	assert_eq(inventory.find(&"a"), 0)


func test_unknown_item_is_invalid() -> void:
	var inventory: Inventory = Inventory.new(_catalog())
	assert_eq(inventory.try_add(&"inconnu"), Inventory.AddResult.INVALID)
	assert_eq(inventory.try_add(&""), Inventory.AddResult.INVALID)
	assert_eq(inventory.count(), 0)


func test_full_inventory_leaves_item_on_ground() -> void:
	var inventory: Inventory = Inventory.new(_catalog())
	for i: int in Inventory.BASE_CAPACITY:
		assert_eq(inventory.try_add(&"a"), Inventory.AddResult.OK)
	assert_true(inventory.is_full())
	watch_signals(inventory)
	assert_eq(inventory.try_add(&"b"), Inventory.AddResult.FULL)
	assert_signal_emitted_with_parameters(inventory, "inventory_full", [&"b"])
	assert_eq(inventory.quantity(&"b"), 0, "l'objet reste au sol")
	assert_eq(inventory.quantity(&"a"), Inventory.BASE_CAPACITY, "rien n'est supprimé")


func test_freed_slot_is_reused() -> void:
	var inventory: Inventory = Inventory.new(_catalog())
	inventory.try_add(&"a")
	inventory.try_add(&"b")
	assert_eq(inventory.remove(0, &"used"), &"a")
	inventory.try_add(&"garde")
	assert_eq(inventory.id_at(0), &"garde")
	assert_eq(inventory.id_at(1), &"b")


func test_extensions_never_delete_items() -> void:
	var inventory: Inventory = Inventory.new(_catalog())
	inventory.set_extensions(2)
	assert_eq(inventory.capacity(), Inventory.BASE_CAPACITY + 2)
	for i: int in inventory.capacity():
		inventory.try_add(&"a")
	inventory.set_extensions(0)
	assert_eq(inventory.quantity(&"a"), Inventory.BASE_CAPACITY + 2, "réduire la capacité ne supprime rien")
	assert_eq(inventory.try_add(&"b"), Inventory.AddResult.FULL)
	inventory.set_extensions(-5)
	assert_eq(inventory.capacity(), Inventory.BASE_CAPACITY, "pas de capacité négative")


func test_defeat_loses_only_mission_items() -> void:
	var inventory: Inventory = Inventory.new(_catalog())
	inventory.try_add(&"a", false)
	inventory.try_add(&"a", true)
	inventory.try_add(&"b", true)
	inventory.try_add(&"garde", true)
	var lost: Array[StringName] = inventory.lose_on_defeat()
	assert_eq(lost, [&"a", &"b"] as Array[StringName])
	assert_eq(inventory.quantity(&"a"), 1, "l'objet possédé avant le parcours est gardé")
	assert_eq(inventory.quantity(&"garde"), 1, "objet non marqué lost_on_defeat")


func test_success_keeps_mission_items() -> void:
	var inventory: Inventory = Inventory.new(_catalog())
	inventory.try_add(&"a", true)
	inventory.keep_mission_items()
	assert_eq(inventory.lose_on_defeat().size(), 0)
	assert_eq(inventory.quantity(&"a"), 1)


func test_round_trip_and_bad_data() -> void:
	var inventory: Inventory = Inventory.new(_catalog())
	inventory.set_extensions(1)
	inventory.try_add(&"a")
	inventory.try_add(&"b")
	inventory.remove(0)
	var restored: Inventory = Inventory.new(_catalog())
	restored.from_dict(JSON.parse_string(JSON.stringify(inventory.to_dict())))
	assert_eq(restored.capacity(), Inventory.BASE_CAPACITY + 1)
	assert_eq(restored.id_at(0), &"")
	assert_eq(restored.id_at(1), &"b")
	assert_eq(restored.lose_on_defeat().size(), 0, "une sauvegarde ne contient que des objets possédés")
	restored.from_dict({"extensions": -3, "slots": [{"id": "inconnu"}, 42, {"id": "a"}]})
	assert_eq(restored.capacity(), Inventory.BASE_CAPACITY)
	assert_eq(restored.count(), 1, "objets inconnus et entrées invalides ignorés")
	assert_eq(restored.id_at(2), &"a")


func test_real_catalog() -> void:
	var catalog: EquipmentCatalog = load(CATALOG_PATH) as EquipmentCatalog
	assert_not_null(catalog)
	assert_eq(catalog.items.size(), 10)
	var ids: Dictionary = {}
	for data: EquipmentData in catalog.items:
		assert_false(ids.has(data.id), "identifiant unique : %s" % data.id)
		ids[data.id] = true
		assert_gt(data.duration, 0.0, "%s a une durée" % data.id)
		assert_ne(data.display_name, "", "%s a un nom" % data.id)
		for other: StringName in data.incompatible_with:
			assert_true(catalog.has_item(other), "%s : incompatibilité connue" % data.id)
	assert_true(catalog.has_item(&"gilet"))
	assert_null(catalog.get_item(&"inconnu"))
