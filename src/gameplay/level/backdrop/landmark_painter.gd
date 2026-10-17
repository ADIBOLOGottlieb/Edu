class_name LandmarkPainter
extends RefCounted
## Monuments et repères de ville, dessinés en silhouette sur le plan lointain.
## Évocations stylisées ORIGINALES (formes simplifiées, pas des copies fidèles :
## droits d'auteur, voir docs/PROPOSITION_TOUR_DU_MONDE.md §8).
## Chaque repère est désigné par un StringName : pour une nouvelle ville, ajouter
## sa clé dans KNOWN et une branche dans _silhouette() / _details().
## Coordonnées : origin = milieu de la base au sol, y négatif vers le haut ;
## scale multiplie les mesures natives (≈ 1 px à l'échelle 1).

const KNOWN: Array[StringName] = [
	&"lome_independence",
	&"cathedral",
	&"hotel_tower",
	&"beach_palms",
]


static func is_known(key: StringName) -> bool:
	return KNOWN.has(key)


## Silhouette pleine du repère (couleur du plan). Clé inconnue : rien, avec avertissement.
static func silhouette(key: StringName, origin: Vector2, scale: float = 1.0) -> Array[PackedVector2Array]:
	var native: Array[PackedVector2Array] = _silhouette(key)
	if native.is_empty() and not is_known(key):
		push_warning("LandmarkPainter : repère inconnu « %s »" % key)
	return _place(native, origin, scale)


## Reliefs et ouvertures dessinés d'un ton plus clair par-dessus la silhouette.
static func details(key: StringName, origin: Vector2, scale: float = 1.0) -> Array[PackedVector2Array]:
	return _place(_details(key), origin, scale)


## Largeur native approximative (mise en page du plan lointain).
static func width(key: StringName) -> float:
	match key:
		&"lome_independence":
			return 160.0
		&"cathedral":
			return 130.0
		&"hotel_tower":
			return 150.0
		&"beach_palms":
			return 220.0
	return 0.0


static func _place(native: Array[PackedVector2Array], origin: Vector2, scale: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var xf: Transform2D = Transform2D(0.0, Vector2(scale, scale), 0.0, origin)
	for poly: PackedVector2Array in native:
		out.append(xf * poly)
	return out


static func _r(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return BackdropShapes.rect(Rect2(x, y, w, h))


static func _silhouette(key: StringName) -> Array[PackedVector2Array]:
	match key:
		&"lome_independence":
			return _independence()
		&"cathedral":
			return _cathedral()
		&"hotel_tower":
			return _hotel_tower()
		&"beach_palms":
			return _beach_palms()
	var none: Array[PackedVector2Array] = []
	return none


static func _details(key: StringName) -> Array[PackedVector2Array]:
	match key:
		&"lome_independence":
			return _independence_relief()
		&"cathedral":
			return _cathedral_openings()
		&"hotel_tower":
			return _hotel_floors()
	var none: Array[PackedVector2Array] = []
	return none


## Stèle de l'indépendance (évocation) : haute dalle élancée sur socle à gradins.
static func _independence() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [
		_r(-80.0, -12.0, 160.0, 12.0),
		_r(-62.0, -24.0, 124.0, 12.0),
		_r(-46.0, -34.0, 92.0, 10.0),
		PackedVector2Array([
			Vector2(-29.0, -34.0), Vector2(29.0, -34.0),
			Vector2(26.0, -290.0), Vector2(-26.0, -290.0),
		]),
		_r(-29.0, -297.0, 58.0, 7.0),
		# Deux mâts de drapeau de part et d'autre du socle.
		_r(-74.0, -96.0, 2.0, 84.0),
		_r(72.0, -96.0, 2.0, 84.0),
		_r(-72.0, -96.0, 12.0, 8.0),
		_r(74.0, -96.0, 12.0, 8.0),
	]
	return out


## Figure humaine stylisée en relief, bras levés vers le ciel.
static func _independence_relief() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [
		# Jambes.
		PackedVector2Array([Vector2(-10.0, -44.0), Vector2(-3.0, -44.0), Vector2(-1.0, -128.0), Vector2(-9.0, -128.0)]),
		PackedVector2Array([Vector2(3.0, -44.0), Vector2(10.0, -44.0), Vector2(9.0, -128.0), Vector2(1.0, -128.0)]),
		# Buste.
		PackedVector2Array([Vector2(-10.0, -126.0), Vector2(10.0, -126.0), Vector2(12.0, -184.0), Vector2(-12.0, -184.0)]),
		BackdropShapes.circle(Vector2(0.0, -198.0), 9.0, 12),
		# Bras levés en V.
		BackdropShapes.ribbon(
			PackedVector2Array([Vector2(-10.0, -180.0), Vector2(-16.0, -222.0), Vector2(-21.0, -262.0)]),
			PackedFloat32Array([3.4, 3.0, 2.6])),
		BackdropShapes.ribbon(
			PackedVector2Array([Vector2(10.0, -180.0), Vector2(16.0, -222.0), Vector2(21.0, -262.0)]),
			PackedFloat32Array([3.4, 3.0, 2.6])),
		BackdropShapes.circle(Vector2(-21.5, -266.0), 3.6, 8),
		BackdropShapes.circle(Vector2(21.5, -266.0), 3.6, 8),
	]
	return out


## Cathédrale néogothique à deux flèches (évocation).
static func _cathedral() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [
		_r(-46.0, -80.0, 92.0, 80.0),
		PackedVector2Array([Vector2(-48.0, -80.0), Vector2(0.0, -108.0), Vector2(48.0, -80.0)]),
		# Tours.
		_r(-64.0, -146.0, 30.0, 146.0),
		_r(34.0, -146.0, 30.0, 146.0),
		_r(-61.0, -166.0, 24.0, 20.0),
		_r(37.0, -166.0, 24.0, 20.0),
		# Flèches.
		PackedVector2Array([Vector2(-62.0, -166.0), Vector2(-49.0, -228.0), Vector2(-36.0, -166.0)]),
		PackedVector2Array([Vector2(36.0, -166.0), Vector2(49.0, -228.0), Vector2(62.0, -166.0)]),
		# Croix.
		_r(-49.8, -242.0, 1.6, 16.0), _r(-54.0, -237.0, 10.0, 1.6),
		_r(48.2, -242.0, 1.6, 16.0), _r(44.0, -237.0, 10.0, 1.6),
		_r(-0.8, -120.0, 1.6, 14.0), _r(-4.0, -116.0, 8.0, 1.6),
	]
	# Pinacles aux angles des tours.
	for x: float in [-64.0, -37.0, 34.0, 61.0]:
		out.append(PackedVector2Array([Vector2(x, -166.0), Vector2(x + 1.5, -180.0), Vector2(x + 3.0, -166.0)]))
	return out


static func _arch(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y - h * 0.7),
		Vector2(x + w * 0.5, y - h), Vector2(x, y - h * 0.7),
	])


static func _cathedral_openings() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [
		BackdropShapes.circle(Vector2(0.0, -62.0), 9.0, 14),
		_arch(-8.0, 0.0, 16.0, 30.0),
		_arch(-53.0, -100.0, 8.0, 26.0),
		_arch(45.0, -100.0, 8.0, 26.0),
		_arch(-52.0, -148.0, 6.0, 14.0),
		_arch(46.0, -148.0, 6.0, 14.0),
	]
	return out


## Tour d'hôtel moderne : haute barre sur un socle, couronnement et mât.
static func _hotel_tower() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [
		_r(-75.0, -38.0, 150.0, 38.0),
		_r(-38.0, -322.0, 76.0, 284.0),
		_r(-30.0, -336.0, 60.0, 14.0),
		_r(-12.0, -346.0, 24.0, 10.0),
		_r(-1.5, -384.0, 3.0, 38.0),
	]
	return out


static func _hotel_floors() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var y: float = -52.0
	while y > -312.0:
		out.append(_r(-33.0, y, 66.0, 2.2))
		y -= 13.0
	return out


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
