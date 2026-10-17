class_name FigureAnimation
extends Resource
## Animation d'une figure par images clés : `poses[i]` est atteinte à
## `times[i]` (0 = début de la figure, 1 = fin prévue). Interpolation lissée.
## La progression vient du corps (Figure.expected_duration) : l'animation suit la physique.

@export var times: PackedFloat32Array = PackedFloat32Array()
@export var poses: Array[AnimClip] = []

const FIELDS: Array[StringName] = [
	&"lean", &"crouch", &"leg_base", &"arm_base", &"stride",
	&"arm_swing", &"knee_bend", &"rotation", &"spin",
]


func is_valid() -> bool:
	if times.is_empty() or times.size() != poses.size():
		return false
	for i: int in range(1, times.size()):
		if times[i] < times[i - 1]:
			return false
	return true


## Pose interpolée à la progression `t` (0..1) : dictionnaire champ → valeur.
func sample(t: float) -> Dictionary[StringName, float]:
	var result: Dictionary[StringName, float] = {}
	if not is_valid():
		return result
	t = clampf(t, 0.0, 1.0)
	var next_index: int = 0
	while next_index < times.size() and times[next_index] < t:
		next_index += 1
	var a: AnimClip
	var b: AnimClip
	var weight: float = 0.0
	if next_index == 0:
		a = poses[0]
		b = poses[0]
	elif next_index >= times.size():
		a = poses.back()
		b = poses.back()
	else:
		a = poses[next_index - 1]
		b = poses[next_index]
		var span: float = maxf(times[next_index] - times[next_index - 1], 0.0001)
		weight = smoothstep(0.0, 1.0, (t - times[next_index - 1]) / span)
	for field: StringName in FIELDS:
		result[field] = lerpf(float(a.get(field)), float(b.get(field)), weight)
	return result
