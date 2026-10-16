class_name ChunkStreamer
extends Node2D
## Garde les tronçons autour d'une position : génère devant, recycle derrière.
##
## Les tronçons quittés sont retirés de l'arbre (donc de l'espace physique) et
## gardés en réserve par identifiant pour être réutilisés sans reconstruction.
## Au-delà de max_pool_per_layout, ils sont libérés : la mémoire reste bornée
## quelle que soit la distance parcourue.

signal chunk_spawned(index: int, layout_id: StringName)
signal chunk_recycled(index: int, layout_id: StringName)
## Mode ordonné : plus de tronçon à fournir. end_x = fin du dernier tronçon.
signal sequence_finished(end_x: float)

## Longueur de niveau tenue prête devant la position suivie (px).
@export var ahead_distance: float = 2400.0
## Un tronçon dont la fin est plus loin que cela derrière est recyclé (px).
@export var behind_distance: float = 1400.0
@export var max_pool_per_layout: int = 2

var sequencer: ChunkSequencer
## Nombre de tronçons construits (hors réutilisation) : mesure l'efficacité de la réserve.
var created_count: int = 0

var _active: Array[LevelChunk] = []
var _pool: Dictionary[StringName, Array] = {}
var _next_x: float = 0.0
var _next_index: int = 0
var _finished: bool = false


func update(target_x: float) -> void:
	if sequencer == null:
		return
	while not _finished and _next_x < target_x + ahead_distance:
		_spawn_next()
	while not _active.is_empty() and _active[0].end_x() < target_x - behind_distance:
		_recycle(_active.pop_front())


func active_count() -> int:
	return _active.size()


func pooled_count() -> int:
	var total: int = 0
	for pooled: Array in _pool.values():
		total += pooled.size()
	return total


func active_chunks() -> Array[LevelChunk]:
	return _active.duplicate()


func chunk_at(x: float) -> LevelChunk:
	for chunk: LevelChunk in _active:
		if chunk.contains_x(x):
			return chunk
	return null


## Fin du dernier tronçon généré.
func end_x() -> float:
	return _next_x


func is_finished() -> bool:
	return _finished


func _spawn_next() -> void:
	var layout: ChunkLayout = sequencer.next()
	if layout == null:
		_finished = true
		sequence_finished.emit(_next_x)
		return
	var chunk: LevelChunk = _take_from_pool(layout)
	chunk.position = Vector2(_next_x, 0.0)
	chunk.index = _next_index
	add_child(chunk)
	_active.append(chunk)
	chunk_spawned.emit(_next_index, layout.id)
	_next_x += layout.width
	_next_index += 1


func _take_from_pool(layout: ChunkLayout) -> LevelChunk:
	var pooled: Array = _pool.get(layout.id, [])
	if not pooled.is_empty():
		return pooled.pop_back() as LevelChunk
	var chunk: LevelChunk = LevelChunk.new()
	chunk.build(layout)
	created_count += 1
	return chunk


func _recycle(chunk: LevelChunk) -> void:
	chunk_recycled.emit(chunk.index, chunk.layout.id)
	remove_child(chunk)
	var pooled: Array = _pool.get_or_add(chunk.layout.id, [])
	if pooled.size() < max_pool_per_layout:
		pooled.append(chunk)
	else:
		chunk.free()


## Les tronçons en réserve sont hors de l'arbre : il faut les libérer soi-même.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for pooled: Array in _pool.values():
			for chunk: Variant in pooled:
				(chunk as LevelChunk).free()
		_pool.clear()
