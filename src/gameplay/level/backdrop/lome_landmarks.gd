class_name LomeLandmarks
extends RefCounted
## Monuments de Lomé en silhouette : évocations stylisées ORIGINALES, dessinées
## d'après l'esprit des lieux (proportions, motifs reconnaissables), jamais
## décalquées sur des photos : œuvres récentes protégées, voir
## docs/PROPOSITION_TOUR_DU_MONDE.md §8 et ADR-010 / ADR-040.
## Coordonnées natives : origine = milieu de la base au sol, y négatif vers le haut.

## Couleurs du drapeau togolais (fondues dans la couleur du plan au dessin).
const FLAG_GREEN: Color = Color(0.0, 0.47, 0.27)
const FLAG_YELLOW: Color = Color(1.0, 0.82, 0.05)
const FLAG_RED: Color = Color(0.84, 0.1, 0.15)
const FLAG_WHITE: Color = Color(1.0, 1.0, 1.0)


static func _r(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return BackdropShapes.rect(Rect2(x, y, w, h))


static func _ellipse(c: Vector2, rx: float, ry: float, rot: float = 0.0, seg: int = 16) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in seg:
		var a: float = TAU * float(i) / float(seg)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


## Symétrique par rapport à l'axe x = 0 (ordre inversé : même orientation).
static func _mirror(poly: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(poly.size() - 1, -1, -1):
		out.append(Vector2(-poly[i].x, poly[i].y))
	return out


static func _with_mirror(polys: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = polys.duplicate()
	for poly: PackedVector2Array in polys:
		out.append(_mirror(poly))
	return out


## Étoile à cinq branches, pointe en haut.
static func star(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var a: float = -PI * 0.5 + PI * float(i) / 5.0
		var r: float = r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Baie en arc posée sur y = bottom : plein cintre, ou brisé (gothique).
static func arch(cx: float, bottom: float, w: float, h: float, pointed: bool = false) -> PackedVector2Array:
	var half: float = w * 0.5
	var pts: PackedVector2Array = PackedVector2Array([Vector2(cx - half, bottom), Vector2(cx + half, bottom)])
	if pointed:
		var spring: float = bottom - h * 0.6
		var apex: float = bottom - h
		for i: int in 5:
			var t: float = float(i) / 5.0
			pts.append(Vector2(cx + half * cos(t * PI * 0.5), spring + (apex - spring) * sin(t * PI * 0.5)))
		pts.append(Vector2(cx, apex))
		for i: int in range(4, -1, -1):
			var t: float = float(i) / 5.0
			pts.append(Vector2(cx - half * cos(t * PI * 0.5), spring + (apex - spring) * sin(t * PI * 0.5)))
	else:
		var spring_r: float = bottom - maxf(h - half, 0.0)
		for i: int in 11:
			var a: float = PI * float(i) / 10.0
			pts.append(Vector2(cx + cos(a) * half, spring_r - sin(a) * half))
	return pts


## Bande épaisse le long d'une courbe de Bézier quadratique.
static func _curve(a: Vector2, ctrl: Vector2, b: Vector2, w0: float, w1: float, steps: int = 8) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var widths: PackedFloat32Array = PackedFloat32Array()
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
		widths.append(lerpf(w0, w1, t))
	return BackdropShapes.ribbon(pts, widths)


static func _ribbon(points: Array[Vector2], widths: Array[float]) -> PackedVector2Array:
	return BackdropShapes.ribbon(PackedVector2Array(points), PackedFloat32Array(widths))


# --- Monument de l'Indépendance ------------------------------------------------

## Deux hautes dalles latérales perforées au sommet incliné vers le centre ;
## entre elles, une large dalle cintrée évidée en forme de figure humaine aux
## bras levés (le ciel passe au travers) ; dans l'évidement, une petite statue
## qui brandit une étoile ; podium central et emmarchements de part et d'autre.
static func independence(d: LandmarkDrawing) -> void:
	d.fill.append(_r(-136.0, -5.0, 272.0, 5.0))
	# Dalle latérale gauche (la droite en miroir).
	var slab: PackedVector2Array = PackedVector2Array([
		Vector2(-132.0, -3.0), Vector2(-70.0, -3.0), Vector2(-70.0, -282.0), Vector2(-132.0, -324.0),
	])
	d.fill.append(slab)
	d.fill.append(_mirror(slab))
	d.fill.append(_independence_arch())
	# Podium central et emmarchements.
	d.fill.append(_r(-74.0, -31.0, 148.0, 31.0))
	var stair: PackedVector2Array = PackedVector2Array([Vector2(-128.0, 0.0)])
	var steps: int = 5
	for i: int in steps:
		var x: float = lerpf(-128.0, -74.0, float(i) / float(steps))
		var y: float = -31.0 * float(i + 1) / float(steps)
		stair.append(Vector2(x, y + 31.0 / float(steps)))
		stair.append(Vector2(x, y))
	stair.append(Vector2(-74.0, -31.0))
	stair.append(Vector2(-74.0, 0.0))
	d.fill.append(stair)
	d.fill.append(_mirror(stair))
	_independence_statue(d)

	# Perforations rondes des dalles latérales (le ciel au travers) et rainures.
	for column: float in [-124.0, -106.0, -88.0]:
		var top: float = lerpf(-324.0, -282.0, (column + 132.0) / 62.0) + 12.0
		var y: float = -40.0
		while y > top:
			d.light.append(BackdropShapes.circle(Vector2(column, y), 2.1, 8))
			d.light.append(BackdropShapes.circle(Vector2(-column, y), 2.1, 8))
			y -= 12.5
	for groove: float in [-115.0, -97.0, -79.0]:
		var gtop: float = lerpf(-324.0, -282.0, (groove + 132.0) / 62.0) + 6.0
		d.dark.append(_r(groove, gtop, 1.4, -8.0 - gtop))
		d.dark.append(_r(-groove - 1.4, gtop, 1.4, -8.0 - gtop))
	# Arête éclairée des dalles, marches, porte du podium.
	d.light.append(PackedVector2Array([
		Vector2(-132.0, -324.0), Vector2(-70.0, -282.0), Vector2(-70.0, -279.6), Vector2(-132.0, -321.6),
	]))
	d.light.append(_mirror(d.light[d.light.size() - 1]))
	for i: int in steps:
		var x: float = lerpf(-128.0, -74.0, float(i) / float(steps))
		var y: float = -31.0 * float(i + 1) / float(steps)
		d.light.append(_r(x, y, -74.0 - x, 1.2))
		d.light.append(_r(74.0, y, -74.0 - x, 1.2))
	d.light.append(_r(-74.0, -31.0, 148.0, 1.4))
	d.dark.append(_r(-9.0, -24.0, 18.0, 24.0))


## Contour gauche de l'évidement, du pied (au ras du podium) jusqu'à la pointe
## du nœud central (bras repliés au-dessus de la tête), qui pend du haut.
const _HOLE_LEFT: Array[Vector2] = [
	Vector2(-46.0, -31.0), Vector2(-43.0, -50.0), Vector2(-38.0, -68.0), Vector2(-31.0, -88.0),
	Vector2(-25.0, -107.0), Vector2(-26.0, -121.0), Vector2(-31.0, -137.0), Vector2(-38.0, -152.0),
	Vector2(-42.0, -166.0), Vector2(-41.0, -181.0), Vector2(-44.0, -196.0), Vector2(-47.0, -208.0),
	Vector2(-48.0, -218.0), Vector2(-44.0, -225.0), Vector2(-22.0, -227.0), Vector2(-6.0, -226.0),
	Vector2(-6.0, -216.0), Vector2(-17.0, -216.5), Vector2(-26.0, -214.0), Vector2(-30.5, -207.0),
	Vector2(-29.5, -199.0), Vector2(-23.0, -191.0), Vector2(-12.0, -185.0), Vector2(0.0, -181.0),
]


## Dalle centrale cintrée et son évidement : un seul polygone simple (l'évidement
## s'ouvre sur le podium, la dalle forme une arche).
static func _independence_arch() -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array([Vector2(-74.0, -31.0)])
	for i: int in 13:
		var t: float = float(i) / 12.0
		pts.append(Vector2(lerpf(-74.0, 74.0, t), -242.0 - 9.0 * sin(PI * t)))
	pts.append(Vector2(74.0, -31.0))
	# Bord droit de l'évidement, du pied à la pointe…
	for i: int in _HOLE_LEFT.size():
		pts.append(Vector2(-_HOLE_LEFT[i].x, _HOLE_LEFT[i].y))
	# …puis bord gauche, de la pointe au pied.
	for i: int in range(_HOLE_LEFT.size() - 2, -1, -1):
		pts.append(_HOLE_LEFT[i])
	return pts


## Statue dans l'évidement : socle, silhouette drapée aux bras levés, étoile.
static func _independence_statue(d: LandmarkDrawing) -> void:
	d.fill.append(_r(-11.0, -52.0, 22.0, 21.0))
	d.fill.append(_r(-13.0, -55.0, 26.0, 3.0))
	d.fill.append(PackedVector2Array([
		Vector2(-8.0, -55.0), Vector2(8.0, -55.0), Vector2(5.0, -80.0),
		Vector2(5.5, -100.0), Vector2(-5.5, -100.0), Vector2(-5.0, -80.0),
	]))
	d.fill.append(_ellipse(Vector2(0.0, -103.0), 5.5, 6.0))
	d.fill.append(BackdropShapes.circle(Vector2(0.0, -113.0), 4.0, 10))
	var arm: PackedVector2Array = _ribbon(
		[Vector2(-5.0, -105.0), Vector2(-10.0, -114.0), Vector2(-3.0, -124.0)] as Array[Vector2],
		[1.9, 1.6, 1.4] as Array[float])
	d.fill.append(arm)
	d.fill.append(_mirror(arm))
	d.fill.append(star(Vector2(0.0, -132.0), 7.5, 3.2))


# --- Colombe de la Paix --------------------------------------------------------

## Rond-point : socle circulaire bas, haute tente évasée de nervures courbes qui
## montent jusqu'à une taille étroite, coupe, sphère, et colombe aux ailes levées.
static func colombe(d: LandmarkDrawing) -> void:
	d.fill.append(_r(-134.0, -9.0, 268.0, 9.0))
	d.fill.append(_ellipse(Vector2(0.0, -9.0), 134.0, 4.0, 0.0, 28))
	var skirt: PackedVector2Array = PackedVector2Array()
	var rows: int = 14
	for i: int in rows + 1:
		var t: float = float(i) / float(rows)
		skirt.append(Vector2(-_skirt_half_width(t), lerpf(-9.0, -150.0, t)))
	for i: int in range(rows, -1, -1):
		var t: float = float(i) / float(rows)
		skirt.append(Vector2(_skirt_half_width(t), lerpf(-9.0, -150.0, t)))
	d.fill.append(skirt)
	# Coupe, anneau et sphère.
	d.fill.append(PackedVector2Array([
		Vector2(-10.0, -148.0), Vector2(10.0, -148.0), Vector2(19.0, -165.0), Vector2(-19.0, -165.0),
	]))
	d.fill.append(_r(-21.0, -168.0, 42.0, 3.0))
	d.fill.append(BackdropShapes.circle(Vector2(0.0, -182.0), 15.0, 20))
	_dove(d, Vector2(0.0, -196.0))

	# Nervures éclairées qui filent de la taille au socle, arcades entre elles.
	for k: int in range(-2, 3):
		var pts: Array[Vector2] = []
		var widths: Array[float] = []
		for i: int in rows + 1:
			var t: float = float(i) / float(rows)
			pts.append(Vector2(float(k) * 0.41 * _skirt_half_width(t), lerpf(-10.0, -148.0, t)))
			widths.append(lerpf(1.3, 0.6, t))
		d.light.append(_ribbon(pts, widths))
	for k: int in range(-2, 2):
		var cx: float = (float(k) + 0.5) * 0.41 * _skirt_half_width(0.0)
		var outer: bool = k == -2 or k == 1
		d.light.append(arch(cx, -10.0, 20.0 if outer else 24.0, 30.0 if outer else 48.0, true))
	d.light.append(_r(-132.0, -9.8, 264.0, 1.2))
	d.light.append(_r(-15.0, -182.6, 30.0, 1.2))
	d.light.append(_r(-21.0, -168.0, 42.0, 1.0))


## Demi-largeur de la tente à la hauteur relative t (0 = pied, 1 = taille).
static func _skirt_half_width(t: float) -> float:
	return 10.0 + 88.0 * pow(1.0 - t, 1.55)


## Colombe posée sur la sphère : corps tourné vers la droite, aile levée en
## éventail vers le haut et l'arrière, rameau d'olivier au bec.
static func _dove(d: LandmarkDrawing, at: Vector2) -> void:
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(-27.0, -3.0), Vector2(-30.0, -8.0), Vector2(-14.0, -11.0), Vector2(0.0, -18.0),
		Vector2(11.0, -26.0), Vector2(15.0, -34.0), Vector2(19.0, -39.0), Vector2(24.0, -40.0),
		Vector2(28.0, -38.0), Vector2(35.0, -38.0), Vector2(28.0, -34.5), Vector2(25.0, -32.0),
		Vector2(21.0, -24.0), Vector2(14.0, -13.0), Vector2(4.0, -4.0), Vector2(-8.0, -1.0),
		Vector2(-20.0, 0.0),
	])
	var wing: PackedVector2Array = PackedVector2Array([
		Vector2(-4.0, -14.0), Vector2(10.0, -24.0), Vector2(9.0, -42.0), Vector2(3.0, -57.0),
		Vector2(-5.0, -67.0), Vector2(-14.0, -73.0), Vector2(-15.0, -66.0), Vector2(-24.0, -67.0),
		Vector2(-20.0, -60.0), Vector2(-30.0, -59.0), Vector2(-22.0, -53.0), Vector2(-32.0, -49.0),
		Vector2(-22.0, -45.0), Vector2(-30.0, -38.0), Vector2(-18.0, -36.0), Vector2(-22.0, -28.0),
	])
	# Seconde aile, en retrait, dressée vers l'avant.
	var far_wing: PackedVector2Array = PackedVector2Array([
		Vector2(8.0, -24.0), Vector2(14.0, -30.0), Vector2(17.0, -46.0), Vector2(15.0, -58.0),
		Vector2(11.0, -52.0), Vector2(8.0, -54.0), Vector2(6.0, -44.0), Vector2(3.0, -40.0),
	])
	var branch: PackedVector2Array = _curve(Vector2(33.0, -37.0), Vector2(39.0, -36.0), Vector2(44.0, -31.0), 0.7, 0.5, 4)
	var shapes: Array[PackedVector2Array] = [
		far_wing, body, wing, branch,
		_ellipse(Vector2(40.0, -38.5), 2.6, 1.1, -0.4, 8),
		_ellipse(Vector2(43.0, -33.0), 2.6, 1.1, 0.9, 8),
		_r(-1.0, -4.0, 2.0, 4.5),
	]
	for poly: PackedVector2Array in shapes:
		var moved: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in poly:
			moved.append(p + at)
		d.fill.append(moved)


# --- Les Deux Lions ------------------------------------------------------------

## Rond-point : deux lions dressés dos à dos sur un socle rond, chacun brandissant
## un arc et une flèche vers l'extérieur ; entre eux, le mât et le drapeau du Togo.
static func deux_lions(d: LandmarkDrawing) -> void:
	d.fill.append(_r(-128.0, -14.0, 256.0, 14.0))
	d.fill.append(_ellipse(Vector2(0.0, -14.0), 128.0, 4.0, 0.0, 28))
	d.fill.append_array(_with_mirror(_lion()))
	# Mât et drapeau flottant vers la droite.
	d.fill.append(_r(-1.6, -264.0, 3.2, 250.0))
	d.fill.append(BackdropShapes.circle(Vector2(0.0, -266.0), 2.6, 8))
	_togo_flag(d, Vector2(1.6, -260.0), 46.0, 27.0)
	d.light.append(_r(-126.0, -14.6, 252.0, 1.2))
	# Yeux éclairés par le couchant.
	for side: float in [-1.0, 1.0]:
		d.light.append(_ellipse(Vector2(-69.0 * side, -142.0), 1.8, 1.1, 0.0, 8))


## Lion gauche, dressé, tourné vers la gauche (le droit est son miroir).
static func _lion() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	# Pattes arrière coudées : celle d'appui en retrait, l'autre avancée.
	out.append(_ribbon([Vector2(-20.0, -54.0), Vector2(-10.0, -36.0), Vector2(-14.0, -19.0)] as Array[Vector2],
		[8.0, 6.0, 5.0] as Array[float]))
	out.append(_ellipse(Vector2(-18.0, -16.5), 8.5, 3.5))
	out.append(_ribbon([Vector2(-32.0, -54.0), Vector2(-46.0, -42.0), Vector2(-40.0, -28.0), Vector2(-47.0, -19.0)] as Array[Vector2],
		[9.0, 6.5, 5.0, 4.5] as Array[float]))
	out.append(_ellipse(Vector2(-52.0, -16.5), 9.0, 3.5))
	out.append(_ellipse(Vector2(-28.0, -59.0), 16.0, 19.0, -0.5))
	# Queue basse qui remonte en crosse, touffe en flamme.
	out.append(_ribbon([Vector2(-15.0, -52.0), Vector2(-5.0, -36.0), Vector2(1.0, -46.0), Vector2(0.0, -62.0),
		Vector2(-5.0, -72.0)] as Array[Vector2], [3.0, 2.6, 2.3, 2.0, 1.8] as Array[float]))
	out.append(PackedVector2Array([
		Vector2(-2.0, -70.0), Vector2(-5.0, -80.0), Vector2(-9.0, -74.0), Vector2(-9.0, -69.0), Vector2(-5.0, -67.0),
	]))
	# Torse incliné vers l'avant, poitrail bombé.
	out.append(_ribbon([Vector2(-27.0, -66.0), Vector2(-37.0, -86.0), Vector2(-48.0, -104.0)] as Array[Vector2],
		[15.0, 10.5, 15.0] as Array[float]))
	out.append(_ellipse(Vector2(-52.0, -106.0), 12.0, 14.0, -0.5))
	# Crinière ronde qui encadre la tête, plus courte devant la face.
	out.append(_mane(Vector2(-41.0, -125.0), 28.0, 32.0, 13, 7.0, 0.22))
	# Tête de profil : front haut, museau court et carré, gueule ouverte
	# (encoche entre les mâchoires).
	out.append(PackedVector2Array([
		Vector2(-56.0, -150.0), Vector2(-66.0, -150.0), Vector2(-72.0, -146.0), Vector2(-77.0, -140.0),
		Vector2(-80.0, -138.5), Vector2(-80.5, -133.0), Vector2(-71.0, -130.5), Vector2(-79.0, -126.5),
		Vector2(-78.0, -121.5), Vector2(-66.0, -118.0), Vector2(-56.0, -122.0),
	]))
	# Pattes avant levées, griffes tendues, tenant l'arc et la flèche.
	out.append(_ribbon([Vector2(-54.0, -114.0), Vector2(-68.0, -119.0), Vector2(-81.0, -126.0)] as Array[Vector2],
		[7.0, 5.5, 4.8] as Array[float]))
	out.append(_paw(Vector2(-84.0, -127.0)))
	out.append(_ribbon([Vector2(-52.0, -98.0), Vector2(-67.0, -95.0), Vector2(-81.0, -92.0)] as Array[Vector2],
		[7.0, 5.5, 4.8] as Array[float]))
	out.append(_paw(Vector2(-84.0, -92.0)))
	# Arc tendu vers l'extérieur, corde, flèche pointée vers le ciel.
	out.append(_curve(Vector2(-89.0, -168.0), Vector2(-120.0, -124.0), Vector2(-89.0, -78.0), 1.7, 1.7, 12))
	out.append(_r(-89.6, -168.0, 0.9, 90.0))
	out.append(_r(-86.6, -186.0, 1.4, 112.0))
	out.append(PackedVector2Array([Vector2(-90.0, -184.0), Vector2(-85.9, -194.0), Vector2(-81.8, -184.0)]))
	out.append(PackedVector2Array([Vector2(-90.0, -74.0), Vector2(-86.0, -80.0), Vector2(-82.0, -74.0), Vector2(-86.0, -77.0)]))
	return out


## Patte griffue (tournée vers la gauche).
static func _paw(c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(4.0, -4.5), c + Vector2(-3.0, -4.5), c + Vector2(-7.5, -3.5), c + Vector2(-5.0, -1.5),
		c + Vector2(-8.0, 0.0), c + Vector2(-5.0, 1.5), c + Vector2(-7.5, 3.5), c + Vector2(-3.0, 4.5),
		c + Vector2(4.0, 4.5),
	])


## Crinière : ellipse bouclée (lobes arrondis séparés de creux), mèches
## étirées vers l'arrière ; plus courte devant la face (côté gauche).
static func _mane(c: Vector2, rx: float, ry: float, lobes: int, depth: float, swirl: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var samples: int = lobes * 6
	for i: int in samples:
		var a: float = TAU * float(i) / float(samples)
		var wave: float = pow(absf(sin(a * float(lobes) * 0.5)), 0.6)
		var r: float = 1.0 - depth / rx * (1.0 - wave)
		if cos(a) < -0.7:
			r = minf(r, 1.0 - depth / rx * 0.8)
		# Les mèches du dessus et de la nuque fuient vers l'arrière (x > 0).
		var drift: Vector2 = Vector2(swirl * rx * maxf(0.0, -sin(a)) * wave, 0.0)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * r + drift)
	return pts


## Drapeau du Togo ondulant : cinq bandes vert/jaune, canton rouge, étoile blanche.
static func _togo_flag(d: LandmarkDrawing, hoist: Vector2, w: float, h: float) -> void:
	var cols: int = 10
	var band_h: float = h / 5.0
	for b: int in 5:
		var top: PackedVector2Array = PackedVector2Array()
		var bottom: PackedVector2Array = PackedVector2Array()
		for i: int in cols + 1:
			var t: float = float(i) / float(cols)
			top.append(_flag_point(hoist, w, t, float(b) * band_h))
			bottom.append(_flag_point(hoist, w, t, float(b + 1) * band_h))
		bottom.reverse()
		top.append_array(bottom)
		d.add_tinted(top, FLAG_GREEN if b % 2 == 0 else FLAG_YELLOW)
	var side: float = band_h * 3.0
	var canton: PackedVector2Array = PackedVector2Array()
	var ct: float = side / w
	for i: int in 4:
		canton.append(_flag_point(hoist, w, ct * float(i) / 3.0, 0.0))
	for i: int in range(3, -1, -1):
		canton.append(_flag_point(hoist, w, ct * float(i) / 3.0, side))
	d.add_tinted(canton, FLAG_RED)
	var mid: Vector2 = _flag_point(hoist, w, ct * 0.5, side * 0.5)
	d.add_tinted(star(mid, side * 0.36, side * 0.15), FLAG_WHITE)


static func _flag_point(hoist: Vector2, w: float, t: float, y: float) -> Vector2:
	return hoist + Vector2(w * t, y + 2.6 * t * sin(t * PI * 1.7 - 0.4))


# --- Palais de Lomé ------------------------------------------------------------

## Ancien palais des gouverneurs : longue bâtisse blanche à deux niveaux sur
## terrasse, arcades au rez-de-chaussée, baies à persiennes à l'étage, toits
## bas débordants, pavillons d'angle ; tour centrale au couronnement festonné
## percée d'un oculus ; grand escalier central évasé, balustrades.
static func palais(d: LandmarkDrawing) -> void:
	# Terrasse, corps de logis, toits débordants.
	d.fill.append(_r(-164.0, -17.0, 328.0, 17.0))
	d.fill.append(_r(-152.0, -84.0, 304.0, 68.0))
	d.fill.append(PackedVector2Array([
		Vector2(-160.0, -83.0), Vector2(160.0, -83.0), Vector2(149.0, -93.0), Vector2(-149.0, -93.0),
	]))
	d.fill.append(_r(-60.0, -92.0, 120.0, 76.0))
	d.fill.append(PackedVector2Array([
		Vector2(-67.0, -91.0), Vector2(67.0, -91.0), Vector2(58.0, -99.0), Vector2(-58.0, -99.0),
	]))
	# Pavillons d'angle.
	var pavilion: PackedVector2Array = _r(-164.0, -89.0, 28.0, 73.0)
	d.fill.append(pavilion)
	d.fill.append(_mirror(pavilion))
	var proof: PackedVector2Array = PackedVector2Array([
		Vector2(-168.0, -88.0), Vector2(-132.0, -88.0), Vector2(-137.0, -96.0), Vector2(-163.0, -96.0),
	])
	d.fill.append(proof)
	d.fill.append(_mirror(proof))
	# Tour centrale et couronnement festonné.
	d.fill.append(_r(-23.0, -150.0, 46.0, 134.0))
	d.fill.append(_r(-25.0, -103.0, 50.0, 4.0))
	d.fill.append(_crown(-23.0, 23.0, -150.0))
	# Grand escalier évasé, murets d'échiffre.
	d.fill.append(PackedVector2Array([
		Vector2(-27.0, -17.0), Vector2(27.0, -17.0), Vector2(48.0, 0.0), Vector2(-48.0, 0.0),
	]))
	var wall: PackedVector2Array = _curve(Vector2(-29.0, -21.0), Vector2(-34.0, -6.0), Vector2(-53.0, -3.0), 2.4, 2.8, 6)
	d.fill.append(wall)
	d.fill.append(_mirror(wall))

	# Oculus de la tour, à persiennes.
	d.dark.append(BackdropShapes.circle(Vector2(0.0, -130.0), 8.0, 18))
	for k: int in range(-2, 3):
		var y: float = float(k) * 2.8
		var half: float = sqrt(maxf(36.0 - y * y, 0.0))
		d.light.append(_r(-half, -130.0 + y - 0.4, half * 2.0, 0.8))
	# Arcades du rez-de-chaussée (sombres), grande arche centrale.
	d.dark.append(arch(0.0, -17.0, 20.0, 36.0))
	for x: float in [44.0, 78.0, 112.0]:
		d.dark.append(arch(-x, -17.0, 18.0, 28.0))
		d.dark.append(arch(x, -17.0, 18.0, 28.0))
	# Baies à persiennes de l'étage (lames claires).
	for x: float in [0.0, -44.0, 44.0, -78.0, 78.0, -112.0, 112.0]:
		var w: float = 26.0 if x == 0.0 else 24.0
		d.dark.append(_r(x - w * 0.5, -80.0, w, 21.0))
		var y: float = -77.0
		while y < -60.0:
			d.light.append(_r(x - w * 0.5, y, w, 0.8))
			y += 3.2
	# Pavillons : oculus et baie.
	for side: float in [-1.0, 1.0]:
		d.light.append(BackdropShapes.circle(Vector2(150.0 * side, -76.0), 3.4, 10))
		d.dark.append(arch(150.0 * side, -17.0, 12.0, 24.0))
	# Bandeaux, balustrades et marches.
	d.light.append(_r(-152.0, -57.0, 304.0, 1.4))
	d.light.append(_r(-164.0, -18.0, 328.0, 1.4))
	for side: float in [-1.0, 1.0]:
		d.light.append(_r(side * 160.0 if side < 0.0 else 31.0, -25.0, 129.0, 1.3))
		var bx: float = 33.0
		while bx < 160.0:
			d.light.append(_r(side * bx - 0.6, -24.0, 1.2, 6.0))
			bx += 3.6
	for i: int in 6:
		var t: float = float(i) / 6.0
		var half: float = lerpf(27.0, 48.0, t + 1.0 / 6.0)
		d.light.append(_r(-half, -17.0 + 17.0 * (t + 1.0 / 6.0) - 1.0, half * 2.0, 1.0))


## Couronnement festonné : festons en arc séparés par de petites pointes.
static func _crown(x0: float, x1: float, base: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array([Vector2(x0, base + 1.0)])
	var lobes: int = 4
	var lw: float = (x1 - x0) / float(lobes)
	pts.append(Vector2(x0 - 1.0, base - 6.0))
	pts.append(Vector2(x0, base - 14.0))
	for l: int in lobes:
		var cx: float = x0 + lw * (float(l) + 0.5)
		for i: int in range(1, 8):
			var a: float = PI - PI * float(i) / 8.0
			pts.append(Vector2(cx + cos(a) * lw * 0.5, base - 6.0 - sin(a) * lw * 0.5))
		pts.append(Vector2(x0 + lw * float(l + 1), base - 14.0))
	pts.append(Vector2(x1 + 1.0, base - 6.0))
	pts.append(Vector2(x1, base + 1.0))
	return pts
