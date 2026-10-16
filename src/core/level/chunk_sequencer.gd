class_name ChunkSequencer
extends RefCounted
## Choisit le tronçon suivant. Logique pure, testable sans scène.
##
## ORDERED : suit une liste fixe d'identifiants (missions de l'histoire), puis s'arrête.
## RANDOM : tirage pondéré à graine (mode course) ; même graine = même parcours,
## ce qui rend un bogue reproductible. Pas deux fois le même tronçon de suite ;
## la difficulté maximale augmente d'un cran tous les ramp_every tronçons.

enum Mode { ORDERED, RANDOM }

const MAX_DIFFICULTY: int = 3

var mode: Mode
var ramp_every: int = 4
var _library: ChunkLibrary
var _order: Array[StringName] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _index: int = 0
var _last_id: StringName = &""


func _init(
	library: ChunkLibrary, sequence_mode: Mode, seed_value: int, order: Array[StringName] = []
) -> void:
	_library = library
	mode = sequence_mode
	_order = order
	_rng.seed = seed_value


## Nombre de tronçons déjà fournis.
func index() -> int:
	return _index


## Difficulté maximale autorisée pour le prochain tronçon (mode RANDOM).
func max_difficulty() -> int:
	return mini(_index / maxi(ramp_every, 1), MAX_DIFFICULTY)


## Retourne null quand la séquence est terminée (mode ORDERED) ou impossible.
func next() -> ChunkLayout:
	var layout: ChunkLayout = _next_ordered() if mode == Mode.ORDERED else _next_random()
	if layout != null:
		_index += 1
		_last_id = layout.id
	return layout


func _next_ordered() -> ChunkLayout:
	if _index >= _order.size():
		return null
	var layout: ChunkLayout = _library.get_layout(_order[_index])
	if layout == null:
		push_error("Tronçon inconnu dans la séquence : %s" % _order[_index])
	return layout


func _next_random() -> ChunkLayout:
	if _library == null or _library.layouts.is_empty():
		return null
	if _index == 0:
		var start: ChunkLayout = _library.get_layout(_library.start_id)
		if start != null:
			return start
	var limit: int = max_difficulty()
	var candidates: Array[ChunkLayout] = []
	for layout: ChunkLayout in _library.layouts:
		if layout.difficulty <= limit and layout.id != _last_id and layout.weight > 0.0:
			candidates.append(layout)
	if candidates.is_empty():
		# Bibliothèque d'un seul tronçon : la répétition est la seule option.
		return _library.get_layout(_last_id)
	return _weighted_pick(candidates)


func _weighted_pick(candidates: Array[ChunkLayout]) -> ChunkLayout:
	var total: float = 0.0
	for layout: ChunkLayout in candidates:
		total += layout.weight
	var roll: float = _rng.randf() * total
	for layout: ChunkLayout in candidates:
		roll -= layout.weight
		if roll <= 0.0:
			return layout
	return candidates.back()
