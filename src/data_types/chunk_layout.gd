class_name ChunkLayout
extends Resource
## Un tronçon de niveau, décrit par des rectangles en coordonnées locales.
##
## Convention : le haut du toit d'entrée est à y = 0 en x = 0 ; le haut du toit
## de sortie est à y = exit_y en x = width (négatif = plus haut). Les tronçons
## s'empilent donc en altitude : on grimpe et on redescend de toit en toit.
## y négatif = au-dessus. LevelValidator vérifie que le tronçon est franchissable.

@export var id: StringName = &""
@export var width: float = 800.0
## Hauteur du toit de sortie par rapport à celui d'entrée (px, négatif = plus haut).
@export var exit_y: float = 0.0
## Toits, obstacles, murs, plafonds, poutres : position = coin haut-gauche.
@export var blocks: Array[Rect2] = []
## 0 = initiation … 4 = expert. Le séquenceur aléatoire augmente la difficulté avec la distance.
@export_range(0, 4) var difficulty: int = 0
## Mouvements sollicités (&"vault", &"slide", &"gap", &"wall", &"precision"…), pour l'équilibrage.
@export var tags: Array[StringName] = []
## Poids relatif dans le tirage aléatoire.
@export var weight: float = 1.0


## Haut de la surface la plus basse du tronçon (le plus grand y) : sert au seuil de chute.
func deepest_top() -> float:
	var deepest: float = maxf(0.0, exit_y)
	for rect: Rect2 in blocks:
		deepest = maxf(deepest, rect.position.y)
	return deepest
