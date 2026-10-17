class_name WorldMapScreen
extends MenuScreen
## Carte du monde (data/world/world_map.tres) : une étiquette par ville, reliée
## à son point par un trait. Ville ouverte = étiquette accent (nom, pays,
## étoiles gagnées / étoiles possibles) qui ouvre l'écran de la ville ; ville
## fermée ou annoncée = étiquette sombre « Bientôt » (un toucher affiche un
## message). Une ville jouable est ouverte selon Progression.is_city_unlocked.

signal city_selected(city_id: StringName)

## Direction de l'étiquette par rapport au point de la ville (px) : les villes
## proches (golfe de Guinée) ont des étiquettes écartées les unes des autres.
const LABEL_OFFSETS: Dictionary[StringName, Vector2] = {
	&"lome": Vector2(-6.0, 92.0),
	&"cotonou": Vector2(92.0, -52.0),
	&"abidjan": Vector2(-118.0, 46.0),
	&"dakar": Vector2(-86.0, -58.0),
	&"rio": Vector2(30.0, 62.0),
	&"nairobi": Vector2(96.0, 36.0),
	&"le_caire": Vector2(86.0, -40.0),
	&"paris": Vector2(-70.0, -54.0),
	&"new_york": Vector2(-24.0, -62.0),
	&"tokyo": Vector2(-30.0, 60.0),
}
const HEADER_HEIGHT: float = 104.0

var world: WorldMap
var view: WorldMapView
## Identifiant de ville → étiquette (Button).
var markers: Dictionary[StringName, Button] = {}
var stars_label: Label

var _open: Dictionary[StringName, bool] = {}
var _leaders: Leaders
var _toast: Label
var _toast_tween: Tween


func _build_background() -> void:
	world = load_world()
	view = WorldMapView.new()
	view.name = "Map"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(view)
	_leaders = Leaders.new()
	_leaders.screen = self
	_leaders.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_leaders)
	add_shade(0.55, 0.0)


func _build() -> void:
	var progression: Progression = current_progression()
	var playable: Array[CityDefinition] = world.playable_cities()
	var total_stars: int = 0
	var max_stars: int = 0
	var dots: Array[Dictionary] = []
	for entry: WorldCity in world.cities:
		var open: bool = false
		if entry.is_playable():
			open = progression.is_city_unlocked(playable, playable.find(entry.city))
			total_stars += progression.city_stars(entry.city)
			max_stars += entry.city.routes.size() * 3
		_open[entry.id] = open
		dots.append({"position": WorldMapView.lon_lat(entry.map_position), "open": open})
		var marker: Button = _make_marker(entry, open, progression)
		ui.add_child(marker)
		markers[entry.id] = marker
	view.cities = dots

	# En-tête : retour, titre, total d'étoiles.
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 20)
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)
	header.add_child(make_back_button())
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", -4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(titles)
	var title: Label = MenuStyle.label("Tour du monde", 44, MenuStyle.CREAM, true)
	titles.add_child(title)
	titles.add_child(MenuStyle.label("Choisis ta ville — d'autres étapes arrivent bientôt", 20, MenuStyle.MUTED))
	var stars_box: HBoxContainer = HBoxContainer.new()
	stars_box.add_theme_constant_override(&"separation", 8)
	stars_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars_box.add_child(MenuIcon.make(MenuIcon.Kind.STAR, 36.0))
	stars_label = MenuStyle.label("%d / %d" % [total_stars, max_stars], 30, MenuStyle.CREAM, true)
	stars_label.name = "StarsTotal"
	stars_box.add_child(stars_label)
	header.add_child(stars_box)

	_toast = MenuStyle.label("", 24, MenuStyle.CREAM, true)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_stylebox_override(&"normal", MenuStyle.panel_box(Color(MenuStyle.INK, 0.88), 16, 16.0))
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_toast)

	ui.resized.connect(_layout)
	_layout.call_deferred()
	_layout()


func is_city_open(city_id: StringName) -> bool:
	return bool(_open.get(city_id, false))


## Toucher d'une ville : ouverte → écran de la ville ; sinon message « Bientôt ».
func select_city(city_id: StringName) -> void:
	if is_city_open(city_id):
		city_selected.emit(city_id)
		go_to(CITY_SCREEN, {"city_id": String(city_id)})
		return
	var entry: WorldCity = world.find(city_id)
	if entry == null:
		return
	var reason: String = "bientôt disponible" if not entry.is_playable() else "termine d'abord la ville précédente"
	show_toast("%s — %s" % [entry.display_name, reason])


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.reset_size()
	var visible_size: Vector2 = ui.size
	_toast.position = Vector2((visible_size.x - _toast.size.x) * 0.5, visible_size.y - _toast.size.y - 36.0)
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func back() -> void:
	go_to(MAIN_MENU)


## Étiquette d'une ville. Ouverte : carte accent avec étoiles ; sinon sombre.
func _make_marker(entry: WorldCity, open: bool, progression: Progression) -> Button:
	var button: Button = Button.new()
	button.name = "City_%s" % entry.id
	button.set_meta(&"city_id", entry.id)
	button.set_meta(&"open", open)
	button.theme_type_variation = &"PrimaryButton" if open else &"Button"
	button.pressed.connect(select_city.bind(entry.id))
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", -2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var text_color: Color = MenuStyle.INK if open else Color(MenuStyle.CREAM, 0.75)
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 8)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		name_row.add_child(MenuIcon.make(MenuIcon.Kind.LOCK, 20.0, Color(MenuStyle.CREAM, 0.55)))
	var name_label: Label = MenuStyle.label(entry.display_name, 28 if open else 20, text_color, open)
	name_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	name_row.add_child(name_label)
	box.add_child(name_row)
	if open:
		var country: Label = MenuStyle.label(entry.country, 18, Color(MenuStyle.INK, 0.7))
		country.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		country.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
		box.add_child(country)
		var stars_row: HBoxContainer = HBoxContainer.new()
		stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stars_row.add_theme_constant_override(&"separation", 6)
		stars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_row.add_child(MenuIcon.make(MenuIcon.Kind.STAR, 22.0, MenuStyle.INK))
		var count: Label = MenuStyle.label("%d / %d" % [progression.city_stars(entry.city), entry.city.routes.size() * 3], 20, MenuStyle.INK, true)
		count.name = "Stars"
		count.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
		stars_row.add_child(count)
		box.add_child(stars_row)
	else:
		var soon: Label = MenuStyle.label("Bientôt" if not entry.is_playable() else "Verrouillée", 16, Color(MenuStyle.ACCENT, 0.85), true)
		soon.name = "Soon"
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		soon.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
		box.add_child(soon)
	button.add_child(box)
	if not open:
		var flat: StyleBoxFlat = MenuStyle.panel_box(Color(MenuStyle.INK, 0.72), 14, 0.0)
		button.add_theme_stylebox_override(&"normal", flat)
	return button


## Taille de l'étiquette selon son contenu (connu une fois dans l'arbre, Theme appliqué).
func _fit_marker(marker: Button) -> void:
	var open: bool = bool(marker.get_meta(&"open"))
	var inner: Vector2 = (marker.get_child(0) as Control).get_combined_minimum_size()
	marker.custom_minimum_size = Vector2(maxf(inner.x + (44.0 if open else 30.0), 170.0 if open else 100.0), inner.y + (24.0 if open else 14.0))
	marker.reset_size()


## Place la carte sous l'en-tête et chaque étiquette à côté de son point.
func _layout() -> void:
	var full: Vector2 = ui.size
	var top: float = HEADER_HEIGHT + 30.0
	view.set_area(Rect2(Vector2(60.0, top), Vector2(full.x - 120.0, full.y - top - 50.0)))
	for entry: WorldCity in world.cities:
		var marker: Button = markers[entry.id]
		_fit_marker(marker)
		var dot: Vector2 = view.project(WorldMapView.lon_lat(entry.map_position))
		var offset: Vector2 = LABEL_OFFSETS.get(entry.id, Vector2(70.0, -40.0))
		var center: Vector2 = dot + offset
		var pos: Vector2 = center - marker.size * 0.5
		pos.x = clampf(pos.x, 8.0, full.x - marker.size.x - 8.0)
		pos.y = clampf(pos.y, top - 20.0, full.y - marker.size.y - 8.0)
		marker.position = pos
	_leaders.queue_redraw()


## Traits entre chaque point de ville et son étiquette.
class Leaders:
	extends Control

	var screen: WorldMapScreen

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if screen == null or screen.world == null:
			return
		for entry: WorldCity in screen.world.cities:
			var marker: Button = screen.markers.get(entry.id) as Button
			if marker == null:
				continue
			var dot: Vector2 = screen.view.project(WorldMapView.lon_lat(entry.map_position))
			var rect: Rect2 = Rect2(marker.position, marker.size)
			var target: Vector2 = Vector2(clampf(dot.x, rect.position.x + 12.0, rect.end.x - 12.0), clampf(dot.y, rect.position.y, rect.end.y))
			var open: bool = screen.is_city_open(entry.id)
			var color: Color = MenuStyle.ACCENT if open else Color(MenuStyle.CREAM, 0.4)
			draw_line(dot, target, color, 2.0 if open else 1.5, true)
