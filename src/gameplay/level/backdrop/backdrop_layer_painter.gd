class_name BackdropLayerPainter
extends RefCounted
## Remplit les trois plans de décor d'une ville (lointain, quartiers, rue) à
## partir de son CityTheme. Génération déterministe : même graine, même décor.
## Coordonnées du motif : x ∈ [0, span[ (répété par le Parallax2D), y = 0 au
## sol du plan, y négatif vers le haut. Aucune forme n'emploie theme.ink :
## le noir reste réservé au premier plan sur lequel on court.

## Ton des reliefs et ouvertures : la couleur du plan éclaircie vers l'horizon.
const DETAIL_LIGHTEN: float = 0.32
## Ton des baies et ombres : la couleur du plan assombrie.
const SHADE_DARKEN: float = 0.2
## Touches de couleur propre (drapeau) : part de la couleur du plan mêlée.
const TINT_BLEND: float = 0.55
## Abscisse du monument sur le motif lointain. À la caméra de référence, tous
## les plans partagent ces coordonnées : les plans proches y laissent une
## fenêtre sans palmier ni panneau pour que le monument se lise dès le départ.
## Choisie pour que le soleil couchant se lise au travers de l'évidement.
const MONUMENT_X: float = 578.0
const MONUMENT_CLEARANCE: float = 190.0
## Demi-largeur de la place du monument : quartiers bas, horizon dégagé.
const MONUMENT_PLAZA: float = 150.0
## Espace libre minimal entre deux repères d'un même plan.
const LANDMARK_GAP: float = 40.0
## Hauteur maximale des immeubles de quartier devant le monument : leur toit
## reste sous le pied du monument à la caméra de référence.
const LOW_RISE: float = 96.0
## Monuments de rond-point du plan des quartiers : agrandis et hissés sur une
## esplanade à gradins, pour dépasser des toits de course à la caméra de référence.
const MID_LANDMARK_SCALE: float = 1.25
const MID_LANDMARK_LIFT: float = 60.0


## Repère placé sur un plan : clé, abscisse du milieu de sa base, échelle.
class Slot:
	extends RefCounted
	var key: StringName
	var x: float
	var scale: float

	func _init(k: StringName, px: float, s: float) -> void:
		key = k
		x = px
		scale = s

	## Emprise au sol [gauche, droite].
	func footprint() -> Vector2:
		var half: float = LandmarkPainter.width(key) * scale * 0.5
		return Vector2(x - half, x + half)


static func keeps_monument_clear(theme: CityTheme, x: float) -> bool:
	return theme.monument != &"" and absf(x - MONUMENT_X) < MONUMENT_CLEARANCE


static func detail_color(base: Color, theme: CityTheme) -> Color:
	return base.lerp(theme.sky_horizon, DETAIL_LIGHTEN)


static func shade_color(base: Color) -> Color:
	return base.darkened(SHADE_DARKEN)


## Monument puis repères du thème, sans doublon.
static func theme_landmarks(theme: CityTheme) -> Array[StringName]:
	var keys: Array[StringName] = []
	if theme.monument != &"":
		keys.append(theme.monument)
	for key: StringName in theme.landmarks:
		if not keys.has(key):
			keys.append(key)
	return keys


## Portion de mer du motif lointain [x0, x1] ; (-1, -1) sans bord de mer.
static func sea_span(theme: CityTheme, span: float) -> Vector2:
	if theme_landmarks(theme).has(&"beach_palms"):
		return Vector2(span * 0.43, span * 0.72)
	return Vector2(-1.0, -1.0)


## Repères d'un plan, triés de gauche à droite, sans chevauchement.
## Lointain : le monument tôt (premier écran, devant le soleil), la cathédrale
## peu après, le bord de mer, puis le palais et la tour d'hôtel. Quartiers :
## les monuments de rond-point, espacés pour revenir à tour de rôle, hors du
## premier écran (réservé au monument lointain).
static func landmark_slots(theme: CityTheme, layer: LandmarkPainter.Layer, span: float) -> Array[Slot]:
	var out: Array[Slot] = []
	var sea: Vector2 = sea_span(theme, span) if layer == LandmarkPainter.Layer.FAR else Vector2(-1.0, -1.0)
	var free_x: float = span * 0.2
	for key: StringName in theme_landmarks(theme):
		if LandmarkPainter.layer_of(key) != layer:
			continue
		if key == theme.monument:
			out.append(Slot.new(key, MONUMENT_X, 1.0))
			continue
		match key:
			&"cathedral":
				out.append(Slot.new(key, span * 0.3, 0.95))
			&"palais_lome":
				out.append(Slot.new(key, span * 0.815, 1.15))
			&"hotel_tower":
				out.append(Slot.new(key, span - 230.0, 0.9))
			&"colombe_paix":
				out.append(Slot.new(key, span * 0.5, MID_LANDMARK_SCALE))
			&"deux_lions":
				out.append(Slot.new(key, span * 0.8, MID_LANDMARK_SCALE))
			&"beach_palms":
				if sea.x >= 0.0:
					out.append(Slot.new(key, sea.x + 140.0, 1.0))
					out.append(Slot.new(key, lerpf(sea.x, sea.y, 0.62), 0.8))
			_:
				out.append(Slot.new(key, free_x, 0.88))
				free_x += 420.0
	_resolve_overlaps(out, sea, span)
	return out


## Pousse vers la droite les repères qui empiètent sur la mer ou sur leur voisin.
static func _resolve_overlaps(slots: Array[Slot], sea: Vector2, span: float) -> void:
	for s: Slot in slots:
		var f: Vector2 = s.footprint()
		if s.key != &"beach_palms" and sea.x >= 0.0 and f.y > sea.x - LANDMARK_GAP and f.x < sea.y + LANDMARK_GAP:
			s.x += sea.y + LANDMARK_GAP - f.x
	slots.sort_custom(func(a: Slot, b: Slot) -> bool: return a.x < b.x)
	for i: int in range(1, slots.size()):
		var limit: float = slots[i - 1].footprint().y + LANDMARK_GAP
		var left: float = slots[i].footprint().x
		if left < limit:
			slots[i].x += limit - left
	if slots.size() > 1 and slots[-1].footprint().y > span + slots[0].footprint().x - LANDMARK_GAP:
		push_warning("BackdropLayerPainter : repères trop nombreux pour le motif (%d)" % slots.size())


## Dessine un repère dans les tons du plan (silhouette, ombres, reliefs, touches).
static func paint_landmark(canvas: BackdropCanvas, theme: CityTheme, slot: Slot, color: Color, ground: float = 0.0) -> void:
	var d: LandmarkDrawing = LandmarkPainter.drawing(slot.key)
	var origin: Vector2 = Vector2(slot.x, ground)
	canvas.add_polygons(LandmarkPainter.place(d.fill, origin, slot.scale), color)
	canvas.add_polygons(LandmarkPainter.place(d.dark, origin, slot.scale), shade_color(color))
	canvas.add_polygons(LandmarkPainter.place(d.light, origin, slot.scale), detail_color(color, theme))
	var tinted: Array[PackedVector2Array] = LandmarkPainter.place(d.tinted, origin, slot.scale)
	for i: int in tinted.size():
		canvas.add_polygon(tinted[i], d.tints[i].lerp(color, TINT_BLEND))


## Plan lointain : ligne d'horizon brumeuse, monument, repères, mer et cocotiers.
static func paint_far(canvas: BackdropCanvas, theme: CityTheme, span: float, rng: RandomNumberGenerator) -> void:
	var color: Color = theme.far_color
	canvas.base_color = color
	var sea: Vector2 = sea_span(theme, span)
	var slots: Array[Slot] = landmark_slots(theme, LandmarkPainter.Layer.FAR, span)

	# Sol continu sous l'horizon (rien ne bâille quand la caméra monte).
	canvas.add_rect(Rect2(-40.0, -3.0, span + 80.0, BackdropShapes.DEPTH), color)
	var x: float = 0.0
	while x < span:
		var w: float = rng.randf_range(22.0, 70.0)
		var h: float = rng.randf_range(14.0, 58.0)
		if rng.randf() < 0.12:
			h = rng.randf_range(80.0, 140.0)
			w = rng.randf_range(24.0, 42.0)
		var mid: float = x + w * 0.5
		# Ni sur la mer, ni derrière le monument (le ciel passe dans l'évidement).
		var blocked: bool = sea.x <= mid and mid <= sea.y
		if theme.monument != &"" and x + w > MONUMENT_X - MONUMENT_PLAZA and x < MONUMENT_X + MONUMENT_PLAZA:
			blocked = true
		if not blocked:
			canvas.add_polygon(BackdropShapes.building(x, w, h), color)
			if theme.palm_trees and rng.randf() < 0.22:
				canvas.add_polygons(BackdropShapes.palm(Vector2(x + w + 3.0, 0.0), rng.randf_range(38.0, 62.0),
					rng.randf_range(-0.3, 0.3), rng.randi()), color)
		x += w + rng.randf_range(0.0, 10.0)

	if sea.x >= 0.0:
		_paint_sea(canvas, theme, sea, rng)
	for s: Slot in slots:
		paint_landmark(canvas, theme, s, color, 0.0 if s.key != &"beach_palms" else -1.0)
	# Brume de chaleur au pied de l'horizon.
	var haze: Color = theme.sky_horizon
	canvas.add_gradient(PackedVector2Array([
		Vector2(-40.0, -70.0), Vector2(span + 40.0, -70.0),
		Vector2(span + 40.0, 10.0), Vector2(-40.0, 10.0),
	]), PackedColorArray([
		Color(haze, 0.0), Color(haze, 0.0), Color(haze, 0.6), Color(haze, 0.6),
	]))


## Mer du golfe de Guinée sur une partie du motif : bande lisse et reflets du soleil.
static func _paint_sea(canvas: BackdropCanvas, theme: CityTheme, sea: Vector2, rng: RandomNumberGenerator) -> void:
	var water: Color = theme.sky_top.lerp(theme.sky_horizon, 0.45).lerp(theme.far_color, 0.2)
	var sparkle: Color = theme.sun_color.lerp(Color.WHITE, 0.25)
	var beach: Color = theme.far_color.lerp(theme.sky_horizon, 0.18)
	canvas.add_rect(Rect2(sea.x, -20.0, sea.y - sea.x, 19.0), water)
	canvas.add_rect(Rect2(sea.x, -1.5, sea.y - sea.x, BackdropShapes.DEPTH), beach)
	var count: int = int((sea.y - sea.x) / 9.0)
	for i: int in count:
		var px: float = rng.randf_range(sea.x + 6.0, sea.y - 20.0)
		var py: float = rng.randf_range(-18.0, -4.0)
		var length: float = rng.randf_range(3.0, 16.0) * (1.0 - (py + 18.0) / 24.0)
		canvas.add_rect(Rect2(px, py, length, 1.2), Color(sparkle, rng.randf_range(0.45, 0.9)))
	# Bateaux de pêche au loin.
	for i: int in 3:
		var bx: float = lerpf(sea.x + 60.0, sea.y - 60.0, (float(i) + 0.5) / 3.0) + rng.randf_range(-40.0, 40.0)
		canvas.add_polygon(PackedVector2Array([
			Vector2(bx - 9.0, -15.0), Vector2(bx + 9.0, -15.0), Vector2(bx + 6.0, -12.5), Vector2(bx - 6.0, -12.5),
		]), theme.far_color)
		canvas.add_polygon(PackedVector2Array([
			Vector2(bx, -15.0), Vector2(bx, -27.0), Vector2(bx + 6.0, -15.0),
		]), theme.far_color)


## Plan des quartiers : maisons et immeubles, citernes, antennes, paraboles,
## toits de tôle, palmiers, un minaret et un clocher de temps en temps.
static func paint_mid(canvas: BackdropCanvas, theme: CityTheme, span: float, rng: RandomNumberGenerator) -> void:
	var color: Color = theme.mid_color
	var detail: Color = detail_color(color, theme)
	canvas.base_color = color
	canvas.add_rect(Rect2(-40.0, -2.0, span + 80.0, BackdropShapes.DEPTH), color)
	var towers: PackedFloat32Array = PackedFloat32Array([span * 0.31, span * 0.62])
	var tower_done: Array[bool] = [false, false]
	# Places des monuments de rond-point : aucun immeuble, le ciel autour.
	var slots: Array[Slot] = landmark_slots(theme, LandmarkPainter.Layer.MID, span)
	var plazas: Array[Vector2] = []
	for s: Slot in slots:
		var f: Vector2 = s.footprint()
		plazas.append(Vector2(f.x - 24.0, f.y + 24.0))
	var x: float = 0.0
	while x < span - 40.0:
		var w: float = minf(rng.randf_range(54.0, 150.0), span - x)
		var h: float = rng.randf_range(40.0, 115.0)
		if rng.randf() < 0.16:
			h = rng.randf_range(150.0, 230.0)
			w = minf(w, 110.0)
		var plaza_end: float = -1.0
		for p: Vector2 in plazas:
			if x + w > p.x and x < p.y:
				plaza_end = p.y
		if plaza_end >= 0.0:
			x = plaza_end + rng.randf_range(4.0, 20.0)
			continue
		# Devant le monument lointain : quartier bas, sans clutter de toit.
		var low: bool = theme.monument != &"" and x + w > MONUMENT_X - MONUMENT_PLAZA \
			and x < MONUMENT_X + MONUMENT_PLAZA
		if low:
			h = minf(h, LOW_RISE)
		var top: float = -h
		canvas.add_polygon(BackdropShapes.building(x, w, h), color)
		_windows(canvas, x, w, h, detail, rng)
		var tin: bool = theme.tin_roofs and h < 110.0 and rng.randf() < 0.5
		if tin:
			canvas.add_polygons(BackdropShapes.lean_to_roof(x, w, top, rng.randf_range(6.0, 12.0),
				1.0 if rng.randf() < 0.5 else -1.0), color)
		elif low:
			canvas.add_rect(Rect2(x - 1.0, top - 3.0, w + 2.0, 3.0), color)
		else:
			# Acrotère et clutter de toit-terrasse.
			canvas.add_rect(Rect2(x - 1.0, top - 3.0, w + 2.0, 3.0), color)
			if rng.randf() < 0.45:
				var tw: float = rng.randf_range(10.0, 16.0)
				canvas.add_polygons(BackdropShapes.water_tank(Vector2(x + rng.randf_range(tw, w - tw), top - 3.0),
					tw, rng.randf() < 0.5), color)
			if rng.randf() < 0.35:
				canvas.add_polygons(BackdropShapes.antenna(Vector2(x + rng.randf_range(6.0, w - 6.0), top - 3.0),
					rng.randf_range(22.0, 40.0)), color)
			if theme.satellite_dishes and rng.randf() < 0.35:
				canvas.add_polygons(BackdropShapes.dish(Vector2(x + rng.randf_range(8.0, w - 8.0), top - 3.0),
					rng.randf_range(6.0, 9.0), 1.0 if rng.randf() < 0.5 else -1.0), color)
			if rng.randf() < 0.25:
				# Cage d'escalier sur le toit.
				canvas.add_rect(Rect2(x + w * 0.15, top - 16.0, minf(22.0, w * 0.3), 14.0), color)
		for t: int in towers.size():
			if not tower_done[t] and x + w > towers[t]:
				tower_done[t] = true
				var base: Vector2 = Vector2(x + w + 6.0, 0.0)
				if t == 0:
					canvas.add_polygons(BackdropShapes.minaret(base, rng.randf_range(250.0, 290.0)), color)
				else:
					canvas.add_polygons(BackdropShapes.church_tower(base, rng.randf_range(230.0, 260.0)), color)
		var gap: float = rng.randf_range(4.0, 26.0)
		if theme.palm_trees and rng.randf() < 0.3 and not keeps_monument_clear(theme, x + w) \
				and not _near_plaza(plazas, x + w, 70.0):
			gap = rng.randf_range(18.0, 40.0)
			canvas.add_polygons(BackdropShapes.palm(Vector2(x + w + gap * 0.5, 0.0), rng.randf_range(120.0, 180.0),
				rng.randf_range(-0.35, 0.35), rng.randi()), color)
		x += w + gap
	for s: Slot in slots:
		_paint_esplanade(canvas, theme, s, color)
		paint_landmark(canvas, theme, s, color, -MID_LANDMARK_LIFT)


## Esplanade à gradins sous un monument de quartier (talus, marches éclairées).
static func _paint_esplanade(canvas: BackdropCanvas, theme: CityTheme, slot: Slot, color: Color) -> void:
	var f: Vector2 = slot.footprint()
	var lift: float = MID_LANDMARK_LIFT
	var inset: float = 6.0
	canvas.add_polygon(PackedVector2Array([
		Vector2(f.x - 18.0, 0.0), Vector2(f.y + 18.0, 0.0),
		Vector2(f.y - inset, -lift), Vector2(f.x + inset, -lift),
	]), color)
	var detail: Color = detail_color(color, theme)
	for k: int in 3:
		var t: float = float(k + 1) / 4.0
		var y: float = -lift * t
		var half: float = lerpf((f.y - f.x) * 0.5 + 18.0, (f.y - f.x) * 0.5 - inset, t)
		canvas.add_rect(Rect2(slot.x - half, y, half * 2.0, 1.2), detail)


static func _near_plaza(plazas: Array[Vector2], x: float, margin: float) -> bool:
	for p: Vector2 in plazas:
		if x > p.x - margin and x < p.y + margin:
			return true
	return false


## Quelques fenêtres claires (reflets du couchant) sur les immeubles hauts.
static func _windows(canvas: BackdropCanvas, x: float, w: float, h: float, tone: Color, rng: RandomNumberGenerator) -> void:
	if h < 120.0 or rng.randf() < 0.4:
		return
	var cols: int = maxi(1, int((w - 12.0) / 16.0))
	var rows: int = int((h - 20.0) / 22.0)
	for r: int in rows:
		for c: int in cols:
			if rng.randf() < 0.22:
				canvas.add_rect(Rect2(x + 9.0 + float(c) * 16.0, -h + 14.0 + float(r) * 22.0, 6.0, 9.0), tone)


## Plan de la rue : maisons basses, palmiers, poteaux et câbles électriques,
## lampadaires, panneaux publicitaires.
static func paint_near(canvas: BackdropCanvas, theme: CityTheme, span: float, rng: RandomNumberGenerator) -> void:
	var color: Color = theme.near_color
	canvas.base_color = color
	canvas.add_rect(Rect2(-40.0, -2.0, span + 80.0, BackdropShapes.DEPTH), color)
	# Maisons basses et murs de clôture.
	var x: float = 0.0
	while x < span - 30.0:
		var w: float = minf(rng.randf_range(70.0, 170.0), span - x)
		var h: float = rng.randf_range(50.0, 110.0)
		canvas.add_polygon(BackdropShapes.building(x, w, h), color)
		if theme.tin_roofs and rng.randf() < 0.65:
			if rng.randf() < 0.5:
				canvas.add_polygon(BackdropShapes.gable_roof(x, w, -h, rng.randf_range(8.0, 16.0)), color)
			else:
				canvas.add_polygons(BackdropShapes.lean_to_roof(x, w, -h, rng.randf_range(8.0, 14.0),
					1.0 if rng.randf() < 0.5 else -1.0), color)
		elif rng.randf() < 0.5:
			var tw: float = rng.randf_range(16.0, 22.0)
			canvas.add_polygons(BackdropShapes.water_tank(Vector2(x + w * 0.7, -h), tw, false), color)
		var gap: float = rng.randf_range(10.0, 50.0)
		canvas.add_rect(Rect2(x + w, -26.0, gap, 26.0), color)
		x += w + gap

	# Panneaux publicitaires.
	for k: float in [0.42, 0.8]:
		canvas.add_polygons(BackdropShapes.billboard(Vector2(span * k, 0.0), 150.0, rng.randf_range(120.0, 160.0), 64.0), color)

	# Poteaux électriques à pas régulier (le motif boucle sans couture).
	if theme.power_lines:
		var poles: int = 10
		var step: float = span / float(poles)
		var height: float = 230.0
		var offset: float = step * 0.5
		for i: int in poles:
			var base: Vector2 = Vector2(offset + step * float(i), 0.0)
			canvas.add_polygons(BackdropShapes.power_pole(base, height), color)
			var a: PackedVector2Array = BackdropShapes.cable_anchors(base, height)
			var b: PackedVector2Array = BackdropShapes.cable_anchors(base + Vector2(step, 0.0), height)
			for j: int in a.size():
				canvas.add_line(BackdropShapes.sagging_cable(a[j], b[j], 22.0 + 5.0 * float(j)), color, 1.6)
			if i == 0:
				# Portée qui entre par la gauche du motif.
				var prev: PackedVector2Array = BackdropShapes.cable_anchors(base - Vector2(step, 0.0), height)
				for j: int in a.size():
					canvas.add_line(BackdropShapes.sagging_cable(prev[j], a[j], 22.0 + 5.0 * float(j)), color, 1.6)

	# Lampadaires.
	var lamps: int = 6
	for i: int in lamps:
		var lx: float = span * (float(i) + 0.3) / float(lamps) + rng.randf_range(-40.0, 40.0)
		canvas.add_polygons(BackdropShapes.lamp_post(Vector2(lx, 0.0), rng.randf_range(150.0, 175.0),
			1.0 if i % 2 == 0 else -1.0), color)

	# Grands cocotiers de rue.
	if theme.palm_trees:
		var px: float = rng.randf_range(60.0, 200.0)
		while px < span - 40.0:
			var h: float = rng.randf_range(220.0, 300.0)
			var lean: float = rng.randf_range(-0.4, 0.4)
			var variant: int = rng.randi()
			if not keeps_monument_clear(theme, px):
				canvas.add_polygons(BackdropShapes.palm(Vector2(px, 0.0), h, lean, variant), color)
			px += rng.randf_range(300.0, 700.0)
