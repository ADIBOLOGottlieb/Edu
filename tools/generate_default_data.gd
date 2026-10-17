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
const STYLE_PATH: String = "res://data/animations/protagonist_style.tres"
const LOME_THEME_PATH: String = "res://data/cities/lome_theme.tres"
const LOME_PATH: String = "res://data/cities/lome.tres"
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
	# Valeurs par défaut du script = silhouette du protagoniste (sweat, cargo, baskets).
	_save(SilhouetteStyle.new(), STYLE_PATH, force)
	_save(_lome_theme(), LOME_THEME_PATH, force)
	_save(_lome_city(load(LOME_THEME_PATH) as CityTheme), LOME_PATH, force)
	quit()


# --- Villes (docs/PROPOSITION_TOUR_DU_MONDE.md) ----------------------------------------

## Lomé, ville de départ : fin d'après-midi dorée sur le golfe de Guinée.
func _lome_theme() -> CityTheme:
	var theme: CityTheme = CityTheme.new()
	theme.id = &"lome"
	theme.display_name = "Lomé"
	theme.sky_top = Color(0.33, 0.48, 0.66)
	theme.sky_horizon = Color(0.99, 0.77, 0.50)
	theme.sun_position = Vector2(0.78, 0.66)
	theme.sun_radius = 46.0
	theme.sun_color = Color(1.0, 0.88, 0.62)
	theme.far_color = Color(0.82, 0.62, 0.52)
	theme.mid_color = Color(0.53, 0.38, 0.37)
	theme.near_color = Color(0.27, 0.20, 0.22)
	theme.ink = Color(0.04, 0.035, 0.045)
	theme.accent = Color(1.0, 0.72, 0.30)
	theme.prop_style = &"lome"
	theme.tin_roofs = true
	theme.palm_trees = true
	theme.satellite_dishes = true
	theme.power_lines = true
	theme.monument = &"lome_independence"
	theme.landmarks = [&"cathedral", &"colombe_paix", &"deux_lions", &"beach_palms", &"palais_lome", &"hotel_tower"] as Array[StringName]
	theme.seed_value = 228
	return theme


func _route(id: StringName, display_name: String, difficulty: int, chunks: Array[StringName]) -> CityRoute:
	var route: CityRoute = CityRoute.new()
	route.id = id
	route.display_name = display_name
	route.difficulty = difficulty
	route.chunk_ids = chunks
	return route


## Cinq parcours du plus facile au plus dur, faits des tronçons existants.
func _lome_city(theme: CityTheme) -> CityDefinition:
	var city: CityDefinition = CityDefinition.new()
	city.id = &"lome"
	city.display_name = "Lomé"
	city.country = "Togo"
	city.theme = theme
	city.routes = [
		_route(&"lome_grand_marche", "Grand Marché", 0, [
			&"flat_run", &"vault_pair", &"low_tunnel", &"small_gap", &"step_platform", &"flat_run",
		] as Array[StringName]),
		_route(&"lome_boulevard", "Boulevard du 13-Janvier", 1, [
			&"flat_run", &"roof_hop", &"stairs_up", &"vent_field", &"drop_down", &"tunnel_then_vault", &"flat_run",
		] as Array[StringName]),
		_route(&"lome_be", "Quartier Bè", 2, [
			&"flat_run", &"double_gap", &"wall_ledge", &"roof_climb", &"gap_drop_roll", &"slide_gap", &"flat_run",
		] as Array[StringName]),
		_route(&"lome_cathedrale", "Cathédrale", 3, [
			&"flat_run", &"high_wall", &"precision_hops", &"upper_route", &"gap_then_wall", &"wall_gap_wall", &"flat_run",
		] as Array[StringName]),
		_route(&"lome_independance", "Place de l'Indépendance", 4, [
			&"flat_run", &"skyline_run", &"crane_line", &"tunnel_drop_climb", &"rooftop_gauntlet", &"flat_run",
		] as Array[StringName]),
	] as Array[CityRoute]
	return city


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
## Chaque figure suit le schéma d'un mouvement réel : anticipation (fléchi, bras
## armés), action, puis suite du mouvement (amorti, retour à l'équilibre). Deux
## images clés consécutives ne sont jamais identiques : le corps reste vivant.
## Pas de stride ni d'arm_swing dans les figures (le cycle y est figé).
func _figure_library() -> FigureLibrary:
	var library: FigureLibrary = FigureLibrary.new()
	library.animations = {
		# Speed vault : appel fléchi, main arrière posée sur l'obstacle, jambes
		# balancées ensemble par-dessus, bras avant levé pour l'équilibre, sortie en course.
		&"speed_vault": _figure([0.0, 0.3, 0.55, 0.8, 1.0], [
			{"lean": 0.4, "crouch": 0.3, "leg_base": 0.45, "leg_split": 0.2, "knee_bend": 0.75, "arm_base": 0.9, "arm_spread": 0.4},
			{"lean": -0.1, "crouch": 0.25, "leg_base": 1.2, "leg_split": 0.15, "knee_bend": 0.45, "arm_base": 0.7, "arm_spread": 1.0},
			{"lean": -0.2, "crouch": 0.2, "leg_base": 1.4, "leg_split": 0.2, "knee_bend": 0.3, "arm_base": 0.9, "arm_spread": 1.05},
			{"lean": 0.15, "crouch": 0.15, "leg_base": 0.8, "leg_split": 0.35, "knee_bend": 0.4, "arm_base": 1.1, "arm_spread": 0.85},
			{"lean": 0.3, "crouch": 0.12, "leg_base": 0.25, "leg_split": 0.25, "knee_bend": 0.45, "arm_base": 0.3, "arm_spread": 0.5},
		]),
		# Kong vault : appel bras armés en arrière, plongeon bras lancés, corps à
		# l'horizontale mains à plat, jambes ramenées entre les bras, réception amortie.
		&"kong_vault": _figure([0.0, 0.2, 0.42, 0.62, 0.82, 1.0], [
			{"lean": 0.5, "crouch": 0.35, "leg_base": 0.1, "leg_split": 0.4, "knee_bend": 0.7, "arm_base": -0.4, "arm_spread": 0.15},
			{"lean": 0.9, "crouch": 0.1, "leg_base": -0.35, "leg_split": 0.3, "knee_bend": 0.25, "arm_base": 1.6, "arm_spread": 0.1},
			{"lean": 1.35, "crouch": 0.1, "leg_base": -0.7, "leg_split": 0.15, "knee_bend": 0.3, "arm_base": 0.2, "arm_spread": 0.05},
			{"lean": 0.8, "crouch": 0.35, "leg_base": 1.2, "leg_split": 0.05, "knee_bend": 1.1, "arm_base": -0.4, "arm_spread": 0.2},
			{"lean": 0.35, "crouch": 0.05, "leg_base": 0.55, "leg_split": 0.35, "knee_bend": 0.45, "arm_base": 1.1, "arm_spread": 0.8},
			{"lean": 0.45, "crouch": 0.35, "leg_base": 0.6, "leg_split": 0.3, "knee_bend": 0.8, "arm_base": 0.7, "arm_spread": 0.6},
		]),
		# Lazy vault : passage lent, main arrière posée, jambe d'attaque levée puis
		# ciseaux par-dessus, reprise d'appui en marchant.
		&"lazy_vault": _figure([0.0, 0.3, 0.55, 0.8, 1.0], [
			{"lean": 0.15, "crouch": 0.1, "leg_base": 0.35, "leg_split": 0.15, "knee_bend": 0.4, "arm_base": 0.5, "arm_spread": 0.2},
			{"lean": -0.15, "crouch": 0.15, "leg_base": 0.9, "leg_split": 0.45, "knee_bend": 0.3, "arm_base": 0.6, "arm_spread": 0.8},
			{"lean": -0.35, "crouch": 0.15, "leg_base": 1.25, "leg_split": 0.4, "knee_bend": 0.15, "arm_base": 0.65, "arm_spread": 0.95},
			{"lean": -0.05, "crouch": 0.1, "leg_base": 0.6, "leg_split": 0.4, "knee_bend": 0.3, "arm_base": 0.6, "arm_spread": 0.6},
			{"lean": 0.12, "crouch": 0.08, "leg_base": 0.3, "leg_split": 0.2, "knee_bend": 0.35, "arm_base": 0.4, "arm_spread": 0.3},
		]),
		# Tic-tac (franchissement de clôture) : pied planté sur le mur bras armés,
		# poussée en extension bras lancés, genou posé sur le sommet (hanche par-dessus),
		# poussée et plongeon de l'autre côté, corps qui se prépare à la réception.
		&"tic_tac": _figure([0.0, 0.25, 0.5, 0.75, 1.0], [
			{"lean": 0.2, "crouch": 0.3, "leg_base": 0.75, "leg_split": 0.7, "knee_bend": 0.8, "arm_base": 0.2, "arm_spread": 0.6},
			{"lean": 0.05, "leg_base": 0.5, "leg_split": 0.5, "knee_bend": 0.2, "arm_base": 2.4, "arm_spread": 0.6},
			{"lean": 0.45, "crouch": 0.3, "leg_base": 1.1, "leg_split": 0.5, "knee_bend": 1.1, "arm_base": 0.6, "arm_spread": 0.3},
			{"lean": 0.7, "crouch": 0.1, "leg_base": 0.2, "leg_split": 0.45, "knee_bend": 0.35, "arm_base": 1.7, "arm_spread": 0.5},
			{"lean": 0.3, "crouch": 0.3, "leg_base": 0.55, "leg_split": 0.3, "knee_bend": 0.7, "arm_base": 0.8, "arm_spread": 0.6},
		]),
		# Wall flip : pieds fléchis contre le mur bras armés en bas, poussée bras lancés
		# au-dessus de la tête, groupé serré, ouverture avant le sol, réception amortie.
		&"wall_flip": _figure([0.0, 0.15, 0.4, 0.65, 0.85, 1.0], [
			{"lean": 0.3, "crouch": 0.3, "leg_base": 0.9, "leg_split": 0.25, "knee_bend": 0.95, "arm_base": -0.5, "arm_spread": 0.2, "rotation": 0.0},
			{"lean": -0.25, "leg_base": 0.3, "leg_split": 0.2, "knee_bend": 0.25, "arm_base": 2.9, "arm_spread": 0.2, "rotation": -0.7},
			{"lean": 0.4, "crouch": 0.3, "leg_base": 1.5, "leg_split": 0.05, "knee_bend": 1.45, "arm_base": 1.0, "arm_spread": 0.1, "rotation": -2.9},
			{"lean": 0.45, "crouch": 0.32, "leg_base": 1.6, "knee_bend": 1.5, "arm_base": 0.95, "arm_spread": 0.05, "rotation": -4.9},
			{"lean": 0.1, "leg_base": 0.5, "leg_split": 0.2, "knee_bend": 0.45, "arm_base": 1.6, "arm_spread": 0.75, "rotation": -5.95},
			{"lean": 0.4, "crouch": 0.4, "leg_base": 0.65, "leg_split": 0.2, "knee_bend": 0.85, "arm_base": 1.1, "arm_spread": 0.6, "rotation": -TAU},
		]),
		# Salto avant groupé (depuis la course) : appel accroupi bras balancés en
		# arrière, bras lancés vers le ciel, genoux à la poitrine mains aux tibias,
		# ouverture avant le sol, réception accroupie (enchaîne sur la roulade/réception).
		&"front_flip": _figure([0.0, 0.12, 0.32, 0.6, 0.8, 0.93, 1.0], [
			{"lean": 0.45, "crouch": 0.35, "leg_base": 0.35, "leg_split": 0.2, "knee_bend": 0.75, "arm_base": -0.7, "arm_spread": 0.15, "rotation": 0.0},
			{"lean": 0.15, "leg_base": -0.1, "leg_split": 0.15, "knee_bend": 0.15, "arm_base": 2.9, "arm_spread": 0.15, "rotation": 0.35},
			{"lean": 0.55, "crouch": 0.3, "leg_base": 1.6, "leg_split": 0.05, "knee_bend": 1.55, "arm_base": 0.95, "arm_spread": 0.1, "rotation": 2.2},
			{"lean": 0.6, "crouch": 0.32, "leg_base": 1.7, "knee_bend": 1.6, "arm_base": 0.9, "arm_spread": 0.05, "rotation": 4.6},
			{"lean": 0.15, "crouch": 0.05, "leg_base": 0.55, "leg_split": 0.15, "knee_bend": 0.45, "arm_base": 1.5, "arm_spread": 0.65, "rotation": 5.9},
			{"lean": 0.35, "crouch": 0.35, "leg_base": 0.7, "leg_split": 0.2, "knee_bend": 0.85, "arm_base": 1.3, "arm_spread": 0.6, "rotation": 6.2},
			{"lean": 0.45, "crouch": 0.45, "leg_base": 0.6, "leg_split": 0.15, "knee_bend": 0.9, "arm_base": 1.0, "arm_spread": 0.5, "rotation": TAU},
		]),
		# Vrille : bras lancés, groupé pendant la rotation et la vrille, ouverture
		# bras écartés, réception amortie.
		&"corkscrew": _figure([0.0, 0.2, 0.55, 0.82, 1.0], [
			{"lean": 0.15, "leg_base": 0.2, "leg_split": 0.25, "knee_bend": 0.35, "arm_base": 2.7, "arm_spread": 0.5, "rotation": 0.0, "spin": 0.0},
			{"lean": 0.35, "crouch": 0.2, "leg_base": 1.0, "knee_bend": 1.0, "arm_base": 1.6, "arm_spread": 0.3, "rotation": 1.0, "spin": 0.9},
			{"lean": 0.5, "crouch": 0.3, "leg_base": 1.45, "knee_bend": 1.4, "arm_base": 1.0, "arm_spread": 0.1, "rotation": 3.7, "spin": 3.6},
			{"lean": 0.15, "crouch": 0.05, "leg_base": 0.5, "leg_split": 0.2, "knee_bend": 0.45, "arm_base": 1.5, "arm_spread": 0.75, "rotation": 5.8, "spin": 5.9},
			{"lean": 0.35, "crouch": 0.3, "leg_base": 0.6, "leg_split": 0.25, "knee_bend": 0.75, "arm_base": 1.2, "arm_spread": 0.6, "rotation": TAU, "spin": TAU},
		]),
		# Cat leap (escalade de clôture) : bras tendus vers le rebord, mains qui
		# accrochent bras fléchis, genoux remontés pieds plantés contre le mur, un pied
		# monte d'un pas, puis le corps se pose en suspension (enchaîne sur ledge_hang).
		&"cat_leap": _figure([0.0, 0.35, 0.7, 1.0], [
			{"lean": 0.1, "crouch": 0.1, "leg_base": 0.5, "leg_split": 0.2, "knee_bend": 0.45, "arm_base": 3.0, "arm_spread": 0.1},
			{"lean": 0.3, "crouch": 0.35, "leg_base": 1.3, "leg_split": 0.3, "knee_bend": 1.15, "arm_base": 2.7, "arm_spread": 0.15},
			{"lean": 0.35, "crouch": 0.4, "leg_base": 1.4, "leg_split": 0.45, "knee_bend": 1.25, "arm_base": 2.75, "arm_spread": 0.1},
			{"lean": 0.25, "crouch": 0.3, "leg_base": 1.2, "leg_split": 0.3, "knee_bend": 1.05, "arm_base": 2.85, "arm_spread": 0.08},
		]),
		# Roulade : réception accroupie mains vers le sol, groupé serré sur l'épaule,
		# déroulé pieds au sol, relevé en course bras ouverts.
		&"parkour_roll": _figure([0.0, 0.25, 0.55, 0.8, 1.0], [
			{"lean": 0.9, "crouch": 0.75, "leg_base": 1.1, "leg_split": 0.2, "knee_bend": 1.15, "arm_base": 1.3, "arm_spread": 0.25, "rotation": 0.0},
			{"lean": 1.0, "crouch": 0.85, "leg_base": 1.7, "knee_bend": 1.5, "arm_base": 1.1, "arm_spread": 0.15, "rotation": 1.9},
			{"lean": 0.95, "crouch": 0.85, "leg_base": 1.75, "leg_split": 0.05, "knee_bend": 1.55, "arm_base": 0.95, "arm_spread": 0.1, "rotation": 4.1},
			{"lean": 0.7, "crouch": 0.65, "leg_base": 1.0, "leg_split": 0.3, "knee_bend": 1.1, "arm_base": 1.2, "arm_spread": 0.4, "rotation": 5.85},
			{"lean": 0.35, "crouch": 0.25, "leg_base": 0.35, "leg_split": 0.35, "knee_bend": 0.55, "arm_base": 0.4, "arm_spread": 0.6, "rotation": TAU},
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
	_add_hazards(library)
	return library


# --- Pièges (style Ninja Arashi) -----------------------------------------------------

func _hazard(
	kind: StringName, rect: Rect2, path_to: Vector2 = Vector2.ZERO,
	period: float = 0.0, phase: float = 0.0, active_ratio: float = 0.5
) -> HazardSpec:
	var spec: HazardSpec = HazardSpec.new()
	spec.kind = kind
	spec.rect = rect
	spec.path_to = path_to
	spec.period = period
	spec.phase = phase
	spec.active_ratio = active_ratio
	return spec


## Pics posés sur une surface dont le dessus est à `top`.
func _spikes(x: float, width: float, top: float = 0.0) -> HazardSpec:
	return _hazard(&"spikes", Rect2(x, top - 16.0, width, 16.0))


## Jet de flammes vertical depuis le sol (`top`), intermittent.
func _flame(x: float, period: float, phase: float = 0.0, top: float = 0.0) -> HazardSpec:
	return _hazard(&"flame", Rect2(x, top - 120.0, 22.0, 120.0), Vector2.ZERO, period, phase, 0.4)


## Écraseur qui s'abat jusqu'au toit `top` (bloc de 60 px, course de `drop`).
func _crusher(x: float, period: float, top: float = 0.0, drop: float = 90.0, phase: float = 0.0) -> HazardSpec:
	return _hazard(&"crusher", Rect2(x, top - drop - 60.0, 80.0, 60.0), Vector2(0.0, drop), period, phase, 0.45)


## Scie mobile (diamètre 44 px) de `from` vers `from + path`.
func _saw(from: Vector2, path: Vector2, period: float, phase: float = 0.0) -> HazardSpec:
	return _hazard(&"saw", Rect2(from, Vector2(44.0, 44.0)), path, period, phase)


## Pièges par tronçon, du palier 1 au palier 4 (le palier 0 reste une initiation
## sans piège). Les 140 premiers px de chaque tronçon restent sûrs (réapparition).
## Le pilote automatique doit tous les franchir (tests de jouabilité).
func _add_hazards(library: ChunkLibrary) -> void:
	var hazards: Dictionary[StringName, Array] = {
		# Palier 1 : pics à sauter, première flamme rythmée.
		&"small_gap": [_spikes(800, 50)],
		&"step_platform": [_flame(780, 2.0)],
		&"stairs_up": [_spikes(660, 64, -110)],
		&"drop_down": [_spikes(935, 45, 140)],
		# Palier 2 : scie, écraseur, flammes désynchronisées.
		&"wall_ledge": [_saw(Vector2(900, -150), Vector2(0, 106), 2.2)],
		&"tunnel_then_vault": [_spikes(680, 60)],
		&"roof_climb": [_crusher(720, 2.8, -200, 80.0)],
		&"vent_field": [_flame(455, 1.8, 0.0), _flame(715, 1.8, 0.5)],
		&"gap_drop_roll": [_spikes(985, 55, 240)],
		# Palier 3 : enchaînements précis.
		&"high_wall": [_crusher(790, 2.6)],
		&"gap_then_wall": [_spikes(1210, 50)],
		&"upper_route": [_spikes(1260, 60)],
		&"wall_gap_wall": [_spikes(700, 50, -180)],
		# Palier 4 : expert.
		&"skyline_run": [_saw(Vector2(1080, -420), Vector2(0, 100), 2.2)],
		&"tunnel_drop_climb": [_crusher(900, 2.6, 100.0, 80.0)],
		&"rooftop_gauntlet": [_flame(1900, 1.8, 0.0, -40.0)],
	}
	for layout: ChunkLayout in library.layouts:
		if hazards.has(layout.id):
			var specs: Array[HazardSpec] = []
			for spec: Variant in hazards[layout.id]:
				specs.append(spec as HazardSpec)
			layout.hazards = specs


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
			"lean": 0.04, "crouch": 0.04, "arm_base": 0.15, "arm_spread": 0.1,
			"arm_swing": 0.03, "knee_bend": 0.08, "cycle_hz": 0.5,
		}),
		# Course et sprint : cycle de foulée humain par images clés (RunnerVisual),
		# stride = amplitude du cycle (et du balancement des bras, coudes à ~90°).
		# Buste penché vers l'avant, phase de suspension ; le sprint penche davantage.
		&"run": _clip({
			"lean": 0.24, "crouch": 0.06, "leg_base": 0.05, "arm_base": 0.12,
			"stride": 0.85, "arm_swing": 0.8, "knee_bend": 0.3, "cycle_hz": 1.45,
		}),
		&"sprint": _clip({
			"lean": 0.42, "crouch": 0.1, "leg_base": 0.08, "arm_base": 0.18,
			"stride": 1.05, "arm_swing": 1.0, "knee_bend": 0.35, "cycle_hz": 1.3,
		}),
		# Bond : genou avant monté, jambe arrière en poussée, bras lancés vers le haut
		# (bras avant au-dessus de la tête, bras arrière devant).
		&"jump": _clip({
			"lean": 0.2, "crouch": 0.02, "leg_base": 0.4, "leg_split": 0.75,
			"knee_bend": 0.6, "arm_base": 1.9, "arm_spread": 0.9,
		}),
		# Chute : pose de l'image de référence du coureur — en suspension, bras
		# écartés vers le bas mains ouvertes, jambes droites serrées, pieds pointés.
		&"fall": _clip({
			"lean": 0.02, "leg_base": 0.05, "leg_split": 0.06, "knee_bend": 0.12,
			"arm_base": 0.45, "arm_spread": 0.4, "arm_swing": 0.06, "cycle_hz": 0.8,
		}),
		# Réception : accroupi profond pour amortir, buste penché, main avant tendue
		# vers le sol, bras arrière en équilibre.
		&"landing": _clip({
			"lean": 0.6, "crouch": 0.75, "leg_base": 0.6, "leg_split": 0.3,
			"knee_bend": 1.05, "arm_base": 0.35, "arm_spread": 0.45,
		}),
		&"slide": _clip({
			"lean": -0.9, "crouch": 0.7, "leg_base": 1.3, "leg_split": 0.25,
			"knee_bend": 0.25, "arm_base": -0.4, "arm_spread": 0.5,
		}),
		# Double saut : genoux ramenés vers la poitrine, bras qui tirent vers le haut.
		&"double_jump": _clip({
			"lean": 0.25, "crouch": 0.1, "leg_base": 1.1, "leg_split": 0.15,
			"arm_base": 2.2, "arm_spread": 0.5, "arm_swing": 0.3, "knee_bend": 1.05,
			"cycle_hz": 2.0,
		}),
		# Roulade : groupé serré, mains vers le sol devant.
		&"roll": _clip({
			"lean": 1.3, "crouch": 0.85, "leg_base": 1.7, "leg_split": 0.05,
			"arm_base": 1.4, "arm_spread": 0.2, "knee_bend": 1.15,
		}),
		# Franchissement : mains posées sur l'obstacle.
		&"vault": _clip({
			"lean": 0.5, "crouch": 0.2, "leg_base": 1.1, "arm_base": 0.3,
			"arm_spread": 0.2, "knee_bend": 0.9,
		}),
		# Course murale : longues foulées contre le mur, bras qui balancent fort.
		&"wall_run": _clip({
			"lean": -0.05, "crouch": 0.05, "leg_base": 0.75, "leg_split": 0.55,
			"arm_base": 1.2, "arm_spread": 0.8, "stride": 0.55, "arm_swing": 0.8,
			"knee_bend": 0.5, "cycle_hz": 1.6,
		}),
		# Escalade (clôture) : mains qui tirent au-dessus de la tête, genoux hauts,
		# pieds plantés qui « marchent » le long du mur.
		&"wall_climb": _clip({
			"lean": 0.2, "crouch": 0.15, "leg_base": 1.05, "leg_split": 0.1,
			"arm_base": 2.6, "arm_spread": 0.15, "arm_swing": 0.35, "stride": 0.5,
			"knee_bend": 0.95, "cycle_hz": 1.0,
		}),
		# Suspension au rebord : mains accrochées bras légèrement fléchis, genoux
		# remontés, pieds plantés contre le mur (prêt pour la hanche par-dessus).
		# Léger mouvement des pieds qui cherchent l'appui.
		&"ledge_hang": _clip({
			"lean": 0.25, "crouch": 0.3, "leg_base": 1.15, "leg_split": 0.3,
			"arm_base": 2.85, "arm_spread": 0.08, "arm_swing": 0.12, "stride": 0.1,
			"knee_bend": 1.0, "cycle_hz": 0.4,
		}),
	}
	return anims
