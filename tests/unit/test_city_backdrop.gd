extends GutTest
## Fond de ville (CityBackdrop) : fond neutre sans thème, trois plans de
## parallaxe aux couleurs de Lomé, génération déterministe, repères stylisés.

const LOME_PATH: String = "res://data/cities/lome_theme.tres"


func _lome() -> CityTheme:
	return load(LOME_PATH) as CityTheme


func _build(theme: CityTheme) -> CityBackdrop:
	var backdrop: CityBackdrop = CityBackdrop.new()
	backdrop.theme = theme
	add_child_autofree(backdrop)
	return backdrop


func _canvas(layer: Parallax2D) -> BackdropCanvas:
	return layer.get_node("Canvas") as BackdropCanvas


func test_neutral_backdrop_without_theme() -> void:
	var backdrop: CityBackdrop = _build(null)
	assert_eq(backdrop.layers.size(), 1, "fond provisoire : un seul plan d'immeubles")
	var fills: Array[Node] = backdrop.find_children("*", "ColorRect", true, false)
	assert_eq(fills.size(), 1)
	assert_eq((fills[0] as ColorRect).color, backdrop.background_color)


func test_lome_builds_three_parallax_layers() -> void:
	var backdrop: CityBackdrop = _build(_lome())
	assert_eq(backdrop.layers.size(), 3)
	var names: Array[String] = []
	for layer: Parallax2D in backdrop.layers:
		names.append(String(layer.name))
		assert_eq(layer.get_child_count(), 1, "un seul élément de dessin par plan (ADR-025)")
		assert_not_null(_canvas(layer))
		assert_gt(layer.repeat_size.x, 1280.0, "motif répété plus large que l'écran")
		assert_gt(_canvas(layer).shape_count(), 20)
	assert_eq(names, ["Far", "Mid", "Near"] as Array[String])
	assert_eq(backdrop.find_children("*", "Parallax2D", true, false).size(), 3)
	assert_eq(backdrop.find_children("*", "SkyPainter", true, false).size(), 1, "ciel en dégradé")


func test_scroll_scales_increase_from_far_to_near() -> void:
	var layers: Array[Parallax2D] = _build(_lome()).layers
	for i: int in range(1, layers.size()):
		assert_gt(layers[i].scroll_scale.x, layers[i - 1].scroll_scale.x, "défilement horizontal croissant")
		assert_gt(layers[i].scroll_scale.y, layers[i - 1].scroll_scale.y, "défilement vertical croissant")
	assert_between(layers[0].scroll_scale.x, 0.1, 0.15)
	assert_almost_eq(layers[1].scroll_scale.x, 0.3, 0.05)
	assert_between(layers[2].scroll_scale.x, 0.55, 0.65)
	assert_lt(layers[2].scroll_scale.y, 1.0, "les plans restent derrière le premier plan")


func test_layer_colours_come_from_the_theme() -> void:
	var theme: CityTheme = _lome()
	var layers: Array[Parallax2D] = _build(theme).layers
	var expected: Array[Color] = [theme.far_color, theme.mid_color, theme.near_color]
	for i: int in layers.size():
		var canvas: BackdropCanvas = _canvas(layers[i])
		assert_eq(canvas.base_color, expected[i])
		assert_true(canvas.used_colors().has(expected[i]))


func test_no_layer_uses_the_foreground_ink() -> void:
	var theme: CityTheme = _lome()
	for layer: Parallax2D in _build(theme).layers:
		for c: Color in _canvas(layer).used_colors():
			var gap: float = Vector3(c.r - theme.ink.r, c.g - theme.ink.g, c.b - theme.ink.b).length()
			assert_gt(gap, 0.15, "%s : couleur %s trop proche de l'encre" % [layer.name, c])


func test_every_polygon_can_be_triangulated() -> void:
	for layer: Parallax2D in _build(_lome()).layers:
		assert_eq(_canvas(layer).invalid_polygon_count(), 0, "%s : polygone invalide" % layer.name)


func test_generation_is_deterministic_for_a_seed() -> void:
	var a: Array[Parallax2D] = _build(_lome()).layers
	var b: Array[Parallax2D] = _build(_lome()).layers
	for i: int in a.size():
		assert_eq(_canvas(a[i]).signature(), _canvas(b[i]).signature(), "même graine, même plan")
	var other: CityTheme = _lome().duplicate() as CityTheme
	other.seed_value += 1
	var c: Array[Parallax2D] = _build(other).layers
	assert_ne(_canvas(a[1]).signature(), _canvas(c[1]).signature(), "autre graine, autres quartiers")


func test_lome_details_follow_the_theme_flags() -> void:
	var layers: Array[Parallax2D] = _build(_lome()).layers
	assert_gt(_canvas(layers[2]).count_of(BackdropCanvas.Kind.LINE), 10, "câbles électriques")
	# Le monument dépasse nettement la ligne d'horizon lointaine.
	assert_lt(_canvas(layers[0]).bounds().position.y, -250.0)
	var plain: CityTheme = _lome().duplicate() as CityTheme
	plain.power_lines = false
	var plain_layers: Array[Parallax2D] = _build(plain).layers
	assert_eq(_canvas(plain_layers[2]).count_of(BackdropCanvas.Kind.LINE), 0)


func test_every_known_landmark_produces_geometry() -> void:
	for key: StringName in LandmarkPainter.KNOWN:
		var shapes: Array[PackedVector2Array] = LandmarkPainter.silhouette(key, Vector2.ZERO, 1.0)
		assert_gt(shapes.size(), 0, "repère %s" % key)
		for poly: PackedVector2Array in shapes + LandmarkPainter.details(key, Vector2.ZERO, 1.0):
			assert_false(Geometry2D.triangulate_polygon(poly).is_empty(), "%s : polygone invalide" % key)
	assert_gt(LandmarkPainter.details(&"lome_independence", Vector2.ZERO).size(), 0, "figure en relief")


func test_lome_landmarks_are_all_known() -> void:
	var theme: CityTheme = _lome()
	assert_true(LandmarkPainter.is_known(theme.monument))
	for key: StringName in theme.landmarks:
		assert_true(LandmarkPainter.is_known(key), String(key))


func test_unknown_landmark_produces_nothing() -> void:
	assert_eq(LandmarkPainter.silhouette(&"atlantis_tower", Vector2.ZERO).size(), 0)
	assert_eq(LandmarkPainter.details(&"atlantis_tower", Vector2.ZERO).size(), 0)


func test_landmark_scale_and_origin_apply() -> void:
	var small: Rect2 = _bounds(LandmarkPainter.silhouette(&"hotel_tower", Vector2.ZERO, 0.5))
	var big: Rect2 = _bounds(LandmarkPainter.silhouette(&"hotel_tower", Vector2(100.0, 0.0), 1.0))
	assert_almost_eq(big.size.y, small.size.y * 2.0, 0.5)
	assert_almost_eq(big.get_center().x, 100.0, 1.0)


func _bounds(polys: Array[PackedVector2Array]) -> Rect2:
	var box: Rect2 = Rect2(polys[0][0], Vector2.ZERO)
	for poly: PackedVector2Array in polys:
		for p: Vector2 in poly:
			box = box.expand(p)
	return box
