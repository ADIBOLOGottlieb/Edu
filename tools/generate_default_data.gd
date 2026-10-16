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
const LIBRARY_PATH: String = "res://data/levels/chunk_library.tres"
## Épaisseur du sol sous y = 0.
const FLOOR_DEPTH: float = 200.0


func _init() -> void:
	var force: bool = OS.get_cmdline_user_args().has("--force")
	_save(MoveTuning.new(), TUNING_PATH, force)
	_save(_player_animations(), ANIMS_PATH, force)
	_save(_chunk_library(), LIBRARY_PATH, force)
	quit()


func _floor(x: float, width: float) -> Rect2:
	return Rect2(x, 0.0, width, FLOOR_DEPTH)


func _chunk(
	id: StringName, width: float, blocks: Array[Rect2], difficulty: int, tags: Array[StringName]
) -> ChunkLayout:
	var layout: ChunkLayout = ChunkLayout.new()
	layout.id = id
	layout.width = width
	layout.blocks = blocks
	layout.difficulty = difficulty
	layout.tags = tags
	return layout


## Tronçons du jalon M3. Sol à y = 0 en entrée et en sortie ; les 140 premiers px
## sont libres (réapparition). LevelValidator vérifie qu'ils sont franchissables.
func _chunk_library() -> ChunkLibrary:
	var library: ChunkLibrary = ChunkLibrary.new()
	library.start_id = &"flat_run"
	library.layouts = [
		_chunk(&"flat_run", 800.0, [_floor(0, 800)], 0, []),
		_chunk(&"vault_pair", 900.0, [
			_floor(0, 900), Rect2(300, -40, 100, 40), Rect2(620, -36, 90, 36),
		], 0, [&"vault"]),
		_chunk(&"low_tunnel", 1000.0, [
			_floor(0, 1000), Rect2(380, -420, 380, 372),
		], 1, [&"slide"]),
		_chunk(&"small_gap", 900.0, [_floor(0, 360), _floor(520, 380)], 1, [&"gap"]),
		_chunk(&"step_platform", 1000.0, [
			_floor(0, 1000), Rect2(360, -100, 300, 100),
		], 1, [&"jump", &"wall"]),
		_chunk(&"wall_ledge", 1000.0, [
			_floor(0, 1000), Rect2(460, -220, 90, 220),
		], 2, [&"wall"]),
		_chunk(&"tunnel_then_vault", 1100.0, [
			_floor(0, 1100), Rect2(240, -420, 320, 372), Rect2(820, -40, 100, 40),
		], 2, [&"slide", &"vault"]),
		_chunk(&"double_gap", 1200.0, [
			_floor(0, 320), _floor(480, 240), _floor(880, 320),
		], 2, [&"gap"]),
		_chunk(&"high_wall", 1100.0, [
			_floor(0, 1100), Rect2(520, -260, 100, 260),
		], 3, [&"wall"]),
		_chunk(&"gap_then_wall", 1300.0, [
			_floor(0, 380), _floor(540, 760), Rect2(900, -200, 90, 200),
		], 3, [&"gap", &"wall"]),
	]
	return library


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
