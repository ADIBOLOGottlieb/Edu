class_name PropPainter
extends RefCounted
## Dessine les objets urbains du premier plan à partir des blocs de collision :
## silhouettes noires façon Vector, avec quelques touches chaudes (fenêtres
## éclairées, enseignes peintes). LevelChunk appelle shapes_for une fois par bloc
## à la construction, puis dessine les polygones dans son _draw unique (ADR-025).
##
## Règles (tests/unit/test_prop_painter.gd) :
## - tous les points restent dans le rectangle de collision (découpage sinon) ;
## - l'encre couvre le bloc (lecture honnête de la collision) ;
## - le dessus praticable reste plein (le dessous pour un plafond) ;
## - la base d'encre vient d'abord, les détails plus clairs ensuite.

const DEFAULT_INK: Color = Color(0.04, 0.04, 0.05)
const DEFAULT_ACCENT: Color = Color(0.95, 0.70, 0.30)
## Peinture des enseignes de Lomé (rouge brique tirant vers l'orange).
const LOME_PAINT: Color = Color(0.78, 0.27, 0.14)
## Hauteur d'un étage (le coureur mesure ~74 px).
const STOREY: float = 118.0
## Profondeur de façade détaillée : plus bas, l'immeuble est hors de l'écran.
const FACADE_DEPTH: float = 640.0
## Budget de polygones par immeuble (mobile).
const BUILDING_BUDGET: int = 110


## Polygones (base d'encre d'abord) représentant le bloc `rect` de type `kind`.
## `variant` choisit la variante (BlockKind.variant) ; `theme` nul = style moderne.
static func shapes_for(rect: Rect2, kind: BlockKind.Kind, variant: int, theme: CityTheme) -> Array[PropShape]:
	var pen: Pen = Pen.new(rect, theme, variant, kind)
	var v: int = absi(variant)
	var lome: bool = pen.lome
	match kind:
		BlockKind.Kind.BUILDING:
			if lome:
				match v % 3:
					0: _lome_house(pen)
					1: _lome_balconies(pen)
					_: _lome_mural(pen)
			else:
				match v % 3:
					0: _office(pen)
					1: _apartments(pen)
					_: _warehouse(pen)
		BlockKind.Kind.PILLAR:
			if lome:
				match v % 3:
					0: _power_pole(pen, false)
					1: _concrete_column(pen)
					_: _power_pole(pen, true)
			else:
				match v % 3:
					0: _brick_chimney(pen)
					1: _concrete_column(pen)
					_: _vent_stack(pen)
		BlockKind.Kind.LOW_OBSTACLE:
			if lome:
				match v % 4:
					0: _market_stall(pen)
					1: _jerrycans(pen)
					2: _tyres(pen)
					_: _zemidjan(pen)
			else:
				match v % 3:
					0: _ac_unit(pen)
					1: _crates(pen)
					_: _roof_vent(pen)
		BlockKind.Kind.WALL:
			if lome:
				match v % 4:
					0: _water_tank(pen, true)
					1: _painted_wall(pen)
					2: _claustra_wall(pen)
					_: _stair_housing(pen)
			else:
				match v % 4:
					0: _water_tank(pen, false)
					1: _stair_housing(pen)
					2: _brick_wall(pen)
					_: _billboard_wall(pen)
		BlockKind.Kind.PLATFORM:
			if lome:
				match v % 3:
					0: _tin_shed(pen)
					1: _kiosk(pen)
					_: _stair_room(pen)
			else:
				match v % 3:
					0: _roof_shed(pen)
					1: _container(pen)
					_: _cooling_unit(pen)
		BlockKind.Kind.CEILING:
			if lome:
				match v % 3:
					0: _market_canopy(pen)
					1: _painted_hanging_sign(pen)
					_: _skybridge(pen)
			else:
				match v % 3:
					0: _hanging_billboard(pen)
					1: _skybridge(pen)
					_: _duct_bank(pen)
		BlockKind.Kind.BEAM:
			match v % 3:
				0: _i_beam(pen)
				1: _lattice_jib(pen)
				_:
					if lome:
						_wood_scaffold(pen)
					else:
						_scaffold_plank(pen)
	return pen.shapes


# --- Crayon : primitives en coordonnées locales au bloc ----------------------

class Pen:
	extends RefCounted
	var rect: Rect2
	var size: Vector2
	var lome: bool = false
	var dishes: bool = true
	var shapes: Array[PropShape] = []
	var ink: Color
	## Renfoncements, vitres sombres : à peine plus clair que l'encre.
	var shade: Color
	## Arêtes, garde-corps, cannelures : gris lisible sur l'encre.
	var line: Color
	## Fenêtres éclairées, ampoules.
	var glow: Color
	var glow_dim: Color
	## Enseignes peintes.
	var paint: Color
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var _clip: PackedVector2Array

	func _init(target: Rect2, theme: CityTheme, variant: int, kind: int) -> void:
		rect = target
		size = target.size
		var accent: Color = DEFAULT_ACCENT
		ink = DEFAULT_INK
		if theme != null:
			ink = theme.ink
			accent = theme.accent
			lome = theme.prop_style == &"lome"
			dishes = theme.satellite_dishes
		shade = ink.lerp(Color(0.62, 0.62, 0.70), 0.13)
		line = ink.lerp(Color(0.80, 0.76, 0.74), 0.24)
		glow = accent
		glow_dim = accent.lerp(ink, 0.45)
		paint = LOME_PAINT.lerp(accent, 0.2) if lome else accent.lerp(ink, 0.25)
		rng.seed = hash("%d:%d:%d:%d" % [variant, kind, int(size.x), int(size.y)])
		_clip = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
				rect.end, Vector2(rect.position.x, rect.end.y)])

	## Polygone en coordonnées locales ; découpé au rectangle s'il en déborde.
	func poly(local: PackedVector2Array, color: Color) -> void:
		var world: PackedVector2Array = PackedVector2Array()
		var inside: bool = true
		var bounds: Rect2 = rect.grow(0.01)
		for p: Vector2 in local:
			var q: Vector2 = rect.position + p
			world.append(q)
			if not bounds.has_point(q):
				inside = false
		if inside:
			_push(world, color)
			return
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(world, _clip):
			_push(piece, color)

	func box(x: float, y: float, w: float, h: float, color: Color) -> void:
		if w <= 0.5 or h <= 0.5:
			return
		poly(PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), color)

	func ellipse(cx: float, cy: float, rx: float, ry: float, color: Color, segments: int = 14) -> void:
		if rx <= 0.5 or ry <= 0.5:
			return
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in segments:
			var a: float = TAU * i / segments
			pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
		poly(pts, color)

	func disc(cx: float, cy: float, r: float, color: Color, segments: int = 14) -> void:
		ellipse(cx, cy, r, r, color, segments)

	## Segment épais de a à b.
	func bar(a: Vector2, b: Vector2, thickness: float, color: Color) -> void:
		var d: Vector2 = b - a
		if d.length() < 0.5:
			return
		var n: Vector2 = d.normalized().orthogonal() * thickness * 0.5
		poly(PackedVector2Array([a + n, b + n, b - n, a - n]), color)

	## Rectangle aux coins arrondis (rayon r).
	func round_box(x: float, y: float, w: float, h: float, r: float, color: Color) -> void:
		var radius: float = minf(r, minf(w, h) * 0.5)
		if radius < 0.5:
			box(x, y, w, h, color)
			return
		var pts: PackedVector2Array = PackedVector2Array()
		var centres: Array[Vector2] = [Vector2(x + w - radius, y + radius), Vector2(x + w - radius, y + h - radius),
				Vector2(x + radius, y + h - radius), Vector2(x + radius, y + radius)]
		for c: int in 4:
			for k: int in 5:
				var a: float = -PI * 0.5 + (c + k / 4.0) * PI * 0.5
				pts.append(centres[c] + Vector2(cos(a), sin(a)) * radius)
		poly(_dedupe(pts), color)

	## Bande trouée par le bas : de xa à xb, pleine entre y_top et hole_top,
	## puis des dents entre les trous (left, right) jusqu'à y_bot. Sert aux
	## trumeaux entre fenêtres (trous = vitres), garde-corps, cannelures.
	## arch : trous à sommet en plein cintre.
	func perforated(xa: float, xb: float, y_top: float, hole_top: float, y_bot: float,
			holes: PackedVector2Array, color: Color, arch: bool = false) -> void:
		var pts: PackedVector2Array = PackedVector2Array([Vector2(xa, y_top), Vector2(xb, y_top), Vector2(xb, y_bot)])
		for i: int in range(holes.size() - 1, -1, -1):
			var hl: float = holes[i].x
			var hr: float = holes[i].y
			var r: float = (hr - hl) * 0.5
			if arch and hole_top + r < y_bot:
				pts.append(Vector2(hr, y_bot))
				pts.append(Vector2(hr, hole_top + r))
				for k: int in range(1, 6):
					var a: float = PI * k / 6.0
					pts.append(Vector2(hl + r + cos(a) * r, hole_top + r - sin(a) * r))
				pts.append(Vector2(hl, hole_top + r))
				pts.append(Vector2(hl, y_bot))
			else:
				pts.append(Vector2(hr, y_bot))
				pts.append(Vector2(hr, hole_top))
				pts.append(Vector2(hl, hole_top))
				pts.append(Vector2(hl, y_bot))
		pts.append(Vector2(xa, y_bot))
		poly(_dedupe(pts), color)

	## Bande sur toute la largeur, du haut y_top jusqu'à une ondulation (tôle).
	func wave_band(y_top: float, y_mid: float, amp: float, period: float, color: Color) -> void:
		var pts: PackedVector2Array = PackedVector2Array([Vector2(0, y_top), Vector2(size.x, y_top)])
		var steps: int = maxi(2, int(size.x / (period / 4.0)))
		for i: int in range(steps, -1, -1):
			var x: float = size.x * i / steps
			pts.append(Vector2(x, y_mid + amp * cos(x / period * TAU)))
		poly(pts, color)

	## Rangée de lettres peintes (barres de largeurs variées).
	func letters(x: float, y: float, w: float, h: float, color: Color, max_count: int = 7) -> void:
		var cursor: float = x
		var count: int = 0
		while cursor < x + w - 3.0 and count < max_count:
			var lw: float = minf(rng.randf_range(h * 0.6, h * 1.8), x + w - cursor)
			box(cursor, y, lw, h, color)
			cursor += lw + (h * 0.9 if rng.randf() < 0.3 else h * 0.35)
			count += 1

	func _push(points: PackedVector2Array, color: Color) -> void:
		if points.size() < 3:
			return
		if Geometry2D.triangulate_polygon(points).is_empty():
			return
		shapes.append(PropShape.make(points, color))

	static func _dedupe(pts: PackedVector2Array) -> PackedVector2Array:
		var out: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.05:
				out.append(p)
		if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) <= 0.05:
			out.remove_at(out.size() - 1)
		return out


# --- Outils communs -----------------------------------------------------------

## Trous régulièrement espacés (pas `pitch`, largeur `hole_w`), centrés sur [xa, xb].
static func _spaced(xa: float, xb: float, pitch: float, hole_w: float) -> PackedVector2Array:
	var tooth: float = pitch - hole_w
	var n: int = int((xb - xa - tooth) / pitch)
	var holes: PackedVector2Array = PackedVector2Array()
	if n <= 0:
		return holes
	var start: float = xa + (xb - xa - (n * pitch - tooth)) * 0.5
	for i: int in n:
		var left: float = start + i * pitch
		holes.append(Vector2(left, left + hole_w))
	return holes


## Corps d'immeuble : corniche sur toute la largeur (le toit), façade en retrait.
static func _frame(pen: Pen, cornice: float, inset: float) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var c: float = minf(cornice, h * 0.5)
	var i: float = minf(inset, w * 0.06)
	pen.poly(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, c), Vector2(w - i, c + i),
			Vector2(w - i, h), Vector2(i, h), Vector2(i, c + i), Vector2(0, c)]), pen.ink)
	pen.box(0, c - 6.0, w, 2.0, pen.line)


## Zone de façade à détailler (locale).
static func _facade(pen: Pen, cornice: float, inset: float) -> Rect2:
	var i: float = minf(inset, pen.size.x * 0.06)
	var x0: float = i + 14.0
	var y0: float = cornice + 26.0
	var y1: float = minf(pen.size.y - 10.0, FACADE_DEPTH)
	return Rect2(x0, y0, maxf(0.0, pen.size.x - 2.0 * x0), maxf(0.0, y1 - y0))


## Rangées de fenêtres : vitres sombres découpées par des trumeaux d'encre,
## quelques-unes éclairées. Renvoie les rectangles des fenêtres.
static func _window_rows(pen: Pen, area: Rect2, bay: float, win_w: float, win_h: float,
		storey: float, lit: float, budget: int, arch: bool = false) -> Array[Rect2]:
	var windows: Array[Rect2] = []
	var holes: PackedVector2Array = _spaced(area.position.x, area.end.x, bay, win_w)
	if holes.is_empty():
		return windows
	var y: float = area.position.y
	var rows: int = 0
	var lit_budget: int = maxi(1, budget / 2)
	while y + win_h <= area.end.y and pen.shapes.size() < budget:
		pen.box(holes[0].x - 1.0, y, holes[holes.size() - 1].y - holes[0].x + 2.0, win_h, pen.shade)
		pen.perforated(area.position.x, area.end.x, y - 2.0, y, y + win_h, holes, pen.ink, arch)
		for hole: Vector2 in holes:
			var win: Rect2 = Rect2(hole.x, y, hole.y - hole.x, win_h)
			windows.append(win)
			if pen.rng.randf() < lit and lit_budget > 0:
				lit_budget -= 1
				var colour: Color = pen.glow if pen.rng.randf() < 0.7 else pen.glow_dim
				_lit_window(pen, win, colour, arch)
		y += storey
		rows += 1
	return windows


static func _lit_window(pen: Pen, win: Rect2, colour: Color, arch: bool) -> void:
	if not arch:
		pen.box(win.position.x, win.position.y, win.size.x, win.size.y, colour)
		# Rideau à moitié tiré : une silhouette de plus dans la lumière.
		if pen.rng.randf() < 0.4:
			pen.box(win.position.x, win.position.y, win.size.x * 0.35, win.size.y, pen.shade)
		return
	var r: float = win.size.x * 0.5
	var pts: PackedVector2Array = PackedVector2Array([Vector2(win.end.x, win.end.y), Vector2(win.end.x, win.position.y + r)])
	for k: int in range(1, 6):
		var a: float = PI * k / 6.0
		pts.append(Vector2(win.position.x + r + cos(a) * r, win.position.y + r - sin(a) * r))
	pts.append(Vector2(win.position.x, win.position.y + r))
	pts.append(Vector2(win.position.x, win.end.y))
	pen.poly(pts, colour)


## Climatiseur mural : caisson clair, face sombre, hélice.
static func _wall_ac(pen: Pen, x: float, y: float, w: float, h: float) -> void:
	pen.box(x, y, w, h, pen.line)
	pen.box(x + 2.0, y + 2.0, w - 4.0, h - 4.0, pen.ink)
	pen.disc(x + w * 0.66, y + h * 0.5, h * 0.3, pen.shade, 10)
	pen.box(x + 4.0, y + h * 0.35, w * 0.3, 1.5, pen.line)
	pen.box(x + 4.0, y + h * 0.6, w * 0.3, 1.5, pen.line)
	# Support en équerre.
	pen.bar(Vector2(x + 3.0, y + h), Vector2(x + 9.0, y + h + 6.0), 2.0, pen.line)


## Hélice de ventilateur vue de face : anneaux alternés.
static func _fan(pen: Pen, cx: float, cy: float, r: float) -> void:
	pen.disc(cx, cy, r, pen.line, 20)
	pen.disc(cx, cy, r - 2.0, pen.ink, 20)
	pen.disc(cx, cy, r * 0.66, pen.shade, 16)
	pen.disc(cx, cy, r * 0.66 - 2.0, pen.ink, 16)
	pen.bar(Vector2(cx - r * 0.6, cy - r * 0.2), Vector2(cx + r * 0.6, cy + r * 0.2), maxf(1.5, r * 0.12), pen.shade)
	pen.disc(cx, cy, maxf(1.5, r * 0.2), pen.line, 10)


## Parabole : coupelle claire et bras.
static func _dish(pen: Pen, x: float, y: float, r: float) -> void:
	pen.ellipse(x, y, r * 0.45, r, pen.line, 14)
	pen.ellipse(x + 1.5, y, r * 0.28, r * 0.8, pen.ink, 12)
	pen.bar(Vector2(x, y), Vector2(x + r * 1.1, y + r * 0.5), 2.0, pen.line)
	pen.box(x + r * 1.05, y + r * 0.35, 4.0, 4.0, pen.line)


## Tôle ondulée en bord de toit, juste sous la ligne de toit (toujours pleine).
static func _tin_eave(pen: Pen, y0: float, band: float) -> void:
	pen.box(0, y0, pen.size.x, band, pen.line)
	pen.wave_band(0, y0 + band * 0.55, band * 0.22, 10.0, pen.ink)


## Enseigne peinte à la main : fond peint, lettres, petit motif.
static func _painted_sign(pen: Pen, x: float, y: float, w: float, h: float) -> void:
	pen.box(x, y, w, h, pen.paint)
	pen.box(x, y + h - 5.0, w, 3.0, pen.glow)
	var icon: float = h * 0.32
	pen.disc(x + 6.0 + icon, y + h * 0.45, icon, pen.ink, 14)
	pen.disc(x + 6.0 + icon, y + h * 0.45, icon * 0.45, pen.glow, 10)
	var tx: float = x + 14.0 + icon * 2.0
	pen.letters(tx, y + h * 0.18, x + w - 6.0 - tx, h * 0.24, pen.ink, 5)
	pen.letters(tx, y + h * 0.56, (x + w - 6.0 - tx) * 0.7, h * 0.14, pen.ink, 4)


## Descente d'eau pluviale avec sa boîte à eau.
static func _drainpipe(pen: Pen, x: float, y0: float, y1: float) -> void:
	pen.box(x - 3.0, y0, 10.0, 7.0, pen.line)
	pen.box(x, y0 + 7.0, 4.0, y1 - y0 - 7.0, pen.line)


# --- Immeubles (le toit est le sol de course) --------------------------------

## Bureaux : bandeaux vitrés, enseigne lumineuse, climatiseurs.
static func _office(pen: Pen) -> void:
	var w: float = pen.size.x
	_frame(pen, 24.0, 6.0)
	pen.box(0, 8.0, w, 1.5, pen.line)
	var area: Rect2 = _facade(pen, 24.0, 6.0)
	if w >= 420.0:
		var sw: float = minf(w * 0.4, 260.0)
		var sx: float = area.position.x + pen.rng.randf() * maxf(0.0, area.size.x - sw)
		pen.letters(sx, area.position.y - 6.0, sw, 14.0, pen.glow, 7)
		area = Rect2(area.position.x, area.position.y + 22.0, area.size.x, area.size.y - 22.0)
	var wins: Array[Rect2] = _window_rows(pen, area, 92.0, 80.0, 46.0, 104.0, 0.12, BUILDING_BUDGET - 14)
	_drainpipe(pen, w - minf(6.0, w * 0.06) - 10.0, 24.0, area.end.y)
	_facade_acs(pen, wins, 2)


## Logements : fenêtres en grille, cordons, climatiseurs, parabole.
static func _apartments(pen: Pen) -> void:
	var w: float = pen.size.x
	_frame(pen, 18.0, 8.0)
	var area: Rect2 = _facade(pen, 18.0, 8.0)
	var wins: Array[Rect2] = _window_rows(pen, area, 100.0, 36.0, 54.0, STOREY, 0.2, BUILDING_BUDGET - 24)
	var y: float = area.position.y + 54.0 + 8.0
	while y < area.end.y and pen.shapes.size() < BUILDING_BUDGET - 20:
		pen.box(area.position.x - 6.0, y, area.size.x + 12.0, 3.0, pen.line)
		y += STOREY
	_drainpipe(pen, minf(8.0, w * 0.06) + 4.0, 18.0, area.end.y)
	_facade_acs(pen, wins, maxi(1, int(w / 260.0)))
	if pen.dishes and wins.size() > 2:
		var win: Rect2 = wins[pen.rng.randi() % mini(wins.size(), 6)]
		_dish(pen, win.end.x + 16.0, win.position.y + 16.0, 11.0)


## Entrepôt en brique : corniche à denticules, fenêtres cintrées, escalier de secours.
static func _warehouse(pen: Pen) -> void:
	var w: float = pen.size.x
	_frame(pen, 32.0, 10.0)
	pen.perforated(0, w, 18.0, 22.0, 30.0, _spaced(0, w, 12.0, 6.0), pen.line)
	var area: Rect2 = _facade(pen, 32.0, 10.0)
	var wins: Array[Rect2] = _window_rows(pen, area, 112.0, 40.0, 70.0, STOREY, 0.12, BUILDING_BUDGET - 24, true)
	if w >= 360.0 and not wins.is_empty():
		var x1: float = area.end.x - 10.0
		var x0: float = maxf(area.position.x, x1 - 190.0)
		var y: float = area.position.y + 70.0 + 12.0
		while y < area.end.y and pen.shapes.size() < BUILDING_BUDGET - 3:
			pen.box(x0, y, x1 - x0, 4.0, pen.line)
			pen.perforated(x0, x1, y - 24.0, y - 21.0, y, _spaced(x0, x1, 16.0, 13.0), pen.line)
			if y + STOREY < area.end.y:
				pen.bar(Vector2(x0 + 14.0, y + 2.0), Vector2(x1 - 14.0, y + STOREY), 4.0, pen.line)
			y += STOREY


static func _facade_acs(pen: Pen, wins: Array[Rect2], count: int) -> void:
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < 12 and wins.size() > 0 and pen.shapes.size() < BUILDING_BUDGET - 6:
		tries += 1
		var win: Rect2 = wins[pen.rng.randi() % wins.size()]
		if win.size.x < 28.0:
			# Fenêtre étroite : le climatiseur dépasse sur le trumeau.
			_wall_ac(pen, win.position.x - 2.0, win.end.y + 6.0, 34.0, 22.0)
		else:
			_wall_ac(pen, win.position.x + 6.0, win.end.y + 6.0, 32.0, 21.0)
		placed += 1


## Maison-boutique de Lomé : tôle ondulée, enseigne peinte, volets, balcon.
static func _lome_house(pen: Pen) -> void:
	var w: float = pen.size.x
	_frame(pen, 28.0, 6.0)
	_tin_eave(pen, 5.0, 15.0)
	var area: Rect2 = _facade(pen, 28.0, 6.0)
	var sw: float = clampf(area.size.x * 0.6, 100.0, 380.0)
	var sx: float = area.position.x + pen.rng.randf() * maxf(0.0, area.size.x - sw)
	_painted_sign(pen, sx, area.position.y - 6.0, minf(sw, area.size.x), 54.0)
	var y: float = area.position.y + 82.0
	var holes: PackedVector2Array = _spaced(area.position.x, area.end.x, 120.0, 58.0)
	var row: int = 0
	while y + 48.0 < area.end.y and not holes.is_empty() and pen.shapes.size() + holes.size() * 3 + 4 < BUILDING_BUDGET:
		for hole: Vector2 in holes:
			var cx: float = (hole.x + hole.y) * 0.5
			var lit: bool = pen.rng.randf() < 0.22
			pen.box(cx - 15.0, y, 30.0, 48.0, pen.glow if lit else pen.shade)
			if pen.rng.randf() < 0.75:
				# Volets persiennés ouverts de part et d'autre.
				pen.box(cx - 29.0, y, 12.0, 48.0, pen.line)
				pen.box(cx + 17.0, y, 12.0, 48.0, pen.line)
			else:
				pen.box(cx - 15.0, y, 30.0, 48.0, pen.line)
				pen.box(cx - 1.0, y, 2.0, 48.0, pen.ink)
		if row == 0:
			# Balcon : dalle et garde-corps ajouré.
			pen.perforated(area.position.x, area.end.x, y + 28.0, y + 31.0, y + 54.0,
					_spaced(area.position.x, area.end.x, 12.0, 8.0), pen.line)
			pen.box(area.position.x - 8.0, y + 54.0, area.size.x + 16.0, 6.0, pen.line)
		y += STOREY
		row += 1
	_drainpipe(pen, w - minf(6.0, w * 0.06) - 10.0, 28.0, area.end.y)


## Immeuble de Lomé : claustras en acrotère, balcons, bandeaux peints, paraboles.
static func _lome_balconies(pen: Pen) -> void:
	var w: float = pen.size.x
	_frame(pen, 22.0, 6.0)
	# Acrotère en claustra : trous sombres dans le parapet (sous la ligne de toit).
	pen.box(4.0, 7.0, w - 8.0, 9.0, pen.shade)
	pen.perforated(0, w, 0, 7.0, 16.0, _spaced(0, w, 14.0, 8.0), pen.ink)
	var area: Rect2 = _facade(pen, 22.0, 6.0)
	var wins: Array[Rect2] = _window_rows(pen, area, 110.0, 36.0, 52.0, STOREY, 0.22, BUILDING_BUDGET - 40)
	var y: float = area.position.y
	var dish_done: bool = not pen.dishes
	while y + 52.0 < area.end.y and pen.shapes.size() < BUILDING_BUDGET - 6:
		# Balcon sur une partie de la façade, garde-corps à barreaux.
		var bw: float = area.size.x * pen.rng.randf_range(0.4, 0.8)
		var bx: float = area.position.x + pen.rng.randf() * (area.size.x - bw)
		pen.perforated(bx, bx + bw, y + 30.0, y + 33.0, y + 58.0, _spaced(bx, bx + bw, 10.0, 6.0), pen.line)
		pen.box(bx - 6.0, y + 58.0, bw + 12.0, 6.0, pen.line)
		pen.box(area.position.x - 8.0, y + 82.0, area.size.x + 16.0, 4.0, pen.glow_dim)
		if not dish_done and bw > 80.0:
			_dish(pen, bx + 12.0, y + 18.0, 10.0)
			dish_done = true
		y += STOREY
	_facade_acs(pen, wins, 1)


## Façade de Lomé à grande publicité peinte, fenêtres à grilles.
static func _lome_mural(pen: Pen) -> void:
	var w: float = pen.size.x
	_frame(pen, 28.0, 6.0)
	_tin_eave(pen, 5.0, 15.0)
	var area: Rect2 = _facade(pen, 28.0, 6.0)
	var mw: float = clampf(area.size.x * 0.75, 90.0, 520.0)
	mw = minf(mw, area.size.x)
	var mx: float = area.position.x + pen.rng.randf() * (area.size.x - mw)
	var my: float = area.position.y - 8.0
	var mh: float = 112.0
	pen.box(mx, my, mw, mh, pen.paint)
	pen.box(mx, my + 6.0, mw, 4.0, pen.glow)
	pen.box(mx, my + mh - 10.0, mw, 4.0, pen.glow)
	# Bouteille peinte (boisson) et slogan.
	var bx: float = mx + 14.0
	pen.poly(PackedVector2Array([Vector2(bx + 8, my + 18), Vector2(bx + 16, my + 18), Vector2(bx + 16, my + 34),
			Vector2(bx + 24, my + 46), Vector2(bx + 24, my + mh - 16), Vector2(bx, my + mh - 16),
			Vector2(bx, my + 46), Vector2(bx + 8, my + 34)]), pen.ink)
	pen.box(bx + 3.0, my + 58.0, 18.0, 14.0, pen.glow)
	var tx: float = bx + 38.0
	if mx + mw - 10.0 - tx > 20.0:
		pen.letters(tx, my + 22.0, mx + mw - 10.0 - tx, 22.0, pen.ink, 5)
		pen.letters(tx, my + 56.0, (mx + mw - 10.0 - tx) * 0.8, 12.0, pen.ink, 5)
		pen.letters(tx, my + 76.0, (mx + mw - 10.0 - tx) * 0.5, 10.0, pen.glow, 3)
	var y: float = my + mh + 34.0
	var holes: PackedVector2Array = _spaced(area.position.x, area.end.x, 100.0, 40.0)
	while y + 50.0 < area.end.y and not holes.is_empty() and pen.shapes.size() + holes.size() * 3 + 4 < BUILDING_BUDGET:
		for hole: Vector2 in holes:
			var lit: bool = pen.rng.randf() < 0.2
			pen.box(hole.x, y, 40.0, 50.0, pen.glow if lit else pen.shade)
			# Grille en fer forgé : deux barreaux.
			pen.box(hole.x + 12.0, y, 2.5, 50.0, pen.ink if lit else pen.line)
			pen.box(hole.x + 26.0, y, 2.5, 50.0, pen.ink if lit else pen.line)
		y += STOREY
	_drainpipe(pen, minf(6.0, w * 0.06) + 4.0, 28.0, area.end.y)


# --- Piliers (étroits et hauts, le haut est praticable) ----------------------

## Cheminée en brique : chapeau débordant, assises de brique.
static func _brick_chimney(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.poly(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 16), Vector2(w - 3, 20),
			Vector2(w - 3, 26), Vector2(w - 5, 28), Vector2(w - 5, h), Vector2(5, h), Vector2(5, 28),
			Vector2(3, 26), Vector2(3, 20), Vector2(0, 16)]), pen.ink)
	pen.box(0, 11.0, w, 2.0, pen.line)
	pen.box(3.0, 22.0, w - 6.0, 1.5, pen.line)
	var y: float = 40.0
	var row: int = 0
	while y < minf(h, 420.0) and pen.shapes.size() < 34:
		pen.box(5.0, y, w - 10.0, 1.5, pen.shade)
		# Joints verticaux décalés d'une assise sur l'autre.
		var jx: float = 5.0 + (w - 10.0) * (0.33 if row % 2 == 0 else 0.66)
		pen.box(jx, y - 11.0, 1.5, 11.0, pen.shade)
		y += 13.0
		row += 1


## Poteau de béton : dalle en tête, banches, armatures à nu là où le béton a éclaté.
static func _concrete_column(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.poly(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 14), Vector2(w - 4, 18),
			Vector2(w - 4, h), Vector2(4, h), Vector2(4, 18), Vector2(0, 14)]), pen.ink)
	pen.box(0, 10.0, w, 1.5, pen.line)
	var y: float = 140.0
	while y < minf(h, 700.0):
		pen.box(4.0, y, w - 8.0, 2.0, pen.shade)
		pen.disc(w * 0.3, y + 26.0, 2.5, pen.shade, 8)
		pen.disc(w * 0.7, y + 26.0, 2.5, pen.shade, 8)
		y += 120.0
	# Éclat de béton : armatures visibles.
	var sy: float = 44.0 + pen.rng.randf() * 30.0
	pen.poly(PackedVector2Array([Vector2(w * 0.2, sy), Vector2(w * 0.55, sy - 6), Vector2(w * 0.8, sy + 4),
			Vector2(w * 0.72, sy + 40), Vector2(w * 0.4, sy + 46), Vector2(w * 0.24, sy + 30)]), pen.shade)
	for k: int in 3:
		var rx: float = w * (0.32 + 0.16 * k)
		pen.box(rx, sy - 3.0, 2.5, 44.0, pen.line)
	pen.box(w * 0.26, sy + 18.0, w * 0.44, 2.0, pen.line)
	if pen.lome:
		# Numéro peint à la main.
		pen.box(w * 0.3, 210.0, w * 0.4, 16.0, pen.paint)
		pen.letters(w * 0.34, 214.0, w * 0.32, 8.0, pen.ink, 3)


## Gaine de ventilation métallique : chapeau, anneaux, échelle.
static func _vent_stack(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.poly(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 10), Vector2(w - 6, 18),
			Vector2(w - 6, h), Vector2(6, h), Vector2(6, 18), Vector2(0, 10)]), pen.ink)
	pen.box(0, 6.0, w, 1.5, pen.line)
	var y: float = 46.0
	while y < minf(h, 600.0):
		pen.box(4.0, y, w - 8.0, 5.0, pen.line)
		pen.box(4.0, y + 5.0, w - 8.0, 1.5, pen.shade)
		y += 70.0
	# Échelle à crinoline : montants et barreaux.
	var lx: float = w * 0.5 - 10.0
	pen.box(lx, 24.0, 2.5, 420.0, pen.line)
	pen.box(lx + 18.0, 24.0, 2.5, 420.0, pen.line)
	var r: float = 34.0
	while r < 440.0 and pen.shapes.size() < 38:
		pen.box(lx, r, 20.0, 2.0, pen.line)
		r += 22.0


## Poteau électrique de Lomé : traverse, isolateurs, câbles, plaque peinte.
static func _power_pole(pen: Pen, transformer: bool) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var top_w: float = w * 0.74
	var tx: float = (w - top_w) * 0.5
	pen.poly(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 10), Vector2(tx + top_w, 30),
			Vector2(w, h), Vector2(0, h), Vector2(tx, 30), Vector2(0, 10)]), pen.ink)
	pen.box(0, 4.0, w, 1.5, pen.line)
	# Isolateurs suspendus sous la traverse.
	for ix: float in [7.0, w - 7.0]:
		pen.disc(ix, 14.0, 3.5, pen.line, 8)
		pen.disc(ix, 20.0, 3.0, pen.line, 8)
	# Câbles qui descendent le long du poteau.
	pen.bar(Vector2(w * 0.35, 30.0), Vector2(w * 0.3, 260.0), 2.5, pen.line)
	pen.bar(Vector2(w * 0.62, 30.0), Vector2(w * 0.68, 180.0), 2.0, pen.shade)
	# Marches de fer alternées.
	var y: float = 140.0
	var side: int = 0
	while y < minf(h, 560.0):
		var sx: float = 6.0 if side == 0 else w - 16.0
		pen.box(sx, y, 10.0, 3.0, pen.line)
		y += 34.0
		side = 1 - side
	if transformer:
		# Transformateur : cuve, ailettes, fusibles.
		var cy: float = 48.0
		pen.round_box(w * 0.14, cy, w * 0.72, 70.0, 6.0, pen.line)
		pen.round_box(w * 0.14 + 3.0, cy + 3.0, w * 0.72 - 6.0, 64.0, 4.0, pen.ink)
		for k: int in 4:
			pen.box(w * 0.22 + k * w * 0.15, cy + 14.0, 3.0, 44.0, pen.shade)
		pen.box(w * 0.36, cy - 6.0, 4.0, 6.0, pen.glow)
		pen.box(w * 0.6, cy - 6.0, 4.0, 6.0, pen.glow)
	else:
		# Compteur dans son coffret.
		pen.box(w * 0.28, 74.0, w * 0.44, 40.0, pen.line)
		pen.box(w * 0.28 + 3.0, 77.0, w * 0.44 - 6.0, 34.0, pen.ink)
		pen.disc(w * 0.5, 90.0, 6.0, pen.glow_dim, 10)
	pen.box(w * 0.3, 300.0, w * 0.4, 18.0, pen.paint)
	pen.letters(w * 0.34, 305.0, w * 0.32, 8.0, pen.ink, 3)


# --- Petits obstacles posés sur le toit (on les franchit d'un saut) ----------

## Climatiseur de toiture : caisson, grille d'hélice, ouïes, pieds.
static func _ac_unit(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var body: float = h - 3.0
	pen.box(0, 0, w, body, pen.ink)
	pen.box(3.0, body, 9.0, 3.0, pen.ink)
	pen.box(w - 12.0, body, 9.0, 3.0, pen.ink)
	pen.box(0, 3.5, w, 1.5, pen.line)
	var r: float = body * 0.5 - 5.0
	var cx: float = w - r - 7.0
	_fan(pen, cx, body * 0.5 + 1.5, r)
	var slat_w: float = cx - r - 13.0
	for i: int in 3:
		pen.box(6.0, 10.0 + i * (body - 18.0) * 0.5, slat_w, 2.0, pen.line)


## Caisses de bois empilées.
static func _crates(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	var split: float = w * pen.rng.randf_range(0.42, 0.58)
	for c: Vector2 in [Vector2(0, split), Vector2(split, w)]:
		var x0: float = c.x + 2.0
		var cw: float = c.y - c.x - 4.0
		pen.box(x0, 3.0, cw, h - 5.0, pen.line)
		pen.box(x0 + 3.0, 6.0, cw - 6.0, h - 11.0, pen.ink)
		pen.bar(Vector2(x0 + 4.0, h - 6.0), Vector2(x0 + cw - 4.0, 7.0), 3.0, pen.line)
		pen.box(x0 + 3.0, h * 0.5 - 1.0, cw - 6.0, 1.5, pen.shade)


## Bouche d'aération à chapeau, ouïes.
static func _roof_vent(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.poly(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 8), Vector2(w - 5, 12),
			Vector2(5, 12), Vector2(0, 8)]), pen.ink)
	pen.box(5.0, 12.0, w - 10.0, h - 16.0, pen.ink)
	pen.box(2.0, h - 4.0, w - 4.0, 4.0, pen.ink)
	pen.box(1.0, 4.0, w - 2.0, 1.5, pen.line)
	var y: float = 16.0
	while y < h - 8.0:
		pen.box(10.0, y, w - 20.0, 2.5, pen.line)
		y += 6.0
	pen.box(w - 18.0, 14.0, 4.0, 4.0, pen.glow_dim)


## Étal de marché : plateau, pagne wax tombant, bassines dessous.
static func _market_stall(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	pen.box(0, 4.0, w, 2.0, pen.line)
	var hem: float = h * 0.55
	var cloth: PackedVector2Array = PackedVector2Array([Vector2(4, 7), Vector2(w - 4, 7)])
	var n: int = maxi(2, int((w - 8.0) / 9.0))
	for i: int in range(n, -1, -1):
		var x: float = 4.0 + (w - 8.0) * i / n
		cloth.append(Vector2(x, hem + (4.0 if i % 2 == 0 else 0.0)))
	pen.poly(cloth, pen.paint)
	# Motif wax : losanges et pastilles.
	var k: int = 0
	var x: float = 12.0
	while x < w - 10.0:
		if k % 2 == 0:
			pen.poly(PackedVector2Array([Vector2(x, 10), Vector2(x + 5, 15), Vector2(x, 20), Vector2(x - 5, 15)]), pen.ink)
		else:
			pen.disc(x, 15.0, 3.0, pen.glow, 8)
		x += 14.0
		k += 1
	# Pieds et bassines rangées sous la table.
	pen.box(4.0, hem, 3.0, h - hem, pen.line)
	pen.box(w - 7.0, hem, 3.0, h - hem, pen.line)
	pen.ellipse(w * 0.36, h - 6.0, w * 0.17, 3.5, pen.line, 12)
	pen.ellipse(w * 0.36, h - 5.0, w * 0.17 - 2.0, 2.0, pen.ink, 12)
	pen.round_box(w * 0.6, hem + 6.0, w * 0.22, h - hem - 7.0, 3.0, pen.shade)


## Bidons jaunes (« bidons d'essence ») serrés les uns contre les autres.
static func _jerrycans(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	var n: int = 2 if w < 80.0 else 3
	var cw: float = w / n
	for i: int in n:
		var x: float = i * cw
		if i > 0:
			pen.box(x - 1.0, 3.0, 2.0, h - 3.0, pen.shade)
		pen.round_box(x + cw * 0.38, 4.0, cw * 0.42, 6.0, 2.5, pen.line)
		pen.box(x + 4.0, 3.0, 5.0, 4.0, pen.glow)
		pen.bar(Vector2(x + 6.0, 15.0), Vector2(x + cw - 6.0, h - 5.0), 2.0, pen.shade)
		pen.bar(Vector2(x + cw - 6.0, 15.0), Vector2(x + 6.0, h - 5.0), 2.0, pen.shade)
		pen.box(x + 4.0, h * 0.45, cw - 8.0, 5.0, pen.glow_dim)


## Pile de pneus usagés.
static func _tyres(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var n: int = 3
	var th: float = h / n
	for i: int in n:
		var y: float = i * th
		var r: float = 4.0 if i == 0 else th * 0.42
		pen.round_box(0, y, w, th + 0.6, r, pen.ink)
	for i: int in n:
		var y: float = i * th
		# Bande de roulement en chevrons.
		var tread: PackedVector2Array = PackedVector2Array()
		var steps: int = maxi(2, int((w - 16.0) / 6.0))
		for s: int in steps + 1:
			tread.append(Vector2(8.0 + (w - 16.0) * s / steps, y + th * 0.5 + (-2.0 if s % 2 == 0 else 2.0)))
		for s: int in range(steps, -1, -1):
			tread.append(Vector2(8.0 + (w - 16.0) * s / steps, y + th * 0.5 + 2.0 + (-2.0 if s % 2 == 0 else 2.0)))
		pen.poly(tread, pen.shade)
		if i > 0:
			pen.box(th * 0.3, y - 0.5, w - th * 0.6, 1.5, pen.line)
	pen.box(w * 0.2, 3.0, w * 0.6, 1.5, pen.line)


## Zémidjan (moto-taxi) garé contre un muret de parpaings.
static func _zemidjan(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	pen.box(0, 3.0, w, 1.5, pen.shade)
	pen.box(0, h * 0.5, w, 1.0, pen.shade)
	var r: float = minf(h * 0.24, w * 0.12)
	var by: float = h - r - 1.0
	var rear: Vector2 = Vector2(r + 3.0, by)
	var front: Vector2 = Vector2(w - r - 3.0, by)
	for c: Vector2 in [rear, front]:
		pen.disc(c.x, c.y, r, pen.line, 16)
		pen.disc(c.x, c.y, r - 2.5, pen.ink, 16)
		pen.disc(c.x, c.y, 2.0, pen.line, 8)
	var seat_y: float = by - r - 6.0
	# Cadre, réservoir, selle, fourche, guidon, phare.
	pen.bar(rear, Vector2(w * 0.5, by - 2.0), 3.0, pen.line)
	pen.poly(PackedVector2Array([Vector2(w * 0.38, seat_y + 6), Vector2(w * 0.62, seat_y + 2),
			Vector2(w * 0.66, by - 2), Vector2(w * 0.42, by - 2)]), pen.line)
	pen.round_box(w * 0.12, seat_y, w * 0.32, 5.0, 2.5, pen.line)
	pen.bar(Vector2(front.x, front.y), Vector2(w * 0.72, 7.0), 3.0, pen.line)
	pen.bar(Vector2(w * 0.66, 7.0), Vector2(w * 0.78, 5.0), 2.5, pen.line)
	pen.disc(w * 0.79, 13.0, 3.0, pen.glow, 8)
	pen.bar(Vector2(rear.x + 2.0, by + 2.0), Vector2(w * 0.4, by + 3.0), 2.0, pen.shade)


# --- Obstacles étroits et hauts posés sur le toit -----------------------------

## Réservoir d'eau sur pieds (cuve en polyéthylène à Lomé, en bois cerclé sinon).
static func _water_tank(pen: Pen, poly_tank: bool) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var th: float = h * 0.64
	if poly_tank:
		pen.round_box(0, 0, w, th + 4.0, 7.0, pen.ink)
	else:
		pen.box(0, 0, w, th, pen.ink)
	pen.box(0, th - 2.0, w, 10.0, pen.ink)
	var leg: float = 14.0
	pen.box(4.0, th + 8.0, leg, h - th - 8.0, pen.ink)
	pen.box(w - 4.0 - leg, th + 8.0, leg, h - th - 8.0, pen.ink)
	pen.bar(Vector2(4.0 + leg, th + 10.0), Vector2(w - 4.0 - leg, h - 8.0), 5.0, pen.ink)
	pen.bar(Vector2(w - 4.0 - leg, th + 10.0), Vector2(4.0 + leg, h - 8.0), 5.0, pen.ink)
	pen.box(0, h - 5.0, 22.0, 5.0, pen.ink)
	pen.box(w - 22.0, h - 5.0, 22.0, 5.0, pen.ink)
	if poly_tank:
		# Cuve moulée : nervures horizontales, couvercle.
		var y: float = 22.0
		while y < th - 8.0:
			pen.box(3.0, y, w - 6.0, 3.0, pen.line)
			y += 22.0
		pen.box(w * 0.3, 5.0, w * 0.4, 3.0, pen.shade)
		# Tuyau qui descend.
		pen.box(w - 26.0, th + 8.0, 4.0, h - th - 14.0, pen.line)
	else:
		# Cuve en douelles cerclées et son échelle.
		for k: int in 4:
			pen.box(0, 14.0 + k * (th - 24.0) / 3.0, w, 3.0, pen.line)
		for k: int in 3:
			pen.box(w * (0.25 + 0.25 * k), 6.0, 1.5, th - 10.0, pen.shade)
		pen.box(w * 0.12, 4.0, 2.5, h - 10.0, pen.line)
		pen.box(w * 0.12 + 12.0, 4.0, 2.5, h - 10.0, pen.line)
		var r: float = 14.0
		while r < h - 10.0:
			pen.box(w * 0.12, r, 14.0, 2.0, pen.line)
			r += 18.0
	pen.box(4.0, th + 2.0, w - 8.0, 2.0, pen.line)


## Cage d'escalier : dalle débordante, porte, lampe, grille de ventilation.
static func _stair_housing(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.poly(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 10), Vector2(w - 4, 14),
			Vector2(w - 4, h), Vector2(4, h), Vector2(4, 14), Vector2(0, 10)]), pen.ink)
	if pen.lome:
		_tin_eave(pen, 3.0, 9.0)
	else:
		pen.box(0, 5.0, w, 1.5, pen.line)
	var dh: float = minf(h - 40.0, 104.0)
	var dw: float = minf(w - 26.0, 52.0)
	var dx: float = (w - dw) * 0.5
	pen.box(dx - 3.0, h - dh - 3.0, dw + 6.0, dh + 3.0, pen.line)
	pen.box(dx, h - dh, dw, dh, pen.shade)
	if pen.lome:
		# Rideau de porte en tissu.
		var cur: PackedVector2Array = PackedVector2Array([Vector2(dx, h - dh), Vector2(dx + dw, h - dh)])
		for k: int in range(6, -1, -1):
			cur.append(Vector2(dx + dw * k / 6.0, h - dh * 0.35 + (4.0 if k % 2 == 0 else 0.0)))
		pen.poly(cur, pen.paint)
	else:
		pen.box(dx + dw - 9.0, h - dh * 0.5, 4.0, 3.0, pen.line)
		pen.box(dx + 4.0, h - dh + 6.0, dw - 8.0, 2.0, pen.ink)
	# Lampe au-dessus de la porte.
	pen.box(w * 0.5 - 6.0, h - dh - 14.0, 12.0, 4.0, pen.line)
	pen.disc(w * 0.5, h - dh - 8.0, 3.5, pen.glow, 10)
	# Grille de ventilation.
	var gy: float = 28.0
	if h - dh - 30.0 > gy + 28.0:
		pen.box(w * 0.25, gy, w * 0.5, 26.0, pen.line)
		pen.box(w * 0.25 + 2.0, gy + 2.0, w * 0.5 - 4.0, 22.0, pen.ink)
		for k: int in 4:
			pen.box(w * 0.25 + 3.0, gy + 4.0 + k * 5.5, w * 0.5 - 6.0, 2.0, pen.line)


## Mur de brique avec canalisations.
static func _brick_wall(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	pen.box(0, 4.0, w, 2.0, pen.line)
	var y: float = 18.0
	var row: int = 0
	while y < h - 4.0 and pen.shapes.size() < 24:
		pen.box(0, y, w, 1.5, pen.shade)
		pen.box(w * (0.3 if row % 2 == 0 else 0.62), y - 11.0, 1.5, 11.0, pen.shade)
		y += 13.0
		row += 1
	# Conduite en col de cygne, brides et vanne.
	var px: float = w * 0.7
	pen.box(px, 26.0, 7.0, h - 26.0, pen.line)
	pen.box(w * 0.18, 26.0, px - w * 0.18 + 7.0, 7.0, pen.line)
	pen.box(w * 0.18, 26.0, 7.0, 34.0, pen.line)
	for fy: float in [70.0, h * 0.5, h - 30.0]:
		pen.box(px - 3.0, fy, 13.0, 5.0, pen.line)
	pen.disc(px + 3.5, h * 0.66, 7.0, pen.glow_dim, 10)
	pen.box(px - 5.0, h * 0.66 - 1.5, 17.0, 3.0, pen.ink)


## Panneau d'affichage sur gros châssis.
static func _billboard_wall(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var fh: float = h * 0.56
	pen.box(0, 0, w, fh, pen.ink)
	pen.box(0, fh, w, 6.0, pen.ink)
	var leg: float = 16.0
	pen.box(8.0, fh, leg, h - fh, pen.ink)
	pen.box(w - 8.0 - leg, fh, leg, h - fh, pen.ink)
	pen.bar(Vector2(8.0 + leg, fh + 6.0), Vector2(w - 8.0 - leg, h - 6.0), 6.0, pen.ink)
	pen.bar(Vector2(w - 8.0 - leg, fh + 6.0), Vector2(8.0 + leg, h - 6.0), 6.0, pen.ink)
	pen.box(0, h - 6.0, w, 6.0, pen.ink)
	# Affiche : fond chaud, grand disque, slogan.
	pen.box(6.0, 8.0, w - 12.0, fh - 16.0, pen.glow_dim)
	pen.disc(w * 0.62, fh * 0.42, minf(w, fh) * 0.24, pen.glow, 18)
	pen.poly(PackedVector2Array([Vector2(6, fh - 8), Vector2(6, fh * 0.55), Vector2(w - 6, fh * 0.3),
			Vector2(w - 6, fh * 0.42), Vector2(w * 0.35, fh - 8)]), pen.ink)
	pen.letters(12.0, 16.0, w * 0.4, 9.0, pen.ink, 3)
	# Projecteurs et passerelle.
	pen.box(0, fh + 1.0, w, 2.0, pen.line)
	pen.bar(Vector2(w * 0.3, fh + 3.0), Vector2(w * 0.3, fh - 10.0), 2.0, pen.line)
	pen.disc(w * 0.3, fh - 12.0, 3.0, pen.glow, 8)


## Mur peint de Lomé : grande réclame peinte à la main.
static func _painted_wall(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	pen.box(0, 4.0, w, 3.0, pen.line)
	var py: float = 18.0
	var ph: float = h * 0.58
	pen.box(5.0, py, w - 10.0, ph, pen.paint)
	pen.box(5.0, py + 4.0, w - 10.0, 3.0, pen.glow)
	# Téléphone portable peint (recharge de crédit) et lettres.
	pen.round_box(w * 0.5 - 13.0, py + 18.0, 26.0, 46.0, 4.0, pen.ink)
	pen.box(w * 0.5 - 9.0, py + 24.0, 18.0, 26.0, pen.glow)
	pen.letters(12.0, py + 74.0, w - 24.0, 12.0, pen.ink, 4)
	pen.letters(12.0, py + 92.0, w - 34.0, 8.0, pen.ink, 4)
	pen.box(5.0, py + ph - 8.0, w - 10.0, 3.0, pen.glow)
	# Coulures de peinture et enduit écaillé.
	pen.box(w * 0.3, py + ph, 3.0, 12.0, pen.paint)
	pen.box(w * 0.72, py + ph, 3.0, 7.0, pen.paint)
	pen.poly(PackedVector2Array([Vector2(w * 0.15, h - 34), Vector2(w * 0.5, h - 40), Vector2(w * 0.62, h - 22),
			Vector2(w * 0.3, h - 14)]), pen.shade)


## Mur de parpaings avec panneau de claustras.
static func _claustra_wall(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	pen.box(0, 4.0, w, 3.0, pen.line)
	var y: float = 22.0
	var row: int = 0
	while y < h - 4.0:
		pen.box(0, y, w, 1.5, pen.shade)
		pen.box(w * (0.5 if row % 2 == 0 else 0.25), y - 18.0, 1.5, 18.0, pen.shade)
		y += 20.0
		row += 1
	# Claustras : quatre rangées d'ajours en losange.
	var cy: float = 40.0
	var cells: int = 3
	var cw: float = (w - 24.0) / cells
	for r: int in 4:
		for c: int in cells:
			var cx: float = 12.0 + cw * (c + 0.5)
			var my: float = cy + r * cw + cw * 0.5
			var s: float = cw * 0.4
			pen.poly(PackedVector2Array([Vector2(cx, my - s), Vector2(cx + s, my), Vector2(cx, my + s), Vector2(cx - s, my)]),
					pen.glow_dim if (r + c) % 5 == 0 else pen.shade)


# --- Volumes larges posés sur le toit ----------------------------------------

## Local technique : dalle débordante, porte, ouïes, lampe, conduites.
static func _roof_shed(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.poly(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 10), Vector2(w - 8, 14),
			Vector2(w - 8, h), Vector2(8, h), Vector2(8, 14), Vector2(0, 10)]), pen.ink)
	pen.box(0, 5.0, w, 1.5, pen.line)
	var dh: float = minf(h - 22.0, 100.0)
	var dx: float = w * 0.18
	pen.box(dx - 3.0, h - dh - 3.0, 50.0, dh + 3.0, pen.line)
	pen.box(dx, h - dh, 44.0, dh, pen.shade)
	pen.box(dx + 36.0, h - dh * 0.5, 4.0, 3.0, pen.line)
	pen.disc(dx + 22.0, h - dh - 12.0, 4.0, pen.glow, 10)
	# Ouïes de ventilation.
	var lx: float = w * 0.5
	var ly: float = 26.0
	var lh: float = minf(40.0, h - 44.0)
	pen.box(lx, ly, 70.0, lh, pen.line)
	pen.box(lx + 2.0, ly + 2.0, 66.0, lh - 4.0, pen.ink)
	var s: float = ly + 6.0
	while s < ly + lh - 4.0:
		pen.box(lx + 4.0, s, 62.0, 2.0, pen.line)
		s += 6.0
	# Conduites qui longent le mur.
	pen.box(w * 0.5 + 80.0, 30.0, maxf(0.0, w - 8.0 - (w * 0.5 + 80.0)), 6.0, pen.line)
	pen.box(w * 0.5 + 80.0, 30.0, 6.0, h - 30.0, pen.line)
	if pen.dishes:
		_dish(pen, w - 40.0, 40.0, 12.0)


## Conteneur maritime : cannelures, pièces de coin, barres de verrouillage.
static func _container(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	var door: bool = w >= 360.0
	var x1: float = w - (w * 0.22 if door else 8.0)
	pen.perforated(8.0, x1, 4.0, 9.0, h - 9.0, _spaced(8.0, x1, 18.0, 12.0), pen.line)
	pen.box(8.0, h - 9.0, x1 - 8.0, 3.0, pen.line)
	for c: Vector2 in [Vector2(1, 4), Vector2(w - 7, 4), Vector2(1, h - 9), Vector2(w - 7, h - 9)]:
		pen.box(c.x, c.y, 6.0, 5.0, pen.line)
	if door:
		var dx: float = x1 + 8.0
		var dw: float = w - 8.0 - dx
		pen.box(dx, 8.0, dw, h - 16.0, pen.shade)
		pen.box(dx + dw * 0.5 - 1.0, 8.0, 2.0, h - 16.0, pen.ink)
		for k: int in 4:
			var bx: float = dx + dw * (0.12 + 0.24 * k)
			pen.box(bx, 10.0, 3.0, h - 20.0, pen.line)
			pen.box(bx - 2.0, h * 0.55, 7.0, 4.0, pen.line)
	# Marquage du propriétaire.
	pen.box(18.0, 14.0, 4.0, 4.0, pen.glow_dim)
	pen.letters(26.0, 14.0, minf(110.0, x1 - 40.0), 6.0, pen.glow_dim, 4)


## Groupe froid : caisson, grandes hélices, ouïes.
static func _cooling_unit(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h - 6.0, pen.ink)
	pen.box(0, h - 6.0, 14.0, 6.0, pen.ink)
	pen.box(w * 0.5 - 7.0, h - 6.0, 14.0, 6.0, pen.ink)
	pen.box(w - 14.0, h - 6.0, 14.0, 6.0, pen.ink)
	pen.box(0, 4.0, w, 2.0, pen.line)
	var fans: int = clampi(int(w / 150.0), 1, 3)
	var r: float = minf((h - 6.0) * 0.32, 44.0)
	var cy: float = 10.0 + r + 6.0
	var pitch: float = w / fans
	for i: int in fans:
		_fan(pen, pitch * (i + 0.5), cy, r)
	var ly: float = cy + r + 10.0
	var y: float = ly
	while y < h - 14.0:
		pen.box(10.0, y, w - 20.0, 2.5, pen.line)
		y += 7.0
	pen.box(w - 40.0, 12.0, 6.0, 6.0, pen.glow)


## Abri en tôle de Lomé : toit ondulé débordant, porte à rideau, volet, enseigne.
static func _tin_shed(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.poly(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 16), Vector2(w - 10, 20),
			Vector2(w - 10, h), Vector2(10, h), Vector2(10, 20), Vector2(0, 16)]), pen.ink)
	_tin_eave(pen, 4.0, 12.0)
	var dh: float = minf(h - 26.0, 96.0)
	var dx: float = w * 0.12
	pen.box(dx, h - dh, 46.0, dh, pen.shade)
	var cur: PackedVector2Array = PackedVector2Array([Vector2(dx, h - dh), Vector2(dx + 46.0, h - dh)])
	for k: int in range(6, -1, -1):
		cur.append(Vector2(dx + 46.0 * k / 6.0, h - dh * 0.3 + (4.0 if k % 2 == 0 else 0.0)))
	pen.poly(cur, pen.paint)
	# Fenêtre à volets.
	var wx: float = dx + 80.0
	if wx + 60.0 < w - 20.0 and h > 80.0:
		pen.box(wx + 14.0, 34.0, 30.0, 34.0, pen.glow if pen.rng.randf() < 0.5 else pen.shade)
		pen.box(wx, 34.0, 13.0, 34.0, pen.line)
		pen.box(wx + 45.0, 34.0, 13.0, 34.0, pen.line)
	# Enseigne peinte.
	var sw: float = minf(w * 0.4, 170.0)
	var sx: float = w - 18.0 - sw
	if sx > wx + 66.0:
		_painted_sign(pen, sx, 30.0, sw, minf(46.0, h - 40.0))
	if pen.dishes and w > 200.0:
		_dish(pen, w - 34.0, h - 30.0, 10.0)


## Conteneur-boutique de Lomé : bandeau peint, guichet, marchandises.
static func _kiosk(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	pen.box(0, 5.0, w, 18.0, pen.paint)
	pen.letters(10.0, 9.0, w * 0.55, 10.0, pen.ink, 6)
	pen.disc(w - 20.0, 14.0, 6.0, pen.glow, 10)
	# Cannelures sur la partie pleine.
	var gx0: float = w * 0.62
	pen.perforated(gx0, w - 6.0, 26.0, 30.0, h - 8.0, _spaced(gx0, w - 6.0, 16.0, 10.0), pen.line)
	# Guichet ouvert, étagères garnies, volet relevé.
	var gx: float = 14.0
	var gw: float = gx0 - 28.0
	var gy: float = 40.0
	var gh: float = minf(h - gy - 26.0, 70.0)
	pen.poly(PackedVector2Array([Vector2(gx - 6, gy - 4), Vector2(gx + gw + 6, gy - 4), Vector2(gx + gw + 12, gy - 12),
			Vector2(gx - 12, gy - 12)]), pen.line)
	pen.box(gx, gy, gw, gh, pen.glow_dim)
	var shelf: float = gy + gh * 0.45
	pen.box(gx, shelf, gw, 2.5, pen.ink)
	var x: float = gx + 6.0
	while x < gx + gw - 12.0 and pen.shapes.size() < 34:
		var bh: float = pen.rng.randf_range(8.0, 14.0)
		pen.box(x, shelf - bh, 7.0, bh, pen.ink)
		pen.box(x + 1.0, gy + gh - bh * 0.8, 9.0, bh * 0.8, pen.ink)
		x += pen.rng.randf_range(11.0, 18.0)
	pen.box(gx - 4.0, gy + gh, gw + 8.0, 5.0, pen.line)


## Cage d'escalier en béton de Lomé : claustras, porte, numéro peint, cuve.
static func _stair_room(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.poly(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 12), Vector2(w - 6, 16),
			Vector2(w - 6, h), Vector2(6, h), Vector2(6, 16), Vector2(0, 12)]), pen.ink)
	pen.box(0, 6.0, w, 2.0, pen.line)
	# Bandeau de claustras sur la cage.
	var cx0: float = w * 0.45
	var cx1: float = w - 20.0
	pen.box(cx0, 28.0, cx1 - cx0, 20.0, pen.shade)
	pen.perforated(cx0 - 2.0, cx1 + 2.0, 26.0, 28.0, 48.0, _spaced(cx0, cx1, 16.0, 10.0), pen.ink)
	var dh: float = minf(h - 30.0, 100.0)
	var dx: float = w * 0.15
	pen.box(dx - 3.0, h - dh - 3.0, 52.0, dh + 3.0, pen.line)
	pen.box(dx, h - dh, 46.0, dh, pen.shade)
	pen.box(dx + 38.0, h - dh * 0.5, 4.0, 3.0, pen.line)
	pen.disc(dx + 23.0, h - dh - 12.0, 4.0, pen.glow, 10)
	pen.box(cx0, 60.0, 34.0, 18.0, pen.paint)
	pen.letters(cx0 + 4.0, 64.0, 26.0, 9.0, pen.ink, 2)
	# Fil à linge tendu le long du mur.
	if h > 110.0:
		var ly: float = 92.0
		pen.box(cx0 + 40.0, ly, cx1 - cx0 - 40.0, 1.5, pen.line)
		var x: float = cx0 + 48.0
		var k: int = 0
		while x < cx1 - 16.0 and k < 4:
			pen.box(x, ly + 1.0, 12.0, 16.0, pen.paint if k % 2 == 0 else pen.glow_dim)
			x += 20.0
			k += 1


# --- Blocs suspendus (on glisse dessous : le bas reste droit) ----------------

## Grand panneau suspendu : poutre, haubans, cadre, affiche éclairée.
static func _hanging_billboard(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var top: float = 46.0
	pen.box(0, 0, w, 10.0, pen.ink)
	pen.bar(Vector2(w * 0.18, 10.0), Vector2(w * 0.18, top), 3.0, pen.ink)
	pen.bar(Vector2(w * 0.82, 10.0), Vector2(w * 0.82, top), 3.0, pen.ink)
	pen.bar(Vector2(w * 0.32, 10.0), Vector2(w * 0.08, top), 2.0, pen.ink)
	pen.bar(Vector2(w * 0.68, 10.0), Vector2(w * 0.92, top), 2.0, pen.ink)
	pen.box(0, top, w, h - top, pen.ink)
	# Affiche : fond chaud, soleil, bande sombre, slogan.
	var fx: float = 12.0
	var fy: float = top + 12.0
	var fw: float = w - 24.0
	var fh: float = h - top - 34.0
	pen.box(fx, fy, fw, fh, pen.glow_dim)
	pen.disc(fx + fw * 0.7, fy + fh * 0.36, minf(fw, fh) * 0.22, pen.glow, 22)
	pen.poly(PackedVector2Array([Vector2(fx, fy + fh * 0.62), Vector2(fx + fw, fy + fh * 0.48),
			Vector2(fx + fw, fy + fh), Vector2(fx, fy + fh)]), pen.ink)
	pen.letters(fx + 12.0, fy + 18.0, fw * 0.45, 16.0, pen.ink, 4)
	pen.letters(fx + 12.0, fy + 44.0, fw * 0.35, 9.0, pen.ink, 4)
	pen.letters(fx + 12.0, fy + fh * 0.8, fw * 0.6, 12.0, pen.glow, 5)
	# Projecteurs sur le cadre.
	for k: int in 3:
		var px: float = w * (0.25 + 0.25 * k)
		pen.box(px - 6.0, top + 2.0, 12.0, 6.0, pen.line)
		pen.box(px - 4.0, top + 8.0, 8.0, 3.0, pen.glow)
	pen.box(0, h - 20.0, w, 2.0, pen.line)


## Passerelle couverte : poutre treillis, vitrage, tablier.
static func _skybridge(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	pen.box(0, 16.0, w, 2.0, pen.line)
	var wy: float = h - 112.0
	var wh: float = 64.0
	# Treillis porteur au-dessus du vitrage.
	var ty0: float = 34.0
	var ty1: float = wy - 18.0
	pen.box(0, ty0, w, 4.0, pen.line)
	pen.box(0, ty1, w, 4.0, pen.line)
	var bays: int = maxi(2, int(w / 70.0))
	var bw: float = w / bays
	for i: int in bays:
		var x0: float = i * bw
		var a: Vector2 = Vector2(x0, ty1 + 2.0) if i % 2 == 0 else Vector2(x0, ty0 + 2.0)
		var b: Vector2 = Vector2(x0 + bw, ty0 + 2.0) if i % 2 == 0 else Vector2(x0 + bw, ty1 + 2.0)
		pen.bar(a, b, 5.0, pen.line)
		pen.box(x0 - 2.0, ty0, 4.0, ty1 - ty0, pen.line)
	# Vitrage : vitres sombres, quelques silhouettes éclairées.
	var holes: PackedVector2Array = _spaced(6.0, w - 6.0, 58.0, 50.0)
	if not holes.is_empty():
		pen.box(holes[0].x, wy, holes[holes.size() - 1].y - holes[0].x, wh, pen.shade)
		pen.perforated(0, w, wy - 2.0, wy, wy + wh, holes, pen.ink)
		for hole: Vector2 in holes:
			if pen.rng.randf() < 0.35:
				pen.box(hole.x, wy, hole.y - hole.x, wh, pen.glow)
	if pen.lome:
		pen.box(0, wy + wh + 6.0, w, 8.0, pen.paint)
	else:
		pen.box(0, wy + wh + 6.0, w, 3.0, pen.line)
	pen.box(0, h - 24.0, w, 2.0, pen.line)


## Gaines techniques suspendues : tiges filetées, gaine, tuyaux, chemin de câbles.
static func _duct_bank(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var top: float = 40.0
	for x: float in [w * 0.12, w * 0.5, w * 0.88]:
		pen.bar(Vector2(x, 0), Vector2(x, top + 2.0), 3.0, pen.ink)
	pen.box(0, top, w, 140.0, pen.ink)
	pen.round_box(0, top + 140.0, w, 56.0, 26.0, pen.ink)
	pen.round_box(0, top + 194.0, w, 48.0, 22.0, pen.ink)
	pen.box(0, top + 238.0, w, h - top - 238.0, pen.ink)
	# Brides de la gaine, reflets des tuyaux, flèches de sens.
	var x: float = 30.0
	while x < w - 10.0:
		pen.box(x, top + 4.0, 4.0, 132.0, pen.line)
		x += 70.0
	pen.box(0, top + 4.0, w, 2.0, pen.line)
	pen.box(20.0, top + 150.0, w - 40.0, 3.0, pen.line)
	pen.box(18.0, top + 202.0, w - 36.0, 3.0, pen.line)
	for k: int in 2:
		var ax: float = w * (0.3 + 0.4 * k)
		pen.poly(PackedVector2Array([Vector2(ax - 14, top + 163), Vector2(ax + 6, top + 163), Vector2(ax + 6, top + 158),
				Vector2(ax + 16, top + 167), Vector2(ax + 6, top + 176), Vector2(ax + 6, top + 171),
				Vector2(ax - 14, top + 171)]), pen.glow_dim)
	pen.box(0, top + 250.0, w, 3.0, pen.line)
	pen.perforated(10.0, w - 10.0, top + 262.0, top + 266.0, top + 290.0,
			_spaced(10.0, w - 10.0, 20.0, 14.0), pen.shade)
	pen.box(w * 0.2, top + 72.0, 30.0, 12.0, pen.glow_dim)


## Marché de Lomé : marchandises stockées sur l'auvent, bâche tendue sur des
## perches qui montent, bandeau en pagne wax en bas.
static func _market_canopy(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var mass: float = 44.0
	pen.box(0, mass, w, h - mass, pen.ink)
	# Perches et bâche affaissée entre elles.
	var p0: float = w * 0.1
	var p1: float = w * 0.9
	pen.box(p0 - 3.0, 0, 6.0, mass + 2.0, pen.ink)
	pen.box(p1 - 3.0, 0, 6.0, mass + 2.0, pen.ink)
	var tarp: PackedVector2Array = PackedVector2Array()
	for k: int in 13:
		var t: float = k / 12.0
		tarp.append(Vector2(lerpf(p0, p1, t), 4.0 + 16.0 * sin(PI * t)))
	tarp.append(Vector2(p1, mass + 1.0))
	tarp.append(Vector2(p0, mass + 1.0))
	pen.poly(tarp, pen.ink)
	pen.bar(Vector2(p0, 2.0), Vector2(0, mass * 0.6), 2.0, pen.ink)
	pen.bar(Vector2(p1, 2.0), Vector2(w, mass * 0.6), 2.0, pen.ink)
	# Sacs et ballots qui dépassent sur les côtés.
	pen.round_box(2.0, mass - 16.0, p0 - 6.0, 20.0, 8.0, pen.ink)
	pen.round_box(p1 + 4.0, mass - 12.0, w - p1 - 6.0, 16.0, 7.0, pen.ink)
	# Étagères de marchandises : sacs, bassines, ballots de pagnes.
	var y: float = mass + 78.0
	var row: int = 0
	while y < h - 70.0 and pen.shapes.size() < 30:
		pen.box(6.0, y, w - 12.0, 4.0, pen.line)
		var x: float = 14.0 + (row % 2) * 12.0
		var k: int = row
		while x < w - 44.0 and pen.shapes.size() < 30:
			match k % 3:
				0:
					pen.round_box(x, y - 34.0, 34.0, 34.0, 11.0, pen.glow_dim)
				1:
					pen.poly(PackedVector2Array([Vector2(x, y - 22), Vector2(x + 40, y - 22), Vector2(x + 33, y),
							Vector2(x + 7, y)]), pen.line)
				_:
					pen.poly(PackedVector2Array([Vector2(x, y), Vector2(x, y - 14), Vector2(x + 4, y - 26), Vector2(x + 38, y - 26),
							Vector2(x + 40, y - 14), Vector2(x + 40, y)]), pen.paint)
			x += 54.0
			k += 1
		y += 76.0
		row += 1
	# Bandeau en pagne wax, ourlet d'encre en bas (bord droit).
	var vy: float = h - 54.0
	pen.box(0, vy, w, 44.0, pen.paint)
	var zig: PackedVector2Array = PackedVector2Array()
	var n: int = maxi(2, int(w / 16.0))
	for i: int in n + 1:
		zig.append(Vector2(w * i / n, vy + (12.0 if i % 2 == 0 else 24.0)))
	for i: int in range(n, -1, -1):
		zig.append(Vector2(w * i / n, vy + (18.0 if i % 2 == 0 else 30.0)))
	pen.poly(zig, pen.ink)
	var dx: float = 8.0
	while dx < w - 6.0:
		pen.disc(dx, vy + 6.0, 2.5, pen.glow, 8)
		dx += 76.0
	pen.box(0, vy - 4.0, w, 3.0, pen.line)


## Enseigne de coiffeur peinte à la main, suspendue.
static func _painted_hanging_sign(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var top: float = 40.0
	pen.box(0, 0, w, 8.0, pen.ink)
	for x: float in [w * 0.15, w * 0.85]:
		pen.box(x - 2.0, 8.0, 4.0, top - 8.0, pen.ink)
		var y: float = 12.0
		while y < top - 4.0:
			pen.box(x - 3.5, y, 7.0, 4.0, pen.ink)
			y += 8.0
	pen.box(0, top, w, h - top, pen.ink)
	var fx: float = 10.0
	var fy: float = top + 10.0
	var fw: float = w - 20.0
	var fh: float = h - top - 30.0
	pen.box(fx, fy, fw, fh, pen.paint)
	pen.box(fx, fy + 6.0, fw, 3.0, pen.glow)
	# Têtes de clients avec leurs coupes (profil et face).
	var heads: int = clampi(int(fw / 110.0), 1, 3)
	var pitch: float = fw / heads
	for i: int in heads:
		var cx: float = fx + pitch * (i + 0.5)
		var cy: float = fy + fh * 0.42
		var r: float = minf(pitch * 0.26, fh * 0.16)
		pen.round_box(cx - r * 1.5, cy + r * 1.1, r * 3.0, r * 1.6, r * 0.7, pen.ink)
		pen.box(cx - r * 0.35, cy + r * 0.6, r * 0.7, r * 0.8, pen.ink)
		pen.ellipse(cx, cy, r * 0.85, r, pen.ink, 16)
		match i % 3:
			0:
				pen.round_box(cx - r * 0.95, cy - r * 1.35, r * 1.9, r * 0.9, r * 0.3, pen.ink)
			1:
				pen.disc(cx, cy - r * 0.6, r * 0.95, pen.ink, 16)
			_:
				pen.poly(PackedVector2Array([Vector2(cx - r, cy - r * 0.4), Vector2(cx - r * 0.3, cy - r * 1.6),
						Vector2(cx + r * 0.4, cy - r * 1.2), Vector2(cx + r, cy - r * 0.5)]), pen.ink)
		pen.box(cx - r * 0.95, cy - r * 0.1, r * 1.9, 2.0, pen.paint)
	pen.letters(fx + 12.0, fy + fh - 40.0, fw - 24.0, 18.0, pen.ink, 6)
	pen.box(fx, fy + fh - 12.0, fw, 3.0, pen.glow)


# --- Poutres fines suspendues -------------------------------------------------

## Poutre en I : ailes, âme boulonnée, platines.
static func _i_beam(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	pen.box(0, 0, w, h, pen.ink)
	pen.box(2.0, 4.0, w - 4.0, 1.0, pen.line)
	pen.box(2.0, h - 5.0, w - 4.0, 1.0, pen.line)
	var x: float = 14.0
	while x < w - 10.0:
		pen.disc(x, h * 0.5, 1.6, pen.line, 6)
		x += 22.0
	pen.box(0, 0, 3.0, h, pen.shade)
	pen.box(w - 3.0, 0, 3.0, h, pen.shade)


## Flèche de grue en treillis : membrures et diagonales ajourées.
static func _lattice_jib(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var chord: float = maxf(3.0, h * 0.3)
	pen.box(0, 0, w, chord, pen.ink)
	pen.poly(PackedVector2Array([Vector2(0, h - chord), Vector2(w - 10.0, h - chord), Vector2(w, h - chord - 2.0),
			Vector2(w, h), Vector2(0, h)]), pen.ink)
	var pitch: float = h - 2.0 * chord + 4.0
	var n: int = maxi(1, int(w / pitch))
	var step: float = w / n
	for i: int in n:
		var x0: float = i * step
		var a: Vector2 = Vector2(x0, h - chord + 0.5) if i % 2 == 0 else Vector2(x0, chord - 0.5)
		var b: Vector2 = Vector2(x0 + step, chord - 0.5) if i % 2 == 0 else Vector2(x0 + step, h - chord + 0.5)
		pen.bar(a, b, 5.5, pen.ink)
	pen.box(0, 0, 4.0, h, pen.ink)
	pen.box(w - 4.0, 0, 4.0, h, pen.ink)
	pen.box(4.0, 1.5, w - 8.0, 1.0, pen.line)


## Planche d'échafaudage sur son tube, colliers de serrage.
static func _scaffold_plank(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var plank: float = h * 0.62
	pen.box(0, 0, w, plank, pen.ink)
	pen.round_box(0, h - 5.0, w, 5.0, 2.5, pen.ink)
	var x: float = 8.0
	while x < w - 8.0:
		pen.box(x, plank, 8.0, h - plank, pen.ink)
		x += 26.0
	pen.box(w - 12.0, plank, 8.0, h - plank, pen.ink)
	pen.box(4.0, plank * 0.5, w * 0.6, 1.0, pen.shade)
	pen.box(w * 0.4, plank * 0.3, w * 0.5, 1.0, pen.shade)
	pen.box(0, 0, 3.0, plank, pen.glow_dim)


## Échafaudage de Lomé : perche de bois, planche, ligatures de corde.
static func _wood_scaffold(pen: Pen) -> void:
	var w: float = pen.size.x
	var h: float = pen.size.y
	var plank: float = h * 0.56
	pen.box(0, 0, w, plank, pen.ink)
	pen.poly(PackedVector2Array([Vector2(0, plank), Vector2(w, plank), Vector2(w, h - 1.5), Vector2(w * 0.6, h),
			Vector2(w * 0.2, h - 0.5), Vector2(0, h - 2.0)]), pen.ink)
	var x: float = 14.0
	while x < w - 10.0:
		pen.box(x, plank - 2.0, 3.0, h - plank + 1.0, pen.paint)
		pen.box(x + 4.0, plank - 2.0, 2.0, h - plank + 1.0, pen.paint)
		x += 46.0
	pen.box(6.0, plank * 0.45, w * 0.5, 1.0, pen.shade)
	pen.box(w * 0.6, plank * 0.6, w * 0.3, 1.0, pen.shade)
