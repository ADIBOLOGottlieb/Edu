class_name FigureLibrary
extends Resource
## Animations des figures, indexées par nom (Figure.name_of : &"kong_vault", &"front_flip"…).

@export var animations: Dictionary[StringName, FigureAnimation] = {}


func get_animation(figure_name: StringName) -> FigureAnimation:
	return animations.get(figure_name) as FigureAnimation
