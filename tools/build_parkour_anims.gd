extends SceneTree
## Extrait les clips de parkour de la bibliothèque Quaternius 2 (CC0) et les
## recible sur le mannequin de la bibliothèque 1.
##
## Les deux squelettes sont identiques (mêmes poses de repos, 53 os vérifiés) ;
## seuls les noms diffèrent (« pelvis » ↔ « DEF-hips ») : le reciblage consiste à
## renommer les pistes. Le déplacement de la racine (« _RM ») est retiré : c'est la
## physique du jeu qui déplace le corps.
## Usage : godot --headless --path . -s tools/build_parkour_anims.gd

const SOURCE: String = "res://assets/characters/quaternius/source/ual2_standard.glb"
const OUTPUT: String = "res://assets/characters/quaternius/parkour_anims.res"
const TARGET_SKELETON: String = "Rig/Skeleton3D"
## Clip source → nom dans la bibliothèque « parkour ».
const CLIPS: Dictionary[StringName, StringName] = {
	&"ClimbUp_1m_RM": &"ClimbUp",
	&"Slide_Start": &"Slide_Start",
	&"Slide": &"Slide",
	&"Slide_Exit": &"Slide_Exit",
	&"NinjaJump_Start": &"NinjaJump_Start",
	&"NinjaJump_Idle": &"NinjaJump_Idle",
	&"NinjaJump_Land": &"NinjaJump_Land",
	&"Hit_Knockback": &"Hit_Knockback",
	&"LayToIdle": &"LayToIdle",
}
const SIDES: Dictionary[String, String] = {"l": "L", "r": "R"}


func _init() -> void:
	var scene: Node = (load(SOURCE) as PackedScene).instantiate()
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var library: AnimationLibrary = AnimationLibrary.new()
	for source_name: StringName in CLIPS:
		var animation: Animation = player.get_animation(source_name).duplicate(true) as Animation
		_retarget(animation)
		library.add_animation(CLIPS[source_name], animation)
		print("%-16s → %-16s %.2f s, %d pistes" % [source_name, CLIPS[source_name], animation.length, animation.get_track_count()])
	scene.free()
	var error: Error = ResourceSaver.save(library, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	print("enregistré : ", OUTPUT, " (", error_string(error), ")")
	quit(0 if error == OK else 1)


func _retarget(animation: Animation) -> void:
	for track: int in range(animation.get_track_count() - 1, -1, -1):
		var bone: String = String(animation.track_get_path(track)).get_slice(":", 1)
		var target: String = target_bone(bone)
		var is_root_motion: bool = bone == "root" and animation.track_get_type(track) == Animation.TYPE_POSITION_3D
		if target == "" or is_root_motion:
			animation.remove_track(track)
			continue
		animation.track_set_path(track, NodePath("%s:%s" % [TARGET_SKELETON, target]))


## Nom de l'os du mannequin (bibliothèque 1) pour un os de la bibliothèque 2,
## ou "" pour un os sans équivalent (extrémités « _leaf »).
static func target_bone(bone: String) -> String:
	if bone.contains("leaf"):
		return ""
	match bone:
		"root":
			return "root"
		"pelvis":
			return "DEF-hips"
		"neck_01":
			return "DEF-neck"
		"Head":
			return "DEF-head"
	if bone.begins_with("spine_0"):
		return "DEF-spine.00" + bone.right(1)
	var side: String = SIDES.get(bone.right(1), "")
	if side == "":
		return ""
	var base: String = bone.left(-2)
	var simple: Dictionary[String, String] = {
		"clavicle": "shoulder", "upperarm": "upper_arm", "lowerarm": "forearm", "hand": "hand",
		"thigh": "thigh", "calf": "shin", "foot": "foot", "ball": "toe",
	}
	if simple.has(base):
		return "DEF-%s.%s" % [simple[base], side]
	# Doigts : index_01 → f_index.01, thumb_01 → thumb.01.
	var finger: String = base.get_slice("_", 0)
	var joint: String = base.get_slice("_", 1)
	if finger == "thumb":
		return "DEF-thumb.%s.%s" % [joint, side]
	return "DEF-f_%s.%s.%s" % [finger, joint, side]
