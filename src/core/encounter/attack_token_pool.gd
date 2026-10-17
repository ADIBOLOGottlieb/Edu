class_name AttackTokenPool
extends RefCounted
## Jetons d'engagement (§5.2) : au plus `max_tokens` poursuivants tiennent le
## coureur en même temps ; les autres restent en retrait et l'encerclent.

var max_tokens: int = 2
var _holders: Array[int] = []


func _init(tokens: int = 2) -> void:
	max_tokens = tokens


## Vrai si `holder` (identifiant d'instance) a ou obtient un jeton.
func request(holder: int) -> bool:
	if _holders.has(holder):
		return true
	if _holders.size() >= max_tokens:
		return false
	_holders.append(holder)
	return true


func release(holder: int) -> void:
	_holders.erase(holder)


func holds(holder: int) -> bool:
	return _holders.has(holder)


func in_use() -> int:
	return _holders.size()


func clear() -> void:
	_holders.clear()
