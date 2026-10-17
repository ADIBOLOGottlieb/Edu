class_name CityBackdrop
extends Node2D
## Fond de la course. Sans thème : fond provisoire neutre (aplat clair et une
## ligne d'immeubles en parallaxe, graine fixe). Avec un CityTheme : ciel en
## dégradé avec soleil, puis trois plans de parallaxe aux couleurs de la ville
## (lointain avec monument et repères, quartiers, rue), à la manière de Vector.
## Chaque plan = un Parallax2D répété et un seul élément de dessin
## (BackdropCanvas, un _draw : batching mobile, ADR-025).
## Ne pas utiliser l'image de référence pngtree (ADR-010) : décors originaux.

## Largeur des motifs répétés de chaque plan.
const FAR_SPAN: float = 4200.0
const MID_SPAN: float = 3600.0
const NEAR_SPAN: float = 3000.0
## Sol de chaque plan à la caméra de référence (y monde équivalent ; 0 = toits du départ).
const FAR_GROUND: float = -75.0
const MID_GROUND: float = 40.0
const NEAR_GROUND: float = 175.0
## Hauteur moyenne des immeubles du plan lointain au-dessus de son sol.
const FAR_SKYLINE: float = 36.0

## Ambiance de la ville ; null = fond neutre provisoire.
@export var theme: CityTheme

@export_group("Fond neutre")
@export var background_color: Color = Color(0.93, 0.93, 0.91)
@export var skyline_color: Color = Color(0.78, 0.78, 0.77)
@export var seed_value: int = 7
## Largeur du motif d'immeubles, répété horizontalement.
@export var span: float = 4000.0
## Défilement vertical à 1 : la base des immeubles reste alignée sur l'horizon.
@export var scroll_scale: Vector2 = Vector2(0.35, 1.0)

@export_group("Plans de la ville")
## Défilement (x, y) de chaque plan : strictement croissant du lointain au proche.
@export var far_scroll: Vector2 = Vector2(0.13, 0.3)
@export var mid_scroll: Vector2 = Vector2(0.3, 0.5)
@export var near_scroll: Vector2 = Vector2(0.6, 0.72)
## Centre de caméra au départ d'un niveau : les plans y sont calés comme prévu
## (sol de chaque plan à *_GROUND), le défilement partiel s'applique autour.
@export var reference_camera: Vector2 = Vector2(220.0, -120.0)

## Plans de parallaxe construits, du plus lointain au plus proche.
var layers: Array[Parallax2D] = []


func _ready() -> void:
	if theme == null:
		_build_neutral()
	else:
		_build_city()


func _build_neutral() -> void:
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
	layers.append(parallax)


func _build_city() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Sky"
	layer.layer = -10
	var sky: SkyPainter = SkyPainter.new()
	sky.city = theme
	# Le disque du soleil affleure la ligne d'horizon lointaine au départ.
	var view: Vector2 = _view_size()
	var skyline_y: float = FAR_GROUND - FAR_SKYLINE - (reference_camera.y - view.y * 0.5)
	sky.sun_max_y = (skyline_y - theme.sun_radius * 0.55) / view.y
	layer.add_child(sky)
	add_child(layer)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var far: BackdropCanvas = BackdropCanvas.new()
	rng.seed = hash([theme.seed_value, 1])
	BackdropLayerPainter.paint_far(far, theme, FAR_SPAN, rng)
	_add_layer("Far", far, far_scroll, FAR_SPAN, FAR_GROUND, -8)

	var mid: BackdropCanvas = BackdropCanvas.new()
	rng.seed = hash([theme.seed_value, 2])
	BackdropLayerPainter.paint_mid(mid, theme, MID_SPAN, rng)
	_add_layer("Mid", mid, mid_scroll, MID_SPAN, MID_GROUND, -7)

	var near: BackdropCanvas = BackdropCanvas.new()
	rng.seed = hash([theme.seed_value, 3])
	BackdropLayerPainter.paint_near(near, theme, NEAR_SPAN, rng)
	_add_layer("Near", near, near_scroll, NEAR_SPAN, NEAR_GROUND, -6)


## Un plan : Parallax2D répété horizontalement, un seul BackdropCanvas.
## Décalage du dessin : à la caméra de référence, le plan apparaît comme s'il
## défilait à 1 (sol au y monde « ground ») ; ailleurs il défile à scroll.
func _add_layer(layer_name: String, canvas: BackdropCanvas, scroll: Vector2, repeat: float, ground: float, z: int) -> void:
	var parallax: Parallax2D = Parallax2D.new()
	parallax.name = layer_name
	parallax.scroll_scale = scroll
	parallax.repeat_size = Vector2(repeat, 0.0)
	parallax.repeat_times = 3
	parallax.z_index = z
	var screen_top_left: Vector2 = reference_camera - _view_size() * 0.5
	canvas.name = "Canvas"
	canvas.position = -screen_top_left * (Vector2.ONE - scroll) + Vector2(0.0, ground)
	parallax.add_child(canvas)
	add_child(parallax)
	layers.append(parallax)


func _view_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(1280.0, 720.0)


## Rectangles d'immeubles entre x = 0 et span, base sur l'horizon (y = 0).
func _generate_buildings() -> Array[Rect2]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var buildings: Array[Rect2] = []
	var x: float = 0.0
	while x < span:
		var width: float = minf(rng.randf_range(70.0, 190.0), span - x)
		var height: float = rng.randf_range(140.0, 420.0)
		# Les immeubles descendent loin sous l'horizon : pas de vide quand on monte en altitude.
		buildings.append(Rect2(x, -height, width, height + 2400.0))
		x += width + rng.randf_range(4.0, 40.0)
	return buildings


class SkylineStrip:
	extends Node2D

	var color: Color = Color.GRAY
	var buildings: Array[Rect2] = []

	func _draw() -> void:
		for rect: Rect2 in buildings:
			draw_rect(rect, color)
