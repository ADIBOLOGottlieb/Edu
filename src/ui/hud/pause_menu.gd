class_name PauseMenu
extends CanvasLayer
## Pause d'une course : bouton pause tactile (coin haut droit, zone sûre),
## touche Échap / P (action « pause ») et bouton retour d'Android. Ouvert, il
## met l'arbre en pause (get_tree().paused) et propose Reprendre, Recommencer
## (même parcours) et Carte. Il fonctionne pendant la pause (PROCESS_MODE_ALWAYS).

signal opened()
signal closed()
## Navigation demandée (Recommencer, Carte) ; émis même sans SceneRouter.
signal navigation_requested(scene_path: String, params: Dictionary)

const WORLD_MAP: String = "res://src/ui/menus/world_map.tscn"

## Coureur du niveau : son route_index sert à Recommencer.
@export var runner: LevelRunner
## false : n'utilise pas SceneRouter (tests) ; seul navigation_requested est émis.
var use_router: bool = true

var pause_button: Button
var panel: Control
var resume_button: Button
var restart_button: Button
var map_button: Button
## Contenu de l'inventaire (M8), mis à jour à chaque ouverture.
var inventory_label: Label

var _is_open: bool = false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_quit_on_go_back(false)
	var root: Control = Control.new()
	root.name = "Root"
	root.theme = MenuStyle.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.tooltip_text = "Pause"
	pause_button.custom_minimum_size = Vector2(MenuStyle.TOUCH, MenuStyle.TOUCH)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.modulate.a = 0.85
	var icon: MenuIcon = MenuIcon.make(MenuIcon.Kind.PAUSE, 40.0, MenuStyle.CREAM)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_button.add_child(icon)
	pause_button.pressed.connect(open)
	root.add_child(pause_button)

	panel = _build_panel()
	panel.visible = false
	root.add_child(panel)
	get_viewport().size_changed.connect(_layout)
	_layout()


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_refresh_inventory()
	panel.visible = true
	pause_button.visible = false
	get_tree().paused = true
	if not MainMenu.is_mobile():
		resume_button.grab_focus()
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	panel.visible = false
	pause_button.visible = true
	get_tree().paused = false
	closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


## Relance le même parcours (paramètre route_index conservé).
func restart() -> void:
	var scene: String = _current_scene_path()
	_navigate(scene, {"route_index": runner.route_index if runner != null else 0})


func to_map() -> void:
	_navigate(WORLD_MAP, {})


func _navigate(scene_path: String, params: Dictionary) -> void:
	navigation_requested.emit(scene_path, params)
	if not use_router:
		close()
		return
	var router: SceneRouterNode = get_node_or_null(^"/root/SceneRouter") as SceneRouterNode
	if router != null:
		# SceneRouter lève la pause au moment du changement de scène.
		router.go_to(scene_path, params)
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file(scene_path)


func _current_scene_path() -> String:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.scene_file_path != "":
		return scene.scene_file_path
	var owner_node: Node = owner
	if owner_node != null and owner_node.scene_file_path != "":
		return owner_node.scene_file_path
	return MenuScreen.LOME_RUN


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	var is_pause_key: bool = key != null and key.pressed and not key.echo and (key.physical_keycode == KEY_ESCAPE or key.physical_keycode == KEY_P or key.keycode == KEY_ESCAPE or key.keycode == KEY_P)
	if is_pause_key or (InputMap.has_action(InputActions.PAUSE) and event.is_action_pressed(InputActions.PAUSE)):
		get_viewport().set_input_as_handled()
		toggle()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _is_open and is_inside_tree() and MainMenu.is_mobile():
		# Sur téléphone, quitter l'appli met la course en pause.
		open()


func _build_panel() -> Control:
	var veil: ColorRect = ColorRect.new()
	veil.name = "Panel"
	veil.color = Color(MenuStyle.INK, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	column.custom_minimum_size.x = 420.0
	center.add_child(column)
	var title: Label = MenuStyle.label("PAUSE", 76, MenuStyle.CREAM)
	title.add_theme_font_override(&"font", MenuStyle.heavy_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var bar: ColorRect = ColorRect.new()
	bar.color = MenuStyle.ACCENT
	bar.custom_minimum_size = Vector2(90.0, 6.0)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(bar)
	var gap: Control = Control.new()
	gap.custom_minimum_size.y = 10.0
	column.add_child(gap)
	resume_button = MenuStyle.button("Reprendre", &"PrimaryButton")
	resume_button.name = "ResumeButton"
	resume_button.pressed.connect(close)
	column.add_child(resume_button)
	restart_button = MenuStyle.button("Recommencer")
	restart_button.name = "RestartButton"
	restart_button.pressed.connect(restart)
	column.add_child(restart_button)
	map_button = MenuStyle.button("Carte")
	map_button.name = "MapButton"
	map_button.pressed.connect(to_map)
	column.add_child(map_button)
	inventory_label = MenuStyle.label("", 20, MenuStyle.MUTED)
	inventory_label.name = "InventoryLabel"
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(inventory_label)
	return veil


## Bouton pause en haut à droite, dans la zone sûre.
func _layout() -> void:
	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	var inset_right: float = 0.0
	var inset_top: float = 0.0
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if MainMenu.is_mobile() and window_size.x > 0.0 and safe.size.x > 0:
		var to_canvas: Vector2 = visible_rect.size / window_size
		inset_right = maxf(0.0, window_size.x - float(safe.end.x)) * to_canvas.x
		inset_top = maxf(0.0, float(safe.position.y)) * to_canvas.y
	pause_button.position = Vector2(visible_rect.size.x - MenuStyle.TOUCH - 20.0 - inset_right, 16.0 + inset_top)


## Inventaire : « Inventaire 3/20 » puis les objets et leur nombre.
func _refresh_inventory() -> void:
	var service: InventoryServiceNode = get_node_or_null(^"/root/InventoryService") as InventoryServiceNode
	if service == null or inventory_label == null:
		return
	var inventory: Inventory = service.inventory
	var parts: PackedStringArray = []
	for data: EquipmentData in service.catalog.items:
		var count: int = inventory.quantity(data.id)
		if count > 0:
			parts.append("%s ×%d" % [data.display_name, count])
	inventory_label.text = "Inventaire %d/%d\n%s" % [inventory.count(), inventory.capacity(),
			", ".join(parts) if not parts.is_empty() else "vide"]
