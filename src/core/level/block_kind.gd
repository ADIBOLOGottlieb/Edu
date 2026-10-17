class_name BlockKind
extends RefCounted
## Type d'objet urbain représenté par un bloc de tronçon (décor, sans effet sur la
## collision). Déduit de la forme du rectangle et de son appui, pour que les 24
## tronçons existants reçoivent un décor sans être réécrits ; un tronçon peut
## imposer ses types (ChunkLayout.kinds).

enum Kind {
	## Immeuble dont le toit est le sol de course (descend loin sous l'écran).
	BUILDING,
	## Pilier étroit et haut : cheminée, poteau, tour (sauts de précision).
	PILLAR,
	## Petit obstacle posé sur un toit : climatiseur, caisse, bouche d'aération.
	LOW_OBSTACLE,
	## Obstacle étroit et haut posé sur un toit : château d'eau, panneau, cage d'escalier.
	WALL,
	## Volume large posé sur un toit : local technique, abri en tôle, marche.
	PLATFORM,
	## Bloc suspendu sous lequel on glisse : enseigne, passerelle, bâche de marché.
	CEILING,
	## Poutre fine suspendue : flèche de grue, poutrelle d'échafaudage.
	BEAM,
}

## Au-delà de cette hauteur, le bloc descend sous l'écran : c'est un immeuble.
const BUILDING_MIN_HEIGHT: float = 600.0
const PILLAR_MAX_WIDTH: float = 110.0
const BEAM_MAX_HEIGHT: float = 20.0
const LOW_MAX_HEIGHT: float = 60.0
const WALL_MAX_WIDTH: float = 140.0
## Tolérance (px) pour décider qu'un bloc repose sur un autre.
const REST_TOLERANCE: float = 2.0


static func classify(rect: Rect2, others: Array[Rect2]) -> Kind:
	if rect.size.y >= BUILDING_MIN_HEIGHT:
		return Kind.PILLAR if rect.size.x <= PILLAR_MAX_WIDTH else Kind.BUILDING
	if rect.size.y <= BEAM_MAX_HEIGHT:
		return Kind.BEAM
	if not _rests_on_something(rect, others):
		return Kind.CEILING
	if rect.size.y <= LOW_MAX_HEIGHT:
		return Kind.LOW_OBSTACLE
	return Kind.WALL if rect.size.x <= WALL_MAX_WIDTH else Kind.PLATFORM


## Types de tous les blocs d'un tronçon (ceux imposés par ChunkLayout.kinds d'abord).
static func kinds_of(layout: ChunkLayout) -> Array[Kind]:
	var result: Array[Kind] = []
	for i: int in layout.blocks.size():
		if i < layout.kinds.size() and layout.kinds[i] >= 0:
			result.append(layout.kinds[i] as Kind)
		else:
			result.append(classify(layout.blocks[i], layout.blocks))
	return result


## Variante d'objet stable pour un bloc donné (même tronçon = même décor).
static func variant(layout_id: StringName, index: int) -> int:
	return absi(hash("%s#%d" % [layout_id, index]))


static func name_of(kind: Kind) -> StringName:
	return StringName(String(Kind.keys()[kind]).to_lower())


static func _rests_on_something(rect: Rect2, others: Array[Rect2]) -> bool:
	var bottom: float = rect.end.y
	for other: Rect2 in others:
		if other == rect:
			continue
		var touches: bool = absf(other.position.y - bottom) <= REST_TOLERANCE
		var overlaps: bool = other.position.x < rect.end.x and other.end.x > rect.position.x
		if touches and overlaps:
			return true
	return false
