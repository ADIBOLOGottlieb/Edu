class_name RunnerVisual
extends Node2D
## Silhouette provisoire dessinée par code, pilotée par l'état du RunnerBody
## parent et par les clips d'un AnimationSet.
##
## PROVISOIRE (docs/PLACEHOLDER_ASSETS.md) : ce sont des formes simples, pas des
## animations dessinées. Le visuel lit l'état, il ne le modifie jamais.
##
## Repère : pieds en (0, 0), avant du personnage vers +x ; le sens est donné par
## scale.x = facing.

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

@export var animation_set: AnimationSet
## Vitesse à laquelle la pose rejoint le clip de l'état courant (par seconde).
@export var blend_speed: float = 18.0
@export var ink: Color = Color(0.04, 0.04, 0.05)
## Teinte des membres arrière, pour lire la profondeur dans une silhouette pleine.
@export var back_limb_ink: Color = Color(0.22, 0.22, 0.25)

var _body: RunnerBody
var _phase: float = 0.0
var _lean: float = 0.0
var _crouch: float = 0.0
var _leg_base: float = 0.0
var _arm_base: float = 0.0
var _stride: float = 0.0
var _arm_swing: float = 0.0
var _knee_bend: float = 0.15


func _ready() -> void:
	_body = get_parent() as RunnerBody


func _process(delta: float) -> void:
	if _body == null or animation_set == null:
		return
	var clip: AnimClip = animation_set.clip_for(_body.current_state_name())
	if clip == null:
		return

	var t: float = 1.0 - exp(-blend_speed * delta)
	_lean = lerpf(_lean, clip.lean, t)
	_crouch = lerpf(_crouch, clip.crouch, t)
	_leg_base = lerpf(_leg_base, clip.leg_base, t)
	_arm_base = lerpf(_arm_base, clip.arm_base, t)
	_stride = lerpf(_stride, clip.stride, t)
	_arm_swing = lerpf(_arm_swing, clip.arm_swing, t)
	_knee_bend = lerpf(_knee_bend, clip.knee_bend, t)

	var hz: float = clip.cycle_hz
	if clip.stride > 0.0 and _body.tuning != null:
		var speed_ratio: float = absf(_body.velocity.x) / maxf(_body.tuning.run_speed, 1.0)
		hz *= clampf(speed_ratio, 0.3, 2.0)
	_phase = fmod(_phase + TAU * hz * delta, TAU)

	scale.x = float(_body.facing)
	queue_redraw()


func _draw() -> void:
	var hip: Vector2 = Vector2(0.0, -(THIGH + SHIN) * (1.0 - _crouch * 0.55))
	var up: Vector2 = Vector2.UP.rotated(_lean)
	var shoulder: Vector2 = hip + up * TORSO
	var head: Vector2 = shoulder + up * NECK

	# Membres arrière d'abord, plus clairs, puis buste, puis membres avant.
	_draw_leg(hip, PI, back_limb_ink)
	_draw_arm(shoulder, 0.0, back_limb_ink)

	draw_line(hip, shoulder, ink, TORSO_WIDTH)
	draw_circle(hip, TORSO_WIDTH * 0.5, ink)
	draw_circle(shoulder, TORSO_WIDTH * 0.55, ink)
	draw_circle(head, HEAD_RADIUS, ink)

	_draw_leg(hip, 0.0, ink)
	_draw_arm(shoulder, PI, ink)


## Angle positif = membre vers l'avant.
func _limb_dir(angle: float) -> Vector2:
	return Vector2.DOWN.rotated(-angle)


func _draw_leg(hip: Vector2, phase_offset: float, color: Color) -> void:
	var swing: float = sin(_phase + phase_offset) * _stride
	var thigh_angle: float = _leg_base + swing
	# Le genou se plie davantage quand la jambe revient vers l'arrière.
	var bend: float = _knee_bend * 1.4 + maxf(0.0, -swing) * 0.9
	var knee: Vector2 = hip + _limb_dir(thigh_angle) * THIGH
	var foot: Vector2 = knee + _limb_dir(thigh_angle - bend) * SHIN
	draw_polyline(PackedVector2Array([hip, knee, foot]), color, LIMB_WIDTH, true)
	draw_circle(knee, LIMB_WIDTH * 0.5, color)
	draw_circle(foot, LIMB_WIDTH * 0.55, color)


func _draw_arm(shoulder: Vector2, phase_offset: float, color: Color) -> void:
	var angle: float = _arm_base + sin(_phase + phase_offset) * _arm_swing
	var elbow: Vector2 = shoulder + _limb_dir(angle) * UPPER_ARM
	var hand: Vector2 = elbow + _limb_dir(angle + 0.7) * FOREARM
	draw_polyline(PackedVector2Array([shoulder, elbow, hand]), color, LIMB_WIDTH * 0.85, true)
	draw_circle(elbow, LIMB_WIDTH * 0.42, color)
	draw_circle(hand, LIMB_WIDTH * 0.5, color)
