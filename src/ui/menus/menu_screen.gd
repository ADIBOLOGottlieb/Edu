class_name MenuScreen
extends Control
## Base des écrans de menu : fond optionnel (MenuBackdrop), calque d'interface
## au Theme commun (MenuStyle), contenu calé dans la zone sûre (encoches),
## navigation par SceneRouter et retour (Échap, bouton retour d'Android).
##
## Chaque écran construit son interface dans _build() ; la navigation passe par
## go_to(), qui émet navigation_requested (les tests s'y abonnent avec
## use_router = false pour ne pas changer de scène).

signal navigation_requested(scene_path: String, params: Dictionary)

const MAIN_MENU: String = "res://src/ui/menus/main_menu.tscn"
const WORLD_MAP: String = "res://src/ui/menus/world_map.tscn"
const CITY_SCREEN: String = "res://src/ui/menus/city_screen.tscn"
const RESULT_SCREEN: String = "res://src/ui/menus/result_screen.tscn"
const SETTINGS_SCREEN: String = "res://src/ui/menus/settings_screen.tscn"
const CREDITS_SCREEN: String = "res://src/ui/menus/credits_screen.tscn"
const DEV_SCREEN: String = "res://scenes/boot.tscn"
const LOME_RUN: String = "res://scenes/levels/lome_run.tscn"
const WORLD_MAP_DATA: String = "res://data/world/world_map.tres"

## false : go_to() émet seulement navigation_requested (tests, captures).
var use_router: bool = true
## Calque de l'interface (au-dessus du fond et de sa caméra).
var ui_layer: CanvasLayer
## Racine plein écran de l'interface (porte le Theme).
var ui: Control
## Conteneur du contenu, marges = zone sûre + MenuStyle.MARGIN.
var content: MarginContainer
var backdrop: MenuBackdrop


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Android : le bouton retour revient à l'écran précédent au lieu de quitter.
	get_tree().set_quit_on_go_back(false)
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 1
	add_child(ui_layer)
	ui = Control.new()
	ui.name = "Root"
	ui.theme = MenuStyle.theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui)
	_build_background()
	content = MarginContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(content)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_build()


## Fond de l'écran (sous le contenu). Par défaut : rien.
func _build_background() -> void:
	pass


## Construit l'interface dans `content` (à redéfinir).
func _build() -> void:
	pass


## Retour (Échap, bouton retour d'Android, bouton ◀). Par défaut : menu principal.
func back() -> void:
	go_to(MAIN_MENU)


func go_to(scene_path: String, params: Dictionary = {}) -> void:
	navigation_requested.emit(scene_path, params)
	if not use_router:
		return
	var router: SceneRouterNode = get_node_or_null(^"/root/SceneRouter") as SceneRouterNode
	if router != null:
		router.go_to(scene_path, params)
	else:
		get_tree().change_scene_to_file(scene_path)


## Paramètre transmis par l'écran précédent (SceneRouter), ou `default`.
func router_param(key: String, default: Variant = null) -> Variant:
	var router: SceneRouterNode = get_node_or_null(^"/root/SceneRouter") as SceneRouterNode
	return router.param(key, default) if router != null else default


func add_backdrop(city_theme: CityTheme, start_offset: float = 0.0, vertical_offset: float = 0.0) -> MenuBackdrop:
	backdrop = MenuBackdrop.new()
	backdrop.name = "Backdrop"
	backdrop.theme = city_theme
	backdrop.start_offset = start_offset
	backdrop.vertical_offset = vertical_offset
	add_child(backdrop)
	move_child(backdrop, 0)
	return backdrop


## Voile sombre en dégradé (lisibilité du texte sur le décor).
func add_shade(top_alpha: float, bottom_alpha: float, left_alpha: float = 0.0) -> Shade:
	var shade: Shade = Shade.new()
	shade.top_alpha = top_alpha
	shade.bottom_alpha = bottom_alpha
	shade.left_alpha = left_alpha
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	return shade


## Bouton rond « retour » (cible tactile carrée de MenuStyle.TOUCH).
func make_back_button() -> Button:
	var button: Button = Button.new()
	button.name = "BackButton"
	button.tooltip_text = "Retour"
	button.custom_minimum_size = Vector2(MenuStyle.TOUCH, MenuStyle.TOUCH)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon: MenuIcon = MenuIcon.make(MenuIcon.Kind.BACK, 44.0, MenuStyle.CREAM)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	button.pressed.connect(back)
	return button


## Le monde : WorldMap des données.
static func load_world() -> WorldMap:
	return load(WORLD_MAP_DATA) as WorldMap


static func current_progression() -> Progression:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var profile: ProfileServiceNode = tree.root.get_node_or_null(^"ProfileService") as ProfileServiceNode if tree != null else null
	return profile.progression if profile != null else Progression.new()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


## Marges du contenu : zone sûre de l'appareil (convertie en px de canevas) + MARGIN.
func _apply_safe_area() -> void:
	if content == null:
		return
	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var insets: Array[float] = [0.0, 0.0, 0.0, 0.0]
	if window_size.x > 0.0 and window_size.y > 0.0 and safe.size.x > 0 and safe.size.y > 0 and OS.has_feature("mobile"):
		var to_canvas: Vector2 = visible_rect.size / window_size
		var window_pos: Vector2 = Vector2(DisplayServer.window_get_position())
		var safe_pos: Vector2 = Vector2(safe.position) - window_pos
		insets = [
			maxf(0.0, safe_pos.x) * to_canvas.x,
			maxf(0.0, safe_pos.y) * to_canvas.y,
			maxf(0.0, window_size.x - safe_pos.x - float(safe.size.x)) * to_canvas.x,
			maxf(0.0, window_size.y - safe_pos.y - float(safe.size.y)) * to_canvas.y,
		]
	content.add_theme_constant_override(&"margin_left", int(MenuStyle.MARGIN + insets[0]))
	content.add_theme_constant_override(&"margin_top", int(MenuStyle.MARGIN * 0.75 + insets[1]))
	content.add_theme_constant_override(&"margin_right", int(MenuStyle.MARGIN + insets[2]))
	content.add_theme_constant_override(&"margin_bottom", int(MenuStyle.MARGIN * 0.75 + insets[3]))


## Voile : dégradé vertical d'encre (haut → bas) et assombrissement à gauche.
class Shade:
	extends Control

	var top_alpha: float = 0.0
	var bottom_alpha: float = 0.5
	var left_alpha: float = 0.0

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var ink: Color = MenuStyle.INK
		var s: Vector2 = size
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0.0), s, Vector2(0.0, s.y)]),
			PackedColorArray([Color(ink, top_alpha), Color(ink, top_alpha), Color(ink, bottom_alpha), Color(ink, bottom_alpha)]))
		if left_alpha > 0.0:
			var w: float = s.x * 0.62
			draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, s.y), Vector2(0.0, s.y)]),
				PackedColorArray([Color(ink, left_alpha), Color(ink, 0.0), Color(ink, 0.0), Color(ink, left_alpha)]))
