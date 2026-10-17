class_name CaptureGauge
extends RefCounted
## Jauge de capture (§6) : se remplit tant que le vigile tient le coureur, se vide
## quand il fuit. Pleine → capture.

## Temps de contact continu pour remplir la jauge (s).
var fill_time: float = 1.5
## Temps pour la vider entièrement hors contact (s).
var drain_time: float = 2.0
var value: float = 0.0


func update(delta: float, in_contact: bool) -> float:
	if in_contact:
		value = minf(1.0, value + delta / fill_time)
	else:
		value = maxf(0.0, value - delta / drain_time)
	return value


func is_full() -> bool:
	return value >= 1.0


func reset() -> void:
	value = 0.0
