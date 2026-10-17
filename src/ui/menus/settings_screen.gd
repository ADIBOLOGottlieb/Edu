class_name SettingsScreen
extends MenuScreen
## Réglages : volumes musique et effets, vibrations, opacité et taille des
## commandes tactiles, qualité graphique, langue. Chaque changement est écrit
## dans SettingsService.settings puis appliqué et sauvegardé (save()).
## Textes en français pour l'instant (la langue choisie est enregistrée).

const QUALITY_NAMES: Array[String] = ["Basse", "Moyenne", "Haute"]
const LANGUAGE_NAMES: Array[String] = ["Français", "English"]

var music_slider: HSlider
var sfx_slider: HSlider
var opacity_slider: HSlider
var scale_slider: HSlider
var vibrations_toggle: CheckButton
var fps_toggle: CheckButton
var quality_option: OptionButton
var language_option: OptionButton

var _value_labels: Dictionary[HSlider, Label] = {}


func _build_background() -> void:
	add_backdrop(load(MainMenu.THEME_PATH) as CityTheme, 5200.0, -40.0)
	add_shade(0.7, 0.8)


func _build() -> void:
	var settings: GameSettings = current_settings()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 20)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	header.add_child(make_back_button())
	var title: Label = MenuStyle.label("Réglages", 48, MenuStyle.CREAM, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(columns)
	var left: VBoxContainer = _section(columns, "Son et commandes")
	music_slider = _slider_row(left, "Musique", 0.0, 1.0, settings.music_volume, true)
	sfx_slider = _slider_row(left, "Effets", 0.0, 1.0, settings.sfx_volume, true)
	opacity_slider = _slider_row(left, "Opacité des boutons", 0.2, 1.0, settings.touch_opacity, true)
	scale_slider = _slider_row(left, "Taille des boutons", 0.8, 1.4, settings.touch_scale, false)
	var right: VBoxContainer = _section(columns, "Jeu")
	vibrations_toggle = CheckButton.new()
	vibrations_toggle.name = "Vibrations"
	vibrations_toggle.button_pressed = settings.vibrations
	vibrations_toggle.custom_minimum_size = Vector2(0.0, MenuStyle.TOUCH * 0.8)
	_row(right, "Vibrations", vibrations_toggle)
	fps_toggle = CheckButton.new()
	fps_toggle.name = "Fps"
	fps_toggle.button_pressed = settings.show_fps
	fps_toggle.custom_minimum_size = Vector2(0.0, MenuStyle.TOUCH * 0.8)
	_row(right, "Afficher les FPS", fps_toggle)
	quality_option = _option(QUALITY_NAMES, GameSettings.QUALITIES.find(settings.quality))
	quality_option.name = "Quality"
	_row(right, "Qualité graphique", quality_option)
	language_option = _option(LANGUAGE_NAMES, GameSettings.LANGUAGES.find(settings.language))
	language_option.name = "Language"
	_row(right, "Langue", language_option)

	for slider: HSlider in [music_slider, sfx_slider, opacity_slider, scale_slider]:
		slider.value_changed.connect(_on_slider_changed.bind(slider))
	vibrations_toggle.toggled.connect(func(_on: bool) -> void: apply_changes())
	fps_toggle.toggled.connect(func(_on: bool) -> void: apply_changes())
	quality_option.item_selected.connect(func(_index: int) -> void: apply_changes())
	language_option.item_selected.connect(func(_index: int) -> void: apply_changes())
	if not MainMenu.is_mobile():
		music_slider.grab_focus.call_deferred()


static func current_settings() -> GameSettings:
	var service: SettingsServiceNode = _service()
	return service.settings if service != null else GameSettings.new()


## Recopie les commandes dans GameSettings, puis applique et sauvegarde.
func apply_changes() -> void:
	var service: SettingsServiceNode = _service()
	if service == null:
		return
	var s: GameSettings = service.settings
	s.music_volume = music_slider.value
	s.sfx_volume = sfx_slider.value
	s.touch_opacity = opacity_slider.value
	s.touch_scale = scale_slider.value
	s.vibrations = vibrations_toggle.button_pressed
	s.show_fps = fps_toggle.button_pressed
	s.quality = GameSettings.QUALITIES[clampi(quality_option.selected, 0, GameSettings.QUALITIES.size() - 1)]
	s.language = GameSettings.LANGUAGES[clampi(language_option.selected, 0, GameSettings.LANGUAGES.size() - 1)]
	service.save()


func _on_slider_changed(_value: float, slider: HSlider) -> void:
	_refresh_value(slider)
	apply_changes()


static func _service() -> SettingsServiceNode:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"SettingsService") as SettingsServiceNode if tree != null else null


func _section(parent: Container, caption: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override(&"panel", MenuStyle.panel_box(Color(MenuStyle.INK, 0.66), 22, 26.0))
	parent.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)
	box.add_child(MenuStyle.label(caption.to_upper(), 18, MenuStyle.ACCENT, true))
	return box


func _row(parent: Container, caption: String, control: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.custom_minimum_size.y = MenuStyle.TOUCH * 0.8
	parent.add_child(row)
	var label: Label = MenuStyle.label(caption, 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)


## Curseur sur sa ligne : libellé, curseur, valeur (en % si percent).
func _slider_row(parent: Container, caption: String, min_value: float, max_value: float, value: float, percent: bool) -> HSlider:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 0)
	parent.add_child(row)
	var top: HBoxContainer = HBoxContainer.new()
	row.add_child(top)
	var label: Label = MenuStyle.label(caption, 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var value_label: Label = MenuStyle.label("", 22, MenuStyle.ACCENT, true)
	top.add_child(value_label)
	var slider: HSlider = HSlider.new()
	slider.name = caption
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.05
	slider.value = value
	slider.set_meta(&"percent", percent)
	slider.custom_minimum_size = Vector2(0.0, 52.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	_value_labels[slider] = value_label
	_refresh_value(slider)
	return slider


func _refresh_value(slider: HSlider) -> void:
	var label: Label = _value_labels.get(slider) as Label
	if label == null:
		return
	if bool(slider.get_meta(&"percent", true)):
		label.text = "%d %%" % roundi(slider.value * 100.0)
	else:
		label.text = "× %.2f" % slider.value


func _option(names: Array[String], selected: int) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	for item: String in names:
		option.add_item(item)
	option.selected = maxi(selected, 0)
	option.custom_minimum_size = Vector2(240.0, MenuStyle.TOUCH * 0.8)
	option.fit_to_longest_item = true
	return option
