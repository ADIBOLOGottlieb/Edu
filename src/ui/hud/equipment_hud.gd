class_name EquipmentHud
extends CanvasLayer
## Équipement à l'écran (M8) : objet choisi en haut à gauche (toucher = ouvrir
## le choix des objets, ItemPicker ; Tab = objet suivant), effets actifs avec leur
## temps restant, messages courts au centre.
## L'utilisation passe par l'action use_item (bouton tactile OBJET, touche E).

const MESSAGE_TIME: float = 1.6
const TOP: float = 44.0

@export var runtime: EquipmentRuntime

var slot_button: Button
var effects_label: Label
var message_label: Label
var picker: ItemPicker

var _message_left: float = 0.0


func _ready() -> void:
	layer = 16
	slot_button = MenuStyle.button("", &"", 210.0)
	slot_button.name = "SlotButton"
	slot_button.focus_mode = Control.FOCUS_NONE
	slot_button.add_theme_font_size_override(&"font_size", 20)
	slot_button.custom_minimum_size.y = 52.0
	slot_button.position = Vector2(20.0, TOP)
	slot_button.pressed.connect(func() -> void: picker.open())
	add_child(slot_button)
	effects_label = MenuStyle.label("", 18, MenuStyle.ACCENT, true)
	effects_label.position = Vector2(24.0, TOP + 62.0)
	add_child(effects_label)
	message_label = MenuStyle.label("", 26, MenuStyle.CREAM, true)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.position.y = 120.0
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message_label)
	picker = ItemPicker.new()
	picker.name = "ItemPicker"
	picker.runtime = runtime
	add_child(picker)
	if runtime != null:
		runtime.changed.connect(_refresh)
		runtime.message.connect(show_message)
	_refresh()


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		message_label.modulate.a = clampf(_message_left / 0.4, 0.0, 1.0)


func show_message(text: String) -> void:
	message_label.text = text
	message_label.reset_size()
	message_label.position.x = (get_viewport().get_visible_rect().size.x - message_label.size.x) * 0.5
	_message_left = MESSAGE_TIME
	message_label.modulate.a = 1.0


func _refresh() -> void:
	if runtime == null or runtime.catalog == null:
		slot_button.visible = false
		return
	var data: EquipmentData = runtime.catalog.get_item(runtime.selected)
	if data == null:
		slot_button.text = "Aucun objet"
		slot_button.disabled = true
	else:
		slot_button.disabled = false
		var kinds: int = runtime.owned_items().size()
		slot_button.text = "%s ×%d%s" % [data.display_name, runtime.inventory.quantity(data.id), "  ⇄" if kinds > 1 else ""]
	var lines: PackedStringArray = []
	for id: StringName in runtime.effects.active_ids():
		var active: EquipmentData = runtime.catalog.get_item(id)
		if active != null and active.duration >= 1.0:
			lines.append("%s  %d s" % [active.display_name, ceili(runtime.effects.remaining(id))])
	effects_label.text = "\n".join(lines)
