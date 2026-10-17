class_name RunnerModelVisual
extends Node2D
## Silhouette 3D : un mannequin humain animé par capture de mouvement (Quaternius,
## CC0), rendu en noir uni dans un SubViewport par une caméra orthographique de
## profil, puis affiché comme un sprite 2D.
##
## Comme RunnerVisual, ce nœud lit l'état du RunnerBody et ne le modifie jamais.
## - Les animations capturées se fondent les unes dans les autres au changement d'état.
## - Course et sprint suivent la vitesse réelle (pas de pieds qui glissent).
## - Escalade et suspension : les clips capturés n'existent pas ; les bras sont posés
##   par-dessus l'animation (un bras se tend vers le haut pendant que l'autre tire,
##   puis les deux mains au rebord).
## - Saltos et vrilles : rotation des FigureAnimation autour des hanches.
## Repère : pieds en (0, 0), avant vers +x.

const MODEL_SCENE: String = "res://assets/characters/quaternius/mannequin_anims.glb"
## Clips de parkour de la bibliothèque 2, reciblés (tools/build_parkour_anims.gd).
const PARKOUR_LIBRARY: String = "res://assets/characters/quaternius/parkour_anims.res"
## Résolution du rendu (carré) et étendue verticale vue par la caméra (m).
const VIEWPORT_SIZE: int = 320
const VIEW_HEIGHT_M: float = 3.2
## Hauteur du point visé par la caméra au-dessus des pieds (m).
const CAMERA_TARGET_M: float = 1.3
## Taille du mannequin à l'écran (px) : calée sur la capsule de collision.
const SCREEN_HEIGHT_PX: float = 74.0
const MODEL_HEIGHT_M: float = 1.8
const HIP_HEIGHT_M: float = 0.95
## Durée des fondus entre animations (s).
const BLEND_TIME: float = 0.16
## Vitesse (px/s) à laquelle les cycles de course sont joués à vitesse normale.
const JOG_REFERENCE_SPEED: float = 300.0
const SPRINT_REFERENCE_SPEED: float = 470.0
## Cadence des bras pendant l'escalade (cycles par seconde).
const CLIMB_ARM_HZ: float = 1.6

## État → animation en boucle (ou finale). Les entrées sont jouées d'abord (INTROS).
const CLIPS: Dictionary[PlayerState.State, StringName] = {
	PlayerState.State.IDLE: &"Idle",
	PlayerState.State.RUN: &"Jog_Fwd",
	PlayerState.State.SPRINT: &"Sprint",
	PlayerState.State.JUMP: &"parkour/NinjaJump_Idle",
	PlayerState.State.DOUBLE_JUMP: &"parkour/NinjaJump_Idle",
	PlayerState.State.FALL: &"parkour/NinjaJump_Idle",
	PlayerState.State.LANDING: &"parkour/NinjaJump_Land",
	PlayerState.State.ROLL: &"Roll",
	PlayerState.State.SLIDE: &"parkour/Slide",
	PlayerState.State.VAULT: &"parkour/ClimbUp",
	PlayerState.State.WALL_RUN: &"Sprint",
	PlayerState.State.WALL_CLIMB: &"Jog_Fwd",
	PlayerState.State.LEDGE_HANG: &"Jump",
	PlayerState.State.HIT: &"parkour/Hit_Knockback",
	PlayerState.State.STAGGER: &"parkour/Hit_Knockback",
	PlayerState.State.DEATH: &"Death01",
}
## Clip d'entrée joué jusqu'au bout avant la boucle de l'état.
const INTROS: Dictionary[PlayerState.State, StringName] = {
	PlayerState.State.JUMP: &"parkour/NinjaJump_Start",
	PlayerState.State.DOUBLE_JUMP: &"parkour/NinjaJump_Start",
	PlayerState.State.SLIDE: &"parkour/Slide_Start",
}
## Vitesse de lecture des clips plus lents que la physique du jeu.
const CLIP_SPEED: Dictionary[StringName, float] = {
	&"parkour/NinjaJump_Start": 2.4,
	&"parkour/NinjaJump_Land": 2.6,
	&"parkour/Slide_Start": 2.2,
	&"parkour/ClimbUp": 1.6,
	&"Roll": 1.7,
}
## Hissage après une suspension : le clip ClimbUp est joué pendant cette durée (s).
const MANTLE_TIME: float = 0.45

@export var figure_library: FigureLibrary
@export var ink: Color = Color(0.04, 0.04, 0.05)

var _body: RunnerBody
var _viewport: SubViewport
var _pivot: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _sprite: Sprite2D
var _current: StringName = &""
var _state: PlayerState.State = PlayerState.State.IDLE
var _intro_done: bool = true
var _mantle_left: float = 0.0
var _rotation: float = 0.0
## Orientation lissée (rad autour de Y) pour un demi-tour sans saut d'image.
var _yaw: float = PI * 0.5
## Poids des gestes de bras posés par-dessus l'animation (0 = animation pure).
var _arm_weight: float = 0.0
var _climb_phase: float = 0.0


func _ready() -> void:
	_body = get_parent() as RunnerBody
	_build_viewport()
	if _body != null:
		_body.state_changed.connect(_on_state_changed)


## Animation en cours (lecture seule, pour les tests).
func current_clip() -> StringName:
	return _current


## Poids des gestes d'escalade sur les bras (lecture seule, pour les tests).
func arm_weight() -> float:
	return _arm_weight


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEWPORT_SIZE, VIEWPORT_SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_HEIGHT_M
	camera.position = Vector3(0.0, CAMERA_TARGET_M, 10.0)
	camera.near = 0.1
	camera.far = 50.0
	_viewport.add_child(camera)

	# Pivot aux hanches : les saltos tournent autour du bassin.
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, HIP_HEIGHT_M, 0.0)
	_viewport.add_child(_pivot)
	_model = (load(MODEL_SCENE) as PackedScene).instantiate() as Node3D
	_model.position = Vector3(0.0, -HIP_HEIGHT_M, 0.0)
	_pivot.add_child(_model)
	_apply_ink(_model)
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	# Les boucles (« _Loop ») sont reconnues à l'import, qui retire ce suffixe.
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_player.add_animation_library(&"parkour", load(PARKOUR_LIBRARY) as AnimationLibrary)
	# Avancée manuelle : les gestes de bras sont posés juste après l'animation.
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

	_sprite = Sprite2D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.centered = false
	var pixels_per_m: float = float(VIEWPORT_SIZE) / VIEW_HEIGHT_M
	var feet_px: float = float(VIEWPORT_SIZE) * 0.5 + CAMERA_TARGET_M * pixels_per_m
	_sprite.offset = Vector2(-float(VIEWPORT_SIZE) * 0.5, -feet_px)
	var screen_scale: float = SCREEN_HEIGHT_PX / (MODEL_HEIGHT_M * pixels_per_m)
	_sprite.scale = Vector2(screen_scale, screen_scale)
	add_child(_sprite)


## Matériau noir uni, sans lumière : une silhouette pure, comme Vector.
func _apply_ink(node: Node) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = ink
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material


func _on_state_changed(from: PlayerState.State, to: PlayerState.State) -> void:
	_intro_done = not INTROS.has(to)
	# Hissage : de la suspension, le corps repart vers le haut par-dessus le rebord.
	if from == PlayerState.State.LEDGE_HANG and to == PlayerState.State.JUMP:
		_mantle_left = MANTLE_TIME
	elif to != PlayerState.State.JUMP:
		_mantle_left = 0.0


func _play(clip: StringName, blend: float = BLEND_TIME) -> void:
	if _player == null or not _player.has_animation(clip):
		return
	_player.play(clip, blend, CLIP_SPEED.get(clip, 1.0))
	_current = clip


func _clip_for(state: PlayerState.State) -> StringName:
	if _mantle_left > 0.0:
		return &"parkour/ClimbUp"
	if not _intro_done and INTROS.has(state):
		var intro: StringName = INTROS[state]
		if _current != intro or _player.is_playing():
			return intro
		_intro_done = true
	return CLIPS.get(state, &"parkour/NinjaJump_Idle")


func _process(delta: float) -> void:
	if _body == null or _player == null:
		return
	_state = _body.current_state()
	_mantle_left = maxf(0.0, _mantle_left - delta)
	var clip: StringName = _clip_for(_state)
	if clip != _current:
		_play(clip)
	# Les cycles de course suivent la vitesse réelle.
	var speed: float = absf(_body.velocity.x)
	match clip:
		&"Jog_Fwd":
			var climbing: bool = _state == PlayerState.State.WALL_CLIMB
			_player.speed_scale = 1.3 if climbing else clampf(speed / JOG_REFERENCE_SPEED, 0.6, 1.6)
		&"Sprint":
			_player.speed_scale = clampf(maxf(speed, absf(_body.velocity.y)) / SPRINT_REFERENCE_SPEED, 0.7, 1.5)
		_:
			_player.speed_scale = 1.0
	_player.advance(delta)
	_apply_arm_gestures(delta)
	_update_orientation(delta)


func _update_orientation(delta: float) -> void:
	if figure_library != null and _body.figure != Figure.Kind.NONE:
		var animation: FigureAnimation = figure_library.get_animation(Figure.name_of(_body.figure))
		if animation != null:
			_rotation = float(animation.sample(_body.figure_progress()).get(&"rotation", 0.0))
	else:
		_rotation = lerp_angle(_rotation, 0.0, minf(1.0, delta * 12.0))
	# Profil : le mannequin regarde +x (yaw +90°) ou -x (yaw -90°), demi-tour lissé.
	_yaw = lerp_angle(_yaw, PI * 0.5 * float(_body.facing), minf(1.0, delta * 14.0))
	_pivot.rotation = Vector3.ZERO
	_pivot.rotate_z(-_rotation * float(_body.facing))
	_pivot.rotate_object_local(Vector3.UP, _yaw)


# --- Gestes de bras (escalade, suspension) --------------------------------------------

## Pose les bras par-dessus l'animation. Repère du squelette : +Y en haut, +Z devant
## (vers le mur pendant l'escalade).
func _apply_arm_gestures(delta: float) -> void:
	var climbing: bool = _state == PlayerState.State.WALL_CLIMB
	var hanging: bool = _state == PlayerState.State.LEDGE_HANG
	_arm_weight = move_toward(_arm_weight, 1.0 if climbing or hanging else 0.0, delta * 8.0)
	if _arm_weight <= 0.001 or _skeleton == null:
		return
	_climb_phase = fmod(_climb_phase + delta * CLIMB_ARM_HZ, 1.0)
	for side: String in ["L", "R"]:
		# Escalade : un bras tendu vers une prise haute pendant que l'autre tire
		# (coude plié, main à hauteur d'épaule) ; alternance à chaque demi-cycle.
		var reach: float = 1.0
		if climbing:
			var offset: float = 0.0 if side == "L" else 0.5
			reach = 0.5 + 0.5 * sin(TAU * (_climb_phase + offset))
		var upper_dir: Vector3 = Vector3(0.0, 1.0, 0.28).lerp(Vector3(0.0, -0.1, 1.0), 1.0 - reach)
		var fore_dir: Vector3 = Vector3(0.0, 1.0, 0.12).lerp(Vector3(0.0, 1.0, 0.45), 1.0 - reach)
		_aim_bone("DEF-upper_arm." + side, upper_dir.normalized(), _arm_weight)
		_aim_bone("DEF-forearm." + side, fore_dir.normalized(), _arm_weight)


## Tourne un os pour que sa direction (+Y local) pointe vers `direction` (repère du
## squelette), avec un poids de mélange.
func _aim_bone(bone_name: String, direction: Vector3, weight: float) -> void:
	var bone: int = _skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var parent: int = _skeleton.get_bone_parent(bone)
	var global_pose: Transform3D = _skeleton.get_bone_global_pose(bone)
	var current: Vector3 = global_pose.basis.y.normalized()
	var target: Vector3 = current.slerp(direction, weight).normalized()
	if current.is_equal_approx(target):
		return
	var turn: Quaternion = Quaternion(current, target)
	var new_basis: Basis = Basis(turn) * global_pose.basis
	var parent_basis: Basis = _skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	_skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * new_basis).get_rotation_quaternion())
