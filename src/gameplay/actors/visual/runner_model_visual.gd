class_name RunnerModelVisual
extends Node2D
## Silhouette 3D : un mannequin humain animé par capture de mouvement (Quaternius,
## CC0), rendu en noir uni dans un SubViewport par une caméra orthographique de
## profil, puis affiché comme un sprite 2D.
##
## Comme RunnerVisual, ce nœud lit l'état du RunnerBody et ne le modifie jamais.
## Animation par AnimationTree (machine à états, fondus enchaînés) :
## - « loco » : repos, footing et sprint mélangés et synchronisés selon la vitesse
##   au sol, cadence accélérée avec la vitesse réelle (11 m/s en sprint : sans cela
##   la course paraît au ralenti et les pieds glissent) ;
## - « air » : cinq poses capturées (appel, montée genou haut, sommet, descente,
##   préparation de la réception) mélangées selon la vitesse verticale réelle, donc
##   synchronisées avec la physique du saut ;
## - réception, roulade, glissade, hissage, escalade, suspension, chute ;
## - escalade et suspension : bras posés par-dessus l'animation ;
## - saltos et vrilles : rotation des FigureAnimation autour des hanches.
## Repère : pieds en (0, 0), avant vers +x.

const MODEL_SCENE: String = "res://assets/characters/quaternius/mannequin_anims.glb"
## Clips de parkour de la bibliothèque 2, reciblés (tools/build_parkour_anims.gd).
const PARKOUR_LIBRARY: String = "res://assets/characters/quaternius/parkour_anims.res"
## Résolution du rendu (carré) et étendue verticale vue par la caméra (m).
## Résolution du rendu 3D (carré) selon la qualité graphique : le sprite est réduit
## à l'écran, donc pas besoin d'anticrénelage ni de grande résolution sur mobile.
const VIEWPORT_SIZES: Dictionary[StringName, int] = {&"low": 160, &"medium": 208, &"high": 256}
const VIEW_HEIGHT_M: float = 3.2
## Hauteur du point visé par la caméra au-dessus des pieds (m).
const CAMERA_TARGET_M: float = 1.3
## Taille du mannequin à l'écran (px) : calée sur la capsule de collision.
const SCREEN_HEIGHT_PX: float = 74.0
const MODEL_HEIGHT_M: float = 1.8
const HIP_HEIGHT_M: float = 0.95
## Images par seconde des clips dérivés (poses, extraits accélérés).
const RESAMPLE_FPS: float = 30.0

## Locomotion : vitesse au sol (px/s) des points du mélange repos → footing → sprint.
const JOG_SPEED: float = 140.0
const SPRINT_SPEED: float = 300.0
## Au-delà de SPRINT_SPEED la cadence suit la vitesse, jusqu'à ce plafond
## (≈ 5 foulées/s, cadence d'un vrai sprint).
const MAX_CADENCE_SCALE: float = 1.65
## Vitesse verticale (px/s) qui correspond aux poses extrêmes du saut.
const AIR_SPEED_REF: float = 650.0
const AIR_RESPONSE: float = 16.0
## Cadence des bras pendant l'escalade (cycles par seconde).
const CLIMB_ARM_HZ: float = 1.6
## Hissage après une suspension : durée pendant laquelle on joue « vault ».
const MANTLE_TIME: float = 0.45

## État du corps → état de l'animation.
const STATES: Dictionary[PlayerState.State, StringName] = {
	PlayerState.State.IDLE: &"loco",
	PlayerState.State.RUN: &"loco",
	PlayerState.State.SPRINT: &"loco",
	PlayerState.State.WALL_RUN: &"loco",
	PlayerState.State.JUMP: &"air",
	PlayerState.State.DOUBLE_JUMP: &"air",
	PlayerState.State.FALL: &"air",
	PlayerState.State.LANDING: &"land",
	PlayerState.State.ROLL: &"roll",
	PlayerState.State.SLIDE: &"slide_start",
	PlayerState.State.VAULT: &"vault",
	PlayerState.State.WALL_CLIMB: &"climb",
	PlayerState.State.LEDGE_HANG: &"hang",
	PlayerState.State.HIT: &"hit",
	PlayerState.State.STAGGER: &"hit",
	PlayerState.State.DEATH: &"death",
}
## Fondu (s) pour entrer dans chaque état : court pour l'air et la réception (réactif).
const XFADE: Dictionary[StringName, float] = {
	&"air": 0.08,
	&"land": 0.05,
	&"loco": 0.16,
	&"slide_start": 0.08,
	&"roll": 0.06,
	&"vault": 0.08,
}

## Tenue de gardien (poursuivants) : casquette à visière, lampe torche et faisceau.
const CAP_RADIUS_M: float = 0.115
const CAP_HEIGHT_M: float = 0.07
const VISOR_SIZE_M: Vector3 = Vector3(0.2, 0.022, 0.13)
const BADGE_SIZE_M: Vector3 = Vector3(0.06, 0.04, 0.02)
const TORCH_SIZE_M: Vector3 = Vector3(0.05, 0.05, 0.2)
## Faisceau de la lampe (px) : longueur, demi-ouverture (rad), inclinaison vers le sol.
const BEAM_LENGTH: float = 130.0
const BEAM_HALF_ANGLE: float = 0.26
const BEAM_TILT: float = 0.32

@export var figure_library: FigureLibrary
@export var ink: Color = Color(0.04, 0.04, 0.05)
## Échelle du mannequin (x : carrure, y : taille, z : épaisseur vue de profil).
## Le joueur garde Vector3.ONE ; le gardien est plus élancé.
@export var body_scale: Vector3 = Vector3.ONE
## Tenue de gardien (casquette, lampe torche et faisceau chaud). Faux pour le joueur.
@export var guard_gear: bool = false
## Couleur chaude de la tenue (bandeau de casquette, lampe, faisceau).
@export var accent: Color = Color(1.0, 0.72, 0.30)

var _body: RunnerBody
var _viewport_px: int = 256
## Faux quand la silhouette est hors écran : ni rendu 3D ni animation (vigile au loin).
var _on_screen: bool = true
var _viewport: SubViewport
var _pivot: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _sprite: Sprite2D
var _current: StringName = &"loco"
var _state: PlayerState.State = PlayerState.State.IDLE
var _mantle_left: float = 0.0
var _air_u: float = 0.5
var _loco_blend: float = 0.0
var _rotation: float = 0.0
## Orientation lissée (rad autour de Y) pour un demi-tour sans saut d'image.
var _yaw: float = PI * 0.5
## Poids des gestes de bras posés par-dessus l'animation (0 = animation pure).
var _arm_weight: float = 0.0
var _climb_phase: float = 0.0
var _camera: Camera3D
## Tenue de gardien : os de la main qui tient la lampe, faisceau 2D.
var _torch_bone: int = -1
var _beam: Polygon2D


func _ready() -> void:
	_body = get_parent() as RunnerBody
	_build_viewport()
	_build_tree()
	if _body != null:
		_body.state_changed.connect(_on_state_changed)
		_body.jump_started.connect(func(_kind: StringName) -> void: _air_u = 0.0)


## État d'animation en cours (« loco », « air », « slide »…), pour les tests.
func current_clip() -> StringName:
	return _current


## Mélange de locomotion (0 = repos, 1 = sprint), pour les tests.
func loco_blend() -> float:
	return _loco_blend


## Position dans le mélange aérien (0 = appel, 0,5 = sommet, 1 = réception), pour les tests.
func air_blend() -> float:
	return _air_u


## Poids des gestes d'escalade sur les bras (lecture seule, pour les tests).
func arm_weight() -> float:
	return _arm_weight


## Faisceau de la lampe du gardien (null sans tenue de gardien), pour les tests.
func torch_beam() -> Polygon2D:
	return _beam


# --- Construction ---------------------------------------------------------------------

func _build_viewport() -> void:
	var settings_service: SettingsServiceNode = get_node_or_null(^"/root/SettingsService") as SettingsServiceNode
	if settings_service != null:
		_viewport_px = VIEWPORT_SIZES.get(settings_service.settings.quality, 256)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(_viewport_px, _viewport_px)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_HEIGHT_M
	camera.position = Vector3(0.0, CAMERA_TARGET_M, 10.0)
	camera.near = 0.1
	camera.far = 50.0
	_viewport.add_child(camera)
	_camera = camera

	# Pivot aux hanches : les saltos tournent autour du bassin.
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, HIP_HEIGHT_M, 0.0)
	_viewport.add_child(_pivot)
	_model = (load(MODEL_SCENE) as PackedScene).instantiate() as Node3D
	_model.position = Vector3(0.0, -HIP_HEIGHT_M, 0.0)
	_model.scale = body_scale
	_pivot.add_child(_model)
	_apply_ink(_model)
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if guard_gear and _skeleton != null:
		_add_guard_gear()
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_player.add_animation_library(&"parkour", load(PARKOUR_LIBRARY) as AnimationLibrary)

	_sprite = Sprite2D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.centered = false
	var pixels_per_m: float = float(_viewport_px) / VIEW_HEIGHT_M
	var feet_px: float = float(_viewport_px) * 0.5 + CAMERA_TARGET_M * pixels_per_m
	_sprite.offset = Vector2(-float(_viewport_px) * 0.5, -feet_px)
	var screen_scale: float = SCREEN_HEIGHT_PX / (MODEL_HEIGHT_M * pixels_per_m)
	_sprite.scale = Vector2(screen_scale, screen_scale)
	add_child(_sprite)
	# Hors écran : plus de rendu 3D ni d'animation (coût nul pour un vigile au loin).
	var notifier: VisibleOnScreenNotifier2D = VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-60.0, -SCREEN_HEIGHT_PX - 30.0, 120.0, SCREEN_HEIGHT_PX + 40.0)
	notifier.screen_entered.connect(_set_on_screen.bind(true))
	notifier.screen_exited.connect(_set_on_screen.bind(false))
	add_child(notifier)
	if guard_gear:
		_build_beam()


## Matériau noir uni, sans lumière : une silhouette pure, comme Vector.
func _apply_ink(node: Node) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = ink
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material


## Tenue de gardien : casquette (encre) à bandeau chaud et lampe torche dans la main,
## fixées aux os (BoneAttachment3D). Repère du squelette : +Y en haut, +Z devant.
func _add_guard_gear() -> void:
	var dark: StandardMaterial3D = _unshaded(ink)
	var warm: StandardMaterial3D = _unshaded(accent)
	var cap: CylinderMesh = CylinderMesh.new()
	cap.top_radius = CAP_RADIUS_M * 1.15
	cap.bottom_radius = CAP_RADIUS_M
	cap.height = CAP_HEIGHT_M
	var visor: BoxMesh = BoxMesh.new()
	visor.size = VISOR_SIZE_M
	var badge: BoxMesh = BoxMesh.new()
	badge.size = BADGE_SIZE_M
	var head: BoneAttachment3D = _attach(&"DEF-head")
	if head != null:
		_gear_piece(head, cap, dark, Vector3(0.0, 0.165, -0.01))
		_gear_piece(head, visor, dark, Vector3(0.0, 0.135, 0.12))
		_gear_piece(head, badge, warm, Vector3(0.0, 0.17, 0.12))
	var torch: BoxMesh = BoxMesh.new()
	torch.size = TORCH_SIZE_M
	var hand: BoneAttachment3D = _attach(&"DEF-hand.L")
	if hand != null:
		_gear_piece(hand, torch, warm, Vector3(0.0, -0.04, 0.06))
		_torch_bone = _skeleton.find_bone("DEF-hand.L")


static func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _attach(bone_name: StringName) -> BoneAttachment3D:
	if _skeleton.find_bone(bone_name) < 0:
		return null
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.bone_name = bone_name
	_skeleton.add_child(attachment)
	return attachment


## Pièce de tenue placée à `offset` (repère du squelette, m) de l'os, quelle que
## soit l'orientation de l'os au repos ; l'échelle du corps est compensée en
## épaisseur pour garder une casquette ronde.
func _gear_piece(attachment: BoneAttachment3D, mesh: Mesh, material: Material, offset: Vector3) -> void:
	var rest: Basis = _skeleton.get_bone_global_rest(_skeleton.find_bone(attachment.bone_name)).basis.orthonormalized()
	var piece: MeshInstance3D = MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.transform = Transform3D(rest.inverse(), rest.inverse() * offset)
	attachment.add_child(piece)


## Faisceau 2D : cône chaud, additif, qui s'efface vers le bout.
func _build_beam() -> void:
	_beam = Polygon2D.new()
	_beam.name = "TorchBeam"
	var tip: Vector2 = Vector2(BEAM_LENGTH, 0.0)
	_beam.polygon = PackedVector2Array([
		Vector2.ZERO, tip.rotated(-BEAM_HALF_ANGLE), tip, tip.rotated(BEAM_HALF_ANGLE),
	])
	var glow: Color = Color(accent, 0.34)
	var fade: Color = Color(accent, 0.0)
	_beam.vertex_colors = PackedColorArray([glow, fade, Color(accent, 0.05), fade])
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = additive
	add_child(_beam)


## Le faisceau part de la main projetée à l'écran et éclaire devant, vers le sol.
func _update_beam() -> void:
	if _beam == null:
		return
	var alive: bool = _state != PlayerState.State.DEATH
	_beam.visible = alive and _torch_bone >= 0
	if not _beam.visible:
		return
	var hand: Vector3 = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_torch_bone)).origin
	var pixel: Vector2 = _camera.unproject_position(hand)
	_beam.position = (pixel + _sprite.offset) * _sprite.scale
	var facing: float = float(_body.facing)
	_beam.scale = Vector2(facing, 1.0)
	_beam.rotation = BEAM_TILT * facing


## Clips dérivés (poses figées, extraits accélérés) dans la bibliothèque « gen ».
func _build_clips() -> void:
	var gen: AnimationLibrary = AnimationLibrary.new()
	var start: Animation = _player.get_animation(&"parkour/NinjaJump_Start")
	var fall: Animation = _player.get_animation(&"Jump_Start")
	var land: Animation = _player.get_animation(&"parkour/NinjaJump_Land")
	# Poses aériennes (fractions de clip choisies sur la planche des captures).
	gen.add_animation(&"air_push", resample(start, start.length * 1.0 / 9.0, -1.0))
	gen.add_animation(&"air_knee", resample(start, start.length * 2.0 / 9.0, -1.0))
	gen.add_animation(&"air_apex", resample(start, start.length * 4.0 / 9.0, -1.0))
	gen.add_animation(&"air_down", resample(fall, fall.length * 5.0 / 9.0, -1.0))
	gen.add_animation(&"air_reach", resample(fall, fall.length * 7.0 / 9.0, -1.0))
	# Réception : accroupissement profond puis relèvement, accéléré.
	gen.add_animation(&"land", resample(land, land.length * 1.0 / 9.0, land.length * 6.0 / 9.0, 2.4))
	gen.add_animation(&"slide_start", resample(_player.get_animation(&"parkour/Slide_Start"), 0.0, -2.0, 2.2))
	gen.add_animation(&"vault", resample(_player.get_animation(&"parkour/ClimbUp"), 0.0, -2.0, 1.6))
	gen.add_animation(&"roll", resample(_player.get_animation(&"Roll"), 0.0, -2.0, 1.7))
	_player.add_animation_library(&"gen", gen)


func _build_tree() -> void:
	_build_clips()
	var machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()

	var loco: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var loco_space: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	loco_space.sync = true
	loco_space.add_blend_point(_anim(&"Idle"), 0.0, -1, &"idle")
	loco_space.add_blend_point(_anim(&"Jog_Fwd"), JOG_SPEED / SPRINT_SPEED, -1, &"jog")
	loco_space.add_blend_point(_anim(&"Sprint"), 1.0, -1, &"sprint")
	loco.add_node(&"space", loco_space)
	loco.add_node(&"cadence", AnimationNodeTimeScale.new())
	loco.connect_node(&"cadence", 0, &"space")
	loco.connect_node(&"output", 0, &"cadence")
	machine.add_node(&"loco", loco)

	var air: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	var poses: Array[StringName] = [&"air_push", &"air_knee", &"air_apex", &"air_down", &"air_reach"]
	for i: int in poses.size():
		air.add_blend_point(_anim(StringName("gen/" + String(poses[i]))), float(i) / float(poses.size() - 1), -1, poses[i])
	machine.add_node(&"air", air)

	machine.add_node(&"land", _anim(&"gen/land"))
	machine.add_node(&"roll", _anim(&"gen/roll"))
	machine.add_node(&"slide_start", _anim(&"gen/slide_start"))
	machine.add_node(&"slide", _anim(&"parkour/Slide"))
	machine.add_node(&"vault", _anim(&"gen/vault"))
	machine.add_node(&"climb", _anim(&"Jog_Fwd"))
	machine.add_node(&"hang", _anim(&"Jump"))
	machine.add_node(&"hit", _anim(&"parkour/Hit_Knockback"))
	machine.add_node(&"death", _anim(&"Death01"))

	var names: Array[StringName] = [
		&"loco", &"air", &"land", &"roll", &"slide_start", &"slide", &"vault", &"climb", &"hang", &"hit", &"death",
	]
	for from: StringName in names:
		for to: StringName in names:
			if from != to:
				machine.add_transition(from, to, _transition(XFADE.get(to, 0.12)))
	# Entrée de glissade, puis boucle de glissade quand elle est finie.
	machine.remove_transition(&"slide_start", &"slide")
	var into_slide: AnimationNodeStateMachineTransition = _transition(0.1)
	into_slide.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	into_slide.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition(&"slide_start", &"slide", into_slide)
	var begin: AnimationNodeStateMachineTransition = _transition(0.0)
	begin.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition(&"Start", &"loco", begin)

	_tree = AnimationTree.new()
	_tree.tree_root = machine
	_model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	# Avancée manuelle : les gestes de bras sont posés juste après l'animation.
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.active = true
	_playback = _tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	_playback.start(&"loco")


static func _anim(clip: StringName) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = clip
	return node


static func _transition(xfade: float) -> AnimationNodeStateMachineTransition:
	var transition: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	transition.xfade_time = xfade
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	return transition


## Extrait de `source` entre t0 et t1 rejoué `speed` fois plus vite, rééchantillonné
## à RESAMPLE_FPS. t1 < 0 : jusqu'à la fin (-2) ou pose figée en t0 (-1).
static func resample(source: Animation, t0: float, t1: float, speed: float = 1.0) -> Animation:
	var end: float = t0 if t1 == -1.0 else (source.length if t1 < 0.0 else t1)
	var duration: float = maxf((end - t0) / speed, 1.0 / RESAMPLE_FPS)
	var steps: int = maxi(1, int(ceilf(duration * RESAMPLE_FPS)))
	var out: Animation = Animation.new()
	out.length = duration
	for track: int in source.get_track_count():
		var type: Animation.TrackType = source.track_get_type(track)
		if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_SCALE_3D:
			continue
		var copy: int = out.add_track(type)
		out.track_set_path(copy, source.track_get_path(track))
		for k: int in steps + 1:
			var u: float = float(k) / float(steps)
			var at: float = duration * u
			var from: float = lerpf(t0, end, u)
			match type:
				Animation.TYPE_POSITION_3D:
					out.position_track_insert_key(copy, at, source.position_track_interpolate(track, from))
				Animation.TYPE_ROTATION_3D:
					out.rotation_track_insert_key(copy, at, source.rotation_track_interpolate(track, from))
				Animation.TYPE_SCALE_3D:
					out.scale_track_insert_key(copy, at, source.scale_track_interpolate(track, from))
	return out


# --- Mise à jour ---------------------------------------------------------------------

func _on_state_changed(from: PlayerState.State, to: PlayerState.State) -> void:
	# Hissage : de la suspension, le corps repart vers le haut par-dessus le rebord.
	if from == PlayerState.State.LEDGE_HANG and to == PlayerState.State.JUMP:
		_mantle_left = MANTLE_TIME
	elif to != PlayerState.State.JUMP:
		_mantle_left = 0.0


func _target_state() -> StringName:
	if _mantle_left > 0.0:
		return &"vault"
	var target: StringName = STATES.get(_state, &"air")
	# La glissade continue dans sa boucle une fois l'entrée jouée.
	if target == &"slide_start" and _playback.get_current_node() == &"slide":
		return &"slide"
	return target


## Rendu et animation seulement à l'écran.
func _set_on_screen(on: bool) -> void:
	_on_screen = on
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	if _body == null or _tree == null:
		return
	if not _on_screen:
		return
	_state = _body.current_state()
	_mantle_left = maxf(0.0, _mantle_left - delta)
	var target: StringName = _target_state()
	if target != _current:
		_playback.travel(target)
		_current = target
	elif target == &"slide_start" and _playback.get_current_node() == &"slide":
		_current = &"slide"

	# Locomotion : mélange et cadence selon la vitesse au sol.
	var speed: float = absf(_body.velocity.x)
	if _state == PlayerState.State.WALL_RUN:
		speed = maxf(speed, absf(_body.velocity.y))
	_loco_blend = clampf(speed / SPRINT_SPEED, 0.0, 1.0)
	_tree.set(&"parameters/loco/space/blend_position", _loco_blend)
	_tree.set(&"parameters/loco/cadence/scale", clampf(speed / SPRINT_SPEED, 1.0, MAX_CADENCE_SCALE))

	# Air : pose selon la vitesse verticale (montée → sommet → descente).
	var air_target: float = 0.5 + 0.5 * clampf(_body.velocity.y / AIR_SPEED_REF, -1.0, 1.0)
	_air_u = move_toward(_air_u, air_target, delta * AIR_RESPONSE * maxf(0.2, absf(air_target - _air_u)))
	_tree.set(&"parameters/air/blend_position", _air_u)

	_tree.advance(delta)
	_apply_arm_gestures(delta)
	_update_orientation(delta)
	_update_beam()


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
