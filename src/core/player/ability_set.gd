class_name AbilitySet
extends RefCounted
## Capacités débloquées d'un acteur (ex. double saut).
## Le joueur utilise celles de ProfileService ; un poursuivant a les siennes.
## La persistance (SaveService) arrive au jalon M7 via to_array() / load_array().

signal changed(ability: StringName, unlocked: bool)

const DOUBLE_JUMP: StringName = &"double_jump"
## Seules ces capacités existent ; tout autre identifiant est refusé.
const KNOWN: Array[StringName] = [DOUBLE_JUMP]

var _unlocked: Dictionary[StringName, bool] = {}


func has(ability: StringName) -> bool:
	return _unlocked.get(ability, false)


## Retourne vrai si la capacité vient d'être débloquée.
func unlock(ability: StringName) -> bool:
	if not KNOWN.has(ability):
		push_warning("Capacité inconnue : %s" % ability)
		return false
	if has(ability):
		return false
	_unlocked[ability] = true
	changed.emit(ability, true)
	return true


## Retourne vrai si la capacité vient d'être verrouillée.
func lock(ability: StringName) -> bool:
	if not has(ability):
		return false
	_unlocked.erase(ability)
	changed.emit(ability, false)
	return true


func to_array() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_unlocked.keys())
	result.sort()
	return result


## Remplace le contenu ; les identifiants inconnus (sauvegarde ancienne ou
## corrompue) sont ignorés au lieu de créer une capacité impossible.
func load_array(values: Array) -> void:
	_unlocked.clear()
	for value: Variant in values:
		var ability: StringName = StringName(str(value))
		if KNOWN.has(ability):
			_unlocked[ability] = true
