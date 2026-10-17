class_name ChunkSequencer
extends RefCounted
## Choisit le tronçon suivant. Logique pure, testable sans scène.
##
## ORDERED : suit une liste fixe d'identifiants (missions de l'histoire), puis s'arrête.
## RANDOM : tirage pondéré à graine (mode course) ; même graine = même parcours,
## ce qui rend un bogue reproductible. Pas deux fois le même tronçon de suite ;
## la difficulté maximale augmente d'un palier tous les ramp_every tronçons ;
## l'altitude reste dans une bande [min_altitude, max_altitude].

enum Mode { ORDERED, RANDOM }

## Paliers 0 (initiation) à 4 (expert).
const MAX_DIFFICULTY: int = 4

var mode: Mode
var ramp_every: int = 5
## Altitude la plus haute autorisée (px, négatif = au-dessus du départ).
var min_altitude: float = -900.0
## Altitude la plus basse autorisée.
var max_altitude: float = 300.0
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


## altitude : hauteur du toit d'entrée du prochain tronçon (ignorée en mode ORDERED).
## Retourne null quand la séquence est terminée (mode ORDERED) ou impossible.
func next(altitude: float = 0.0) -> ChunkLayout:
	var layout: ChunkLayout = _next_ordered() if mode == Mode.ORDERED else _next_random(altitude)
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


func _next_random(altitude: float) -> ChunkLayout:
	if _library == null or _library.layouts.is_empty():
		return null
	if _index == 0:
		var start: ChunkLayout = _library.get_layout(_library.start_id)
		if start != null:
			return start
	var limit: int = max_difficulty()
	var candidates: Array[ChunkLayout] = []
	var any_altitude: Array[ChunkLayout] = []
	for layout: ChunkLayout in _library.layouts:
		if layout.difficulty > limit or layout.id == _last_id or layout.weight <= 0.0:
			continue
		any_altitude.append(layout)
		var exit_altitude: float = altitude + layout.exit_y
		if exit_altitude >= min_altitude and exit_altitude <= max_altitude:
			candidates.append(layout)
	if candidates.is_empty():
		# Aucun tronçon ne garde l'altitude dans la bande : on accepte d'en sortir
		# plutôt que de bloquer la course.
		candidates = any_altitude
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
