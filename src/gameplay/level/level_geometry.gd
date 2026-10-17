class_name LevelGeometry
extends RefCounted
## Fabrique la géométrie de niveau à partir de rectangles : un StaticBody2D
## (couche « monde ») et son aplat visuel. Provisoire : aplats noirs pleins.

const INK: Color = Color(0.04, 0.04, 0.05)
const WORLD_LAYER: int = 1


## with_visual = false : collision seule, quand le parent dessine lui-même
## tous ses blocs en un seul élément de dessin (voir LevelChunk).
static func make_block(rect: Rect2, color: Color = INK, with_visual: bool = true) -> StaticBody2D:
	var block: StaticBody2D = StaticBody2D.new()
	block.position = rect.position
	block.collision_layer = WORLD_LAYER
	block.collision_mask = 0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.size * 0.5
	block.add_child(collision)
	if not with_visual:
		return block
	var visual: Polygon2D = Polygon2D.new()
	visual.color = color
	visual.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)
	])
	block.add_child(visual)
	return block
