class_name CreditsScreen
extends MenuScreen
## Crédits : équipe, moteur, ressources tierces et leurs licences, note sur
## les monuments (évocations stylisées originales). Liste défilante.

## [titre de section, lignes].
const SECTIONS: Array[Array] = [
	["Jeu", [
		"EDU — « édu » : la course, le pays (en ewe)",
		"Conception, programmation et décors par code : l'équipe EDU",
	]],
	["Ressources tierces", [
		"Mannequin et animations : Quaternius — Universal Animation Library 1 & 2 (CC0)",
		"Moteur : Godot Engine (MIT)",
		"Tests : GUT — Godot Unit Test (MIT)",
	]],
	["Villes et monuments", [
		"Les monuments et repères des villes sont des évocations stylisées originales, dessinées par code : aucune photographie ni image existante n'est reproduite.",
		"La carte du monde est un tracé simplifié original.",
	]],
	["Merci", [
		"À Lomé et au Togo, première étape du tour du monde.",
		"À toutes celles et ceux qui testent le jeu.",
	]],
]

var scroll: ScrollContainer
## Défilement automatique (px/s), arrêté dès que le joueur touche la liste.
var auto_scroll_speed: float = 26.0

## Négatif : pause avant le défilement (≈ 2 s).
var _scroll_position: float = -52.0
var _auto: bool = true


func _build_background() -> void:
	add_backdrop(load(MainMenu.THEME_PATH) as CityTheme, 8200.0, -40.0)
	add_shade(0.75, 0.85)


func _build() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 20)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	header.add_child(make_back_button())
	var title: Label = MenuStyle.label("Crédits", 48, MenuStyle.CREAM, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.gui_input.connect(_on_scroll_input)
	column.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var text: VBoxContainer = VBoxContainer.new()
	text.name = "Lines"
	text.add_theme_constant_override(&"separation", 6)
	text.custom_minimum_size.x = 900.0
	center.add_child(text)
	var logo: Label = MenuStyle.label("EDU", 72, MenuStyle.CREAM)
	logo.add_theme_font_override(&"font", MenuStyle.heavy_font())
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_child(logo)
	for section: Array in SECTIONS:
		var gap: Control = Control.new()
		gap.custom_minimum_size.y = 16.0
		text.add_child(gap)
		var caption: Label = MenuStyle.label(String(section[0]).to_upper(), 20, MenuStyle.ACCENT, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.add_child(caption)
		for line: Variant in section[1] as Array:
			var label: Label = MenuStyle.label(str(line), 23, MenuStyle.CREAM)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.add_child(label)
	var tail: Control = Control.new()
	tail.custom_minimum_size.y = 120.0
	text.add_child(tail)


func _process(delta: float) -> void:
	if not _auto or scroll == null:
		return
	_scroll_position += auto_scroll_speed * delta
	scroll.scroll_vertical = maxi(0, int(_scroll_position))


func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_auto = false


## Texte complet affiché (tests).
func all_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for node: Node in find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	return "\n".join(lines)
