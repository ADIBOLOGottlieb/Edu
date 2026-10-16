extends SceneTree
## Génère les ressources de données par défaut (jalon M1) avec le sérialiseur
## de Godot, pour garantir un format .tres valide.
##
## Usage : godot --headless --path . -s tools/generate_default_data.gd
##         godot --headless --path . -s tools/generate_default_data.gd -- --force
## Sans --force, un fichier existant n'est jamais écrasé (réglages modifiés à
## la main dans l'éditeur préservés).

const TUNING_PATH: String = "res://data/tuning/player_move.tres"
const ANIMS_PATH: String = "res://data/animations/player_anims.tres"


func _init() -> void:
	var force: bool = OS.get_cmdline_user_args().has("--force")
	_save(MoveTuning.new(), TUNING_PATH, force)
	_save(_player_animations(), ANIMS_PATH, force)
	quit()


func _save(resource: Resource, path: String, force: bool) -> void:
	if FileAccess.file_exists(path) and not force:
		print("conservé : ", path)
		return
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		push_error("échec d'écriture %s (%s)" % [path, error_string(error)])
		return
	print("écrit : ", path)


func _clip(values: Dictionary) -> AnimClip:
	var clip: AnimClip = AnimClip.new()
	for key: String in values:
		clip.set(key, values[key])
	return clip


## Poses provisoires de la silhouette (radians ; positif = vers l'avant).
func _player_animations() -> AnimationSet:
	var anims: AnimationSet = AnimationSet.new()
	anims.fallback = &"idle"
	anims.clips = {
		&"idle": _clip({
			"lean": 0.04, "crouch": 0.04, "arm_base": 0.12,
			"arm_swing": 0.04, "knee_bend": 0.08, "cycle_hz": 0.5,
		}),
		&"run": _clip({
			"lean": 0.22, "crouch": 0.1, "leg_base": 0.05, "arm_base": 0.15,
			"stride": 0.75, "arm_swing": 0.8, "knee_bend": 0.35, "cycle_hz": 2.4,
		}),
		&"sprint": _clip({
			"lean": 0.4, "crouch": 0.15, "leg_base": 0.1, "arm_base": 0.2,
			"stride": 1.0, "arm_swing": 1.1, "knee_bend": 0.45, "cycle_hz": 2.0,
		}),
		&"jump": _clip({
			"lean": 0.1, "crouch": 0.08, "leg_base": 0.55, "arm_base": 2.3,
			"knee_bend": 0.6,
		}),
		&"fall": _clip({
			"lean": 0.04, "leg_base": 0.25, "arm_base": 1.9,
			"arm_swing": 0.2, "knee_bend": 0.3, "cycle_hz": 1.5,
		}),
		&"landing": _clip({
			"lean": 0.32, "crouch": 0.45, "leg_base": 0.35, "arm_base": 0.6,
			"knee_bend": 0.8,
		}),
		&"slide": _clip({
			"lean": -0.9, "crouch": 0.7, "leg_base": 1.3, "arm_base": -0.6,
			"knee_bend": 0.2,
		}),
		# Jalon M2
		&"double_jump": _clip({
			"lean": 0.2, "leg_base": 0.9, "arm_base": 1.5,
			"arm_swing": 0.6, "knee_bend": 0.9, "cycle_hz": 3.0,
		}),
		&"roll": _clip({
			"lean": 1.4, "crouch": 0.85, "leg_base": 1.8, "arm_base": 1.6,
			"knee_bend": 1.0,
		}),
		&"vault": _clip({
			"lean": 0.5, "crouch": 0.2, "leg_base": 1.1, "arm_base": 0.9,
			"knee_bend": 0.9,
		}),
		&"wall_run": _clip({
			"lean": -0.15, "leg_base": 1.2, "arm_base": 0.4,
			"stride": 0.5, "arm_swing": 0.9, "knee_bend": 0.6, "cycle_hz": 1.5,
		}),
		&"wall_climb": _clip({
			"lean": 0.15, "leg_base": 0.8, "arm_base": 2.6, "arm_swing": 0.5,
			"stride": 0.4, "knee_bend": 0.7, "cycle_hz": 0.9,
		}),
		&"ledge_hang": _clip({
			"lean": 0.08, "leg_base": 0.2, "arm_base": 2.95, "knee_bend": 0.25,
		}),
	}
	return anims
