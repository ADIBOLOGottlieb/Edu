extends Control
## Écran de démarrage provisoire : accès aux scènes de développement.
## Sera remplacé par le menu principal au jalon M7 (via SceneRouter).

const BACKGROUND: Color = Color(0.93, 0.93, 0.91)
const INK: Color = Color(0.05, 0.05, 0.06)
## Libellé → scène.
const DESTINATIONS: Array[Array] = [
	["Parcours fixe (avec arrivée)", "res://scenes/levels/fixed_run.tscn"],
	["Course infinie (aléatoire)", "res://scenes/levels/endless_run.tscn"],
	["Bac à sable : mouvement", "res://scenes/sandbox/movement_sandbox.tscn"],
]


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
	label.offset_bottom = -260.0
	add_child(label)

	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 14)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	buttons.position.y += 80.0
	for destination: Array in DESTINATIONS:
		var button: Button = Button.new()
		button.text = String(destination[0])
		button.add_theme_font_size_override(&"font_size", 24)
		button.custom_minimum_size = Vector2(420, 72)
		button.pressed.connect(_open.bind(String(destination[1])))
		buttons.add_child(button)
	add_child(buttons)
	buttons.position.x -= buttons.get_combined_minimum_size().x * 0.5


func _open(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
