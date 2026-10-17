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
const FIGURES_PATH: String = "res://data/animations/player_figures.tres"
## Hauteur des immeubles sous leur toit : la rue est loin en dessous.
const BUILDING_DEPTH: float = 1400.0
## Épaisseur d'une poutre (grue, passerelle).
const BEAM_THICKNESS: float = 16.0


func _init() -> void:
	var force: bool = OS.get_cmdline_user_args().has("--force")
	_save(MoveTuning.new(), TUNING_PATH, force)
	_save(_player_animations(), ANIMS_PATH, force)
	_save(_chunk_library(), LIBRARY_PATH, force)
	_save(_figure_library(), FIGURES_PATH, force)
	quit()


func _figure(times: Array[float], poses: Array[Dictionary]) -> FigureAnimation:
	var animation: FigureAnimation = FigureAnimation.new()
	animation.times = PackedFloat32Array(times)
	var clips: Array[AnimClip] = []
	for pose: Dictionary in poses:
		clips.append(_clip(pose))
	animation.poses = clips
	return animation


## Figures de parkour par images clés (radians ; rotation positive = vers
## l'avant ; arm_base 0 = bras le long du corps, π/2 = devant, π = en l'air).
## Un salto fait un tour complet (±2π) pour finir debout.
func _figure_library() -> FigureLibrary:
	var library: FigureLibrary = FigureLibrary.new()
	library.animations = {
		# Speed vault : le corps passe de profil, jambes groupées sur le côté, une main posée.
		&"speed_vault": _figure([0.0, 0.4, 0.75, 1.0], [
			{"lean": 0.3, "crouch": 0.2, "leg_base": 0.4, "arm_base": 0.8, "knee_bend": 0.6},
			{"lean": -0.2, "crouch": 0.3, "leg_base": 1.4, "arm_base": 0.3, "knee_bend": 0.4},
			{"lean": 0.1, "crouch": 0.15, "leg_base": 0.9, "arm_base": 1.5, "knee_bend": 0.3},
			{"lean": 0.25, "leg_base": 0.2, "arm_base": 0.3, "knee_bend": 0.4},
		]),
		# Kong vault : plongeon horizontal mains en avant, jambes ramenées entre les bras.
		&"kong_vault": _figure([0.0, 0.35, 0.6, 1.0], [
			{"lean": 0.6, "crouch": 0.2, "leg_base": -0.3, "arm_base": 1.6, "knee_bend": 0.2},
			{"lean": 1.25, "crouch": 0.15, "leg_base": -0.6, "arm_base": 1.25, "knee_bend": 0.3},
			{"lean": 0.8, "crouch": 0.35, "leg_base": 1.1, "arm_base": 0.6, "knee_bend": 1.0},
			{"lean": 0.3, "leg_base": 0.5, "arm_base": 0.9, "knee_bend": 0.5},
		]),
		# Lazy vault : passage lent, buste en arrière, jambes tendues devant.
		&"lazy_vault": _figure([0.0, 0.5, 1.0], [
			{"lean": 0.1, "leg_base": 0.2, "arm_base": 0.4, "knee_bend": 0.3},
			{"lean": -0.35, "crouch": 0.15, "leg_base": 1.2, "arm_base": 0.2, "knee_bend": 0.15},
			{"lean": 0.1, "leg_base": 0.3, "arm_base": 0.4, "knee_bend": 0.3},
		]),
		# Tic-tac : pied planté sur le mur, poussée, genoux groupés au-dessus du sommet.
		&"tic_tac": _figure([0.0, 0.3, 0.7, 1.0], [
			{"lean": 0.2, "crouch": 0.25, "leg_base": 1.35, "arm_base": 1.0, "knee_bend": 0.95},
			{"lean": 0.1, "leg_base": 1.0, "arm_base": 2.5, "knee_bend": 0.2},
			{"lean": 0.35, "crouch": 0.3, "leg_base": 0.95, "arm_base": 1.3, "knee_bend": 0.95},
			{"lean": 0.2, "leg_base": 0.4, "arm_base": 0.6, "knee_bend": 0.5},
		]),
		# Wall flip : salto arrière en se repoussant du mur (un tour vers l'arrière).
		&"wall_flip": _figure([0.0, 0.2, 0.6, 0.85, 1.0], [
			{"lean": -0.3, "leg_base": 0.8, "arm_base": 2.6, "knee_bend": 0.7, "rotation": 0.0},
			{"crouch": 0.3, "leg_base": 1.25, "arm_base": 1.6, "knee_bend": 1.1, "rotation": -1.2},
			{"crouch": 0.35, "leg_base": 1.35, "arm_base": 1.4, "knee_bend": 1.2, "rotation": -4.5},
			{"leg_base": 0.4, "arm_base": 2.0, "knee_bend": 0.5, "rotation": -6.0},
			{"leg_base": 0.3, "arm_base": 0.8, "knee_bend": 0.4, "rotation": -TAU},
		]),
		# Salto avant : bras lancés, groupé, ouverture avant la réception.
		&"front_flip": _figure([0.0, 0.15, 0.7, 0.9, 1.0], [
			{"lean": 0.3, "leg_base": 0.3, "arm_base": 2.8, "knee_bend": 0.3, "rotation": 0.0},
			{"crouch": 0.3, "leg_base": 1.3, "arm_base": 1.4, "knee_bend": 1.2, "rotation": 0.8},
			{"crouch": 0.35, "leg_base": 1.4, "arm_base": 1.3, "knee_bend": 1.25, "rotation": 5.2},
			{"leg_base": 0.5, "arm_base": 2.2, "knee_bend": 0.5, "rotation": 6.1},
			{"leg_base": 0.4, "arm_base": 1.2, "knee_bend": 0.4, "rotation": TAU},
		]),
		# Vrille : salto avant avec un tour complet sur soi-même.
		&"corkscrew": _figure([0.0, 0.5, 1.0], [
			{"lean": 0.2, "leg_base": 0.3, "arm_base": 2.9, "knee_bend": 0.3, "rotation": 0.0, "spin": 0.0},
			{"crouch": 0.3, "leg_base": 1.2, "arm_base": 1.2, "knee_bend": 1.1, "rotation": PI, "spin": PI},
			{"leg_base": 0.4, "arm_base": 1.6, "knee_bend": 0.4, "rotation": TAU, "spin": TAU},
		]),
		# Cat leap : arrivée accroché au rebord, pieds amortissant contre le mur.
		&"cat_leap": _figure([0.0, 1.0], [
			{"lean": 0.3, "crouch": 0.4, "leg_base": 1.5, "arm_base": 2.9, "knee_bend": 1.2},
			{"lean": 0.2, "crouch": 0.35, "leg_base": 1.3, "arm_base": 2.95, "knee_bend": 1.0},
		]),
		# Roulade : tour complet vers l'avant, groupé.
		&"parkour_roll": _figure([0.0, 0.5, 1.0], [
			{"lean": 0.8, "crouch": 0.6, "leg_base": 1.3, "arm_base": 1.4, "knee_bend": 1.1, "rotation": 0.0},
			{"lean": 0.9, "crouch": 0.7, "leg_base": 1.6, "arm_base": 1.3, "knee_bend": 1.3, "rotation": PI},
			{"lean": 0.3, "crouch": 0.3, "leg_base": 0.4, "arm_base": 0.5, "knee_bend": 0.5, "rotation": TAU},
		]),
	}
	return library


## Immeuble dont le toit est à la hauteur `top` (négatif = plus haut que l'entrée).
func _roof(x: float, width: float, top: float = 0.0) -> Rect2:
	return Rect2(x, top, width, BUILDING_DEPTH)


## Obstacle posé sur un toit dont le dessus est à `base`.
func _box(x: float, width: float, height: float, base: float = 0.0) -> Rect2:
	return Rect2(x, base - height, width, height)


## Plafond de tunnel laissant `clearance` px au-dessus du toit `base`.
func _ceiling(x: float, width: float, clearance: float, base: float = 0.0) -> Rect2:
	return Rect2(x, base - 420.0, width, 420.0 - clearance)


## Poutre fine au-dessus du vide (pas de paroi pour courir).
func _beam(x: float, width: float, top: float) -> Rect2:
	return Rect2(x, top, width, BEAM_THICKNESS)


func _chunk(
	id: StringName,
	width: float,
	blocks: Array[Rect2],
	difficulty: int,
	tags: Array[StringName],
	exit_y: float = 0.0
) -> ChunkLayout:
	var layout: ChunkLayout = ChunkLayout.new()
	layout.id = id
	layout.width = width
	layout.exit_y = exit_y
	layout.blocks = blocks
	layout.difficulty = difficulty
	layout.tags = tags
	return layout


## Tronçons sur les toits, en 5 paliers (0 initiation → 4 expert). Le toit
## d'entrée est à y = 0, celui de sortie à exit_y ; les 140 premiers px sont
## libres (réapparition). LevelValidator et le test de jouabilité (pilote
## automatique) vérifient qu'ils sont franchissables.
func _chunk_library() -> ChunkLibrary:
	var library: ChunkLibrary = ChunkLibrary.new()
	library.start_id = &"flat_run"
	library.layouts = [
		# --- Palier 0 : initiation ---------------------------------------------------
		_chunk(&"flat_run", 800.0, [_roof(0, 800)], 0, []),
		_chunk(&"vault_pair", 900.0, [
			_roof(0, 900), _box(300, 100, 40), _box(620, 90, 36),
		], 0, [&"vault"]),
		_chunk(&"low_tunnel", 1000.0, [
			_roof(0, 1000), _ceiling(380, 380, 48),
		], 0, [&"slide"]),
		# --- Palier 1 : premiers sauts entre toits ---------------------------------------
		_chunk(&"small_gap", 900.0, [_roof(0, 360), _roof(520, 380)], 1, [&"gap"]),
		_chunk(&"step_platform", 1000.0, [_roof(0, 1000), _box(360, 300, 100)], 1, [&"jump", &"wall"]),
		_chunk(&"roof_hop", 1100.0, [
			_roof(0, 320), _roof(460, 280), _roof(880, 220),
		], 1, [&"gap"]),
		_chunk(&"stairs_up", 1000.0, [_roof(0, 380), _roof(500, 500, -110)], 1, [&"gap", &"climb"], -110.0),
		_chunk(&"drop_down", 1000.0, [_roof(0, 420), _roof(560, 440, 140)], 1, [&"gap", &"drop"], 140.0),
		# --- Palier 2 : murs, enchaînements, dénivelés --------------------------------------
		_chunk(&"wall_ledge", 1000.0, [_roof(0, 1000), _box(460, 90, 220)], 2, [&"wall"]),
		_chunk(&"tunnel_then_vault", 1100.0, [
			_roof(0, 1100), _ceiling(240, 320, 48), _box(820, 100, 40),
		], 2, [&"slide", &"vault"]),
		_chunk(&"double_gap", 1200.0, [
			_roof(0, 320), _roof(480, 240), _roof(880, 320),
		], 2, [&"gap"]),
		_chunk(&"roof_climb", 1000.0, [_roof(0, 500), _roof(500, 500, -200)], 2, [&"wall", &"climb"], -200.0),
		_chunk(&"vent_field", 1200.0, [
			_roof(0, 1200), _box(300, 80, 40), _box(560, 70, 44), _box(820, 90, 40),
		], 2, [&"vault"]),
		_chunk(&"gap_drop_roll", 1100.0, [_roof(0, 400), _roof(580, 520, 240)], 2, [&"gap", &"drop", &"roll"], 240.0),
		# --- Palier 3 : précision et combinaisons -------------------------------------------
		_chunk(&"high_wall", 1100.0, [_roof(0, 1100), _box(520, 100, 260)], 3, [&"wall"]),
		_chunk(&"gap_then_wall", 1300.0, [
			_roof(0, 380), _roof(540, 760), _box(900, 90, 200),
		], 3, [&"gap", &"wall"]),
		_chunk(&"precision_hops", 1300.0, [
			_roof(0, 300), _roof(470, 90, -40), _roof(730, 90, -90), _roof(990, 310, -60),
		], 3, [&"gap", &"precision"], -60.0),
		_chunk(&"slide_gap", 1200.0, [
			_roof(0, 520), _ceiling(240, 240, 48), _roof(680, 520),
		], 3, [&"slide", &"gap"]),
		_chunk(&"upper_route", 1400.0, [
			_roof(0, 1400), _box(500, 90, 40), _box(950, 90, 40),
			_beam(380, 220, -130), _beam(700, 220, -170), _beam(1020, 200, -130),
		], 3, [&"vault", &"route"]),
		_chunk(&"wall_gap_wall", 1500.0, [
			_roof(0, 400), _roof(540, 300, -180), _roof(1000, 500),
		], 3, [&"gap", &"wall", &"drop"]),
		# --- Palier 4 : expert ------------------------------------------------------------
		_chunk(&"skyline_run", 1800.0, [
			_roof(0, 380), _roof(560, 300, -60), _roof(860, 360, -260), _roof(1400, 400, -100),
		], 4, [&"gap", &"wall", &"drop"], -100.0),
		_chunk(&"crane_line", 1600.0, [
			_roof(0, 300), _beam(460, 140, -60), _beam(760, 140, -100), _beam(1060, 140, -60),
			_roof(1340, 260),
		], 4, [&"gap", &"precision"]),
		_chunk(&"tunnel_drop_climb", 1600.0, [
			_roof(0, 600), _ceiling(200, 300, 48), _roof(760, 400, 100), _roof(1160, 440, -150),
		], 4, [&"slide", &"drop", &"wall"], -150.0),
		_chunk(&"rooftop_gauntlet", 2000.0, [
			_roof(0, 420), _box(180, 80, 40), _roof(600, 400, -40), _ceiling(780, 180, 48, -40),
			_beam(1160, 140, -120), _roof(1460, 540, -40),
		], 4, [&"vault", &"gap", &"slide", &"precision"], -40.0),
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
