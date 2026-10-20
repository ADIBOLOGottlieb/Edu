class_name SceneRouterNode
extends Node
## Autoload « SceneRouter » — transitions de scène (fondu au noir) et passage de
## paramètres entre scènes. Aucune logique de mission.

const FADE_TIME: float = 0.22

var _params: Dictionary = {}
var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	# Les fondus continuent pendant la pause (menu pause → carte).
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.03, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


## Paramètre passé par la scène précédente (ex. "route_index", "result").
## Vrai pendant un changement de scène (les appuis répétés sont ignorés).
func is_busy() -> bool:
	return _busy


func param(key: String, default: Variant = null) -> Variant:
	return _params.get(key, default)


func params() -> Dictionary:
	return _params.duplicate(true)


## Va vers `scene_path` avec un fondu ; `params` est lisible par la scène suivante.
func go_to(scene_path: String, scene_params: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	_params = scene_params.duplicate(true)
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await tween.finished
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_warning("SceneRouter : scène introuvable %s" % scene_path)
	await get_tree().process_frame
	var back: Tween = create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await back.finished
	_busy = false
