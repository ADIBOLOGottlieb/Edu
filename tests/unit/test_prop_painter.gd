extends GutTest
## Objets urbains du premier plan (PropPainter) : les silhouettes doivent rester
## dans le bloc de collision, le couvrir honnêtement, garder le dessus praticable
## plein (le dessous pour un plafond) et tenir le budget de polygones mobile.

const LOME_PATH: String = "res://data/cities/lome_theme.tres"
const VARIANTS: Array[int] = [0, 1, 2, 3, 7, 1234567]
## Grille d'échantillonnage pour la couverture d'encre.
const SAMPLES: int = 40
const EDGE_SAMPLES: int = 120
const BUILDING_MAX_POLYGONS: int = 120
const PROP_MAX_POLYGONS: int = 40

## Tailles réelles de data/levels/chunk_library.tres, avec un décalage de tronçon.
var _sizes: Dictionary = {
	BlockKind.Kind.BUILDING: [Rect2(0, 0, 800, 1400), Rect2(880, 0, 220, 1400),
			Rect2(0, 0, 1400, 1400), Rect2(500, -110, 380, 1400)],
	BlockKind.Kind.PILLAR: [Rect2(470, -40, 90, 1400), Rect2(730, -90, 90, 1400)],
	BlockKind.Kind.LOW_OBSTACLE: [Rect2(300, -40, 100, 40), Rect2(620, -36, 90, 36),
			Rect2(560, -44, 70, 44), Rect2(180, -40, 80, 40)],
	BlockKind.Kind.WALL: [Rect2(460, -220, 90, 220), Rect2(520, -260, 100, 260), Rect2(900, -200, 90, 200)],
	BlockKind.Kind.PLATFORM: [Rect2(360, -100, 300, 100), Rect2(400, -200, 500, 200), Rect2(100, -150, 400, 150)],
	BlockKind.Kind.CEILING: [Rect2(380, -420, 380, 372), Rect2(240, -420, 240, 372), Rect2(780, -460, 180, 372)],
	BlockKind.Kind.BEAM: [Rect2(760, -100, 140, 16), Rect2(700, -170, 220, 16), Rect2(1020, -130, 200, 16)],
}


func _themes() -> Array[CityTheme]:
	var modern: CityTheme = CityTheme.new()
	var lome: CityTheme = load(LOME_PATH) as CityTheme
	return [null, modern, lome]


func _ink(theme: CityTheme) -> Color:
	return PropPainter.DEFAULT_INK if theme == null else theme.ink


func _label(kind: int, theme: CityTheme, variant: int, rect: Rect2) -> String:
	var style: String = "null" if theme == null else String(theme.prop_style)
	return "%s/%s/v%d/%s" % [BlockKind.Kind.keys()[kind], style, variant, rect.size]


## Appelle `check` pour chaque type × style × variante × taille réelle.
func _each_case(check: Callable) -> void:
	for kind: int in _sizes:
		for theme: CityTheme in _themes():
			for variant: int in VARIANTS:
				for rect: Rect2 in _sizes[kind]:
					var shapes: Array[PropShape] = PropPainter.shapes_for(rect, kind as BlockKind.Kind, variant, theme)
					check.call(kind, theme, variant, rect, shapes)


func test_lome_theme_selects_the_lome_style() -> void:
	var lome: CityTheme = load(LOME_PATH) as CityTheme
	assert_not_null(lome)
	assert_eq(lome.prop_style, &"lome")


func test_every_point_stays_inside_the_block() -> void:
	var failures: Array[String] = []
	_each_case(func(kind: int, theme: CityTheme, variant: int, rect: Rect2, shapes: Array[PropShape]) -> void:
		var bounds: Rect2 = rect.grow(2.0)
		for shape: PropShape in shapes:
			for p: Vector2 in shape.points:
				if not bounds.has_point(p):
					failures.append("%s : %s" % [_label(kind, theme, variant, rect), p])
					return
	)
	assert_eq(failures, [] as Array[String], "points hors du bloc")


func test_every_polygon_is_valid_and_the_base_is_ink() -> void:
	var failures: Array[String] = []
	_each_case(func(kind: int, theme: CityTheme, variant: int, rect: Rect2, shapes: Array[PropShape]) -> void:
		if shapes.is_empty():
			failures.append("%s : aucun polygone" % _label(kind, theme, variant, rect))
			return
		if shapes[0].color != _ink(theme):
			failures.append("%s : la base n'est pas à l'encre" % _label(kind, theme, variant, rect))
		for shape: PropShape in shapes:
			if shape.points.size() < 3 or Geometry2D.triangulate_polygon(shape.points).is_empty():
				failures.append("%s : polygone invalide" % _label(kind, theme, variant, rect))
				return
	)
	assert_eq(failures, [] as Array[String], "polygones invalides")


func test_output_is_deterministic() -> void:
	var failures: Array[String] = []
	_each_case(func(kind: int, theme: CityTheme, variant: int, rect: Rect2, shapes: Array[PropShape]) -> void:
		var again: Array[PropShape] = PropPainter.shapes_for(rect, kind as BlockKind.Kind, variant, theme)
		if again.size() != shapes.size():
			failures.append(_label(kind, theme, variant, rect))
			return
		for i: int in shapes.size():
			if again[i].points != shapes[i].points or again[i].color != shapes[i].color:
				failures.append(_label(kind, theme, variant, rect))
				return
	)
	assert_eq(failures, [] as Array[String], "même entrée, même dessin")


func test_ink_covers_the_collision_block() -> void:
	var failures: Array[String] = []
	_each_case(func(kind: int, theme: CityTheme, variant: int, rect: Rect2, shapes: Array[PropShape]) -> void:
		var ink: Color = _ink(theme)
		var inked: Array[PackedVector2Array] = []
		var boxes: Array[Rect2] = []
		for shape: PropShape in shapes:
			if shape.color == ink:
				inked.append(shape.points)
				boxes.append(_bounds_of(shape.points))
		var covered: int = 0
		for ix: int in SAMPLES:
			for iy: int in SAMPLES:
				var p: Vector2 = rect.position + rect.size * Vector2((ix + 0.5) / SAMPLES, (iy + 0.5) / SAMPLES)
				for i: int in inked.size():
					if boxes[i].has_point(p) and Geometry2D.is_point_in_polygon(p, inked[i]):
						covered += 1
						break
		var ratio: float = float(covered) / (SAMPLES * SAMPLES)
		var wanted: float = 0.70 if kind == BlockKind.Kind.WALL else 0.85
		if ratio < wanted:
			failures.append("%s : %.0f %%" % [_label(kind, theme, variant, rect), ratio * 100.0])
	)
	assert_eq(failures, [] as Array[String], "couverture d'encre insuffisante")


func test_walkable_edge_stays_solid_ink() -> void:
	var failures: Array[String] = []
	_each_case(func(kind: int, theme: CityTheme, variant: int, rect: Rect2, shapes: Array[PropShape]) -> void:
		var ink: Color = _ink(theme)
		# Plafond : on glisse dessous, c'est le bord du bas qui doit rester droit et plein.
		var y: float = rect.end.y - 1.0 if kind == BlockKind.Kind.CEILING else rect.position.y + 1.0
		var solid: int = 0
		for i: int in EDGE_SAMPLES:
			var p: Vector2 = Vector2(rect.position.x + rect.size.x * (i + 0.5) / EDGE_SAMPLES, y)
			# Le polygone dessiné en dernier à cet endroit doit être de l'encre.
			for s: int in range(shapes.size() - 1, -1, -1):
				if Geometry2D.is_point_in_polygon(p, shapes[s].points):
					if shapes[s].color == ink:
						solid += 1
					break
		var ratio: float = float(solid) / EDGE_SAMPLES
		if ratio < 0.9:
			failures.append("%s : %.0f %%" % [_label(kind, theme, variant, rect), ratio * 100.0])
	)
	assert_eq(failures, [] as Array[String], "bord praticable troué")


func test_ceiling_bottom_edge_is_straight() -> void:
	var failures: Array[String] = []
	_each_case(func(kind: int, theme: CityTheme, variant: int, rect: Rect2, shapes: Array[PropShape]) -> void:
		if kind != BlockKind.Kind.CEILING:
			return
		var lowest: float = -INF
		for shape: PropShape in shapes:
			for p: Vector2 in shape.points:
				lowest = maxf(lowest, p.y)
		if absf(lowest - rect.end.y) > 0.01:
			failures.append("%s : bas à %.2f" % [_label(kind, theme, variant, rect), lowest])
	)
	assert_eq(failures, [] as Array[String], "le dessous d'un plafond reste au bas du bloc")


func test_polygon_budget_for_mobile() -> void:
	var failures: Array[String] = []
	_each_case(func(kind: int, theme: CityTheme, variant: int, rect: Rect2, shapes: Array[PropShape]) -> void:
		var budget: int = BUILDING_MAX_POLYGONS if kind == BlockKind.Kind.BUILDING else PROP_MAX_POLYGONS
		if shapes.size() > budget:
			failures.append("%s : %d polygones" % [_label(kind, theme, variant, rect), shapes.size()])
	)
	assert_eq(failures, [] as Array[String], "trop de polygones")


func test_styles_give_different_objects() -> void:
	var rect: Rect2 = Rect2(300, -40, 100, 40)
	var modern: Array[PropShape] = PropPainter.shapes_for(rect, BlockKind.Kind.LOW_OBSTACLE, 0, CityTheme.new())
	var lome: Array[PropShape] = PropPainter.shapes_for(rect, BlockKind.Kind.LOW_OBSTACLE, 0, load(LOME_PATH) as CityTheme)
	assert_ne(modern.size(), 0)
	assert_ne(_signature(modern), _signature(lome), "Lomé dessine ses propres objets")
	var other: Array[PropShape] = PropPainter.shapes_for(rect, BlockKind.Kind.LOW_OBSTACLE, 1, CityTheme.new())
	assert_ne(_signature(modern), _signature(other), "les variantes changent l'objet")


func _signature(shapes: Array[PropShape]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for shape: PropShape in shapes:
		parts.append("%d:%s" % [shape.points.size(), shape.color.to_html()])
	return ",".join(parts)


static func _bounds_of(points: PackedVector2Array) -> Rect2:
	var box: Rect2 = Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		box = box.expand(p)
	return box.grow(0.01)
