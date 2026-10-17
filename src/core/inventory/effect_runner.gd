class_name EffectRunner
extends RefCounted
## Effets d'équipement actifs pendant une partie (§7.3–7.4), logique pure.
## Les chronos avancent par tick(delta) en temps de jeu : l'appelant n'appelle pas
## tick pendant la pause, le menu ou quand l'application est en arrière-plan,
## donc les chronos sont gelés. Fin de parcours : end_mission() fait tout expirer.

signal effect_started(id: StringName)
signal effect_refreshed(id: StringName)
signal effect_expired(id: StringName, reason: StringName)
signal effect_rejected(id: StringName, reason: StringName)

enum ActivateResult { STARTED, REFRESHED, REPLACED, REJECTED }

## Effets actifs : id → {data: EquipmentData, remaining: float, charges: int}.
var _active: Dictionary = {}
## Raison du dernier refus (&"incompatible", &"category_busy"), pour le message affiché.
var last_reject_reason: StringName = &""


## Active un équipement. En cas de refus, l'objet doit être conservé par l'appelant.
func activate(data: EquipmentData) -> ActivateResult:
	last_reject_reason = &""
	for other_id: Variant in _active:
		var other: EquipmentData = _active[other_id]["data"]
		if other.id != data.id and (data.incompatible_with.has(other.id) or other.incompatible_with.has(data.id)):
			return _reject(data, &"incompatible")
	if _active.has(data.id):
		if data.stack_rule == EquipmentData.StackRule.REJECT:
			return _reject(data, &"already_active")
		_active[data.id]["remaining"] = data.duration
		_active[data.id]["charges"] = data.charges
		effect_refreshed.emit(data.id)
		return ActivateResult.REFRESHED
	var same_category: StringName = _active_in_category(data.category)
	if same_category != &"":
		match data.stack_rule:
			EquipmentData.StackRule.REJECT:
				return _reject(data, &"category_busy")
			EquipmentData.StackRule.REPLACE:
				_expire(same_category, &"replaced")
				_start(data)
				return ActivateResult.REPLACED
	_start(data)
	return ActivateResult.STARTED


## Avance les chronos (temps de jeu) ; retourne les effets expirés pendant ce tick.
func tick(delta: float) -> Array[StringName]:
	var expired: Array[StringName] = []
	for id: Variant in _active.keys():
		_active[id]["remaining"] = float(_active[id]["remaining"]) - delta
		if float(_active[id]["remaining"]) <= 0.0:
			expired.append(id as StringName)
	for id: StringName in expired:
		_expire(id, &"timeout")
	return expired


## Utilise une charge (ex. bouclier qui repousse une prise) ; l'effet expire à zéro.
func consume_charge(id: StringName) -> bool:
	if not _active.has(id):
		return false
	var charges: int = int(_active[id]["charges"])
	if charges <= 0:
		return true
	charges -= 1
	_active[id]["charges"] = charges
	if charges == 0:
		_expire(id, &"used_up")
	return true


## Annule un effet (ex. cachette quand on bouge).
func cancel(id: StringName, reason: StringName = &"cancelled") -> void:
	if _active.has(id):
		_expire(id, reason)


func end_mission() -> void:
	for id: Variant in _active.keys():
		_expire(id as StringName, &"mission_end")


func is_active(id: StringName) -> bool:
	return _active.has(id)


func remaining(id: StringName) -> float:
	return float(_active[id]["remaining"]) if _active.has(id) else 0.0


func charges_left(id: StringName) -> int:
	return int(_active[id]["charges"]) if _active.has(id) else 0


func power(id: StringName) -> float:
	return (_active[id]["data"] as EquipmentData).power if _active.has(id) else 0.0


func active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in _active:
		ids.append(id as StringName)
	return ids


func _start(data: EquipmentData) -> void:
	_active[data.id] = {"data": data, "remaining": data.duration, "charges": data.charges}
	effect_started.emit(data.id)


func _expire(id: StringName, reason: StringName) -> void:
	_active.erase(id)
	effect_expired.emit(id, reason)


func _reject(data: EquipmentData, reason: StringName) -> ActivateResult:
	last_reject_reason = reason
	effect_rejected.emit(data.id, reason)
	return ActivateResult.REJECTED


func _active_in_category(category: EquipmentData.Category) -> StringName:
	for id: Variant in _active:
		if (_active[id]["data"] as EquipmentData).category == category:
			return id as StringName
	return &""
