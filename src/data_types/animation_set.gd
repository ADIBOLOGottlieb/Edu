class_name AnimationSet
extends Resource
## Associe chaque état (nom en minuscules, ex. &"run") à son clip d'animation.
## Séparé de la logique : le corps ne connaît pas les animations, le visuel ne
## connaît pas la physique.

@export var clips: Dictionary[StringName, AnimClip] = {}
## Clip utilisé pour un état sans entrée (ex. états des jalons futurs).
@export var fallback: StringName = &"idle"


func clip_for(state_name: StringName) -> AnimClip:
	if clips.has(state_name):
		return clips[state_name]
	return clips.get(fallback) as AnimClip


func has_clip(state_name: StringName) -> bool:
	return clips.has(state_name)
