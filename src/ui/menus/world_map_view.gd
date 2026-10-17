class_name WorldMapView
extends Control
## Carte du monde stylisée dessinée par code : océan au crépuscule, graticule,
## continents en polygones simplifiés (tracés originaux, approximatifs, en
## degrés longitude/latitude, projection équirectangulaire — aucune image
## importée), routes aériennes en pointillés animés entre les villes et
## points des villes (le point ouvert pulse). Les étiquettes cliquables sont
## des nœuds posés par l'écran (WorldMapScreen) grâce à project().

## Contours simplifiés [longitude, latitude] (sens indifférent, sans croisement).
const LANDS: Array[Array] = [
	# Amérique du Nord.
	[Vector2(-168, 65), Vector2(-160, 71), Vector2(-140, 70), Vector2(-125, 70), Vector2(-110, 68), Vector2(-95, 70), Vector2(-85, 69), Vector2(-80, 63), Vector2(-90, 57), Vector2(-94, 59), Vector2(-82, 52), Vector2(-79, 55), Vector2(-77, 62), Vector2(-70, 61), Vector2(-64, 60), Vector2(-60, 55), Vector2(-56, 51), Vector2(-60, 47), Vector2(-66, 45), Vector2(-70, 43), Vector2(-74, 40), Vector2(-76, 35), Vector2(-81, 31), Vector2(-80, 26), Vector2(-82, 25), Vector2(-83, 29), Vector2(-90, 30), Vector2(-97, 27), Vector2(-97, 22), Vector2(-92, 18), Vector2(-88, 21), Vector2(-87, 16), Vector2(-83, 15), Vector2(-83, 10), Vector2(-79, 9), Vector2(-80, 7), Vector2(-85, 10), Vector2(-92, 14), Vector2(-105, 20), Vector2(-110, 24), Vector2(-112, 29), Vector2(-115, 31), Vector2(-117, 32), Vector2(-120, 34), Vector2(-124, 40), Vector2(-124, 46), Vector2(-123, 49), Vector2(-130, 54), Vector2(-135, 58), Vector2(-140, 60), Vector2(-150, 61), Vector2(-155, 58), Vector2(-160, 58), Vector2(-165, 60), Vector2(-162, 63)],
	# Groenland.
	[Vector2(-73, 78), Vector2(-60, 82), Vector2(-30, 83), Vector2(-20, 80), Vector2(-20, 72), Vector2(-30, 68), Vector2(-40, 65), Vector2(-44, 60), Vector2(-50, 62), Vector2(-54, 67), Vector2(-58, 74), Vector2(-68, 76)],
	# Amérique du Sud.
	[Vector2(-80, 8), Vector2(-77, 8), Vector2(-72, 12), Vector2(-62, 11), Vector2(-55, 6), Vector2(-50, 2), Vector2(-48, -1), Vector2(-40, -3), Vector2(-35, -6), Vector2(-35, -9), Vector2(-39, -14), Vector2(-40, -21), Vector2(-44, -23), Vector2(-48, -26), Vector2(-52, -32), Vector2(-57, -36), Vector2(-58, -39), Vector2(-63, -41), Vector2(-65, -45), Vector2(-68, -50), Vector2(-69, -53), Vector2(-72, -54), Vector2(-74, -50), Vector2(-75, -44), Vector2(-73, -37), Vector2(-71, -30), Vector2(-70, -18), Vector2(-76, -13), Vector2(-80, -6), Vector2(-81, -3), Vector2(-79, 1), Vector2(-78, 4)],
	# Eurasie.
	[Vector2(-9, 43), Vector2(-9, 37), Vector2(-6, 36), Vector2(-2, 37), Vector2(0, 39), Vector2(3, 42), Vector2(6, 43), Vector2(9, 44), Vector2(12, 42), Vector2(16, 38), Vector2(18, 40), Vector2(13, 45.5), Vector2(19, 42), Vector2(22, 37), Vector2(24, 38), Vector2(26, 40), Vector2(29, 41), Vector2(36, 36), Vector2(35, 33), Vector2(34, 31), Vector2(35, 28), Vector2(39, 21), Vector2(43, 13), Vector2(45, 13), Vector2(52, 16), Vector2(57, 19), Vector2(59, 22), Vector2(56, 26), Vector2(51, 25), Vector2(48, 29.5), Vector2(50, 30), Vector2(56, 27), Vector2(62, 25), Vector2(67, 24), Vector2(70, 21), Vector2(73, 16), Vector2(77, 8), Vector2(80, 10), Vector2(80, 15), Vector2(87, 21), Vector2(91, 22), Vector2(94, 17), Vector2(98, 16), Vector2(99, 8), Vector2(101, 3), Vector2(104, 1.5), Vector2(103, 6), Vector2(100, 13), Vector2(105, 9), Vector2(109, 12), Vector2(108, 16), Vector2(106, 20), Vector2(110, 21), Vector2(117, 23), Vector2(121, 29), Vector2(122, 32), Vector2(119, 35), Vector2(122, 37), Vector2(118, 38), Vector2(121, 41), Vector2(126, 39), Vector2(126.5, 35), Vector2(129, 35), Vector2(129.5, 42), Vector2(135, 43), Vector2(141, 48), Vector2(140, 53), Vector2(135, 55), Vector2(143, 59), Vector2(155, 59), Vector2(156, 51), Vector2(160, 54), Vector2(163, 60), Vector2(178, 64), Vector2(180, 66), Vector2(180, 69), Vector2(170, 70), Vector2(160, 70), Vector2(150, 72), Vector2(140, 72), Vector2(130, 71), Vector2(113, 74), Vector2(105, 77), Vector2(95, 76), Vector2(85, 74), Vector2(80, 73), Vector2(70, 73), Vector2(67, 69), Vector2(60, 69), Vector2(55, 68), Vector2(44, 68), Vector2(41, 67), Vector2(33, 69), Vector2(28, 71), Vector2(20, 70), Vector2(15, 68), Vector2(12, 65), Vector2(8, 63), Vector2(5, 61), Vector2(5, 58), Vector2(8, 58), Vector2(11, 59), Vector2(12, 56), Vector2(16, 56), Vector2(18, 59), Vector2(17, 61), Vector2(22, 65), Vector2(25, 65), Vector2(21, 61), Vector2(23, 60), Vector2(30, 60), Vector2(24, 59), Vector2(22, 57), Vector2(21, 55), Vector2(14, 54), Vector2(10, 54), Vector2(9, 57), Vector2(8, 55), Vector2(8, 53), Vector2(5, 53), Vector2(3, 51), Vector2(-1, 50), Vector2(-4, 48), Vector2(-2, 47), Vector2(-1, 44)],
	# Afrique.
	[Vector2(-17, 21), Vector2(-16, 24), Vector2(-13, 28), Vector2(-10, 30), Vector2(-9, 33), Vector2(-6, 35.8), Vector2(0, 35.8), Vector2(10, 37), Vector2(11, 34), Vector2(20, 31), Vector2(25, 32), Vector2(32, 31), Vector2(34, 28), Vector2(39, 20), Vector2(43, 12), Vector2(51, 12), Vector2(51, 10), Vector2(47, 4), Vector2(42, -1), Vector2(39, -6), Vector2(40, -11), Vector2(40, -16), Vector2(35, -24), Vector2(33, -28), Vector2(28, -33), Vector2(20, -35), Vector2(18, -33), Vector2(15, -27), Vector2(12, -18), Vector2(13, -12), Vector2(9, -1), Vector2(9, 4), Vector2(6, 4), Vector2(3, 6), Vector2(-2, 5), Vector2(-8, 4), Vector2(-12, 7), Vector2(-15, 11), Vector2(-17.6, 14.7), Vector2(-16.5, 16)],
	# Madagascar.
	[Vector2(44, -12), Vector2(50, -15), Vector2(47, -25), Vector2(44, -24), Vector2(43, -17)],
	# Australie.
	[Vector2(114, -22), Vector2(122, -18), Vector2(130, -12), Vector2(137, -12), Vector2(136, -15), Vector2(140, -17), Vector2(142, -11), Vector2(146, -19), Vector2(153, -25), Vector2(153, -29), Vector2(150, -37), Vector2(145, -38), Vector2(140, -38), Vector2(135, -35), Vector2(130, -32), Vector2(124, -34), Vector2(115, -34), Vector2(113, -26)],
	# Grande-Bretagne, Irlande, Islande.
	[Vector2(-5, 50), Vector2(1, 51), Vector2(2, 53), Vector2(-1, 55), Vector2(-2, 57), Vector2(-5, 58.5), Vector2(-6, 57), Vector2(-5, 55), Vector2(-3, 54), Vector2(-5, 52)],
	[Vector2(-10, 52), Vector2(-6, 52), Vector2(-6, 54.5), Vector2(-8, 55), Vector2(-10, 54)],
	[Vector2(-24, 65), Vector2(-14, 66), Vector2(-14, 64), Vector2(-22, 63.5)],
	# Japon (Honshu et Kyushu, Hokkaido).
	[Vector2(130, 31), Vector2(132, 34), Vector2(135, 34), Vector2(140, 35), Vector2(141, 38), Vector2(142, 41), Vector2(140, 40), Vector2(139, 38), Vector2(136, 37), Vector2(132, 35)],
	[Vector2(140, 42), Vector2(145, 43), Vector2(142, 45), Vector2(140, 43)],
	# Insulinde : Sumatra, Bornéo, Java, Nouvelle-Guinée, Philippines, Sri Lanka.
	[Vector2(95, 5), Vector2(98, 4), Vector2(106, -3), Vector2(104, -6), Vector2(100, -2)],
	[Vector2(109, 1), Vector2(111, -3), Vector2(116, -4), Vector2(119, 1), Vector2(117, 7), Vector2(113, 3)],
	[Vector2(105, -6), Vector2(114, -7), Vector2(114, -8.5), Vector2(106, -7)],
	[Vector2(131, -1), Vector2(138, -2), Vector2(146, -6), Vector2(150, -10), Vector2(141, -9), Vector2(137, -5)],
	[Vector2(120, 18), Vector2(122, 18), Vector2(124, 13), Vector2(126, 7), Vector2(122, 7), Vector2(120, 14)],
	[Vector2(80, 9.5), Vector2(82, 7), Vector2(80, 6)],
	# Nouvelle-Zélande, Cuba.
	[Vector2(172, -34), Vector2(178, -38), Vector2(175, -41), Vector2(172, -40)],
	[Vector2(172, -41), Vector2(174, -41), Vector2(171, -44), Vector2(167, -46), Vector2(169, -43)],
	[Vector2(-85, 22), Vector2(-80, 23), Vector2(-74, 20), Vector2(-77, 20), Vector2(-84, 21.3)],
]

## Région (longitude, latitude) à faire tenir à l'écran : toutes les villes.
var focus: Rect2 = Rect2(-95.0, -40.0, 255.0, 108.0)
## Zone d'écran (locale) où caser `focus` (sous l'en-tête).
var area: Rect2 = Rect2()
## Villes dans l'ordre de déblocage : [{position: Vector2 (lon, lat), open: bool}].
var cities: Array[Dictionary] = []
var accent: Color = MenuStyle.ACCENT

var _scale: float = 5.0
var _origin: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_refit)
	_refit()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Longitude/latitude d'une position normalisée de WorldCity.map_position.
static func lon_lat(map_position: Vector2) -> Vector2:
	return Vector2(map_position.x * 360.0 - 180.0, 90.0 - map_position.y * 180.0)


## Point d'écran (local) d'une longitude/latitude.
func project(lonlat: Vector2) -> Vector2:
	return _origin + Vector2(lonlat.x, -lonlat.y) * _scale


func set_area(screen_area: Rect2) -> void:
	area = screen_area
	_refit()


func _refit() -> void:
	var target: Rect2 = area if area.size.x > 0.0 else Rect2(Vector2.ZERO, size)
	if target.size.x <= 0.0 or target.size.y <= 0.0:
		return
	_scale = minf(target.size.x / focus.size.x, target.size.y / focus.size.y)
	var focus_center: Vector2 = Vector2(focus.get_center().x, -focus.get_center().y)
	_origin = target.get_center() - focus_center * _scale
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0.0), s, Vector2(0.0, s.y)]),
		PackedColorArray([MenuStyle.OCEAN_TOP, MenuStyle.OCEAN_TOP, MenuStyle.OCEAN_BOTTOM, MenuStyle.OCEAN_BOTTOM]))
	_draw_graticule()
	# Chaque terre est aussi dessinée un tour plus à l'est et plus à l'ouest
	# (écrans très larges : la carte se répète sans bord).
	for wrap: float in [-360.0, 0.0, 360.0]:
		for land: Array in LANDS:
			_draw_land(land, wrap)
	_draw_routes()
	_draw_cities()


func _draw_land(land: Array, wrap: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in land:
		points.append(project(p + Vector2(wrap, 0.0)))
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		bounds = bounds.expand(p)
	if not bounds.intersects(Rect2(Vector2.ZERO, size)):
		return
	# Ombre portée puis terre, liseré clair sur la côte.
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		shadow.append(p + Vector2(0.0, 4.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.25))
	draw_colored_polygon(points, MenuStyle.LAND)
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(1.0, 0.86, 0.68, 0.55), 1.5, true)


func _draw_graticule() -> void:
	var line: Color = Color(MenuStyle.CREAM, 0.06)
	for lon: int in range(-540, 541, 30):
		draw_line(project(Vector2(lon, 85)), project(Vector2(lon, -85)), line, 1.0)
	for lat: int in range(-60, 81, 30):
		draw_line(project(Vector2(-540, lat)), project(Vector2(540, lat)), line, 1.0)
	# Équateur un peu plus marqué.
	draw_line(project(Vector2(-540, 0)), project(Vector2(540, 0)), Color(MenuStyle.CREAM, 0.12), 1.5)


## Routes aériennes : arcs en pointillés d'une ville à la suivante ; les
## pointillés avancent lentement vers la ville suivante.
func _draw_routes() -> void:
	for i: int in cities.size() - 1:
		var a: Vector2 = project(cities[i]["position"] as Vector2)
		var b: Vector2 = project(cities[i + 1]["position"] as Vector2)
		var reached: bool = bool(cities[i + 1]["open"])
		var color: Color = accent if reached else Color(MenuStyle.CREAM, 0.38)
		var distance: float = a.distance_to(b)
		if distance < 1.0:
			continue
		var normal: Vector2 = (b - a).normalized().orthogonal()
		if normal.y > 0.0:
			normal = -normal
		var control: Vector2 = (a + b) * 0.5 + normal * distance * 0.22
		var step: float = 11.0
		var length: float = distance * 1.1
		var count: int = maxi(2, int(length / step))
		var shift: float = fposmod(_time * 0.35, 1.0)
		for k: int in count:
			var t: float = (float(k) + shift) / float(count)
			if t > 1.0:
				continue
			var p: Vector2 = a.lerp(control, t).lerp(control.lerp(b, t), t)
			draw_circle(p, 2.2, color, true, -1.0, true)


func _draw_cities() -> void:
	for city: Dictionary in cities:
		var p: Vector2 = project(city["position"] as Vector2)
		if bool(city["open"]):
			var pulse: float = fposmod(_time * 0.6, 1.0)
			draw_circle(p, 10.0 + 26.0 * pulse, Color(accent, 0.45 * (1.0 - pulse)), true, -1.0, true)
			draw_circle(p, 14.0, Color(accent, 0.3), true, -1.0, true)
			draw_circle(p, 9.0, accent, true, -1.0, true)
			draw_circle(p, 4.0, MenuStyle.INK, true, -1.0, true)
		else:
			draw_circle(p, 6.0, Color(MenuStyle.INK, 0.6), true, -1.0, true)
			draw_circle(p, 4.5, Color(MenuStyle.CREAM, 0.55), true, -1.0, true)
