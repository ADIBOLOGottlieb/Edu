extends Control
## Écran de démarrage provisoire du socle M0.
## Sera remplacé par le menu principal au jalon M7 (via SceneRouter).

const BACKGROUND: Color = Color(0.93, 0.93, 0.91)
const INK: Color = Color(0.05, 0.05, 0.06)


func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	var label: Label = Label.new()
	label.text = "EDU\nversion %s — socle M0 (aucun gameplay)" % version
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", INK)
	label.add_theme_font_size_override(&"font_size", 32)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)
