extends SceneTree
## Capture du niveau de Lomé tel que sur téléphone (boutons tactiles affichés,
## HUD d'équipement) pour contrôle visuel. Nécessite une fenêtre (pas --headless).
## Usage : godot --path . -s tools/capture_level_hud.gd -- <fichier_png_absolu>

const SCENE: String = "res://scenes/levels/lome_run.tscn"
const WAIT_FRAMES: int = 90

var _out: String = ""
var _frame: int = 0
var _level: Node


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	_level = (load(SCENE) as PackedScene).instantiate()
	(_level.get_node("TouchControls") as TouchControls).force_visible = true
	root.add_child.call_deferred(_level)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == WAIT_FRAMES - 20:
		(_level.get_node("EquipmentHud") as EquipmentHud).show_message("+ Gilet")
	if _frame >= WAIT_FRAMES:
		root.get_texture().get_image().save_png(_out)
		print("capture : ", _out)
		return true
	return false
