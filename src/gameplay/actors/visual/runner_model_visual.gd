class_name RunnerModelVisual
extends Node2D
## Silhouette 3D : un mannequin humain animé par capture de mouvement (Quaternius,
## CC0), rendu en noir uni dans un SubViewport par une caméra orthographique de
## profil, puis affiché comme un sprite 2D.
##
## Comme RunnerVisual, ce nœud lit l'état du RunnerBody et ne le modifie jamais.
## Les animations se fondent les unes dans les autres au changement d'état ; la
## course suit la vitesse réelle ; les saltos tournent le mannequin autour des
## hanches avec la rotation des FigureAnimation.
## Repère : pieds en (0, 0), avant vers +x.

const MODEL_SCENE: String = "res://assets/characters/quaternius/mannequin_anims.glb"
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
const BLEND_TIME: float = 0.18
## Vitesse (px/s) à laquelle les cycles de course sont joués à vitesse normale.
const JOG_REFERENCE_SPEED: float = 300.0
const SPRINT_REFERENCE_SPEED: float = 470.0

## État → animation. Un état absent prend la pose aérienne (voir _clip_for).
const CLIPS: Dictionary[PlayerState.State, StringName] = {
	PlayerState.State.IDLE: &"Idle",
	PlayerState.State.RUN: &"Jog_Fwd",
	PlayerState.State.SPRINT: &"Sprint",
	PlayerState.State.FALL: &"Jump",
	PlayerState.State.LANDING: &"Jump_Land",
	PlayerState.State.ROLL: &"Roll",
	PlayerState.State.SLIDE: &"Crouch_Fwd",
	PlayerState.State.VAULT: &"Jump",
	PlayerState.State.WALL_RUN: &"Sprint",
	PlayerState.State.WALL_CLIMB: &"Crouch_Fwd",
	PlayerState.State.LEDGE_HANG: &"Jump",
	PlayerState.State.HIT: &"Hit_Chest",
	PlayerState.State.DEATH: &"Death01",
}

## Vitesse de lecture des clips trop lents pour la physique du jeu (appel en
## 1,3 s dans le clip, contre ~0,4 s de montée réelle).
const CLIP_SPEED: Dictionary[StringName, float] = {
	&"Jump_Start": 2.6,
	&"Jump_Land": 2.0,
	&"Roll": 1.7,
}

@export var figure_library: FigureLibrary
@export var ink: Color = Color(0.04, 0.04, 0.05)

var _body: RunnerBody
var _viewport: SubViewport
var _pivot: Node3D
var _model: Node3D
var _player: AnimationPlayer
var _sprite: Sprite2D
var _current: StringName = &""
var _rotation: float = 0.0
## Orientation lissée (rad autour de Y) pour un demi-tour sans saut d'image.
var _yaw: float = PI * 0.5


func _ready() -> void:
	_body = get_parent() as RunnerBody
	_build_viewport()
	if _body != null:
		_body.jump_started.connect(func(_kind: StringName) -> void: _play(&"Jump_Start", 0.08))


## Animation en cours (lecture seule, pour les tests).
func current_clip() -> StringName:
	return _current


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
	# Les boucles (« _Loop ») sont reconnues à l'import, qui retire ce suffixe.
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer

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


func _play(clip: StringName, blend: float = BLEND_TIME) -> void:
	if _player == null or not _player.has_animation(clip):
		return
	_player.play(clip, blend, CLIP_SPEED.get(clip, 1.0))
	_current = clip


func _clip_for(state: PlayerState.State) -> StringName:
	if state == PlayerState.State.JUMP or state == PlayerState.State.DOUBLE_JUMP:
		# Impulsion jouée jusqu'au bout, puis pose aérienne.
		if _current == &"Jump_Start" and _player.is_playing():
			return &"Jump_Start"
		return &"Jump"
	return CLIPS.get(state, &"Jump")


func _process(delta: float) -> void:
	if _body == null or _player == null:
		return
	var state: PlayerState.State = _body.current_state()
	var clip: StringName = _clip_for(state)
	if clip != _current:
		_play(clip)
	# Les cycles de course suivent la vitesse réelle (pas de pieds qui glissent).
	var speed: float = absf(_body.velocity.x)
	match clip:
		&"Jog_Fwd":
			_player.speed_scale = clampf(speed / JOG_REFERENCE_SPEED, 0.6, 1.6)
		&"Sprint":
			_player.speed_scale = clampf(speed / SPRINT_REFERENCE_SPEED, 0.7, 1.5)
		_:
			_player.speed_scale = 1.0

	# Saltos et vrilles : rotation des FigureAnimation autour des hanches.
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
