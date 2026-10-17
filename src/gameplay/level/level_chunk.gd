class_name LevelChunk
extends Node2D
## Instance d'un ChunkLayout dans le monde. Construit une seule fois, puis
## réutilisé par ChunkStreamer (seule sa position change).
## Tous les blocs sont dessinés dans un seul _draw : un élément de dessin par
## tronçon au lieu d'un par bloc (moins d'appels de dessin sur mobile).

var layout: ChunkLayout
## Rang du tronçon dans le parcours (0 = premier).
var index: int = -1


func build(source: ChunkLayout) -> void:
	layout = source
	for rect: Rect2 in source.blocks:
		add_child(LevelGeometry.make_block(rect, LevelGeometry.INK, false))
	queue_redraw()


func _draw() -> void:
	if layout == null:
		return
	for rect: Rect2 in layout.blocks:
		draw_rect(rect, LevelGeometry.INK)


func end_x() -> float:
	return position.x + layout.width


## Haut de la surface la plus basse du tronçon, en coordonnées du monde.
func deepest_y() -> float:
	return position.y + layout.deepest_top()


func contains_x(x: float) -> bool:
	return x >= position.x and x < end_x()
