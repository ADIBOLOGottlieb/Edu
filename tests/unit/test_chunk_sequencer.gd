extends GutTest
## Choix des tronçons (src/core/level/chunk_sequencer.gd).


func _layout(id: StringName, difficulty: int, weight: float = 1.0) -> ChunkLayout:
	var layout: ChunkLayout = ChunkLayout.new()
	layout.id = id
	layout.width = 800.0
	layout.difficulty = difficulty
	layout.weight = weight
	return layout


func _library() -> ChunkLibrary:
	var library: ChunkLibrary = ChunkLibrary.new()
	library.start_id = &"start"
	library.layouts = [
		_layout(&"start", 0),
		_layout(&"easy_a", 0),
		_layout(&"easy_b", 0),
		_layout(&"medium", 1),
		_layout(&"hard", 2),
		_layout(&"expert", 3),
	]
	return library


func _ids(sequencer: ChunkSequencer, count: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for i: int in count:
		var layout: ChunkLayout = sequencer.next()
		result.append(layout.id if layout != null else &"<null>")
	return result


func test_ordered_mode_follows_the_list_then_ends() -> void:
	var order: Array[StringName] = [&"start", &"hard", &"easy_a"]
	var sequencer: ChunkSequencer = ChunkSequencer.new(_library(), ChunkSequencer.Mode.ORDERED, 1, order)
	assert_eq(_ids(sequencer, 3), order)
	assert_null(sequencer.next(), "fin de séquence")
	assert_eq(sequencer.index(), 3)


func test_random_mode_starts_with_the_safe_chunk() -> void:
	var sequencer: ChunkSequencer = ChunkSequencer.new(_library(), ChunkSequencer.Mode.RANDOM, 42)
	assert_eq(sequencer.next().id, &"start")


func test_same_seed_gives_the_same_course_and_another_seed_differs() -> void:
	var a: Array[StringName] = _ids(ChunkSequencer.new(_library(), ChunkSequencer.Mode.RANDOM, 1234), 60)
	var b: Array[StringName] = _ids(ChunkSequencer.new(_library(), ChunkSequencer.Mode.RANDOM, 1234), 60)
	var c: Array[StringName] = _ids(ChunkSequencer.new(_library(), ChunkSequencer.Mode.RANDOM, 9876), 60)
	assert_eq(a, b, "même graine, même parcours")
	assert_ne(a, c, "graines différentes, parcours différents")


func test_never_the_same_chunk_twice_in_a_row() -> void:
	var ids: Array[StringName] = _ids(ChunkSequencer.new(_library(), ChunkSequencer.Mode.RANDOM, 7), 300)
	for i: int in range(1, ids.size()):
		assert_ne(ids[i], ids[i - 1], "répétition au rang %d" % i)


func test_difficulty_ramps_up_with_distance() -> void:
	var library: ChunkLibrary = _library()
	var sequencer: ChunkSequencer = ChunkSequencer.new(library, ChunkSequencer.Mode.RANDOM, 5)
	sequencer.ramp_every = 4
	for i: int in 40:
		var allowed: int = sequencer.max_difficulty()
		var layout: ChunkLayout = sequencer.next()
		assert_lte(layout.difficulty, allowed, "rang %d : difficulté %d > %d" % [i, layout.difficulty, allowed])
	assert_eq(sequencer.max_difficulty(), ChunkSequencer.MAX_DIFFICULTY)


func test_zero_weight_chunks_are_never_picked() -> void:
	var library: ChunkLibrary = _library()
	library.layouts.append(_layout(&"disabled", 0, 0.0))
	var ids: Array[StringName] = _ids(ChunkSequencer.new(library, ChunkSequencer.Mode.RANDOM, 3), 200)
	assert_false(ids.has(&"disabled"))


func test_empty_library_returns_null_without_crashing() -> void:
	var sequencer: ChunkSequencer = ChunkSequencer.new(ChunkLibrary.new(), ChunkSequencer.Mode.RANDOM, 1)
	assert_null(sequencer.next())
