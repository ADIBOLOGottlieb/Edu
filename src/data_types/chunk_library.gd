class_name ChunkLibrary
extends Resource
## Ensemble des tronçons disponibles pour un niveau ou un mode de course.

@export var layouts: Array[ChunkLayout] = []
## Premier tronçon d'une course aléatoire : toujours sûr (zone de départ).
@export var start_id: StringName = &"flat_run"


func get_layout(id: StringName) -> ChunkLayout:
	for layout: ChunkLayout in layouts:
		if layout.id == id:
			return layout
	return null


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for layout: ChunkLayout in layouts:
		result.append(layout.id)
	return result
