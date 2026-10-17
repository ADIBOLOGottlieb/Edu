class_name RunnerVisual
extends Node2D
## Silhouette humaine dessinée par code : sweat à capuche ample, pantalon cargo,
## baskets, mains (proportions dans un SilhouetteStyle).
##
## Gestuelle : la pose suit l'état du RunnerBody (clips d'un AnimationSet) et ses
## figures (images clés d'une FigureLibrary, synchronisées via figure_progress()),
## lissée par des ressorts amortis. La course et le sprint utilisent un vrai cycle
## de foulée humain par images clés (appui, amorti, poussée, suspension, ramené),
## bras opposés aux jambes, coudes fléchis et léger rebond du corps.
##
## PROVISOIRE (docs/PLACEHOLDER_ASSETS.md) : dessin vectoriel par code, en attendant
## des sprites dessinés. Le visuel lit l'état, il ne le modifie jamais.
## Repère : pieds en (0, 0), avant vers +x ; le sens est donné par scale.x = facing.

## Ressort des poses : raideur et amortissement (légèrement sous-critique : souple).
const SPRING_STIFFNESS: float = 320.0
const SPRING_DAMPING: float = 32.0
## Cycle de foulée d'une jambe (appui à 0) : angle de cuisse et flexion du genou (degrés).
const GAIT_THIGH: Array[float] = [28.0, 12.0, -6.0, -24.0, -34.0, -8.0, 30.0, 42.0]
const GAIT_KNEE: Array[float] = [12.0, 34.0, 24.0, 22.0, 72.0, 108.0, 78.0, 30.0]
const LIMB_SIDES: int = 7
## Couche de mouvement (agilité) : impulsions données aux ressorts au saut et à
## l'atterrissage, pose aérienne selon la vitesse verticale, inclinaison selon
## la vitesse et l'accélération, tête stabilisée (regard vers l'avant).
## Impact (px/s) pour lequel l'amorti d'atterrissage est complet.
const LANDING_FULL_IMPACT: float = 900.0
## Part de l'inclinaison du buste que la tête compense.
const HEAD_STABILIZE: float = 0.45

@export var animation_set: AnimationSet
@export var figure_library: FigureLibrary
@export var style: SilhouetteStyle

var _body: RunnerBody
var _phase: float = 0.0
var _pose: Dictionary[StringName, float] = {}
var _velocity: Dictionary[StringName, float] = {}
## Poids du cycle de course (0 = poses de clip, 1 = cycle complet), lissé.
var _gait_weight: float = 0.0
var _figure_active: bool = false
var _spin_scale: float = 1.0
var _pivot: Vector2 = Vector2.ZERO
## Accélération horizontale lissée (px/s²), pour pencher en accélérant et freinant.
var _accel_x: float = 0.0
var _last_velocity_x: float = 0.0


func _ready() -> void:
	_body = get_parent() as RunnerBody
	if style == null:
		style = SilhouetteStyle.new()
	for field: StringName in FigureAnimation.FIELDS:
		_pose[field] = 0.0
		_velocity[field] = 0.0
	if _body != null:
		_body.jump_started.connect(_on_jump_started)
		_body.landed.connect(_on_landed)


## Impulsion d'appel : bras lancés vers le haut, jambes qui se tendent, buste qui
## se redresse (le ressort revient seul : détente puis relâchement).
func _on_jump_started(kind: StringName) -> void:
	var power: float = 0.7 if kind == &"double" else 1.0
	_kick(&"arm_base", 30.0 * power)
	_kick(&"crouch", -6.0 * power)
	_kick(&"knee_bend", -8.0 * power)
	_kick(&"lean", -1.5 * power)


## Amorti de réception proportionnel à l'impact : genoux qui plient, bassin qui
## descend, buste vers l'avant, bras devant pour l'équilibre.
func _on_landed(impact_speed: float) -> void:
	var k: float = clampf(impact_speed / LANDING_FULL_IMPACT, 0.15, 1.0)
	_kick(&"crouch", 20.0 * k)
	_kick(&"knee_bend", 24.0 * k)
	_kick(&"lean", 8.0 * k)
	_kick(&"arm_base", 14.0 * k)


func _kick(field: StringName, speed: float) -> void:
	if _velocity.has(field):
		_velocity[field] += speed


## Pose actuelle (lecture seule, pour les tests et le débogage).
func pose_value(field: StringName) -> float:
	return _pose.get(field, 0.0)


func _process(delta: float) -> void:
	if _body == null or animation_set == null:
		return
	delta = minf(delta, 1.0 / 20.0)
	var target: Dictionary[StringName, float] = _figure_target()
	var figure_now: bool = not target.is_empty()
	if _figure_active and not figure_now:
		# Fin de figure : rotation ramenée dans [-π, π] pour revenir à la verticale
		# par le plus court chemin (pas de salto à l'envers à l'atterrissage).
		_pose[&"rotation"] = wrapf(_pose[&"rotation"], -PI, PI)
		_pose[&"spin"] = wrapf(_pose[&"spin"], -PI, PI)
	_figure_active = figure_now

	var cycle_hz: float = 0.0
	var gait_target: float = 0.0
	if not figure_now:
		var clip: AnimClip = animation_set.clip_for(_body.current_state_name())
		if clip == null:
			return
		for field: StringName in FigureAnimation.FIELDS:
			target[field] = float(clip.get(field))
		cycle_hz = clip.cycle_hz
		var state: PlayerState.State = _body.current_state()
		if state == PlayerState.State.RUN or state == PlayerState.State.SPRINT:
			gait_target = 1.0
			var speed_ratio: float = absf(_body.velocity.x) / maxf(_body.tuning.run_speed, 1.0)
			cycle_hz *= clampf(speed_ratio, 0.35, 1.8)
		_add_motion_layer(target, state, delta)

	for field: StringName in target:
		if figure_now and (field == &"rotation" or field == &"spin"):
			_pose[field] = target[field]
			_velocity[field] = 0.0
			continue
		var stiffness: float = SPRING_STIFFNESS * (2.0 if figure_now else 1.0)
		var accel: float = (target[field] - _pose[field]) * stiffness - _velocity[field] * SPRING_DAMPING
		_velocity[field] += accel * delta
		_pose[field] += _velocity[field] * delta
	_gait_weight = move_toward(_gait_weight, gait_target, delta * 6.0)
	_phase = fmod(_phase + cycle_hz * delta, 1.0)

	var spin_cos: float = cos(_pose[&"spin"])
	_spin_scale = (1.0 if spin_cos >= 0.0 else -1.0) * maxf(absf(spin_cos), 0.2)
	scale.x = float(_body.facing)
	queue_redraw()


## Ajoute à la pose de clip ce qui dépend du mouvement réel du corps.
func _add_motion_layer(
		target: Dictionary[StringName, float], state: PlayerState.State, delta: float
) -> void:
	var v: Vector2 = _body.velocity
	var raw_accel: float = (v.x - _last_velocity_x) / maxf(delta, 0.001)
	_accel_x = lerpf(_accel_x, raw_accel, minf(1.0, delta * 8.0))
	_last_velocity_x = v.x
	var facing: float = float(_body.facing)
	var tuning: MoveTuning = _body.tuning
	match state:
		PlayerState.State.RUN, PlayerState.State.SPRINT:
			# Plus on va vite, plus on se penche ; on se penche aussi en accélérant
			# et on se redresse (voire en arrière) en freinant.
			var speed_ratio: float = absf(v.x) / maxf(tuning.sprint_speed, 1.0)
			target[&"lean"] += 0.1 * speed_ratio + clampf(_accel_x * facing / 6000.0, -0.25, 0.2)
		PlayerState.State.JUMP, PlayerState.State.DOUBLE_JUMP, PlayerState.State.FALL:
			# Montée : genoux groupés ; descente rapide : jambes tendues vers le sol,
			# bras écartés pour l'équilibre.
			var rise: float = clampf(-v.y / maxf(tuning.jump_velocity, 1.0), 0.0, 1.0)
			var drop: float = clampf(v.y / maxf(tuning.max_fall_speed * 0.6, 1.0), 0.0, 1.0)
			target[&"knee_bend"] += 0.35 * rise - 0.15 * drop
			target[&"leg_base"] += 0.25 * rise + 0.15 * drop
			target[&"arm_spread"] += 0.55 * drop + 0.2 * rise
			target[&"arm_base"] += 0.1 * drop
			target[&"lean"] += 0.08 * rise - 0.06 * drop


## Pose cible de la figure en cours, ou vide s'il n'y en a pas (ou pas d'animation).
func _figure_target() -> Dictionary[StringName, float]:
	if figure_library == null or _body.figure == Figure.Kind.NONE:
		return {}
	var animation: FigureAnimation = figure_library.get_animation(Figure.name_of(_body.figure))
	if animation == null:
		return {}
	return animation.sample(_body.figure_progress())


# --- Cycle de course -------------------------------------------------------------------

## Interpolation de Catmull-Rom cyclique dans une table de 8 images clés.
static func _cyclic(table: Array[float], u: float) -> float:
	var count: int = table.size()
	var x: float = fposmod(u, 1.0) * float(count)
	var i: int = int(x)
	var t: float = x - float(i)
	var p0: float = table[(i - 1 + count) % count]
	var p1: float = table[i % count]
	var p2: float = table[(i + 1) % count]
	var p3: float = table[(i + 2) % count]
	return 0.5 * (
		2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t
	)


## Angles d'une jambe (cuisse, flexion du genou) et du bras opposé (épaule, coude).
## side = 0 pour le côté avant, 1 pour le côté arrière (décalé d'un demi-cycle).
func _limb_angles(side: int) -> Dictionary[StringName, float]:
	var sign: float = 1.0 if side == 0 else -1.0
	var wave: float = sin(TAU * _phase + (0.0 if side == 0 else PI))
	# Hors course (escalade, course murale) : balancement simple des jambes et des bras.
	var leg_swing: float = wave * _pose[&"stride"]
	var pose_thigh: float = _pose[&"leg_base"] + sign * _pose[&"leg_split"] + leg_swing
	var pose_knee: float = _pose[&"knee_bend"] * 1.4 + maxf(0.0, -leg_swing) * 0.9
	var pose_arm: float = _pose[&"arm_base"] + sign * _pose[&"arm_spread"] - wave * _pose[&"arm_swing"]
	# Coudes toujours un peu fléchis (bras humains, jamais raides) ; plus en balançant ou accroupi.
	var pose_elbow: float = 0.5 + 0.4 * absf(_pose[&"arm_swing"]) + 0.4 * _pose[&"crouch"]

	var u: float = _phase + (0.0 if side == 0 else 0.5)
	var amplitude: float = _pose[&"stride"]
	var gait_thigh: float = _pose[&"leg_base"] + deg_to_rad(_cyclic(GAIT_THIGH, u)) * amplitude
	var gait_knee: float = deg_to_rad(_cyclic(GAIT_KNEE, u)) * (0.55 + 0.45 * amplitude)
	# Bras opposé : avance quand la jambe du même côté recule ; coude fléchi ~90°.
	var gait_arm: float = _pose[&"arm_base"] - deg_to_rad(_cyclic(GAIT_THIGH, u)) * 0.9 * amplitude
	var gait_elbow: float = 1.35 + 0.35 * sin(TAU * u)

	var w: float = _gait_weight
	return {
		&"thigh": lerpf(pose_thigh, gait_thigh, w),
		&"knee": lerpf(pose_knee, gait_knee, w),
		&"arm": lerpf(pose_arm, gait_arm, w),
		&"elbow": lerpf(pose_elbow, gait_elbow, w),
	}


# --- Dessin ----------------------------------------------------------------------------

func _draw() -> void:
	var s: SilhouetteStyle = style
	_pivot = Vector2(0.0, -s.hip_height())
	# Rebond : le bassin monte en suspension, descend à l'amorti (deux fois par cycle).
	var bob: float = -cos(TAU * 2.0 * _phase) * 1.6 * _pose[&"stride"] * _gait_weight
	var hip: Vector2 = Vector2(0.0, -s.hip_height() * (1.0 - _pose[&"crouch"] * 0.55) + bob)
	var lean: float = _pose[&"lean"] + sin(TAU * 2.0 * _phase) * 0.03 * _gait_weight
	var up: Vector2 = Vector2.UP.rotated(lean)
	## Perpendiculaire au buste, vers l'avant du personnage.
	var front: Vector2 = Vector2(-up.y, up.x)
	var shoulder: Vector2 = hip + up * s.torso

	var back_side: Dictionary[StringName, float] = _limb_angles(1)
	var front_side: Dictionary[StringName, float] = _limb_angles(0)
	_draw_leg(hip - front * 1.0, back_side, s.back_ink)
	_draw_arm(shoulder - front * 1.5, back_side, s.back_ink)
	_draw_torso(hip, shoulder, up, front)
	# Tête stabilisée : elle compense une partie de l'inclinaison du buste (hors figures).
	var head_lean: float = lean * (1.0 if _figure_active else 1.0 - HEAD_STABILIZE)
	var head_up: Vector2 = Vector2.UP.rotated(head_lean)
	_draw_head(shoulder, head_up, Vector2(-head_up.y, head_up.x))
	_draw_leg(hip + front * 1.0, front_side, s.ink)
	_draw_arm(shoulder + front * 1.0, front_side, s.ink)


## Buste : contour courbe continu (ourlet ample, taille, poitrine, épaules tombantes, cou).
func _draw_torso(hip: Vector2, shoulder: Vector2, up: Vector2, front: Vector2) -> void:
	var s: SilhouetteStyle = style
	var hem: Vector2 = hip - up * 4.0
	var waist: Vector2 = hip + up * (s.torso * 0.3)
	var chest: Vector2 = hip + up * (s.torso * 0.72)
	var neck_base: Vector2 = shoulder + up * 2.0
	var control: PackedVector2Array = PackedVector2Array([
		hem - front * s.hem_half_width,
		waist - front * s.waist_half_width,
		chest - front * s.chest_half_width,
		shoulder - front * s.shoulder_half_width,
		neck_base - front * s.neck_radius,
		neck_base + front * s.neck_radius,
		shoulder + front * (s.shoulder_half_width - 0.5),
		chest + front * s.chest_half_width,
		waist + front * (s.waist_half_width + s.belly_bulge),
		hem + front * (s.hem_half_width + 0.5),
	])
	_fill(_smooth_closed(control, 4), s.ink)


## Tête ovale sur un cou fin, capuche qui l'enveloppe à l'arrière.
func _draw_head(shoulder: Vector2, up: Vector2, front: Vector2) -> void:
	var s: SilhouetteStyle = style
	var neck_top: Vector2 = shoulder + up * s.neck
	_capsule(shoulder, neck_top, s.neck_radius, s.neck_radius * 0.9, s.ink)
	var head: Vector2 = neck_top + up * (s.head_half_height - 0.5) + front * 0.8
	if s.hood:
		_ellipse(head - front * 1.4 + up * 0.6, s.head_radius + 1.5, s.head_half_height + 1.2, up, s.ink)
		_fill(PackedVector2Array([
			head - front * (s.head_radius + 1.2),
			shoulder - front * (s.shoulder_half_width - 1.5),
			shoulder + front * 1.0,
			neck_top - front * 1.0,
		]), s.ink)
	_ellipse(head + front * 0.6, s.head_radius, s.head_half_height, up, s.ink)
	if s.hair:
		# Cheveux courts en casque : volume arrondi un peu plus large en haut et à
		# l'arrière, frange qui descend sur le front.
		_ellipse(head - front * 0.6 + up * 1.2, s.head_radius + 1.1, s.head_half_height * 0.85, up, s.ink)
		_capsule(head + up * 2.5, head + front * (s.head_radius + 0.4) + up * 0.6, 1.8, 1.4, s.ink)
	# Col de sweat relevé.
	_capsule(shoulder - front * 1.5, shoulder + up * 2.5 + front * 0.5, s.collar_radius, s.collar_radius * 0.8, s.ink)


## Angle positif = membre vers l'avant.
func _limb_dir(angle: float) -> Vector2:
	return Vector2.DOWN.rotated(-angle)


## Jambe de pantalon cargo : cuisse ample, genou, mollet, cheville froncée, basket.
func _draw_leg(hip: Vector2, angles: Dictionary[StringName, float], color: Color) -> void:
	var s: SilhouetteStyle = style
	var thigh_dir: Vector2 = _limb_dir(angles[&"thigh"])
	var shin_dir: Vector2 = _limb_dir(angles[&"thigh"] - angles[&"knee"])
	var knee: Vector2 = hip + thigh_dir * s.thigh
	var calf: Vector2 = knee + shin_dir * (s.shin * 0.4)
	var ankle: Vector2 = knee + shin_dir * s.shin
	_capsule(hip, knee, s.thigh_radius, s.knee_radius, color)
	if s.cargo_pockets:
		var outer: Vector2 = Vector2(-thigh_dir.y, thigh_dir.x)
		_capsule(hip + thigh_dir * (s.thigh * 0.45), hip + thigh_dir * (s.thigh * 0.75), 2.2, 2.0, color, outer * 2.6)
	_capsule(knee, calf, s.knee_radius, s.calf_radius, color)
	_capsule(calf, ankle, s.calf_radius, s.ankle_radius, color)
	# Tissu froissé au genou (à l'avant) et resserré au-dessus de la chaussure.
	if s.knee_bunch > 0.0:
		var knee_front: Vector2 = Vector2(thigh_dir.y, -thigh_dir.x)
		_capsule(knee - thigh_dir * 2.0, knee + shin_dir * 2.0, s.knee_radius + s.knee_bunch, s.knee_radius, color, knee_front * 0.8)
		_capsule(ankle - shin_dir * 4.0, ankle - shin_dir * 1.0, s.ankle_radius + s.knee_bunch * 0.7, s.ankle_radius, color)
	_draw_shoe(ankle, shin_dir, color)


## Basket fine : talon court, semelle, bout arrondi vers l'avant.
func _draw_shoe(ankle: Vector2, shin_dir: Vector2, color: Color) -> void:
	var s: SilhouetteStyle = style
	var forward: Vector2 = Vector2(shin_dir.y, -shin_dir.x)
	var sole: Vector2 = shin_dir * s.shoe_height
	var outline: PackedVector2Array = PackedVector2Array([
		ankle - forward * s.heel_length - shin_dir * 1.5,
		ankle - forward * s.heel_length + sole,
		ankle + forward * s.shoe_length + sole,
		ankle + forward * (s.shoe_length + 0.5) + sole * 0.4,
		ankle + forward * (s.shoe_length * 0.5) - shin_dir * 0.6,
		ankle + forward * 1.5 - shin_dir * 2.0,
	])
	_fill(_smooth_closed(outline, 3), color)


## Manche ample jusqu'au poignet, main fine dans le prolongement de l'avant-bras.
func _draw_arm(shoulder: Vector2, angles: Dictionary[StringName, float], color: Color) -> void:
	var s: SilhouetteStyle = style
	var upper_dir: Vector2 = _limb_dir(angles[&"arm"])
	var fore_dir: Vector2 = _limb_dir(angles[&"arm"] + angles[&"elbow"])
	var elbow: Vector2 = shoulder + upper_dir * s.upper_arm
	var wrist: Vector2 = elbow + fore_dir * s.forearm
	_capsule(shoulder, elbow, s.sleeve_radius, s.elbow_radius, color)
	_capsule(elbow, wrist, s.elbow_radius, s.cuff_radius, color)
	if s.sleeve_puff > 0.0:
		# Manche bouffante : plis gonflés au milieu du bras et de l'avant-bras.
		var upper_out: Vector2 = Vector2(-upper_dir.y, upper_dir.x)
		var fore_out: Vector2 = Vector2(-fore_dir.y, fore_dir.x)
		_capsule(shoulder + upper_dir * (s.upper_arm * 0.35), shoulder + upper_dir * (s.upper_arm * 0.7), s.sleeve_radius + s.sleeve_puff * 0.6, s.sleeve_radius, color, upper_out * s.sleeve_puff)
		_capsule(elbow + fore_dir * (s.forearm * 0.3), elbow + fore_dir * (s.forearm * 0.7), s.elbow_radius + s.sleeve_puff * 0.5, s.cuff_radius, color, -fore_out * s.sleeve_puff)
	# Main ouverte : paume, puis doigts écartés en éventail.
	var palm: Vector2 = wrist + fore_dir * (s.hand_radius * 1.1)
	_capsule(wrist, palm, s.hand_radius * 0.9, s.hand_radius, color)
	for i: int in s.finger_count:
		var fan: float = (float(i) - float(s.finger_count - 1) * 0.5) * 0.35
		var finger_dir: Vector2 = fore_dir.rotated(fan)
		_capsule(palm, palm + finger_dir * s.finger_length, 0.9, 0.6, color)
	_capsule(wrist + fore_dir * 0.8, wrist + fore_dir.rotated(-1.0) * (s.finger_length * 0.75), 0.9, 0.7, color)


# --- Primitives (toutes passent par la rotation / vrille du corps) --------------------

## Applique la rotation et la vrille du corps entier autour des hanches.
func _tx(point: Vector2) -> Vector2:
	var local: Vector2 = (point - _pivot).rotated(_pose[&"rotation"])
	local.x *= _spin_scale
	return local + _pivot


func _fill(points: PackedVector2Array, color: Color) -> void:
	var transformed: PackedVector2Array = PackedVector2Array()
	transformed.resize(points.size())
	for i: int in points.size():
		transformed[i] = _tx(points[i])
	draw_colored_polygon(transformed, color)


## Courbe fermée de Catmull-Rom passant par les points de contrôle.
static func _smooth_closed(control: PackedVector2Array, steps: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var count: int = control.size()
	for i: int in count:
		var p0: Vector2 = control[(i - 1 + count) % count]
		var p1: Vector2 = control[i]
		var p2: Vector2 = control[(i + 1) % count]
		var p3: Vector2 = control[(i + 2) % count]
		for step: int in steps:
			var t: float = float(step) / float(steps)
			result.append(0.5 * (
				2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t
			))
	return result


## Ellipse alignée sur l'axe `up` (demi-largeur rx, demi-hauteur ry).
func _ellipse(center: Vector2, rx: float, ry: float, up: Vector2, color: Color) -> void:
	var side: Vector2 = Vector2(-up.y, up.x)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 14:
		var a: float = TAU * float(i) / 14.0
		points.append(center + side * cos(a) * rx + up * sin(a) * ry)
	_fill(points, color)


## Segment de membre effilé d'un seul tenant (bouts arrondis), décalable latéralement.
func _capsule(
	from: Vector2, to: Vector2, from_radius: float, to_radius: float, color: Color,
	offset: Vector2 = Vector2.ZERO
) -> void:
	from += offset
	to += offset
	var direction: Vector2 = to - from
	if direction.length_squared() < 0.0001:
		direction = Vector2.DOWN
	var axis: float = direction.angle()
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in LIMB_SIDES + 1:
		var a: float = axis - PI * 0.5 + PI * float(i) / float(LIMB_SIDES)
		points.append(to + Vector2.RIGHT.rotated(a) * to_radius)
	for i: int in LIMB_SIDES + 1:
		var a: float = axis + PI * 0.5 + PI * float(i) / float(LIMB_SIDES)
		points.append(from + Vector2.RIGHT.rotated(a) * from_radius)
	_fill(points, color)
