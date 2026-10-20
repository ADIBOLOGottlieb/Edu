class_name CityScreen
extends MenuScreen
## Écran d'une ville (paramètre SceneRouter « city_id ») : nom et pays sur son
## décor, puis une carte par parcours — numéro, nom, difficulté (points),
## vigile si poursuite, étoiles (0 à 3), meilleur temps, cadenas si le parcours
## n'est pas encore débloqué (Progression.is_route_unlocked). Toucher une carte
## ouverte lance le parcours (scène de la ville, paramètre « route_index »).

signal route_selected(route_index: int)

## Scène de course de chaque ville jouable.
const CITY_SCENES: Dictionary[StringName, String] = {
	&"lome": "res://scenes/levels/lome_run.tscn",
}
const DEFAULT_CITY: StringName = &"lome"
const CARD_HEIGHT: float = 360.0

## Ville affichée ; vide = paramètre « city_id » de SceneRouter (sinon Lomé).
var city_id: StringName = &""
var world_city: WorldCity
var city: CityDefinition
var route_cards: Array[Button] = []
## « Énergie 4/5 · +1 dans 1 h 12 », mis à jour chaque seconde.
var energy_label: Label
## Message quand l’énergie manque.
var energy_message: Label

var _energy_tick: float = 0.0

var _progression: Progression


func _build_background() -> void:
	if city_id == &"":
		city_id = StringName(str(router_param("city_id", String(DEFAULT_CITY))))
	world_city = load_world().find(city_id)
	if world_city == null or not world_city.is_playable():
		world_city = load_world().find(DEFAULT_CITY)
		city_id = DEFAULT_CITY
	city = world_city.city
	add_backdrop(city.theme, 1400.0, -60.0)
	add_shade(0.4, 0.62)


func _build() -> void:
	_progression = current_progression()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 20)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	header.add_child(make_back_button())
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", -10)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	var name_label: Label = MenuStyle.label(city.display_name.to_upper(), 64, MenuStyle.CREAM)
	name_label.name = "CityName"
	name_label.add_theme_font_override(&"font", MenuStyle.heavy_font())
	titles.add_child(name_label)
	var country: Label = MenuStyle.label("%s · %d parcours" % [city.country, city.routes.size()], 22, Color(MenuStyle.ACCENT, 0.95), true)
	country.name = "Country"
	titles.add_child(country)
	var stars_box: HBoxContainer = HBoxContainer.new()
	stars_box.add_theme_constant_override(&"separation", 8)
	stars_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars_box.add_child(MenuIcon.make(MenuIcon.Kind.STAR, 36.0))
	var total: Label = MenuStyle.label("%d / %d" % [_progression.city_stars(city), city.routes.size() * 3], 30, MenuStyle.CREAM, true)
	total.name = "StarsTotal"
	stars_box.add_child(total)
	header.add_child(stars_box)

	energy_label = MenuStyle.label("", 24, MenuStyle.CREAM, true)
	energy_label.name = "Energy"
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(energy_label)
	energy_message = MenuStyle.label("", 22, MenuStyle.ACCENT, true)
	energy_message.name = "EnergyMessage"
	energy_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(energy_message)
	energy_refused.connect(_on_energy_refused)
	_refresh_energy()
	if bool(router_param("no_energy", false)):
		_on_energy_refused()

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	var cards: HBoxContainer = HBoxContainer.new()
	cards.name = "Routes"
	cards.add_theme_constant_override(&"separation", 16)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(cards)
	for i: int in city.routes.size():
		var card: Button = _make_card(i)
		cards.add_child(card)
		route_cards.append(card)

	var hint: Label = MenuStyle.label("3 étoiles : arrivée sans mourir, sous le temps de référence", 20, MenuStyle.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	var first_open: int = 0
	for i: int in city.routes.size():
		if is_route_open(i) and not _progression.is_completed(city.routes[i].id):
			first_open = i
			break
	if not MainMenu.is_mobile() and not route_cards.is_empty():
		route_cards[first_open].grab_focus.call_deferred()


func is_route_open(index: int) -> bool:
	return _progression.is_route_unlocked(city, index)


## Lance le parcours n° index s'il est débloqué (énergie : launch_route).
func play_route(index: int) -> void:
	if not is_route_open(index):
		return
	if launch_route(city, index):
		route_selected.emit(index)


func _process(delta: float) -> void:
	_energy_tick += delta
	if _energy_tick >= 1.0:
		_energy_tick = 0.0
		_refresh_energy()


func _refresh_energy() -> void:
	var attempts: AttemptServiceNode = get_node_or_null(^"/root/AttemptService") as AttemptServiceNode
	if energy_label != null and attempts != null:
		energy_label.text = attempts.status_text()


func _on_energy_refused() -> void:
	var attempts: AttemptServiceNode = get_node_or_null(^"/root/AttemptService") as AttemptServiceNode
	var wait: String = EnergyMeter.format_wait(attempts.seconds_to_next()) if attempts != null else ""
	energy_message.text = "Plus d'énergie : prochain ticket dans %s. Les parcours réussis se rejouent gratuitement." % wait


func back() -> void:
	go_to(WORLD_MAP)


func _make_card(index: int) -> Button:
	var route: CityRoute = city.routes[index]
	var open: bool = is_route_open(index)
	var card: Button = Button.new()
	card.name = "Route%d" % (index + 1)
	card.theme_type_variation = &"CardButton"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(180.0, CARD_HEIGHT)
	card.disabled = not open
	card.set_meta(&"open", open)
	card.pressed.connect(play_route.bind(index))

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	card.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	var dim: Color = MenuStyle.LOCKED

	# Numéro (ou cadenas) et vigile.
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.custom_minimum_size.y = 64.0
	box.add_child(top)
	if open:
		var number: Label = MenuStyle.label("%02d" % (index + 1), 44, MenuStyle.ACCENT)
		number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		number.add_theme_font_override(&"font", MenuStyle.heavy_font())
		top.add_child(number)
	else:
		var lock: MenuIcon = MenuIcon.make(MenuIcon.Kind.LOCK, 46.0, dim)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock.name = "Lock"
		top.add_child(lock)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fill)
	if route.pursuit:
		var chase: MenuIcon = MenuIcon.make(MenuIcon.Kind.CHASE, 34.0, Color(0.93, 0.36, 0.26) if open else dim)
		chase.name = "Pursuit"
		chase.tooltip_text = "Un vigile vous poursuit"
		chase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(chase)

	var title: Label = MenuStyle.label(route.display_name, 25, MenuStyle.CREAM if open else dim, true)
	title.name = "RouteName"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.y = 80.0
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(title)

	# Difficulté : 5 points, remplis jusqu'au niveau du parcours.
	var difficulty: HBoxContainer = HBoxContainer.new()
	difficulty.name = "Difficulty"
	difficulty.add_theme_constant_override(&"separation", 6)
	difficulty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for d: int in 5:
		var dot: Dot = Dot.new()
		dot.filled = d <= route.difficulty
		dot.color = (MenuStyle.ACCENT if open else dim) if dot.filled else Color(MenuStyle.CREAM, 0.18)
		dot.custom_minimum_size = Vector2(14.0, 14.0)
		difficulty.add_child(dot)
	var difficulty_caption: Label = MenuStyle.label(_difficulty_name(route.difficulty), 18, MenuStyle.MUTED if open else dim)
	difficulty_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	difficulty.add_child(difficulty_caption)
	box.add_child(difficulty)

	var push: Control = Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(push)

	# Étoiles et meilleur temps.
	var earned: int = _progression.stars(route.id)
	var stars: HBoxContainer = HBoxContainer.new()
	stars.name = "Stars"
	stars.set_meta(&"earned", earned)
	stars.add_theme_constant_override(&"separation", 4)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s: int in 3:
		var kind: MenuIcon.Kind = MenuIcon.Kind.STAR if s < earned else MenuIcon.Kind.STAR_EMPTY
		stars.add_child(MenuIcon.make(kind, 34.0, MenuStyle.ACCENT if s < earned else (Color(MenuStyle.CREAM, 0.3) if open else Color(dim, 0.2))))
	box.add_child(stars)
	var time_row: HBoxContainer = HBoxContainer.new()
	time_row.add_theme_constant_override(&"separation", 8)
	time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_row.add_child(MenuIcon.make(MenuIcon.Kind.CLOCK, 22.0, MenuStyle.MUTED if open else dim))
	var best: float = _progression.best_time(route.id)
	var time_text: String = MenuStyle.format_time(best) if best > 0.0 else ("Pas encore couru" if open else "Verrouillé")
	var time_label: Label = MenuStyle.label(time_text, 20, MenuStyle.CREAM if open else dim, best > 0.0)
	time_label.name = "BestTime"
	time_row.add_child(time_label)
	box.add_child(time_row)
	return card


static func _difficulty_name(level: int) -> String:
	return ["Initiation", "Facile", "Moyen", "Difficile", "Expert"][clampi(level, 0, 4)] as String


## Point de difficulté.
class Dot:
	extends Control

	var filled: bool = false
	var color: Color = MenuStyle.ACCENT

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5
		if filled:
			draw_circle(size * 0.5, r, color, true, -1.0, true)
		else:
			draw_circle(size * 0.5, r - 1.0, color, false, 2.0, true)
