class_name LevelChunk
extends Node2D
## Instance d'un ChunkLayout dans le monde. Construit une seule fois, puis
## réutilisé par ChunkStreamer (seule sa position change).
## Tous les blocs sont dessinés dans un seul _draw : un élément de dessin par
## tronçon au lieu d'un par bloc (moins d'appels de dessin sur mobile).

var layout: ChunkLayout
## Rang du tronçon dans le parcours (0 = premier).
var index: int = -1
## Ambiance de la ville (null = aplats noirs, comme avant M3d) ; sinon chaque bloc est
## dessiné comme un objet urbain (PropPainter), toujours en un seul _draw.
var theme: CityTheme

## Groupe des pièges actifs (lu par l'autopilote pour les éviter).
const HAZARD_GROUP: StringName = &"hazards"

var _shapes: Array[PropShape] = []
var _hazards: Array[Hazard] = []


func build(source: ChunkLayout, city_theme: CityTheme = null) -> void:
	layout = source
	theme = city_theme
	for rect: Rect2 in source.blocks:
		add_child(LevelGeometry.make_block(rect, LevelGeometry.INK, false))
	for spec: HazardSpec in source.hazards:
		var hazard: Hazard = Hazard.create(spec, theme)
		hazard.add_to_group(HAZARD_GROUP)
		add_child(hazard)
		_hazards.append(hazard)
	_shapes.clear()
	if theme != null:
		# Objets urbains de la ville, calculés une fois : la collision reste le rectangle.
		var kinds: Array[BlockKind.Kind] = BlockKind.kinds_of(source)
		for i: int in source.blocks.size():
			var variant: int = BlockKind.variant(source.id, i)
			_shapes.append_array(PropPainter.shapes_for(source.blocks[i], kinds[i], variant, theme))
	queue_redraw()


## Pièges du tronçon (pour les tests et l'autopilote).
func hazards() -> Array[Hazard]:
	return _hazards


## Remet les pièges dans leur état de départ (tronçon réutilisé depuis la réserve).
func reset_hazards() -> void:
	for hazard: Hazard in _hazards:
		hazard.reset()


## Nombre de polygones de décor du tronçon (0 sans ville), pour les tests et le profilage.
func prop_shape_count() -> int:
	return _shapes.size()


func _draw() -> void:
	if layout == null:
		return
	if _shapes.is_empty():
		for rect: Rect2 in layout.blocks:
			draw_rect(rect, LevelGeometry.INK)
		return
	for shape: PropShape in _shapes:
		if shape.is_text():
			var font: Font = ThemeDB.fallback_font
			var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER if shape.max_width > 0.0 else HORIZONTAL_ALIGNMENT_LEFT
			draw_string(font, shape.points[0], shape.text, alignment, shape.max_width if shape.max_width > 0.0 else -1.0, shape.font_size, shape.color)
		else:
			draw_colored_polygon(shape.points, shape.color)


func end_x() -> float:
	return position.x + layout.width


## Haut de la surface la plus basse du tronçon, en coordonnées du monde.
func deepest_y() -> float:
	return position.y + layout.deepest_top()


func contains_x(x: float) -> bool:
	return x >= position.x and x < end_x()
