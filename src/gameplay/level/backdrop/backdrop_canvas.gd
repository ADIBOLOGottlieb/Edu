class_name BackdropCanvas
extends Node2D
## Plan de décor : liste ordonnée de formes (polygones pleins, dégradés, câbles)
## dessinée en un seul _draw (un seul élément de dessin par plan : batching
## mobile, ADR-025). Les formes sont ajoutées une fois à la construction.

enum Kind { FILL, GRADIENT, LINE }

## Couleur principale du plan (silhouettes) ; les autres tons en dérivent.
var base_color: Color = Color.GRAY

var _kinds: PackedByteArray = PackedByteArray()
var _points: Array[PackedVector2Array] = []
var _colors: Array[PackedColorArray] = []
var _widths: PackedFloat32Array = PackedFloat32Array()


func add_polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	_push(Kind.FILL, points, PackedColorArray([color]), 0.0)


func add_polygons(polygons: Array[PackedVector2Array], color: Color) -> void:
	for points: PackedVector2Array in polygons:
		add_polygon(points, color)


func add_rect(rect: Rect2, color: Color) -> void:
	add_polygon(BackdropShapes.rect(rect), color)


## Polygone à couleurs par sommet (brume, reflets).
func add_gradient(points: PackedVector2Array, colors: PackedColorArray) -> void:
	if points.size() < 3 or colors.size() != points.size():
		return
	_push(Kind.GRADIENT, points, colors, 0.0)


## Câble ou trait fin (lignes électriques).
func add_line(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	_push(Kind.LINE, points, PackedColorArray([color]), width)


func shape_count() -> int:
	return _kinds.size()


func count_of(kind: Kind) -> int:
	return _kinds.count(kind)


## Nombre de polygones pleins que le rendu ne saurait pas trianguler (doit être nul).
func invalid_polygon_count() -> int:
	var bad: int = 0
	for i: int in _kinds.size():
		if _kinds[i] != Kind.LINE and Geometry2D.triangulate_polygon(_points[i]).is_empty():
			bad += 1
	return bad


## Toutes les couleurs employées par le plan (contrôle : jamais l'encre du premier plan).
func used_colors() -> Array[Color]:
	var out: Array[Color] = []
	for cols: PackedColorArray in _colors:
		for c: Color in cols:
			if not out.has(c):
				out.append(c)
	return out


## Vrai si le plan contient exactement ce polygone (tests : repère bien dessiné).
func has_polygon(points: PackedVector2Array) -> bool:
	for i: int in _points.size():
		if _kinds[i] != Kind.LINE and _points[i] == points:
			return true
	return false


## Point le plus haut (y minimal) des formes pleines qui empiètent sur [x0, x1].
func top_between(x0: float, x1: float) -> float:
	var top: float = INF
	for i: int in _points.size():
		if _kinds[i] == Kind.LINE:
			continue
		var lo: float = INF
		var hi: float = -INF
		var y: float = INF
		for p: Vector2 in _points[i]:
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
			y = minf(y, p.y)
		if hi > x0 and lo < x1:
			top = minf(top, y)
	return top


## Empreinte de la géométrie : deux constructions de même graine sont identiques.
func signature() -> int:
	var h: int = 17
	for i: int in _points.size():
		h = hash([h, _kinds[i], _points[i], _colors[i]])
	return h


## Boîte englobante de toutes les formes (tests, mise en page).
func bounds() -> Rect2:
	var box: Rect2 = Rect2()
	var first: bool = true
	for pts: PackedVector2Array in _points:
		for p: Vector2 in pts:
			if first:
				box = Rect2(p, Vector2.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box


func _push(kind: Kind, points: PackedVector2Array, colors: PackedColorArray, width: float) -> void:
	_kinds.append(kind)
	_points.append(points)
	_colors.append(colors)
	_widths.append(width)
	queue_redraw()


func _draw() -> void:
	for i: int in _kinds.size():
		match _kinds[i]:
			Kind.FILL:
				draw_colored_polygon(_points[i], _colors[i][0])
			Kind.GRADIENT:
				draw_polygon(_points[i], _colors[i])
			Kind.LINE:
				draw_polyline(_points[i], _colors[i][0], _widths[i], true)
