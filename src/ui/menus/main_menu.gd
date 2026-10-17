class_name MainMenu
extends MenuScreen
## Menu principal : titre « EDU », décor de Lomé qui dérive lentement derrière,
## coureur en plein saut sur les toits. Jouer → carte du monde ; Réglages ;
## Crédits ; Quitter (PC uniquement) ; « Développeur » discret → scène de
## lancement des niveaux de test (scenes/boot.tscn).

const THEME_PATH: String = "res://data/cities/lome_theme.tres"

var play_button: Button
var settings_button: Button
var credits_button: Button
var quit_button: Button
var developer_button: Button


func _build_background() -> void:
	var city_theme: CityTheme = load(THEME_PATH) as CityTheme
	add_backdrop(city_theme, 0.0, -40.0)
	add_shade(0.05, 0.2, 0.72)
	var art: RooftopArt = RooftopArt.new()
	art.name = "Rooftops"
	art.ink = city_theme.ink
	art.accent = city_theme.accent
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(art)


func _build() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.x = 420.0
	row.add_child(column)

	var title: Label = MenuStyle.label("EDU", 168, MenuStyle.CREAM)
	title.name = "Title"
	title.add_theme_font_override(&"font", MenuStyle.heavy_font())
	title.add_theme_constant_override(&"line_spacing", -40)
	title.add_theme_color_override(&"font_shadow_color", Color(MenuStyle.INK, 0.55))
	title.add_theme_constant_override(&"shadow_offset_x", 0)
	title.add_theme_constant_override(&"shadow_offset_y", 6)
	var title_box: MarginContainer = MarginContainer.new()
	# La police réserve beaucoup d'espace au-dessus et au-dessous des capitales.
	title_box.add_theme_constant_override(&"margin_top", -18)
	title_box.add_theme_constant_override(&"margin_bottom", -34)
	title_box.add_child(title)
	column.add_child(title_box)

	var bar: ColorRect = ColorRect.new()
	bar.color = MenuStyle.ACCENT
	bar.custom_minimum_size = Vector2(120.0, 8.0)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(bar)

	var subtitle: Label = MenuStyle.label("« édu » : la course, le pays — en ewe", 24, MenuStyle.MUTED)
	subtitle.name = "Subtitle"
	column.add_child(subtitle)
	var tour: Label = MenuStyle.label("Tour du monde · 1re étape : Lomé, Togo", 22, Color(MenuStyle.ACCENT, 0.95), true)
	column.add_child(tour)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 18.0
	column.add_child(spacer)

	play_button = MenuStyle.button("JOUER", &"PrimaryButton", 400.0)
	play_button.name = "PlayButton"
	play_button.custom_minimum_size.y = 96.0
	play_button.pressed.connect(play)
	column.add_child(play_button)

	var pair: HBoxContainer = HBoxContainer.new()
	pair.add_theme_constant_override(&"separation", 14)
	column.add_child(pair)
	settings_button = MenuStyle.button("Réglages")
	settings_button.name = "SettingsButton"
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.pressed.connect(go_to.bind(SETTINGS_SCREEN, {}))
	pair.add_child(settings_button)
	credits_button = MenuStyle.button("Crédits")
	credits_button.name = "CreditsButton"
	credits_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_button.pressed.connect(go_to.bind(CREDITS_SCREEN, {}))
	pair.add_child(credits_button)

	quit_button = MenuStyle.button("Quitter")
	quit_button.name = "QuitButton"
	quit_button.visible = not is_mobile()
	quit_button.pressed.connect(quit)
	column.add_child(quit_button)

	# Coin bas droit : version et accès développeur, discrets.
	var corner: HBoxContainer = HBoxContainer.new()
	corner.add_theme_constant_override(&"separation", 8)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	var version_label: Label = MenuStyle.label("v%s" % version, 18, Color(MenuStyle.CREAM, 0.45))
	version_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	corner.add_child(version_label)
	developer_button = MenuStyle.button("Développeur", &"GhostButton")
	developer_button.name = "DeveloperButton"
	developer_button.custom_minimum_size = Vector2(0.0, 56.0)
	developer_button.pressed.connect(go_to.bind(DEV_SCREEN, {}))
	corner.add_child(developer_button)
	ui.add_child(corner)
	corner.anchor_left = 1.0
	corner.anchor_top = 1.0
	corner.anchor_right = 1.0
	corner.anchor_bottom = 1.0
	corner.offset_left = -20.0
	corner.offset_top = -14.0
	corner.offset_right = -20.0
	corner.offset_bottom = -14.0

	if not is_mobile():
		play_button.grab_focus.call_deferred()


func play() -> void:
	go_to(WORLD_MAP)


func quit() -> void:
	get_tree().quit()


## Retour sur le menu principal : quitte le jeu sur mobile, ne fait rien sur PC.
func back() -> void:
	if is_mobile():
		quit()


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
