extends SceneTree
## Vidéo tutoriel complète du jeu (pour les joueurs) : menus, commandes, figures
## de parkour, pièges, vigile, objets, pause, résultat, énergie, réglages.
## Le pilote automatique joue ; les sous-titres suivent ce que fait le coureur et
## le bouton tactile utilisé s'allume. Sauvegarde isolée (la vraie n'est pas touchée).
## Usage (Movie Maker de Godot, 30 images/s, fenêtre nécessaire) :
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <sortie.avi> -s tools/record_tutorial.gd
## Puis : ffmpeg -i sortie.avi -c:v libx264 -pix_fmt yuv420p -crf 20 tutoriel.mp4

const FPS: int = 30
const SAVE_DIR: String = "user://capture_saves/tutorial"
const LOME: String = "res://data/cities/lome.tres"
## Tronçons riches en figures (comme tools/capture_motion.gd), décor de Lomé.
const MOVES_ROUTE: Array[StringName] = [
	&"flat_run", &"vault_pair", &"low_tunnel", &"small_gap", &"wall_ledge", &"gap_drop_roll",
	&"tunnel_then_vault", &"high_wall", &"precision_hops", &"rooftop_gauntlet", &"flat_run",
]
## Démonstrations mise en scène, une par mouvement : blocs, commandes tenues et
## action déclenchée (« special », voir _demo_tick). Repris de tools/capture_figures.gd.
const FIGURE_DEMOS: Array[Dictionary] = [
	{"text": "SAUT : en courant, appuie sur SAUT au bord pour franchir un trou.",
		"blocks": [], "sprint": false, "axis": 1.0, "special": &"gap"},
	{"text": "GLISSE : en courant, appuie sur GLISSE pour passer sous un obstacle.",
		"blocks": [Rect2(330, -420, 260, 370)], "sprint": false, "axis": 1.0, "special": &"slide"},
	{"text": "Franchissement : cours (sans sprint) vers un obstacle bas. C'est automatique.",
		"blocks": [Rect2(300, -40, 100, 40)], "sprint": false, "axis": 1.0, "special": &""},
	{"text": "Franchissement rapide : obstacle très bas pris en SPRINT.",
		"blocks": [Rect2(300, -20, 100, 20)], "sprint": true, "axis": 1.0, "special": &""},
	{"text": "Saut de chat (kong) : obstacle bas pris en SPRINT, mains en avant.",
		"blocks": [Rect2(300, -40, 100, 40)], "sprint": true, "axis": 1.0, "special": &""},
	{"text": "Tic-tac : en SPRINT, fonce vers un mur un peu trop haut. Rebond automatique.",
		"blocks": [Rect2(300, -100, 120, 100)], "sprint": true, "axis": 1.0, "special": &""},
	{"text": "Escalade et rebord : cours vers un mur haut en gardant la direction. En haut, garde-la pour te hisser.",
		"blocks": [Rect2(300, -190, 700, 190)], "sprint": false, "axis": 1.0, "special": &"", "time": 6.5},
	{"text": "Saut mural : pendant la course sur le mur, appuie sur SAUT.",
		"blocks": [Rect2(300, -400, 60, 400)], "sprint": true, "axis": 1.0, "special": &"wall_jump"},
	{"text": "Salto avant : en SPRINT, appuie sur SAUT au bord d'un toit.",
		"blocks": [], "sprint": true, "axis": 1.0, "special": &"gap"},
	{"text": "Saut de chat au mur : SAUT vers un mur, tu attrapes le rebord en plein élan.",
		"blocks": [Rect2(300, -200, 60, 200)], "sprint": false, "axis": 0.8, "special": &"jump_at_200"},
	{"text": "Roulade : après une grande chute, appuie sur GLISSE juste avant de toucher le sol.",
		"blocks": [], "sprint": true, "axis": 1.0, "special": &"drop_roll"},
	{"text": "Double saut (capacité à débloquer) : SAUT, puis SAUT encore en l'air.",
		"blocks": [], "sprint": false, "axis": 0.0, "special": &"double_jump"},
]
## Sous-titre affiché au moins ce temps (s) avant d'être remplacé par un sous-titre vivant.
const LIVE_MIN_TIME: float = 2.4
## Place du sous-titre en jeu (sous la distance du vigile, au-dessus du coureur).
const CAPTION_TOP: Vector2 = Vector2(250.0, 112.0)

## Mouvement → explication (états et figures du coureur).
const MOVE_TEXT: Dictionary[StringName, String] = {
	&"RUN": "Flèche droite : courir. Le coureur garde la direction tout seul.",
	&"SPRINT": "SPRINT (maintenu) : course rapide, sauts plus longs.",
	&"JUMP": "SAUT : pour franchir un trou ou monter sur un toit.",
	&"SLIDE": "GLISSE en courant : passer sous un obstacle bas.",
	&"WALL_RUN": "Course murale : cours vers un mur en gardant la direction.",
	&"WALL_CLIMB": "Escalade : garde la direction vers le mur pour grimper.",
	&"LEDGE_HANG": "Rebord : flèche avant ou SAUT pour te hisser, GLISSE pour lâcher.",
	&"DOUBLE_JUMP": "Double saut : SAUT en l'air (capacité à débloquer).",
	&"LAZY_VAULT": "Franchissement : cours vers un obstacle bas, c'est automatique.",
	&"SPEED_VAULT": "Franchissement rapide : obstacle bas pris en courant.",
	&"KONG_VAULT": "Saut de chat : obstacle bas pris en SPRINT.",
	&"TIC_TAC": "Tic-tac : cours vers un mur trop haut, rebond automatique.",
	&"WALL_FLIP": "Saut mural : SAUT pendant que tu es sur le mur.",
	&"FRONT_FLIP": "Salto avant : SAUT en sprint au bord d'un toit.",
	&"CAT_LEAP": "Saut de chat au mur : tu t'accroches au rebord en plein élan.",
	&"PARKOUR_ROLL": "Roulade : GLISSE juste avant de toucher le sol après une grande chute.",
}
const HAZARD_TEXT: Dictionary[StringName, String] = {
	&"spikes": "Pics : saute par-dessus. Les toucher = recommencer le tronçon.",
	&"saw": "Scie : elle va et vient. Passe quand elle s'éloigne.",
	&"crusher": "Écraseur : il tremble avant de tomber. Passe juste après.",
	&"flame": "Flamme : elle crépite avant de s'allumer. Observe le rythme.",
	&"crumble": "Dalle fragile : elle s'effondre peu après ton passage. Ne t'arrête pas !",
}

var _segments: Array[Dictionary] = []
var _index: int = -1
var _t: float = 0.0
var _current: Node
var _runner: LevelRunner
var _body: RunnerBody
var _director: EncounterDirector
var _equipment: EquipmentRuntime
var _touch: TouchControls
var _ctrl: ScriptedController
var _flags: Dictionary = {}
var _live_age: float = 99.0
var _held_until: Dictionary = {}

var _overlay: CanvasLayer
var _chapter: Label
var _caption: Label
var _caption_box: PanelContainer
var _title_card: ColorRect
var _title: Label
var _subtitle: Label


func _init() -> void:
	_build_overlay()
	_segments = [
		{"chapter": "", "time": 4.0, "setup": _title_setup.bind("EDU", "Tutoriel complet · parkour à Lomé")},
		{"chapter": "1 · Menu principal", "time": 5.0, "setup": _screen_setup.bind(MenuScreen.MAIN_MENU), "cap": Vector2(680.0, 300.0), "capw": 560.0,
			"text": "JOUER ouvre la carte du monde. Réglages et crédits sont ici aussi."},
		{"chapter": "2 · Carte du monde", "time": 6.0, "setup": _screen_setup.bind(MenuScreen.WORLD_MAP), "cap": Vector2(250.0, 600.0),
			"text": "Un tour du monde ville par ville. Lomé est ouverte, les autres villes arrivent."},
		{"chapter": "3 · Choisir un parcours", "time": 9.0, "setup": _city_setup, "tick": _city_tick, "cap": Vector2(150.0, 112.0), "capw": 740.0},
		{"chapter": "4 · Les commandes", "time": 9.0, "setup": _controls_setup, "tick": _controls_tick},
	]
	for demo: Dictionary in FIGURE_DEMOS:
		_segments.append({"chapter": "5 · Comment faire chaque figure", "time": float(demo.get("time", 5.5)),
			"setup": _demo_setup.bind(demo), "tick": _demo_tick.bind(demo), "text": demo["text"]})
	_segments.append_array([
		{"chapter": "6 · Les figures en course", "time": 34.0, "setup": _moves_setup, "tick": _moves_tick},
		{"chapter": "7 · Les pièges", "time": 36.0, "setup": _traps_setup, "tick": _traps_tick},
		{"chapter": "8 · Le vigile", "time": 34.0, "setup": _guard_setup, "tick": _guard_tick},
		{"chapter": "9 · Les objets", "time": 34.0, "setup": _items_setup, "tick": _items_tick},
		{"chapter": "10 · Pause et inventaire", "time": 7.0, "setup": _pause_setup, "tick": _pause_tick, "cap": Vector2(250.0, 6.0)},
		{"chapter": "11 · Résultat et étoiles", "time": 8.0, "setup": _result_setup, "cap": Vector2(250.0, 6.0),
			"text": "1 étoile : arrivée · 2 : au plus 2 morts · 3 : sans mourir et sous le temps de référence."},
		{"chapter": "12 · L'énergie", "time": 10.0, "setup": _energy_setup, "tick": _energy_tick, "cap": Vector2(150.0, 112.0), "capw": 740.0},
		{"chapter": "13 · Réglages", "time": 7.0, "setup": _screen_setup.bind(MenuScreen.SETTINGS_SCREEN), "cap": Vector2(250.0, 590.0),
			"text": "Son, vibrations, taille et opacité des boutons, qualité graphique, compteur de FPS."},
		{"chapter": "", "time": 4.0, "setup": _title_setup.bind("À toi de jouer !", "Bonne course dans les rues de Lomé")},
	])
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	var dt: float = 1.0 / FPS
	if _index < 0:
		_isolate_save()
		_next()
		return
	_t += dt
	_live_age += dt
	var segment: Dictionary = _segments[_index]
	if segment.has("tick"):
		(segment["tick"] as Callable).call()
	_highlight_buttons()
	if _t >= float(segment["time"]):
		_next()


func _next() -> void:
	paused = false
	if _current != null:
		_current.queue_free()
		_current = null
	_runner = null
	_body = null
	_director = null
	_equipment = null
	_touch = null
	_ctrl = null
	_flags = {}
	_held_until = {}
	_index += 1
	_t = 0.0
	if _index >= _segments.size():
		print("record_tutorial : terminé")
		quit()
		return
	var segment: Dictionary = _segments[_index]
	_chapter.text = segment["chapter"]
	_chapter.visible = segment["chapter"] != ""
	_title_card.visible = false
	var at: Vector2 = segment.get("cap", CAPTION_TOP)
	_caption_box.position = at
	_caption_box.custom_minimum_size.x = float(segment.get("capw", 780.0))
	_caption.custom_minimum_size.x = float(segment.get("capw", 780.0)) - 36.0
	_say(str(segment.get("text", "")))
	(segment["setup"] as Callable).call()
	print("record_tutorial : ", segment["chapter"] if segment["chapter"] != "" else "titre")


# --- Sous-titres ----------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 250
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child.call_deferred(_overlay)
	_title_card = ColorRect.new()
	_title_card.color = MenuStyle.INK
	_title_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_title_card)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_card.add_child(column)
	_title = MenuStyle.label("", 110, MenuStyle.CREAM)
	_title.add_theme_font_override(&"font", MenuStyle.heavy_font())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_subtitle = MenuStyle.label("", 32, MenuStyle.ACCENT, true)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)

	# Encadré : titre du chapitre (petit, orange) puis le sous-titre.
	_caption_box = PanelContainer.new()
	_caption_box.add_theme_stylebox_override(&"panel", MenuStyle.panel_box(Color(MenuStyle.INK, 0.82), 14, 18.0))
	_caption_box.position = Vector2(250.0, 112.0)
	_caption_box.custom_minimum_size = Vector2(780.0, 0.0)
	_overlay.add_child(_caption_box)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 2)
	_caption_box.add_child(lines)
	_chapter = MenuStyle.label("", 18, MenuStyle.ACCENT, true)
	_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(_chapter)
	_caption = MenuStyle.label("", 27, MenuStyle.CREAM, true)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(744.0, 0.0)
	lines.add_child(_caption)


func _say(text: String) -> void:
	_caption.text = text
	_caption_box.visible = text != ""
	_caption_box.reset_size()
	_live_age = 0.0


## Sous-titre vivant : remplace le précédent s'il est resté assez longtemps.
func _say_live(key: StringName, text: String) -> void:
	if text == "" or _flags.get(&"said_" + key, false) or _live_age < LIVE_MIN_TIME:
		return
	_flags[&"said_" + key] = true
	_say(text)


# --- Écrans ---------------------------------------------------------------------

func _title_setup(title: String, subtitle: String) -> void:
	_title_card.visible = true
	_title.text = title
	_subtitle.text = subtitle
	_caption_box.visible = false


func _screen_setup(path: String) -> void:
	var screen: MenuScreen = (load(path) as PackedScene).instantiate() as MenuScreen
	screen.use_router = false
	if screen is CityScreen:
		(screen as CityScreen).city_id = &"lome"
	_current = screen
	root.add_child(screen)


func _city_setup() -> void:
	_set_progress(true)
	_screen_setup(MenuScreen.CITY_SCREEN)
	_say("Chaque carte : difficulté, icône rouge = un vigile te poursuit, étoiles et meilleur temps.")


func _city_tick() -> void:
	if _t > 4.5 and not _flags.get(&"city2", false):
		_flags[&"city2"] = true
		_say("Termine un parcours pour débloquer le suivant. Touche une carte pour partir.")


func _result_setup() -> void:
	var result: ResultScreen = (load(MenuScreen.RESULT_SCREEN) as PackedScene).instantiate() as ResultScreen
	result.use_router = false
	result.result = {
		"city_id": "lome", "route_index": 1, "route_id": "lome_boulevard", "route_name": "Boulevard du 13-Janvier",
		"time": 19.37, "deaths": 0, "captures": 0, "stars": 3, "best_time": 19.37, "new_best": true,
		"par_time": 20.0, "next_route_index": 2,
	}
	_current = result
	root.add_child(result)


func _energy_setup() -> void:
	var attempts: AttemptServiceNode = root.get_node_or_null(^"AttemptService") as AttemptServiceNode
	if attempts != null:
		attempts.reload()
		attempts.request_start(false)
		attempts.request_start(false)
	_set_progress(true)
	_screen_setup(MenuScreen.CITY_SCREEN)
	_say("5 tickets d'énergie. Un nouveau parcours coûte 1 ticket… rendu dès que tu arrives au bout !")


func _energy_tick() -> void:
	if _t > 5.0 and not _flags.get(&"energy2", false):
		_flags[&"energy2"] = true
		_say("Mourir est gratuit. Les parcours réussis se rejouent gratuitement. +1 ticket toutes les 72 min.")


# --- Niveaux --------------------------------------------------------------------

## Niveau de Lomé avec le pilote automatique et les boutons tactiles affichés.
func _level(route_index: int, ordered: Array[StringName] = [], guard: bool = true) -> void:
	var level: Node = (load(MenuScreen.LOME_RUN) as PackedScene).instantiate()
	_runner = level.get_node("LevelRunner") as LevelRunner
	_runner.route_index = route_index
	if not ordered.is_empty():
		_runner.mode = ChunkSequencer.Mode.ORDERED
		_runner.ordered_ids = ordered
	_body = level.get_node("Player") as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	var pilot: AutopilotController = AutopilotController.new()
	pilot.name = "Controller"
	_body.add_child(pilot)
	_touch = level.get_node("TouchControls") as TouchControls
	_touch.force_visible = true
	# Pas d'écran de résultat ni de changement de scène pendant l'enregistrement.
	var session: Node = level.get_node("Session")
	level.remove_child(session)
	session.free()
	_director = level.get_node("Encounter") as EncounterDirector
	_director.captured.connect(_on_captured)
	_equipment = level.get_node("Equipment") as EquipmentRuntime
	_current = level
	root.add_child(level)
	if not guard:
		_director.enabled = false


func _controls_setup() -> void:
	_level(0)
	_body.set_physics_process(false)
	_say("À gauche : les flèches pour courir. À droite : SAUT, GLISSE, SPRINT et OBJET.")


func _controls_tick() -> void:
	if _t > 4.5 and not _flags.get(&"controls2", false):
		_flags[&"controls2"] = true
		_say("En haut à gauche : ton objet (touche-le pour changer). En haut à droite : pause.")
	# Démonstration : chaque bouton s'allume à tour de rôle.
	var order: Array[StringName] = [InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.JUMP,
		InputActions.SLIDE, InputActions.SPRINT, InputActions.USE_ITEM]
	var step: int = int(_t / 0.75) % order.size()
	_held_until = {order[step]: _t + 0.05}


func _moves_setup() -> void:
	_level(-1, MOVES_ROUTE, false)
	_say("Le parkour, c'est surtout courir et sauter au bon moment. Les figures se font toutes seules.")


func _moves_tick() -> void:
	if _body == null:
		return
	var state: StringName = StringName(PlayerState.State.keys()[_body.current_state()])
	var figure: StringName = StringName(Figure.Kind.keys()[_body.figure]) if _body.figure != Figure.Kind.NONE else &""
	if figure != &"" and MOVE_TEXT.has(figure):
		_say_live(figure, MOVE_TEXT[figure])
	elif MOVE_TEXT.has(state):
		_say_live(state, MOVE_TEXT[state])


func _traps_setup() -> void:
	_level(4, [], false)
	_say("Les pièges ont un rythme. Ils s'annoncent toujours avant d'être dangereux.")


func _traps_tick() -> void:
	if _body == null or _body.is_dead():
		if _body != null and not _flags.get(&"death_said", false) and _flags.get(&"killed", false):
			_flags[&"death_said"] = true
			_live_age = 99.0
			_say("Touché ! Retour au début du tronçon. Mourir ne coûte pas d'énergie.")
		return
	var ahead: Hazard = _nearest_hazard_ahead(520.0)
	if ahead != null:
		_say_live(ahead.spec.kind, HAZARD_TEXT.get(ahead.spec.kind, ""))
		# Une mort de démonstration sur le premier piège rencontré après 8 s.
		if _t > 8.0 and not _flags.get(&"killed", false) and ahead.spec.kind != Hazard.CRUMBLE \
				and ahead.to_global(ahead.spec.rect.get_center()).x - _body.global_position.x < 120.0:
			_flags[&"killed"] = true
			_body.kill(ahead.spec.kind)


func _nearest_hazard_ahead(range_px: float) -> Hazard:
	var best: Hazard = null
	var best_dx: float = range_px
	for node: Node in get_nodes_in_group(LevelChunk.HAZARD_GROUP):
		var hazard: Hazard = node as Hazard
		if hazard == null or not hazard.is_inside_tree():
			continue
		var dx: float = hazard.to_global(hazard.spec.rect.get_center()).x - _body.global_position.x
		if dx > -20.0 and dx < best_dx:
			best_dx = dx
			best = hazard
	return best


func _guard_setup() -> void:
	_level(1)
	_say("Sur les parcours avec l'icône rouge, un vigile te poursuit. Pas de combat : il faut le semer.")


func _guard_tick() -> void:
	if _director == null or _body == null:
		return
	var distance: float = _director.pursuer_distance()
	if distance >= 0.0:
		_say_live(&"guard_in", "Il arrive derrière toi. Sa distance s'affiche en haut de l'écran.")
	# Démonstration : le coureur s'arrête, le vigile l'attrape, la jauge se remplit.
	if _t > 12.0 and distance >= 0.0 and not _flags.get(&"stop_done", false):
		if not _flags.get(&"stopping", false):
			_flags[&"stopping"] = true
			_body.set_physics_process(false)
			_live_age = 99.0
			_say("Si tu t'arrêtes, il te rattrape…")
		elif _director.gauge.value > 0.45:
			_flags[&"stop_done"] = true
			_body.set_physics_process(true)
			_live_age = 99.0
			_say("…et la jauge de capture se remplit. Cours pour t'arracher à sa prise !")
	for node: Node in get_nodes_in_group(StealthZone.GROUP):
		var zone: StealthZone = node as StealthZone
		if zone != null and zone.contains(_body):
			_say_live(&"shadow", "Zone d'ombre : cache-toi dedans, il peut perdre ta trace.")
	if _t > 26.0:
		_say_live(&"guard_end", "Une course propre le distance. Une hésitation se paie.")


## Capture par le vigile : expliquée à l'écran.
func _on_captured() -> void:
	if _body != null and not _body.is_physics_processing():
		_body.set_physics_process(true)
	_flags[&"stop_done"] = true
	_live_age = 99.0
	_say("Jauge pleine : attrapé ! Tu repars du point de contrôle. Les objets ramassés dans ce parcours sont perdus.")


func _items_setup() -> void:
	var service: InventoryServiceNode = root.get_node_or_null(^"InventoryService") as InventoryServiceNode
	if service != null:
		service.reload()
		for id: StringName in [&"gilet", &"impulsion", &"piratage"]:
			service.inventory.try_add(id, false)
	_level(1)
	_equipment.message.connect(_on_item_message)
	_say("Objets : ton objet est en haut à gauche. Le bouton OBJET l'utilise.")


func _items_tick() -> void:
	if _equipment == null:
		return
	_use_at(3.0, &"accelerateur", "Accélérateur : +25 % de vitesse pendant 10 s.")
	_use_at(8.5, &"gilet", "Gilet : encaisse un piège à ta place (20 s).")
	if _director != null and _director.has_pursuer():
		_use_at(14.0, &"impulsion", "Impulsion : repousse le vigile loin derrière toi.")
		_use_at(20.0, &"surcharge", "Surcharge : vide 60 % de la jauge de capture.")
	_use_at(25.0, &"piratage", "Piratage : coupe les pièges proches pendant 8 s.")
	if _t > 29.5:
		_say_live(&"items_end", "Caisses d'objets sur les toits : cours dessus pour les ramasser (20 places).")


func _use_at(at: float, id: StringName, text: String) -> void:
	var flag: StringName = &"used_" + id
	if _t < at or _flags.get(flag, false):
		return
	_flags[flag] = true
	_equipment.selected = id
	_equipment.changed.emit()
	if _equipment.use_item(id):
		_held_until[InputActions.USE_ITEM] = _t + 0.4
		_live_age = 99.0
		_say(text)


func _on_item_message(text: String) -> void:
	if text.begins_with("+ "):
		_live_age = 99.0
		_say("Caisse ramassée : %s rejoint ton inventaire." % text.trim_prefix("+ "))


func _pause_setup() -> void:
	_level(0, [], false)
	_say("Le bouton pause (en haut à droite) met le jeu en pause.")


func _pause_tick() -> void:
	if _t > 1.5 and not _flags.get(&"paused", false):
		_flags[&"paused"] = true
		var pause: PauseMenu = _current.get_node_or_null(^"PauseMenu") as PauseMenu
		if pause != null:
			pause.open()
		_say("Reprendre, Recommencer (même ticket), Carte. Ton inventaire est affiché ici.")


# --- Démonstrations des figures ------------------------------------------------

## Scène de démonstration : sol (ou trou), blocs, coureur piloté par un script,
## décor de Lomé, caméra rapprochée, boutons tactiles affichés.
func _demo_setup(demo: Dictionary) -> void:
	var world: Node2D = Node2D.new()
	var backdrop: CityBackdrop = CityBackdrop.new()
	backdrop.theme = (load(LOME) as CityDefinition).theme
	world.add_child(backdrop)
	var special: StringName = demo["special"]
	if special == &"gap":
		world.add_child(LevelGeometry.make_block(Rect2(-1000, 0, 1400, 600)))
		world.add_child(LevelGeometry.make_block(Rect2(560, 0, 1400, 600)))
	else:
		world.add_child(LevelGeometry.make_block(Rect2(-1000, 0, 4000, 600)))
	for rect: Rect2 in demo["blocks"]:
		world.add_child(LevelGeometry.make_block(rect))
	_body = (load("res://src/gameplay/actors/player/player.tscn") as PackedScene).instantiate() as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	_ctrl = ScriptedController.new()
	_ctrl.name = "Controller"
	_ctrl.move_axis = float(demo["axis"])
	_ctrl.sprint_held = bool(demo["sprint"])
	_ctrl.jump_held = true
	_body.add_child(_ctrl)
	_body.position = Vector2(-120, -400) if special == &"drop_roll" else Vector2(-120, -2)
	if special == &"double_jump":
		_body.position = Vector2(150, -2)
		_body.abilities.unlock(AbilitySet.DOUBLE_JUMP)
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(0, -60)
	camera.zoom = Vector2(1.5, 1.5)
	_body.add_child(camera)
	world.add_child(_body)
	_touch = TouchControls.new()
	_touch.force_visible = true
	world.add_child(_touch)
	_current = world
	root.add_child(world)
	camera.make_current()


func _demo_tick(demo: Dictionary) -> void:
	if _body == null or _ctrl == null:
		return
	if _t < 0.8:
		# Petit temps d'arrêt au départ : on lit le sous-titre.
		_body.set_physics_process(false)
		return
	_body.set_physics_process(true)
	var x: float = _body.global_position.x
	match demo["special"]:
		&"gap":
			if not _flags.get(&"jumped", false) and _body.is_on_floor() and x > 375.0:
				_press_jump()
		&"slide":
			if not _flags.get(&"slid", false) and x > 230.0:
				_flags[&"slid"] = true
				_ctrl.press_slide()
				_held_until[InputActions.SLIDE] = _t + 0.35
		&"wall_jump":
			if not _flags.get(&"jumped", false) and _body.current_state() == PlayerState.State.WALL_RUN:
				_press_jump()
		&"double_jump":
			if _t > 1.3 and not _flags.get(&"jumped", false):
				_press_jump()
			elif _t > 1.7 and not _flags.get(&"double", false) and _body.velocity.y > -150.0:
				_flags[&"double"] = true
				_ctrl.press_jump()
				_held_until[InputActions.JUMP] = _t + 0.3
		&"jump_at_200":
			if not _flags.get(&"jumped", false) and _body.is_on_floor() and x > 200.0:
				_press_jump()
			if _body.current_state() == PlayerState.State.LEDGE_HANG and _t < 3.5:
				_ctrl.move_axis = 0.0
			elif _t >= 3.5:
				_ctrl.move_axis = 1.0
		&"drop_roll":
			if not _flags.get(&"slid", false) and _body.velocity.y > 0.0 and _body.global_position.y > -110.0:
				_flags[&"slid"] = true
				_ctrl.press_slide()
				_held_until[InputActions.SLIDE] = _t + 0.35


func _press_jump() -> void:
	_flags[&"jumped"] = true
	_ctrl.press_jump()
	_held_until[InputActions.JUMP] = _t + 0.3


# --- Boutons tactiles -----------------------------------------------------------

## Allume les boutons que le coureur « appuie » (intention du pilote automatique).
func _highlight_buttons() -> void:
	if _touch == null or not is_instance_valid(_touch):
		return
	var pressed: Dictionary = {}
	if _body != null and is_instance_valid(_body) and _body.is_physics_processing():
		var intent: IntentFrame = _body.intent
		pressed[InputActions.MOVE_RIGHT] = intent.move_axis > 0.2
		pressed[InputActions.MOVE_LEFT] = intent.move_axis < -0.2
		pressed[InputActions.JUMP] = intent.jump_pressed or intent.jump_held
		pressed[InputActions.SLIDE] = intent.slide_pressed or _body.current_state() == PlayerState.State.SLIDE
		pressed[InputActions.SPRINT] = intent.sprint_held
	for action: Variant in _held_until:
		if _t <= float(_held_until[action]):
			pressed[action] = true
	for child: Node in _touch.get_children():
		var button: TouchScreenButton = child as TouchScreenButton
		if button == null:
			continue
		for face: Node in button.get_children():
			if face.has_method(&"set_pressed"):
				face.call(&"set_pressed", bool(pressed.get(StringName(button.action), false)))


# --- Sauvegarde isolée ----------------------------------------------------------

func _isolate_save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	for file: String in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR.path_join(file))
	var save: SaveServiceNode = root.get_node_or_null(^"SaveService") as SaveServiceNode
	if save != null:
		save.use_store(SaveStore.new(SAVE_DIR, "save.json"))
	for service: String in ["ProfileService", "SettingsService", "InventoryService", "AttemptService"]:
		var node: Node = root.get_node_or_null(NodePath(service))
		if node != null and node.has_method(&"reload"):
			node.call(&"reload")


## Progression de démonstration : parcours 1 (3 étoiles) et 2 (2 étoiles) réussis.
func _set_progress(enabled: bool) -> void:
	var profile: ProfileServiceNode = root.get_node_or_null(^"ProfileService") as ProfileServiceNode
	if profile == null:
		return
	profile.progression.routes = {}
	if not enabled:
		return
	var city: CityDefinition = load(LOME) as CityDefinition
	profile.progression.record_finish(city.routes[0].id, city.routes[0].par_time - 1.0, 0, city.routes[0].par_time)
	profile.progression.record_finish(city.routes[1].id, city.routes[1].par_time + 4.0, 1, city.routes[1].par_time)
