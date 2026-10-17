class_name LandmarkPainter
extends RefCounted
## Monuments et repères de ville, dessinés en silhouette sur les plans de décor.
## Évocations stylisées ORIGINALES (formes simplifiées, pas des copies fidèles :
## droits d'auteur, voir docs/PROPOSITION_TOUR_DU_MONDE.md §8).
## Chaque repère est désigné par un StringName : pour une nouvelle ville, ajouter
## sa clé dans KNOWN, sa largeur dans width(), son plan dans layer_of() et une
## branche dans drawing().
## Coordonnées : origin = milieu de la base au sol, y négatif vers le haut ;
## scale multiplie les mesures natives (≈ 1 px à l'échelle 1).

## Plan de décor qui accueille un repère : les grands édifices sur l'horizon
## lointain, les petits monuments de rond-point sur le plan des quartiers
## (assez proches pour rester lisibles).
enum Layer { FAR, MID }

const KNOWN: Array[StringName] = [
	&"lome_independence",
	&"colombe_paix",
	&"deux_lions",
	&"palais_lome",
	&"cathedral",
	&"hotel_tower",
	&"beach_palms",
]


static func is_known(key: StringName) -> bool:
	return KNOWN.has(key)


static func layer_of(key: StringName) -> Layer:
	match key:
		&"colombe_paix", &"deux_lions":
			return Layer.MID
	return Layer.FAR


## Silhouette pleine du repère (couleur du plan). Clé inconnue : rien, avec avertissement.
static func silhouette(key: StringName, origin: Vector2, scale: float = 1.0) -> Array[PackedVector2Array]:
	if not is_known(key):
		push_warning("LandmarkPainter : repère inconnu « %s »" % key)
	return place(drawing(key).fill, origin, scale)


## Reliefs et ouvertures dessinés d'un ton plus clair par-dessus la silhouette.
static func details(key: StringName, origin: Vector2, scale: float = 1.0) -> Array[PackedVector2Array]:
	return place(drawing(key).light, origin, scale)


## Ombres et baies dessinées d'un ton plus sombre par-dessus la silhouette.
static func shades(key: StringName, origin: Vector2, scale: float = 1.0) -> Array[PackedVector2Array]:
	return place(drawing(key).dark, origin, scale)


## Largeur native (emprise au sol, mise en page sans chevauchement).
static func width(key: StringName) -> float:
	match key:
		&"lome_independence":
			return 272.0
		&"colombe_paix":
			return 268.0
		&"deux_lions":
			return 256.0
		&"palais_lome":
			return 336.0
		&"cathedral":
			return 128.0
		&"hotel_tower":
			return 150.0
		&"beach_palms":
			return 296.0
	return 0.0


## Dessin natif complet du repère (vide si la clé est inconnue).
static func drawing(key: StringName) -> LandmarkDrawing:
	var d: LandmarkDrawing = LandmarkDrawing.new()
	match key:
		&"lome_independence":
			LomeLandmarks.independence(d)
		&"colombe_paix":
			LomeLandmarks.colombe(d)
		&"deux_lions":
			LomeLandmarks.deux_lions(d)
		&"palais_lome":
			LomeLandmarks.palais(d)
		&"cathedral":
			_cathedral(d)
		&"hotel_tower":
			_hotel_tower(d)
		&"beach_palms":
			d.fill = _beach_palms()
	return d


static func place(native: Array[PackedVector2Array], origin: Vector2, scale: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var xf: Transform2D = Transform2D(0.0, Vector2(scale, scale), 0.0, origin)
	for poly: PackedVector2Array in native:
		out.append(xf * poly)
	return out


static func _r(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return BackdropShapes.rect(Rect2(x, y, w, h))


## Cathédrale néogothique à deux tours inégales (évocation) : flèches à crochets
## cantonnées de pinacles, pignon central avec horloge, rosace et portail brisé,
## bandeaux qui rythment les étages.
static func _cathedral(d: LandmarkDrawing) -> void:
	d.fill.append(_r(-32.0, -96.0, 64.0, 96.0))
	d.fill.append(PackedVector2Array([Vector2(-34.0, -96.0), Vector2(0.0, -127.0), Vector2(34.0, -96.0)]))
	d.fill.append(_r(-0.8, -138.0, 1.6, 13.0))
	d.fill.append(_r(-4.0, -134.0, 8.0, 1.6))
	# Tour gauche (la plus basse) et tour droite.
	_cathedral_tower(d, -45.0, 28.0, -148.0, -216.0)
	_cathedral_tower(d, 46.0, 30.0, -168.0, -258.0)
	# Pinacles du pignon.
	for x: float in [-33.0, 33.0]:
		d.fill.append(PackedVector2Array([Vector2(x - 2.0, -96.0), Vector2(x, -110.0), Vector2(x + 2.0, -96.0)]))

	d.dark.append(LomeLandmarks.arch(0.0, 0.0, 17.0, 36.0, true))
	# Rosace : remplage sombre, couronne de lobes et cœur clairs.
	d.dark.append(BackdropShapes.circle(Vector2(0.0, -62.0), 11.5, 20))
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		d.light.append(BackdropShapes.circle(Vector2(cos(a), sin(a)) * 6.8 + Vector2(0.0, -62.0), 2.5, 8))
	d.light.append(BackdropShapes.circle(Vector2(0.0, -62.0), 2.8, 10))
	# Horloge du pignon : cadran clair cerclé de sombre.
	d.dark.append(BackdropShapes.circle(Vector2(0.0, -106.0), 6.5, 14))
	d.light.append(BackdropShapes.circle(Vector2(0.0, -106.0), 5.0, 14))
	d.light.append(_r(-32.0, -86.0, 64.0, 1.4))


## Une tour de la cathédrale : fût, corniche, pinacles d'angle, flèche à
## crochets et croix ; baies brisées et bandeaux clairs.
static func _cathedral_tower(d: LandmarkDrawing, cx: float, w: float, top: float, apex: float) -> void:
	var half: float = w * 0.5
	d.fill.append(_r(cx - half, top, w, -top))
	d.fill.append(_r(cx - half - 2.0, top - 3.0, w + 4.0, 3.0))
	for x: float in [cx - half - 1.0, cx + half - 2.0]:
		d.fill.append(PackedVector2Array([Vector2(x, top - 3.0), Vector2(x + 1.5, top - 20.0), Vector2(x + 3.0, top - 3.0)]))
	d.fill.append(_spire(cx, top - 3.0, apex, half * 0.78))
	d.fill.append(_r(cx - 0.8, apex - 13.0, 1.6, 14.0))
	d.fill.append(_r(cx - 4.0, apex - 9.5, 8.0, 1.6))
	# Bandeaux clairs entre les étages, baies brisées (géminées en haut).
	var stage: float = -top / 3.0
	for k: int in range(1, 3):
		d.light.append(_r(cx - half, -stage * float(k), w, 1.4))
	for k: int in range(1, 3):
		var bottom: float = -stage * float(k) - stage * 0.22
		d.dark.append(LomeLandmarks.arch(cx - w * 0.17, bottom, w * 0.2, stage * 0.56, true))
		d.dark.append(LomeLandmarks.arch(cx + w * 0.17, bottom, w * 0.2, stage * 0.56, true))
	d.dark.append(LomeLandmarks.arch(cx, -stage * 0.25, w * 0.26, stage * 0.5, true))
	# Lucarne claire au pied de la flèche.
	d.light.append(LomeLandmarks.arch(cx, top - 10.0, 4.0, 8.0, true))


## Flèche octogonale vue de face : bords dentelés de crochets.
static func _spire(cx: float, base: float, apex: float, half: float) -> PackedVector2Array:
	var teeth: int = 6
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for i: int in teeth:
		var t0: float = float(i) / float(teeth)
		var t1: float = (float(i) + 0.55) / float(teeth)
		var y0: float = lerpf(base, apex, t0)
		var y1: float = lerpf(base, apex, t1)
		left.append(Vector2(cx - half * (1.0 - t0), y0))
		left.append(Vector2(cx - half * (1.0 - t1) - 1.8, y1))
		right.append(Vector2(cx + half * (1.0 - t0), y0))
		right.append(Vector2(cx + half * (1.0 - t1) + 1.8, y1))
	right.reverse()
	left.append(Vector2(cx, apex))
	left.append_array(right)
	return left


## Tour d'hôtel moderne : haute barre sur un socle, couronnement et mât.
static func _hotel_tower(d: LandmarkDrawing) -> void:
	d.fill.append(_r(-75.0, -38.0, 150.0, 38.0))
	d.fill.append(_r(-38.0, -322.0, 76.0, 284.0))
	d.fill.append(_r(-30.0, -336.0, 60.0, 14.0))
	d.fill.append(_r(-12.0, -346.0, 24.0, 10.0))
	d.fill.append(_r(-1.5, -384.0, 3.0, 38.0))
	var y: float = -52.0
	while y > -312.0:
		d.light.append(_r(-33.0, y, 66.0, 2.2))
		y -= 13.0


## Bosquet de cocotiers du bord de mer, avec une paillote.
static func _beach_palms() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var palms: Array[Vector3] = [
		Vector3(-92.0, 96.0, -0.45),
		Vector3(-58.0, 128.0, -0.25),
		Vector3(-24.0, 84.0, 0.1),
		Vector3(18.0, 116.0, 0.35),
		Vector3(70.0, 74.0, 0.55),
		Vector3(96.0, 104.0, 0.2),
	]
	var i: int = 0
	for p: Vector3 in palms:
		out.append_array(BackdropShapes.palm(Vector2(p.x, 0.0), p.y, p.z, 31 + i))
		i += 1
	# Paillote : toit de chaume conique sur poteaux.
	out.append(_r(38.0, -20.0, 2.0, 20.0))
	out.append(_r(58.0, -20.0, 2.0, 20.0))
	out.append(PackedVector2Array([Vector2(30.0, -18.0), Vector2(49.0, -34.0), Vector2(68.0, -18.0)]))
	return out
