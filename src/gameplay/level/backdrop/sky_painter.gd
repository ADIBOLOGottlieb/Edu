class_name SkyPainter
extends Control
## Ciel en espace écran : dégradé vertical sky_top → sky_horizon, lueur
## chaude sur l'horizon et soleil au halo doux. Un seul _draw.

## Hauteur relative (0..1) de l'écran où le ciel atteint sky_horizon.
const HORIZON: float = 0.66

var city: CityTheme
## Hauteur relative maximale du centre du soleil : il se couche derrière la
## ligne d'horizon lointaine sans disparaître derrière les toits (1 = libre).
var sun_max_y: float = 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Arrêts du dégradé : (hauteur relative, couleur), du haut vers le bas.
func gradient_stops() -> Array[Color]:
	var glow: Color = city.sky_horizon.lerp(city.sun_color, 0.45)
	var stops: Array[Color] = [
		city.sky_top,
		city.sky_top.lerp(city.sky_horizon, 0.38),
		city.sky_horizon,
		glow,
		city.sky_horizon,
	]
	return stops


func _draw() -> void:
	if city == null:
		return
	var s: Vector2 = size
	var heights: PackedFloat32Array = PackedFloat32Array([0.0, HORIZON * 0.55, HORIZON, HORIZON + 0.06, 1.0])
	var stops: Array[Color] = gradient_stops()
	for i: int in heights.size() - 1:
		var y0: float = heights[i] * s.y
		var y1: float = heights[i + 1] * s.y
		draw_polygon(PackedVector2Array([
			Vector2(0.0, y0), Vector2(s.x, y0), Vector2(s.x, y1), Vector2(0.0, y1),
		]), PackedColorArray([stops[i], stops[i], stops[i + 1], stops[i + 1]]))
	if city.sun_radius <= 0.0:
		return
	var center: Vector2 = Vector2(city.sun_position.x, minf(city.sun_position.y, sun_max_y)) * s
	var r: float = city.sun_radius
	_draw_glow(center, r)
	draw_circle(center, r, city.sun_color.lerp(Color.WHITE, 0.35), true, -1.0, true)


## Halo radial lisse (anneaux à couleurs par sommet, un seul tableau de triangles).
func _draw_glow(center: Vector2, r: float) -> void:
	var radii: PackedFloat32Array = PackedFloat32Array([0.0, 1.0, 1.5, 2.6, 4.5, 8.0])
	var alphas: PackedFloat32Array = PackedFloat32Array([0.9, 0.55, 0.3, 0.14, 0.05, 0.0])
	var segments: int = 48
	var points: PackedVector2Array = PackedVector2Array([center])
	var colors: PackedColorArray = PackedColorArray([Color(city.sun_color, alphas[0])])
	for ring: int in range(1, radii.size()):
		for i: int in segments:
			var a: float = TAU * float(i) / float(segments)
			points.append(center + Vector2(cos(a), sin(a)) * r * radii[ring])
			colors.append(Color(city.sun_color, alphas[ring]))
	var indices: PackedInt32Array = PackedInt32Array()
	for i: int in segments:
		var j: int = (i + 1) % segments
		indices.append_array([0, 1 + i, 1 + j])
	for ring: int in range(1, radii.size() - 1):
		var inner: int = 1 + (ring - 1) * segments
		var outer: int = inner + segments
		for i: int in segments:
			var j: int = (i + 1) % segments
			indices.append_array([inner + i, outer + i, outer + j, inner + i, outer + j, inner + j])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)
