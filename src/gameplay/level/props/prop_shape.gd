class_name PropShape
extends RefCounted
## Élément d'un objet urbain du premier plan, en coordonnées locales du tronçon
## (même repère que le rectangle de collision). Produit par PropPainter, dessiné
## tel quel dans le _draw unique du tronçon : un polygone plein, ou un texte
## (enseigne peinte) quand `text` n'est pas vide.

var points: PackedVector2Array
var color: Color
## Texte d'enseigne (pharmacie, station-service…) ; vide = polygone.
var text: String = ""
## Taille de police du texte (px) ; le texte commence à points[0] (ligne de base).
var font_size: int = 10
## Largeur maximale du texte (px), au-delà il est réduit ; 0 = libre.
var max_width: float = 0.0


static func make(shape_points: PackedVector2Array, shape_color: Color) -> PropShape:
	var shape: PropShape = PropShape.new()
	shape.points = shape_points
	shape.color = shape_color
	return shape


## Texte d'enseigne : `baseline` = début de la ligne de base, centré sur `max_text_width` si > 0.
static func label(baseline: Vector2, label_text: String, size: int, label_color: Color, max_text_width: float = 0.0) -> PropShape:
	var shape: PropShape = PropShape.new()
	shape.points = PackedVector2Array([baseline])
	shape.color = label_color
	shape.text = label_text
	shape.font_size = size
	shape.max_width = max_text_width
	return shape


func is_text() -> bool:
	return not text.is_empty()
