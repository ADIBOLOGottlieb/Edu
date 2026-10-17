class_name BackdropLayerPainter
extends RefCounted
## Remplit les trois plans de décor d'une ville (lointain, quartiers, rue) à
## partir de son CityTheme. Génération déterministe : même graine, même décor.
## Coordonnées du motif : x ∈ [0, span[ (répété par le Parallax2D), y = 0 au
## sol du plan, y négatif vers le haut. Aucune forme n'emploie theme.ink :
## le noir reste réservé au premier plan sur lequel on court.

## Ton des reliefs et ouvertures : la couleur du plan éclaircie vers l'horizon.
const DETAIL_LIGHTEN: float = 0.32
## Abscisse du monument sur le motif lointain. À la caméra de référence, tous
## les plans partagent ces coordonnées : les plans proches y laissent une
## fenêtre sans palmier ni panneau pour que le monument se lise dès le départ.
const MONUMENT_X: float = 560.0
const MONUMENT_CLEARANCE: float = 190.0


static func keeps_monument_clear(theme: CityTheme, x: float) -> bool:
	return theme.monument != &"" and absf(x - MONUMENT_X) < MONUMENT_CLEARANCE


static func detail_color(base: Color, theme: CityTheme) -> Color:
	return base.lerp(theme.sky_horizon, DETAIL_LIGHTEN)


## Plan lointain : ligne d'horizon brumeuse, monument, repères, mer et cocotiers.
static func paint_far(canvas: BackdropCanvas, theme: CityTheme, span: float, rng: RandomNumberGenerator) -> void:
	var color: Color = theme.far_color
	var detail: Color = detail_color(color, theme)
	canvas.base_color = color
	# Réservations : [x0, x1] sans immeubles (place du monument, mer).
	var landmarks: Array[StringName] = []
	if theme.monument != &"":
		landmarks.append(theme.monument)
	for key: StringName in theme.landmarks:
		if not landmarks.has(key):
			landmarks.append(key)
	var sea: Vector2 = Vector2(-1.0, -1.0)
	if landmarks.has(&"beach_palms"):
		sea = Vector2(span * 0.43, span * 0.72)
	var placed: Array[Vector3] = _layout_landmarks(landmarks, theme.monument, span, sea)

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
		var blocked: bool = sea.x <= mid and mid <= sea.y
		for p: Vector3 in placed:
			if landmarks[int(p.z)] == theme.monument and absf(mid - p.x) < 120.0:
				blocked = true
		if not blocked:
			canvas.add_polygon(BackdropShapes.building(x, w, h), color)
			if theme.palm_trees and rng.randf() < 0.22:
				canvas.add_polygons(BackdropShapes.palm(Vector2(x + w + 3.0, 0.0), rng.randf_range(38.0, 62.0),
					rng.randf_range(-0.3, 0.3), rng.randi()), color)
		x += w + rng.randf_range(0.0, 10.0)

	if sea.x >= 0.0:
		_paint_sea(canvas, theme, sea, rng)
	for p: Vector3 in placed:
		var key: StringName = landmarks[int(p.z)]
		var origin: Vector2 = Vector2(p.x, 0.0 if key != &"beach_palms" else -1.0)
		canvas.add_polygons(LandmarkPainter.silhouette(key, origin, p.y), color)
		canvas.add_polygons(LandmarkPainter.details(key, origin, p.y), detail)
	# Brume de chaleur au pied de l'horizon.
	var haze: Color = theme.sky_horizon
	canvas.add_gradient(PackedVector2Array([
		Vector2(-40.0, -70.0), Vector2(span + 40.0, -70.0),
		Vector2(span + 40.0, 10.0), Vector2(-40.0, 10.0),
	]), PackedColorArray([
		Color(haze, 0.0), Color(haze, 0.0), Color(haze, 0.6), Color(haze, 0.6),
	]))


## Position (x), échelle et indice de chaque repère sur le motif lointain.
## Le monument est placé tôt (visible dès les premiers écrans), près du soleil.
static func _layout_landmarks(keys: Array[StringName], monument: StringName, span: float, sea: Vector2) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var free_x: float = span * 0.27
	for i: int in keys.size():
		var key: StringName = keys[i]
		if key == monument:
			out.append(Vector3(MONUMENT_X, 1.0, i))
		elif key == &"hotel_tower":
			out.append(Vector3(span - 230.0, 0.9, i))
		elif key == &"beach_palms" and sea.x >= 0.0:
			out.append(Vector3(sea.x + 140.0, 1.0, i))
			out.append(Vector3(lerpf(sea.x, sea.y, 0.62), 0.8, i))
		else:
			out.append(Vector3(free_x, 0.88, i))
			free_x += 420.0
	return out


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
	var towers: PackedFloat32Array = PackedFloat32Array([span * 0.31, span * 0.74])
	var tower_done: Array[bool] = [false, false]
	var x: float = 0.0
	while x < span - 40.0:
		var w: float = minf(rng.randf_range(54.0, 150.0), span - x)
		var h: float = rng.randf_range(40.0, 115.0)
		if rng.randf() < 0.16:
			h = rng.randf_range(150.0, 230.0)
			w = minf(w, 110.0)
		var top: float = -h
		canvas.add_polygon(BackdropShapes.building(x, w, h), color)
		_windows(canvas, x, w, h, detail, rng)
		var tin: bool = theme.tin_roofs and h < 110.0 and rng.randf() < 0.5
		if tin:
			canvas.add_polygons(BackdropShapes.lean_to_roof(x, w, top, rng.randf_range(6.0, 12.0),
				1.0 if rng.randf() < 0.5 else -1.0), color)
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
		if theme.palm_trees and rng.randf() < 0.3 and not keeps_monument_clear(theme, x + w):
			gap = rng.randf_range(18.0, 40.0)
			canvas.add_polygons(BackdropShapes.palm(Vector2(x + w + gap * 0.5, 0.0), rng.randf_range(120.0, 180.0),
				rng.randf_range(-0.35, 0.35), rng.randi()), color)
		x += w + gap


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
