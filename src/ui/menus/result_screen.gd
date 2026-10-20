class_name ResultScreen
extends MenuScreen
## Écran de résultat d'un parcours (ouvert par RouteSession, paramètre
## « result » : voir src/gameplay/level/route_session.gd). « ARRIVÉE », nom du
## parcours, temps comparé au temps de référence, morts, captures, étoiles
## révélées une à une, badge « Nouveau record », puis Rejouer, Parcours
## suivant (s'il existe et qu'il est débloqué) et Carte.

## Délai entre deux étoiles révélées (s).
const STAR_DELAY: float = 0.28

## Résultat affiché ; vide = paramètre « result » de SceneRouter.
var result: Dictionary = {}
var route_label: Label
var time_label: Label
var par_label: Label
var deaths_label: Label
var captures_label: Label
var best_label: Label
var record_badge: Control
var star_icons: Array[MenuIcon] = []
var replay_button: Button
var next_button: Button
var map_button: Button

var _city: CityDefinition


func _build_background() -> void:
	if result.is_empty():
		result = router_param("result", {}) as Dictionary
	var entry: WorldCity = load_world().find(StringName(str(result.get("city_id", "lome"))))
	if entry == null or not entry.is_playable():
		entry = load_world().find(CityScreen.DEFAULT_CITY)
	_city = entry.city
	add_backdrop(_city.theme, 2600.0, -40.0)
	add_shade(0.72, 0.82)


func _build() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	column.custom_minimum_size.x = 820.0
	center.add_child(column)

	route_label = MenuStyle.label("%s · %s" % [str(result.get("route_name", "")), _city.display_name], 24, MenuStyle.ACCENT, true)
	route_label.name = "RouteName"
	route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(route_label)
	var title: Label = MenuStyle.label("ARRIVÉE", 92, MenuStyle.CREAM)
	title.name = "Title"
	title.add_theme_font_override(&"font", MenuStyle.heavy_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override(&"line_spacing", -20)
	column.add_child(title)

	# Étoiles (révélées par _reveal_stars).
	var stars_row: HBoxContainer = HBoxContainer.new()
	stars_row.name = "Stars"
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override(&"separation", 18)
	column.add_child(stars_row)
	var earned: int = stars()
	for i: int in 3:
		var holder: Control = Control.new()
		holder.custom_minimum_size = Vector2(84.0, 84.0) if i != 1 else Vector2(100.0, 100.0)
		holder.size_flags_vertical = Control.SIZE_SHRINK_END if i != 1 else Control.SIZE_SHRINK_BEGIN
		stars_row.add_child(holder)
		var empty: MenuIcon = MenuIcon.make(MenuIcon.Kind.STAR_EMPTY, 0.0, Color(MenuStyle.CREAM, 0.28))
		empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty.visible = i >= earned
		holder.add_child(empty)
		var star: MenuIcon = MenuIcon.make(MenuIcon.Kind.STAR, 0.0, MenuStyle.ACCENT)
		star.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		star.visible = i < earned
		holder.add_child(star)
		star_icons.append(star)

	var badge_row: CenterContainer = CenterContainer.new()
	badge_row.custom_minimum_size.y = 48.0
	column.add_child(badge_row)
	var badge: Label = MenuStyle.label("NOUVEAU RECORD", 22, MenuStyle.INK, true)
	badge.name = "RecordBadge"
	badge.add_theme_stylebox_override(&"normal", _pill(MenuStyle.ACCENT))
	badge.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	badge.visible = bool(result.get("new_best", false))
	badge_row.add_child(badge)
	record_badge = badge

	# Statistiques : temps / référence / record, morts / captures.
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", MenuStyle.panel_box(Color(MenuStyle.INK, 0.6), 22, 22.0))
	column.add_child(panel)
	var grid: HBoxContainer = HBoxContainer.new()
	grid.add_theme_constant_override(&"separation", 0)
	panel.add_child(grid)
	var time_s: float = float(result.get("time", 0.0))
	var par_s: float = float(result.get("par_time", 0.0))
	var under_par: bool = par_s > 0.0 and time_s <= par_s
	time_label = _stat(grid, "Temps", MenuStyle.format_time(time_s), MenuStyle.ACCENT if under_par else MenuStyle.CREAM)
	par_label = _stat(grid, "Référence", MenuStyle.format_time(par_s), MenuStyle.CREAM)
	best_label = _stat(grid, "Record", MenuStyle.format_time(float(result.get("best_time", time_s))), MenuStyle.CREAM)
	deaths_label = _stat(grid, "Morts", str(int(result.get("deaths", 0))), MenuStyle.CREAM)
	captures_label = _stat(grid, "Captures", str(int(result.get("captures", 0))), MenuStyle.CREAM)

	var gap: Control = Control.new()
	gap.custom_minimum_size.y = 8.0
	column.add_child(gap)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 16)
	column.add_child(buttons)
	map_button = MenuStyle.button("Carte", &"", 200.0)
	map_button.name = "MapButton"
	map_button.pressed.connect(go_to.bind(WORLD_MAP, {}))
	buttons.add_child(map_button)
	replay_button = MenuStyle.button("Rejouer", &"", 220.0)
	replay_button.name = "ReplayButton"
	replay_button.pressed.connect(replay)
	buttons.add_child(replay_button)
	next_button = MenuStyle.button("Parcours suivant", &"PrimaryButton", 320.0)
	next_button.name = "NextButton"
	next_button.add_theme_font_size_override(&"font_size", 30)
	next_button.visible = has_next()
	next_button.pressed.connect(next_route)
	buttons.add_child(next_button)
	if not MainMenu.is_mobile():
		(next_button if next_button.visible else replay_button).grab_focus.call_deferred()
	_reveal_stars.call_deferred()


func stars() -> int:
	return clampi(int(result.get("stars", 0)), 0, 3)


## Parcours suivant proposé : il existe et il est débloqué.
func has_next() -> bool:
	var next: int = int(result.get("next_route_index", -1))
	return next >= 0 and current_progression().is_route_unlocked(_city, next)


func replay() -> void:
	_play(int(result.get("route_index", 0)))


func next_route() -> void:
	if has_next():
		_play(int(result.get("next_route_index", 0)))


func back() -> void:
	go_to(CITY_SCREEN, {"city_id": String(_city.id)})


func _play(index: int) -> void:
	# Plus d’énergie : retour à l’écran de la ville, qui affiche l’attente.
	if not launch_route(_city, index):
		back()


## Les étoiles gagnées apparaissent l'une après l'autre (grossissement élastique).
func _reveal_stars() -> void:
	for i: int in star_icons.size():
		var star: MenuIcon = star_icons[i]
		if not star.visible:
			continue
		star.pivot_offset = star.size * 0.5
		star.scale = Vector2.ZERO
		var tween: Tween = create_tween()
		tween.tween_interval(0.25 + STAR_DELAY * float(i))
		tween.tween_property(star, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if record_badge.visible:
		record_badge.pivot_offset = record_badge.size * 0.5
		record_badge.modulate.a = 0.0
		var badge_tween: Tween = create_tween()
		badge_tween.tween_interval(0.25 + STAR_DELAY * 3.0)
		badge_tween.tween_property(record_badge, "modulate:a", 1.0, 0.3)


func _stat(parent: Container, caption: String, value: String, color: Color) -> Label:
	var cell: VBoxContainer = VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override(&"separation", 0)
	parent.add_child(cell)
	var top: Label = MenuStyle.label(caption.to_upper(), 16, MenuStyle.MUTED, true)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(top)
	var value_label: Label = MenuStyle.label(value, 34, color, true)
	value_label.name = caption
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(value_label)
	return value_label


static func _pill(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = MenuStyle.panel_box(color, 20, 0.0)
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box
