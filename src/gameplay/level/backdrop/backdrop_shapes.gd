class_name BackdropShapes
extends RefCounted
## Formes de silhouette réutilisables par les plans de décor : immeubles,
## palmiers, citernes, antennes, paraboles, toits de tôle, poteaux électriques…
## Chaque fonction renvoie des polygones simples (sans auto-intersection) en
## coordonnées locales du plan : y = 0 au sol du plan, y négatif vers le haut.
## Les variantes sont déterministes (entier « variant », pas d'aléa global).

## Profondeur sous le sol jusqu'où descendent les bâtiments : pas de vide quand
## la caméra monte ou descend.
const DEPTH: float = 2600.0


static func rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	])


static func circle(center: Vector2, radius: float, segments: int = 14) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in segments:
		var a: float = TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


## Bâtiment posé au sol (x, largeur, hauteur) prolongé loin sous le sol.
static func building(x: float, width: float, height: float, ground: float = 0.0) -> PackedVector2Array:
	return rect(Rect2(x, ground - height, width, height + DEPTH))


## Bande épaisse le long d'une suite de points (tronc, bras de lampadaire).
static func ribbon(points: PackedVector2Array, half_widths: PackedFloat32Array) -> PackedVector2Array:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var n: int = points.size()
	for i: int in n:
		var a: Vector2 = points[maxi(i - 1, 0)]
		var b: Vector2 = points[mini(i + 1, n - 1)]
		var tangent: Vector2 = (b - a).normalized()
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		left.append(points[i] + normal * half_widths[i])
		right.append(points[i] - normal * half_widths[i])
	right.reverse()
	left.append_array(right)
	return left


## Cocotier : tronc courbe effilé, couronne de palmes retombantes, noix de coco.
## lean ∈ [-1, 1] : inclinaison du tronc (vers la mer, au vent).
static func palm(base: Vector2, height: float, lean: float, variant: int) -> Array[PackedVector2Array]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(variant)
	var out: Array[PackedVector2Array] = []
	var top: Vector2 = base + Vector2(lean * height * 0.32, -height)
	var ctrl: Vector2 = base + Vector2(-lean * height * 0.04, -height * 0.55)
	var trunk: PackedVector2Array = PackedVector2Array()
	var widths: PackedFloat32Array = PackedFloat32Array()
	var steps: int = 10
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		trunk.append(base.lerp(ctrl, t).lerp(ctrl.lerp(top, t), t))
		widths.append(lerpf(height * 0.032, height * 0.016, t))
	out.append(ribbon(trunk, widths))
	# Palmes en arceaux : surtout latérales et retombantes, plus courtes vers le haut.
	var angles: PackedFloat32Array = PackedFloat32Array([
		-0.96, -0.86, -0.75, -0.63, -0.5, -0.37, -0.25, -0.14, -0.04, 0.08, 0.92,
	])
	var length: float = height * 0.42
	for a: float in angles:
		var angle: float = (a + rng.randf_range(-0.03, 0.03)) * PI
		var frond_len: float = length * rng.randf_range(0.85, 1.08) * lerpf(0.55, 1.0, absf(cos(angle)))
		out.append(_frond(top, angle, frond_len, rng.randf_range(0.6, 0.95)))
	# Noix de coco sous la couronne.
	var r: float = height * 0.024
	out.append(circle(top + Vector2(-r * 0.9, r * 1.2), r, 8))
	out.append(circle(top + Vector2(r * 0.9, r * 1.3), r, 8))
	out.append(circle(top + Vector2(0.0, r * 2.2), r, 8))
	return out


## Une palme : nervure courbe qui retombe, folioles en dents de scie dessous.
static func _frond(origin: Vector2, angle: float, length: float, droop: float) -> PackedVector2Array:
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var steps: int = 12
	# Les palmes dressées retombent peu : la nervure ne se replie pas sur elle-même.
	var sag: float = droop * lerpf(0.3, 1.0, absf(dir.x))
	var side: float = 1.0 if dir.x >= 0.0 else -1.0
	var spine: PackedVector2Array = PackedVector2Array()
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		spine.append(origin + dir * length * t + Vector2(0.0, sag * length * t * t))
	var upper: PackedVector2Array = PackedVector2Array()
	var lower: PackedVector2Array = PackedVector2Array()
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		var a: Vector2 = spine[maxi(i - 1, 0)]
		var b: Vector2 = spine[mini(i + 1, steps)]
		var tangent: Vector2 = (b - a).normalized()
		var normal: Vector2 = Vector2(tangent.y, -tangent.x) * side
		var w: float = length * 0.085 * pow(sin(PI * clampf(t * 1.05, 0.0, 1.0)), 0.6)
		upper.append(spine[i] + normal * w * 0.35)
		# Folioles : bord inférieur dentelé (sans répéter la base ni la pointe).
		if i > 0 and i < steps:
			var jag: float = 1.0 if i % 2 == 0 else 0.45
			lower.append(spine[i] - normal * w * jag)
	lower.reverse()
	upper.append_array(lower)
	return upper


## Citerne d'eau en plastique (cylindre au couvercle bombé), sur pieds ou non.
static func water_tank(base: Vector2, width: float, on_stand: bool) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var y: float = base.y
	if on_stand:
		var stand_h: float = width * 0.7
		out.append(rect(Rect2(base.x - width * 0.45, y - stand_h, 2.0, stand_h)))
		out.append(rect(Rect2(base.x + width * 0.45 - 2.0, y - stand_h, 2.0, stand_h)))
		out.append(rect(Rect2(base.x - width * 0.55, y - stand_h - 2.0, width * 1.1, 2.5)))
		y -= stand_h + 2.0
	var h: float = width * 1.05
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(base.x - width * 0.5, y),
		Vector2(base.x + width * 0.5, y),
		Vector2(base.x + width * 0.5, y - h * 0.82),
	])
	for i: int in 7:
		var a: float = PI * float(i) / 6.0
		body.append(Vector2(base.x + cos(a) * width * 0.5, y - h * 0.82 - sin(a) * h * 0.18))
	body.append(Vector2(base.x - width * 0.5, y - h * 0.82))
	out.append(body)
	out.append(rect(Rect2(base.x - width * 0.12, y - h - 2.0, width * 0.24, 3.0)))
	return out


## Antenne râteau de télévision : mât et barres.
static func antenna(base: Vector2, height: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(rect(Rect2(base.x - 1.0, base.y - height, 2.0, height)))
	var bars: int = 3
	for i: int in bars:
		var w: float = height * (0.55 - 0.13 * float(i))
		out.append(rect(Rect2(base.x - w * 0.5, base.y - height + 2.0 + float(i) * height * 0.13, w, 1.6)))
	return out


## Parabole sur pied, tournée vers le ciel (facing = ±1).
static func dish(base: Vector2, radius: float, facing: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var stem_h: float = radius * 1.1
	out.append(rect(Rect2(base.x - 1.2, base.y - stem_h, 2.4, stem_h)))
	var center: Vector2 = base + Vector2(0.0, -stem_h - radius * 0.3)
	var tilt: float = -0.55 * facing
	var bowl: PackedVector2Array = PackedVector2Array()
	for i: int in 11:
		var a: float = PI * float(i) / 10.0
		var p: Vector2 = Vector2(cos(a) * radius, sin(a) * radius * 0.45)
		bowl.append(center + p.rotated(tilt))
	out.append(bowl)
	# Bras de la tête de réception.
	var arm_end: Vector2 = center + Vector2(0.0, -radius * 0.9).rotated(tilt)
	out.append(ribbon(PackedVector2Array([center, arm_end]), PackedFloat32Array([0.8, 0.8])))
	return out


## Toit de tôle à un pan avec débord (rive basse côté slope_side).
static func lean_to_roof(x: float, width: float, top: float, pitch: float, slope_side: float) -> Array[PackedVector2Array]:
	var overhang: float = minf(10.0, width * 0.12)
	var high_left: bool = slope_side > 0.0
	var y_left: float = top - (pitch if high_left else 0.0)
	var y_right: float = top - (0.0 if high_left else pitch)
	var slope: float = (y_right - y_left) / width
	var left_top: Vector2 = Vector2(x - overhang, y_left - slope * overhang - 1.5)
	var right_top: Vector2 = Vector2(x + width + overhang, y_right + slope * overhang - 1.5)
	var sheet: PackedVector2Array = PackedVector2Array([
		left_top, right_top, right_top + Vector2(0.0, 2.5), left_top + Vector2(0.0, 2.5),
	])
	var gable: PackedVector2Array = PackedVector2Array([
		Vector2(x, top + 0.5),
		Vector2(x + width, top + 0.5),
		Vector2(x + width, y_right),
	]) if not high_left else PackedVector2Array([
		Vector2(x, top + 0.5),
		Vector2(x + width, top + 0.5),
		Vector2(x, y_left),
	])
	var out: Array[PackedVector2Array] = [sheet, gable]
	return out


## Toit de tôle à deux pans, très plat, avec débords.
static func gable_roof(x: float, width: float, top: float, pitch: float) -> PackedVector2Array:
	var overhang: float = minf(8.0, width * 0.1)
	return PackedVector2Array([
		Vector2(x - overhang, top + 1.5),
		Vector2(x - overhang, top - 1.0),
		Vector2(x + width * 0.5, top - pitch - 2.0),
		Vector2(x + width + overhang, top - 1.0),
		Vector2(x + width + overhang, top + 1.5),
	])


## Minaret : fût, balcon, lanterne et dôme pointu.
static func minaret(base: Vector2, height: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var w: float = height * 0.09
	out.append(rect(Rect2(base.x - w * 0.5, base.y - height * 0.72, w, height * 0.72 + DEPTH)))
	out.append(rect(Rect2(base.x - w * 0.85, base.y - height * 0.74, w * 1.7, height * 0.03)))
	out.append(rect(Rect2(base.x - w * 0.36, base.y - height * 0.88, w * 0.72, height * 0.14)))
	var dome: PackedVector2Array = PackedVector2Array()
	for i: int in 9:
		var a: float = PI * float(i) / 8.0
		dome.append(base + Vector2(cos(a) * w * 0.45, -height * 0.88 - sin(a) * height * 0.05))
	dome.insert(5, base + Vector2(0.0, -height))
	out.append(dome)
	return out


## Clocher d'église : tour carrée, beffroi, flèche et croix.
static func church_tower(base: Vector2, height: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var w: float = height * 0.16
	out.append(rect(Rect2(base.x - w * 0.5, base.y - height * 0.62, w, height * 0.62 + DEPTH)))
	out.append(rect(Rect2(base.x - w * 0.4, base.y - height * 0.72, w * 0.8, height * 0.1)))
	out.append(PackedVector2Array([
		base + Vector2(-w * 0.45, -height * 0.72),
		base + Vector2(0.0, -height * 0.94),
		base + Vector2(w * 0.45, -height * 0.72),
	]))
	out.append(rect(Rect2(base.x - 0.8, base.y - height, 1.6, height * 0.08)))
	out.append(rect(Rect2(base.x - 3.0, base.y - height * 0.975, 6.0, 1.5)))
	return out


## Poteau électrique en bois : fût, traverse et isolateurs.
## Les points d'attache des câbles sont donnés par cable_anchors().
static func power_pole(base: Vector2, height: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(PackedVector2Array([
		base + Vector2(-2.6, 0.0),
		base + Vector2(-1.6, -height),
		base + Vector2(1.6, -height),
		base + Vector2(2.6, 0.0),
	]))
	var arm_y: float = base.y - height + 8.0
	out.append(rect(Rect2(base.x - height * 0.11, arm_y, height * 0.22, 3.0)))
	for k: float in [-0.09, 0.0, 0.09]:
		out.append(rect(Rect2(base.x + height * k - 1.2, arm_y - 4.0, 2.4, 4.0)))
	# Transformateur sur un poteau sur deux (fixé par la position).
	if int(absf(base.x)) % 2 == 0:
		out.append(rect(Rect2(base.x + 2.0, arm_y + 22.0, 9.0, 14.0)))
	return out


static func cable_anchors(base: Vector2, height: float) -> PackedVector2Array:
	var arm_y: float = base.y - height + 8.0 - 4.0
	return PackedVector2Array([
		Vector2(base.x - height * 0.09, arm_y),
		Vector2(base.x, arm_y),
		Vector2(base.x + height * 0.09, arm_y),
	])


## Câble qui pend entre deux points (chaînette approchée par une parabole).
static func sagging_cable(a: Vector2, b: Vector2, sag: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 10
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		pts.append(a.lerp(b, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t)))
	return pts


## Lampadaire à crosse (facing = ±1 : côté de la lampe).
static func lamp_post(base: Vector2, height: float, facing: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(PackedVector2Array([
		base + Vector2(-2.2, 0.0),
		base + Vector2(-1.3, -height),
		base + Vector2(1.3, -height),
		base + Vector2(2.2, 0.0),
	]))
	var arm: PackedVector2Array = PackedVector2Array()
	for i: int in 7:
		var a: float = PI * 0.5 * float(i) / 6.0
		arm.append(base + Vector2(facing * (1.0 - cos(a)) * height * 0.16, -height - sin(a) * height * 0.06))
	var widths: PackedFloat32Array = PackedFloat32Array()
	for i: int in arm.size():
		widths.append(1.1)
	out.append(ribbon(arm, widths))
	var head: Vector2 = base + Vector2(facing * height * 0.16, -height - height * 0.06)
	out.append(PackedVector2Array([
		head + Vector2(-facing * 1.0, -2.0),
		head + Vector2(facing * 9.0, -2.0),
		head + Vector2(facing * 7.0, 3.0),
		head + Vector2(facing * 1.0, 3.0),
	]))
	return out


## Panneau publicitaire sur deux pieds, avec passerelle et projecteurs.
static func billboard(base: Vector2, width: float, height: float, panel_h: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(rect(Rect2(base.x + width * 0.2, base.y - height, 4.0, height)))
	out.append(rect(Rect2(base.x + width * 0.8 - 4.0, base.y - height, 4.0, height)))
	out.append(rect(Rect2(base.x, base.y - height - panel_h, width, panel_h)))
	out.append(rect(Rect2(base.x - 2.0, base.y - height + 2.0, width + 4.0, 2.5)))
	for k: float in [0.25, 0.5, 0.75]:
		out.append(rect(Rect2(base.x + width * k - 1.0, base.y - height - panel_h - 7.0, 2.0, 7.0)))
		out.append(rect(Rect2(base.x + width * k - 3.0, base.y - height - panel_h - 9.0, 6.0, 3.0)))
	return out
