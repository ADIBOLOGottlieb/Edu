extends Control
## Écran de démarrage provisoire.
## Sera remplacé par le menu principal au jalon M7 (via SceneRouter).

const BACKGROUND: Color = Color(0.93, 0.93, 0.91)
const INK: Color = Color(0.05, 0.05, 0.06)
const MOVEMENT_SANDBOX: String = "res://scenes/sandbox/movement_sandbox.tscn"


func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	var label: Label = Label.new()
	label.text = "EDU\nversion %s — prototype (aucune mission jouable)" % version
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", INK)
	label.add_theme_font_size_override(&"font_size", 32)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)

	var sandbox_button: Button = Button.new()
	sandbox_button.text = "Bac à sable : mouvement"
	sandbox_button.add_theme_font_size_override(&"font_size", 24)
	sandbox_button.custom_minimum_size = Vector2(360, 72)
	sandbox_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	sandbox_button.position.y -= 120.0
	sandbox_button.pressed.connect(_open_movement_sandbox)
	add_child(sandbox_button)


func _open_movement_sandbox() -> void:
	get_tree().change_scene_to_file(MOVEMENT_SANDBOX)
