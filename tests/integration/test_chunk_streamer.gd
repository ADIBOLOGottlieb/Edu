extends GutTest
## Génération et recyclage des tronçons (ChunkStreamer) dans un vrai arbre de scène.
## La position suivie est avancée à la main : déterministe et rapide.

const LIBRARY_PATH: String = "res://data/levels/chunk_library.tres"

var _library: ChunkLibrary
var _streamer: ChunkStreamer


func before_each() -> void:
	_library = load(LIBRARY_PATH) as ChunkLibrary
	_streamer = ChunkStreamer.new()
	add_child_autofree(_streamer)


func _random_sequencer(seed_value: int) -> ChunkSequencer:
	return ChunkSequencer.new(_library, ChunkSequencer.Mode.RANDOM, seed_value)


func test_chunks_are_laid_end_to_end_without_gaps_or_overlaps() -> void:
	_streamer.sequencer = _random_sequencer(11)
	_streamer.update(0.0)
	var chunks: Array[LevelChunk] = _streamer.active_chunks()
	assert_gt(chunks.size(), 1)
	assert_eq(chunks[0].position.x, 0.0)
	for i: int in range(1, chunks.size()):
		assert_almost_eq(chunks[i].position.x, chunks[i - 1].end_x(), 0.001)
		assert_eq(chunks[i].index, chunks[i - 1].index + 1)


func test_level_is_always_ready_ahead_of_the_target() -> void:
	_streamer.sequencer = _random_sequencer(12)
	for step: int in 100:
		var x: float = step * 333.0
		_streamer.update(x)
		assert_gte(_streamer.end_x(), x + _streamer.ahead_distance)
		assert_not_null(_streamer.chunk_at(x), "aucun tronçon sous x = %.0f" % x)


func test_two_hundred_chunks_keep_memory_bounded() -> void:
	_streamer.sequencer = _random_sequencer(13)
	_streamer.update(0.0)
	await wait_physics_frames(2)
	var nodes_at_start: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var max_active: int = 0
	var x: float = 0.0
	while _streamer.sequencer.index() < 200:
		x += 400.0
		_streamer.update(x)
		max_active = maxi(max_active, _streamer.active_count())
	await wait_physics_frames(2)
	var nodes_at_end: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

	assert_lte(max_active, 8, "tronçons actifs bornés")
	var layout_count: int = _library.layouts.size()
	assert_lte(_streamer.pooled_count(), layout_count * _streamer.max_pool_per_layout)
	assert_lte(
		_streamer.created_count, layout_count * (_streamer.max_pool_per_layout + 2),
		"la réserve évite de reconstruire : %d constructions pour 200 tronçons" % _streamer.created_count
	)
	# Chaque tronçon fait au plus ~13 nœuds : la croissance doit rester bien en deçà
	# de ce que coûteraient 200 tronçons conservés (> 2000 nœuds).
	assert_lt(nodes_at_end - nodes_at_start, 400.0, "nœuds : %d → %d" % [nodes_at_start, nodes_at_end])


func test_recycled_chunks_leave_the_physics_space() -> void:
	_streamer.sequencer = _random_sequencer(14)
	var recycled: Array[int] = []
	_streamer.chunk_recycled.connect(func(index: int, _id: StringName) -> void: recycled.append(index))
	_streamer.update(0.0)
	_streamer.update(20000.0)
	assert_gt(recycled.size(), 0)
	for chunk: LevelChunk in _streamer.active_chunks():
		assert_false(recycled.has(chunk.index), "un tronçon recyclé est encore actif")
		assert_true(chunk.is_inside_tree())
	assert_true(_streamer.active_chunks()[0].end_x() >= 20000.0 - _streamer.behind_distance)


func test_ordered_sequence_finishes_once_at_the_total_length() -> void:
	var order: Array[StringName] = [&"flat_run", &"vault_pair", &"flat_run"]
	_streamer.sequencer = ChunkSequencer.new(_library, ChunkSequencer.Mode.ORDERED, 1, order)
	watch_signals(_streamer)
	_streamer.update(0.0)
	_streamer.update(5000.0)
	var expected_end: float = 0.0
	for id: StringName in order:
		expected_end += _library.get_layout(id).width
	assert_signal_emit_count(_streamer, "sequence_finished", 1)
	assert_eq(get_signal_parameters(_streamer, "sequence_finished")[0], expected_end)
	assert_true(_streamer.is_finished())
