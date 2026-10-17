class_name PropShape
extends RefCounted
## Polygone plein d'un objet urbain du premier plan, en coordonnées locales du
## tronçon (même repère que le rectangle de collision). Produit par PropPainter,
## dessiné tel quel (draw_colored_polygon) dans le _draw unique du tronçon.

var points: PackedVector2Array
var color: Color


static func make(shape_points: PackedVector2Array, shape_color: Color) -> PropShape:
	var shape: PropShape = PropShape.new()
	shape.points = shape_points
	shape.color = shape_color
	return shape
