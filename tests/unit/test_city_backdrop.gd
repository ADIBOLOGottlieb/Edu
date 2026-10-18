extends GutTest
## Fond de ville (CityBackdrop) : fond neutre sans thème, trois plans de
## parallaxe aux couleurs de Lomé, génération déterministe, repères stylisés.

const LOME_PATH: String = "res://data/cities/lome_theme.tres"
## Repères de Lomé (CityTheme.landmarks) : cathédrale, monuments de rond-point,
## bord de mer, palais, tour d'hôtel ; le monument est l'Indépendance.
const LOME_LANDMARKS: Array[StringName] = [
	&"cathedral", &"colombe_paix", &"deux_lions", &"beach_palms", &"palais_lome", &"hotel_tower",
]


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
		var d: LandmarkDrawing = LandmarkPainter.drawing(key)
		assert_gt(d.fill.size(), 0, "repère %s" % key)
		assert_eq(d.tinted.size(), d.tints.size(), "%s : une teinte par touche de couleur" % key)
		for poly: PackedVector2Array in d.fill + d.light + d.dark + d.tinted:
			assert_false(Geometry2D.triangulate_polygon(poly).is_empty(), "%s : polygone invalide" % key)
	assert_gt(LandmarkPainter.details(&"lome_independence", Vector2.ZERO).size(), 0, "perforations en relief")


func test_lome_monuments_have_relief_and_shadow() -> void:
	for key: StringName in [&"lome_independence", &"colombe_paix", &"deux_lions", &"palais_lome", &"cathedral"]:
		assert_true(LandmarkPainter.is_known(key), String(key))
		assert_gt(LandmarkPainter.details(key, Vector2.ZERO).size(), 0, "%s : reliefs clairs" % key)
	for key: StringName in [&"lome_independence", &"palais_lome", &"cathedral"]:
		assert_gt(LandmarkPainter.shades(key, Vector2.ZERO).size(), 0, "%s : baies sombres" % key)
	assert_gt(LandmarkPainter.drawing(&"deux_lions").tinted.size(), 4, "drapeau togolais")


func test_independence_cutout_lets_the_sky_through() -> void:
	# Le milieu de l'évidement (sous la statue, au-dessus du podium) n'est
	# couvert par aucun polygone plein du monument.
	var probes: Array[Vector2] = [Vector2(-20.0, -100.0), Vector2(20.0, -150.0), Vector2(0.0, -165.0)]
	for p: Vector2 in probes:
		for poly: PackedVector2Array in LandmarkPainter.silhouette(&"lome_independence", Vector2.ZERO):
			assert_false(Geometry2D.is_point_in_polygon(p, poly), "évidement bouché en %s" % p)
	var top: float = _bounds(LandmarkPainter.silhouette(&"lome_independence", Vector2.ZERO)).position.y
	assert_lt(top, -300.0, "hautes dalles latérales")


func test_landmark_widths_cover_their_silhouette() -> void:
	for key: StringName in LandmarkPainter.KNOWN:
		var box: Rect2 = _bounds(LandmarkPainter.silhouette(key, Vector2.ZERO))
		assert_lte(box.size.x, LandmarkPainter.width(key) + 0.5, "%s : emprise déclarée trop étroite" % key)
		assert_almost_eq(box.get_center().x, 0.0, LandmarkPainter.width(key) * 0.1, "%s : centré sur l'origine" % key)


func test_all_lome_landmarks_are_drawn_in_the_backdrop() -> void:
	var theme: CityTheme = _lome_with_landmarks()
	var layers: Array[Parallax2D] = _build(theme).layers
	var spans: Array[float] = [CityBackdrop.FAR_SPAN, CityBackdrop.MID_SPAN]
	var grounds: Array[float] = [0.0, -BackdropLayerPainter.MID_LANDMARK_LIFT]
	var seen: Array[StringName] = []
	for layer: int in [LandmarkPainter.Layer.FAR, LandmarkPainter.Layer.MID]:
		var canvas: BackdropCanvas = _canvas(layers[layer])
		for s: BackdropLayerPainter.Slot in BackdropLayerPainter.landmark_slots(theme, layer as LandmarkPainter.Layer, spans[layer]):
			assert_eq(LandmarkPainter.layer_of(s.key), layer, "%s sur le bon plan" % s.key)
			var ground: float = grounds[layer] if s.key != &"beach_palms" else -1.0
			var first: PackedVector2Array = LandmarkPainter.silhouette(s.key, Vector2(s.x, ground), s.scale)[0]
			assert_true(canvas.has_polygon(first), "%s dessiné sur le plan %d" % [s.key, layer])
			if not seen.has(s.key):
				seen.append(s.key)
	for key: StringName in BackdropLayerPainter.theme_landmarks(theme):
		assert_true(seen.has(key), "repère %s absent du décor" % key)
	assert_eq(LandmarkPainter.layer_of(&"colombe_paix"), LandmarkPainter.Layer.MID, "rond-point sur les quartiers")
	assert_eq(LandmarkPainter.layer_of(&"deux_lions"), LandmarkPainter.Layer.MID, "rond-point sur les quartiers")


func test_landmarks_never_overlap_on_a_layer() -> void:
	var theme: CityTheme = _lome_with_landmarks()
	var spans: Array[float] = [CityBackdrop.FAR_SPAN, CityBackdrop.MID_SPAN]
	for layer: int in [LandmarkPainter.Layer.FAR, LandmarkPainter.Layer.MID]:
		var slots: Array[BackdropLayerPainter.Slot] = BackdropLayerPainter.landmark_slots(
			theme, layer as LandmarkPainter.Layer, spans[layer])
		for i: int in slots.size():
			var a: Vector2 = slots[i].footprint()
			assert_gte(a.x, -1.0, "%s commence dans le motif" % slots[i].key)
			if i + 1 < slots.size():
				assert_lte(a.y, slots[i + 1].footprint().x, "%s chevauche %s" % [slots[i].key, slots[i + 1].key])
		if slots.size() > 1:
			# Le motif boucle : le dernier repère ne mord pas sur le premier.
			assert_lte(slots[-1].footprint().y, spans[layer] + slots[0].footprint().x, "chevauchement au raccord")


func test_monument_alone_on_the_first_screen_and_others_met_early() -> void:
	var theme: CityTheme = _lome_with_landmarks()
	var backdrop: CityBackdrop = _build(theme)
	var view: Vector2 = Vector2(1280.0, 720.0)
	# À la caméra de référence, x motif + offset = x écran sur chaque plan.
	var offset: float = view.x * 0.5 - backdrop.reference_camera.x
	var far: Array[BackdropLayerPainter.Slot] = BackdropLayerPainter.landmark_slots(
		theme, LandmarkPainter.Layer.FAR, CityBackdrop.FAR_SPAN)
	var monument: Vector2 = Vector2.ZERO
	for s: BackdropLayerPainter.Slot in far:
		if s.key == theme.monument:
			monument = s.footprint()
	assert_gt(monument.x + offset, 0.0, "monument entier sur le premier écran")
	assert_lt(monument.y + offset, view.x, "monument entier sur le premier écran")
	var mid: Array[BackdropLayerPainter.Slot] = BackdropLayerPainter.landmark_slots(
		theme, LandmarkPainter.Layer.MID, CityBackdrop.MID_SPAN)
	for s: BackdropLayerPainter.Slot in mid:
		var f: Vector2 = s.footprint()
		assert_gt(f.x + offset, view.x, "%s hors du premier écran" % s.key)
		assert_lt(f.y + offset - CityBackdrop.MID_SPAN, 0.0, "%s hors du premier écran (raccord)" % s.key)
	# Chaque repère entre à l'écran en moins de 90 s au rythme le plus lent (320 px/s).
	var scrolls: Array[float] = [backdrop.far_scroll.x, backdrop.mid_scroll.x]
	var all: Array[Array] = [far, mid]
	for layer: int in all.size():
		for s: BackdropLayerPainter.Slot in all[layer]:
			var distance: float = maxf(s.footprint().x + offset - view.x, 0.0) / scrolls[layer]
			assert_lt(distance / 320.0, 90.0, "%s rencontré trop tard" % s.key)


func test_mid_layer_stays_low_in_front_of_the_monument() -> void:
	var theme: CityTheme = _lome_with_landmarks()
	var mid: BackdropCanvas = _canvas(_build(theme).layers[1])
	var x0: float = BackdropLayerPainter.MONUMENT_X - 60.0
	var x1: float = BackdropLayerPainter.MONUMENT_X + 60.0
	# Rien sur le plan des quartiers ne monte au-dessus du toit bas (tôle
	# comprise) dans l'axe du monument.
	assert_gt(mid.top_between(x0, x1), -BackdropLayerPainter.LOW_RISE - 16.0, "immeuble trop haut devant le monument")


## Thème de Lomé avec les repères proposés (ajoutés s'ils manquent aux données).
func _lome_with_landmarks() -> CityTheme:
	var theme: CityTheme = _lome().duplicate() as CityTheme
	for key: StringName in LOME_LANDMARKS:
		if not theme.landmarks.has(key):
			theme.landmarks.append(key)
	return theme


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


## Téléphone à 7 FPS : chaque forme était un appel de dessin. Un plan = un maillage.
func test_layer_is_one_merged_mesh() -> void:
	var canvas: BackdropCanvas = BackdropCanvas.new()
	canvas.add_rect(Rect2(0, 0, 10, 10), Color.RED)
	canvas.add_gradient(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 8)]),
			PackedColorArray([Color.RED, Color.GREEN, Color.BLUE]))
	canvas.add_line(PackedVector2Array([Vector2(0, 20), Vector2(30, 22), Vector2(60, 20)]), Color.BLACK, 1.5)
	var mesh: ArrayMesh = canvas.build_mesh()
	assert_not_null(mesh)
	assert_eq(mesh.get_surface_count(), 1, "un seul appel de dessin")
	# rectangle 2 + triangle 1 + câble 2 segments × 3 quadrilatères × 2 triangles
	assert_eq(canvas.triangle_count(), 2 + 1 + 12)
	canvas.free()
