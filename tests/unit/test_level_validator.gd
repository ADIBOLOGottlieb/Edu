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


func test_higher_roof_is_reached_by_jump_or_climb_but_not_beyond() -> void:
	var jump_up: ChunkLayout = _layout(1000, [Rect2(0, 0, 400, 1400), Rect2(500, -100, 500, 1400)])
	jump_up.exit_y = -100.0
	assert_eq(LevelValidator.validate(jump_up, _tuning), [] as Array[String], "100 px plus haut, trou de 100")
	var climb: ChunkLayout = _layout(1000, [Rect2(0, 0, 500, 1400), Rect2(500, -220, 500, 1400)])
	climb.exit_y = -220.0
	assert_eq(LevelValidator.validate(climb, _tuning), [] as Array[String], "paroi de 220 px")
	var too_high: ChunkLayout = _layout(1000, [Rect2(0, 0, 500, 1400), Rect2(500, -400, 500, 1400)])
	too_high.exit_y = -400.0
	assert_has(LevelValidator.validate(too_high, _tuning), "aucun chemin franchissable de l'entrée à la sortie")


func test_dropping_down_reaches_further_than_a_flat_jump() -> void:
	var flat_limit: float = LevelValidator.max_gap(_tuning)
	assert_gt(LevelValidator.jump_reach(-200.0, _tuning), flat_limit)
	assert_lt(LevelValidator.jump_reach(100.0, _tuning), flat_limit)
	assert_eq(LevelValidator.jump_reach(500.0, _tuning), -1.0, "hors d'atteinte")
	var gap: float = flat_limit + 30.0
	var drop: ChunkLayout = _layout(1000, [Rect2(0, 0, 400, 1400), Rect2(400 + gap, 200, 600 - gap, 1400)])
	drop.exit_y = 200.0
	assert_eq(LevelValidator.validate(drop, _tuning), [] as Array[String])


func test_thin_beams_over_the_void_are_valid_stepping_stones() -> void:
	var beams: ChunkLayout = _layout(1000, [
		Rect2(0, 0, 300, 1400), Rect2(450, -60, 140, 16), Rect2(740, 0, 260, 1400),
	])
	assert_eq(LevelValidator.validate(beams, _tuning), [] as Array[String])


func test_exit_roof_must_match_exit_height() -> void:
	var layout: ChunkLayout = _layout(800, [Rect2(0, 0, 800, 1400)])
	layout.exit_y = -100.0
	assert_has(LevelValidator.validate(layout, _tuning), "pas de toit à la sortie (y = -100)")


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
