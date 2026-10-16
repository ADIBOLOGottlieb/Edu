class_name CityBackdrop
extends Node2D
## Fond provisoire : aplat clair et lignes d'immeubles en aplats sur un plan
## de parallaxe répété à l'infini (graine fixe). Ne pas remplacer par l'image
## de référence pngtree (ADR-010) : les décors finaux seront originaux.
## Les immeubles sont dessinés dans un seul élément de dessin (SkylineStrip).

@export var background_color: Color = Color(0.93, 0.93, 0.91)
@export var skyline_color: Color = Color(0.78, 0.78, 0.77)
@export var seed_value: int = 7
## Largeur du motif d'immeubles, répété horizontalement.
@export var span: float = 4000.0
## Défilement vertical à 1 : la base des immeubles reste alignée sur l'horizon.
@export var scroll_scale: Vector2 = Vector2(0.35, 1.0)


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = -10
	var fill: ColorRect = ColorRect.new()
	fill.color = background_color
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fill)
	add_child(layer)

	var parallax: Parallax2D = Parallax2D.new()
	parallax.scroll_scale = scroll_scale
	parallax.repeat_size = Vector2(span, 0.0)
	parallax.repeat_times = 3
	parallax.z_index = -5
	var strip: SkylineStrip = SkylineStrip.new()
	strip.color = skyline_color
	strip.buildings = _generate_buildings()
	parallax.add_child(strip)
	add_child(parallax)


## Rectangles d'immeubles entre x = 0 et span, base sur l'horizon (y = 0).
func _generate_buildings() -> Array[Rect2]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var buildings: Array[Rect2] = []
	var x: float = 0.0
	while x < span:
		var width: float = minf(rng.randf_range(70.0, 190.0), span - x)
		var height: float = rng.randf_range(140.0, 420.0)
		buildings.append(Rect2(x, -height, width, height))
		x += width + rng.randf_range(4.0, 40.0)
	return buildings


class SkylineStrip:
	extends Node2D

	var color: Color = Color.GRAY
	var buildings: Array[Rect2] = []

	func _draw() -> void:
		for rect: Rect2 in buildings:
			draw_rect(rect, color)
