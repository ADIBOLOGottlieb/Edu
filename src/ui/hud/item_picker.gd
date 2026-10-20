class_name ItemPicker
extends CanvasLayer
## Choix de l'objet (M8) : toucher l'objet en haut à gauche ouvre ce panneau.
## Le jeu se met en pause ; chaque objet possédé est une carte (nom, nombre,
## effet, durée, actif ou non). Toucher une carte la choisit pour le bouton
## OBJET ; « Fermer » ou retour referme sans rien changer.

signal opened()
signal closed()

const COLUMNS: int = 4

@export var runtime: EquipmentRuntime

var panel: Control
var grid: GridContainer
var cards: Array[Button] = []

var _was_paused: bool = false


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = _build()
	panel.visible = false
	add_child(panel)


func is_open() -> bool:
	return panel.visible


func open() -> void:
	if is_open() or runtime == null:
		return
	_fill()
	panel.visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	opened.emit()


func close() -> void:
	if not is_open():
		return
	panel.visible = false
	get_tree().paused = _was_paused
	closed.emit()


## Choisit l'objet `id` pour le bouton OBJET et referme.
func choose(id: StringName) -> void:
	if runtime != null and runtime.inventory.quantity(id) > 0:
		runtime.selected = id
		runtime.changed.emit()
	close()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputActions.PAUSE)):
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open():
		close()


func _fill() -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	cards.clear()
	for item: Dictionary in runtime.owned_items():
		var data: EquipmentData = runtime.catalog.get_item(item["id"])
		var card: Button = Button.new()
		card.name = "Item_%s" % String(item["id"])
		card.theme_type_variation = &"CardButton"
		card.custom_minimum_size = Vector2(250.0, 150.0)
		card.focus_mode = Control.FOCUS_NONE
		card.set_meta(&"item_id", item["id"])
		card.pressed.connect(choose.bind(item["id"]))
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		var selected: bool = item["id"] == runtime.selected
		var title: Label = MenuStyle.label("%s ×%d" % [item["name"], item["count"]], 22, MenuStyle.ACCENT if selected else MenuStyle.CREAM, true)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(title)
		var text: String = data.description if data != null else ""
		if data != null and data.duration >= 1.0:
			text += "  (%d s)" % roundi(data.duration)
		var info: Label = MenuStyle.label(text, 16, MenuStyle.MUTED)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(info)
		var state: String = "Choisi" if selected else ("Actif" if runtime.effects.is_active(item["id"]) else "")
		if state != "":
			box.add_child(MenuStyle.label(state, 16, Color(0.55, 0.9, 0.45), true))
		grid.add_child(card)
		cards.append(card)
	if cards.is_empty():
		var empty: Label = MenuStyle.label("Aucun objet. Ramasse des caisses sur les toits !", 22, MenuStyle.CREAM)
		empty.name = "Empty"
		grid.add_child(empty)


func _build() -> Control:
	var veil: ColorRect = ColorRect.new()
	veil.name = "Panel"
	veil.color = Color(MenuStyle.INK, 0.78)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	center.add_child(column)
	var title: Label = MenuStyle.label("CHOISIS TON OBJET", 40, MenuStyle.CREAM)
	title.add_theme_font_override(&"font", MenuStyle.heavy_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var hint: Label = MenuStyle.label("Touche un objet : le bouton OBJET l'utilisera.", 20, MenuStyle.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1080.0, 330.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	grid = GridContainer.new()
	grid.name = "Grid"
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 14)
	scroll.add_child(grid)
	var close_button: Button = MenuStyle.button("Fermer")
	close_button.name = "CloseButton"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	column.add_child(close_button)
	return veil
