extends GutTest
## Règles de validation des tronçons, et validité de la bibliothèque livrée.

const LIBRARY_PATH: String = "res://data/levels/chunk_library.tres"
const PLAYER_TUNING_PATH: String = "res://data/tuning/player_move.tres"

var _tuning: MoveTuning


func before_each() -> void:
	_tuning = MoveTuning.new()


func _layout(width: float, blocks: Array[Rect2]) -> ChunkLayout:
	var layout: ChunkLayout = ChunkLayout.new()
	layout.id = &"test"
	layout.width = width
	layout.blocks = blocks
	return layout


func test_flat_chunk_is_valid() -> void:
	var layout: ChunkLayout = _layout(800, [Rect2(0, 0, 800, 200)])
	assert_eq(LevelValidator.validate(layout, _tuning), [] as Array[String])


func test_missing_floor_at_entry_or_exit_is_reported() -> void:
	var errors: Array[String] = LevelValidator.validate(_layout(800, [Rect2(100, 0, 600, 200)]), _tuning)
	assert_eq(errors.size(), 2, str(errors))


func test_gap_wider_than_a_sprint_jump_is_reported() -> void:
	var limit: float = LevelValidator.max_gap(_tuning)
	var ok: ChunkLayout = _layout(1000, [Rect2(0, 0, 400, 200), Rect2(400 + limit - 1.0, 0, 600 - limit + 1.0, 200)])
	assert_eq(LevelValidator.validate(ok, _tuning), [] as Array[String])
	var too_wide: ChunkLayout = _layout(1000, [Rect2(0, 0, 300, 200), Rect2(300 + limit + 10.0, 0, 700 - limit - 10.0, 200)])
	assert_eq(LevelValidator.validate(too_wide, _tuning).size(), 1)


func test_wall_taller_than_the_climb_limit_is_reported() -> void:
	var limit: float = LevelValidator.max_climb(_tuning)
	var ok: ChunkLayout = _layout(1000, [Rect2(0, 0, 1000, 200), Rect2(500, -(limit - 1.0), 80, limit - 1.0)])
	assert_eq(LevelValidator.validate(ok, _tuning), [] as Array[String])
	var too_tall: ChunkLayout = _layout(1000, [Rect2(0, 0, 1000, 200), Rect2(500, -(limit + 20.0), 80, limit + 20.0)])
	assert_eq(LevelValidator.validate(too_tall, _tuning).size(), 1)


func test_ceiling_too_low_even_for_a_slide_is_reported() -> void:
	var low: ChunkLayout = _layout(1000, [Rect2(0, 0, 1000, 200), Rect2(400, -300, 200, 280)])
	assert_eq(LevelValidator.validate(low, _tuning).size(), 1, "20 px de hauteur libre")
	var slide_only: ChunkLayout = _layout(1000, [Rect2(0, 0, 1000, 200), Rect2(400, -300, 200, 252)])
	assert_eq(LevelValidator.validate(slide_only, _tuning), [] as Array[String], "48 px : glissade")


func test_obstacle_in_the_respawn_zone_is_reported() -> void:
	var layout: ChunkLayout = _layout(800, [Rect2(0, 0, 800, 200), Rect2(60, -40, 60, 40)])
	assert_eq(LevelValidator.validate(layout, _tuning).size(), 1)


func test_block_outside_the_chunk_is_reported() -> void:
	var layout: ChunkLayout = _layout(800, [Rect2(0, 0, 900, 200)])
	assert_gt(LevelValidator.validate(layout, _tuning).size(), 0)


func test_shipped_library_is_entirely_valid_for_the_player() -> void:
	var library: ChunkLibrary = load(LIBRARY_PATH) as ChunkLibrary
	var tuning: MoveTuning = load(PLAYER_TUNING_PATH) as MoveTuning
	assert_not_null(library)
	assert_gte(library.layouts.size(), 8, "assez de variété pour la course")
	assert_not_null(library.get_layout(library.start_id), "tronçon de départ présent")
	var seen: Dictionary[StringName, bool] = {}
	for layout: ChunkLayout in library.layouts:
		assert_false(seen.has(layout.id), "identifiant en double : %s" % layout.id)
		seen[layout.id] = true
		var errors: Array[String] = LevelValidator.validate(layout, tuning)
		assert_eq(errors, [] as Array[String], "%s : %s" % [layout.id, errors])


func test_every_difficulty_level_is_represented() -> void:
	var library: ChunkLibrary = load(LIBRARY_PATH) as ChunkLibrary
	var levels: Dictionary[int, bool] = {}
	for layout: ChunkLayout in library.layouts:
		levels[layout.difficulty] = true
	for difficulty: int in range(0, ChunkSequencer.MAX_DIFFICULTY + 1):
		assert_true(levels.has(difficulty), "aucun tronçon de difficulté %d" % difficulty)
