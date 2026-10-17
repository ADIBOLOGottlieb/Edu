extends GutTest
## Type d'objet urbain déduit de chaque bloc des tronçons livrés.

const LIBRARY_PATH: String = "res://data/levels/chunk_library.tres"


func _kinds(id: StringName) -> Array[BlockKind.Kind]:
	return BlockKind.kinds_of((load(LIBRARY_PATH) as ChunkLibrary).get_layout(id))


func test_rooftops_are_buildings() -> void:
	assert_eq(_kinds(&"flat_run"), [BlockKind.Kind.BUILDING] as Array[BlockKind.Kind])
	assert_eq(_kinds(&"roof_hop"), [
		BlockKind.Kind.BUILDING, BlockKind.Kind.BUILDING, BlockKind.Kind.BUILDING,
	] as Array[BlockKind.Kind])


func test_small_boxes_on_a_roof_are_low_obstacles() -> void:
	assert_eq(_kinds(&"vent_field").count(BlockKind.Kind.LOW_OBSTACLE), 3)


func test_hovering_tunnel_roof_is_a_ceiling() -> void:
	assert_eq(_kinds(&"low_tunnel")[1], BlockKind.Kind.CEILING)
	assert_eq(_kinds(&"slide_gap")[1], BlockKind.Kind.CEILING)


func test_tall_narrow_obstacle_is_a_wall_and_wide_one_a_platform() -> void:
	assert_eq(_kinds(&"wall_ledge")[1], BlockKind.Kind.WALL)
	assert_eq(_kinds(&"step_platform")[1], BlockKind.Kind.PLATFORM)


func test_thin_beams_and_narrow_pillars() -> void:
	assert_eq(_kinds(&"crane_line").count(BlockKind.Kind.BEAM), 3)
	var hops: Array[BlockKind.Kind] = _kinds(&"precision_hops")
	assert_eq(hops[1], BlockKind.Kind.PILLAR)
	assert_eq(hops[2], BlockKind.Kind.PILLAR)


func test_every_block_of_every_chunk_gets_a_kind() -> void:
	for layout: ChunkLayout in (load(LIBRARY_PATH) as ChunkLibrary).layouts:
		assert_eq(BlockKind.kinds_of(layout).size(), layout.blocks.size(), String(layout.id))


func test_a_chunk_can_force_its_kinds() -> void:
	var layout: ChunkLayout = ChunkLayout.new()
	layout.blocks = [Rect2(0, 0, 800, 1400), Rect2(300, -40, 100, 40)] as Array[Rect2]
	layout.kinds = [-1, BlockKind.Kind.PLATFORM] as Array[int]
	assert_eq(BlockKind.kinds_of(layout), [
		BlockKind.Kind.BUILDING, BlockKind.Kind.PLATFORM,
	] as Array[BlockKind.Kind])


func test_variant_is_stable_and_differs_between_blocks() -> void:
	assert_eq(BlockKind.variant(&"vent_field", 1), BlockKind.variant(&"vent_field", 1))
	assert_ne(BlockKind.variant(&"vent_field", 1), BlockKind.variant(&"vent_field", 2))
	assert_gte(BlockKind.variant(&"vent_field", 1), 0)
