class_name RunnerVisual
extends Node2D
## Silhouette provisoire dessinée par code, pilotée par l'état du RunnerBody
## parent (clips d'un AnimationSet) et par ses figures de parkour (images clés
## d'une FigureLibrary, synchronisées sur la physique via figure_progress()).
##
## PROVISOIRE (docs/PLACEHOLDER_ASSETS.md) : ce sont des formes simples, pas des
## animations dessinées. Le visuel lit l'état, il ne le modifie jamais.
##
## Repère : pieds en (0, 0), avant du personnage vers +x ; le sens est donné par
## scale.x = facing. Les saltos font pivoter tout le corps autour des hanches.

const THIGH: float = 17.0
const SHIN: float = 17.0
const TORSO: float = 22.0
const NECK: float = 10.0
const HEAD_RADIUS: float = 9.0
const UPPER_ARM: float = 13.0
const FOREARM: float = 12.0
## Volumes larges (sweat, pantalon ample) : silhouette pleine, pas un bonhomme bâton.
const LIMB_WIDTH: float = 9.0
const TORSO_WIDTH: float = 19.0
## Centre de rotation des figures (hanches, corps debout).
const PIVOT: Vector2 = Vector2(0.0, -34.0)
## Vitesse à laquelle la pose rejoint une image clé de figure (quasi immédiat).
const FIGURE_BLEND: float = 40.0

@export var animation_set: AnimationSet
@export var figure_library: FigureLibrary
## Vitesse à laquelle la pose rejoint le clip de l'état courant (par seconde).
@export var blend_speed: float = 18.0
@export var ink: Color = Color(0.04, 0.04, 0.05)
## Teinte des membres arrière, pour lire la profondeur dans une silhouette pleine.
@export var back_limb_ink: Color = Color(0.22, 0.22, 0.25)

var _body: RunnerBody
var _phase: float = 0.0
var _pose: Dictionary[StringName, float] = {
	&"lean": 0.0, &"crouch": 0.0, &"leg_base": 0.0, &"arm_base": 0.0, &"stride": 0.0,
	&"arm_swing": 0.0, &"knee_bend": 0.15, &"rotation": 0.0, &"spin": 0.0,
}
var _figure_active: bool = false
var _spin_scale: float = 1.0


func _ready() -> void:
	_body = get_parent() as RunnerBody


## Pose actuelle (lecture seule, pour les tests et le débogage).
func pose_value(field: StringName) -> float:
	return _pose.get(field, 0.0)


func _process(delta: float) -> void:
	if _body == null or animation_set == null:
		return
	var target: Dictionary[StringName, float] = _figure_target()
	var figure_now: bool = not target.is_empty()
	if _figure_active and not figure_now:
		# Fin de figure : ramène la rotation dans [-π, π] pour revenir à la verticale
		# par le plus court chemin (pas de salto à l'envers à l'atterrissage).
		_pose[&"rotation"] = wrapf(_pose[&"rotation"], -PI, PI)
		_pose[&"spin"] = wrapf(_pose[&"spin"], -PI, PI)
	_figure_active = figure_now

	var cycle_hz: float = 0.0
	var stride_driven: bool = false
	if figure_now:
		var t: float = 1.0 - exp(-FIGURE_BLEND * delta)
		for field: StringName in target:
			if field == &"rotation" or field == &"spin":
				_pose[field] = target[field]
			else:
				_pose[field] = lerpf(_pose[field], target[field], t)
	else:
		var clip: AnimClip = animation_set.clip_for(_body.current_state_name())
		if clip == null:
			return
		var t: float = 1.0 - exp(-blend_speed * delta)
		for field: StringName in FigureAnimation.FIELDS:
			_pose[field] = lerpf(_pose[field], float(clip.get(field)), t)
		cycle_hz = clip.cycle_hz
		stride_driven = clip.stride > 0.0

	if stride_driven and _body.tuning != null:
		var speed_ratio: float = absf(_body.velocity.x) / maxf(_body.tuning.run_speed, 1.0)
		cycle_hz *= clampf(speed_ratio, 0.3, 2.0)
	_phase = fmod(_phase + TAU * cycle_hz * delta, TAU)

	var spin_cos: float = cos(_pose[&"spin"])
	_spin_scale = (1.0 if spin_cos >= 0.0 else -1.0) * maxf(absf(spin_cos), 0.2)
	scale.x = float(_body.facing)
	queue_redraw()


## Pose cible de la figure en cours, ou vide s'il n'y en a pas (ou pas d'animation).
func _figure_target() -> Dictionary[StringName, float]:
	if figure_library == null or _body.figure == Figure.Kind.NONE:
		return {}
	var animation: FigureAnimation = figure_library.get_animation(Figure.name_of(_body.figure))
	if animation == null:
		return {}
	return animation.sample(_body.figure_progress())


## Applique la rotation et la vrille du corps entier autour des hanches.
func _tx(point: Vector2) -> Vector2:
	var local: Vector2 = (point - PIVOT).rotated(_pose[&"rotation"])
	local.x *= _spin_scale
	return local + PIVOT


func _draw() -> void:
	var hip: Vector2 = Vector2(0.0, -(THIGH + SHIN) * (1.0 - _pose[&"crouch"] * 0.55))
	var up: Vector2 = Vector2.UP.rotated(_pose[&"lean"])
	var shoulder: Vector2 = hip + up * TORSO
	var head: Vector2 = shoulder + up * NECK

	# Membres arrière d'abord, plus clairs, puis buste, puis membres avant.
	_draw_leg(hip, PI, back_limb_ink)
	_draw_arm(shoulder, 0.0, back_limb_ink)

	draw_line(_tx(hip), _tx(shoulder), ink, TORSO_WIDTH)
	draw_circle(_tx(hip), TORSO_WIDTH * 0.5, ink)
	draw_circle(_tx(shoulder), TORSO_WIDTH * 0.55, ink)
	draw_circle(_tx(head), HEAD_RADIUS, ink)

	_draw_leg(hip, 0.0, ink)
	_draw_arm(shoulder, PI, ink)


## Angle positif = membre vers l'avant.
func _limb_dir(angle: float) -> Vector2:
	return Vector2.DOWN.rotated(-angle)


func _draw_leg(hip: Vector2, phase_offset: float, color: Color) -> void:
	var swing: float = sin(_phase + phase_offset) * _pose[&"stride"]
	var thigh_angle: float = _pose[&"leg_base"] + swing
	# Le genou se plie davantage quand la jambe revient vers l'arrière.
	var bend: float = _pose[&"knee_bend"] * 1.4 + maxf(0.0, -swing) * 0.9
	var knee: Vector2 = hip + _limb_dir(thigh_angle) * THIGH
	var foot: Vector2 = knee + _limb_dir(thigh_angle - bend) * SHIN
	draw_polyline(PackedVector2Array([_tx(hip), _tx(knee), _tx(foot)]), color, LIMB_WIDTH, true)
	draw_circle(_tx(knee), LIMB_WIDTH * 0.5, color)
	draw_circle(_tx(foot), LIMB_WIDTH * 0.55, color)


func _draw_arm(shoulder: Vector2, phase_offset: float, color: Color) -> void:
	var angle: float = _pose[&"arm_base"] + sin(_phase + phase_offset) * _pose[&"arm_swing"]
	var elbow: Vector2 = shoulder + _limb_dir(angle) * UPPER_ARM
	var hand: Vector2 = elbow + _limb_dir(angle + 0.7) * FOREARM
	draw_polyline(PackedVector2Array([_tx(shoulder), _tx(elbow), _tx(hand)]), color, LIMB_WIDTH * 0.85, true)
	draw_circle(_tx(elbow), LIMB_WIDTH * 0.42, color)
	draw_circle(_tx(hand), LIMB_WIDTH * 0.5, color)
