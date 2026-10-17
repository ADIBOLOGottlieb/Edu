class_name Inventory
extends RefCounted
## Inventaire (docs/ARCHITECTURE.md §7.1) : 1 objet = 1 emplacement, capacité =
## BASE_CAPACITY + extensions. Plein → l'objet reste au sol (rien n'est supprimé).
## Chaque emplacement retient si l'objet a été ramassé pendant le parcours en
## cours (perdu en cas de défaite s'il est marqué lost_on_defeat, ADR-005).

signal item_added(slot: int, id: StringName)
signal item_removed(slot: int, id: StringName, reason: StringName)
signal inventory_full(rejected_id: StringName)
signal capacity_changed(capacity: int)

enum AddResult { OK, FULL, INVALID }

const BASE_CAPACITY: int = 20

## Emplacements : {id: StringName, from_mission: bool} ou {} (vide).
var _slots: Array[Dictionary] = []
var _extensions: int = 0
var _catalog: EquipmentCatalog


func _init(catalog: EquipmentCatalog = null) -> void:
	_catalog = catalog
	_resize()


func capacity() -> int:
	return BASE_CAPACITY + _extensions


## Extensions gagnées (ProfileService) ou achetées et validées (MonetizationService).
func set_extensions(count_value: int) -> void:
	_extensions = maxi(0, count_value)
	_resize()
	capacity_changed.emit(capacity())


func count() -> int:
	var used: int = 0
	for slot: Dictionary in _slots:
		if not slot.is_empty():
			used += 1
	return used


func is_full() -> bool:
	return count() >= capacity()


func id_at(slot: int) -> StringName:
	if slot < 0 or slot >= _slots.size() or _slots[slot].is_empty():
		return &""
	return _slots[slot]["id"]


func find(id: StringName) -> int:
	for i: int in _slots.size():
		if not _slots[i].is_empty() and _slots[i]["id"] == id:
			return i
	return -1


func quantity(id: StringName) -> int:
	var total: int = 0
	for slot: Dictionary in _slots:
		if not slot.is_empty() and slot["id"] == id:
			total += 1
	return total


## Ajoute un objet dans le premier emplacement libre.
func try_add(id: StringName, from_mission: bool = true) -> AddResult:
	if id == &"" or (_catalog != null and not _catalog.has_item(id)):
		return AddResult.INVALID
	for i: int in _slots.size():
		if _slots[i].is_empty():
			_slots[i] = {"id": id, "from_mission": from_mission}
			item_added.emit(i, id)
			return AddResult.OK
	inventory_full.emit(id)
	return AddResult.FULL


## Retire l'objet d'un emplacement (raison : &"used", &"dropped", &"defeat"…).
func remove(slot: int, reason: StringName = &"used") -> StringName:
	var id: StringName = id_at(slot)
	if id == &"":
		return &""
	_slots[slot] = {}
	item_removed.emit(slot, id, reason)
	return id


## Défaite : perd les objets ramassés pendant le parcours et marqués lost_on_defeat.
## Retourne les identifiants perdus.
func lose_on_defeat() -> Array[StringName]:
	var lost: Array[StringName] = []
	for i: int in _slots.size():
		if _slots[i].is_empty() or not bool(_slots[i]["from_mission"]):
			continue
		var data: EquipmentData = _catalog.get_item(_slots[i]["id"]) if _catalog != null else null
		if data == null or data.lost_on_defeat:
			lost.append(remove(i, &"defeat"))
	return lost


## Parcours réussi : les objets ramassés deviennent des objets possédés.
func keep_mission_items() -> void:
	for slot: Dictionary in _slots:
		if not slot.is_empty():
			slot["from_mission"] = false


func to_dict() -> Dictionary:
	var items: Array = []
	for slot: Dictionary in _slots:
		items.append(slot.duplicate())
	return {"extensions": _extensions, "slots": items}


## Charge en ignorant les objets inconnus ; une sauvegarde ne contient jamais
## d'objets « en cours de parcours » (ils sont gardés ou perdus avant).
func from_dict(data: Dictionary) -> void:
	_extensions = maxi(0, int(data.get("extensions", 0)))
	_slots.clear()
	_resize()
	var saved: Array = data.get("slots", [])
	var index: int = 0
	for entry: Variant in saved:
		if index >= _slots.size():
			break
		if entry is Dictionary and not (entry as Dictionary).is_empty():
			var id: StringName = StringName(str((entry as Dictionary).get("id", "")))
			if id != &"" and (_catalog == null or _catalog.has_item(id)):
				_slots[index] = {"id": id, "from_mission": false}
		index += 1


func _resize() -> void:
	while _slots.size() < capacity():
		_slots.append({})
	# Réduction de capacité : on ne supprime jamais un objet, les emplacements en
	# trop restent tant qu'ils sont occupés.
	while _slots.size() > capacity() and _slots.back().is_empty():
		_slots.pop_back()
