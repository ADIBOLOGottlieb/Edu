class_name ChunkLayout
extends Resource
## Un tronçon de niveau, décrit par des rectangles en coordonnées locales.
##
## Convention (jalon M3) : le haut du sol est à y = 0 à l'entrée (x = 0) et à la
## sortie (x = width), pour que les tronçons s'enchaînent dans n'importe quel ordre.
## y négatif = au-dessus du sol. LevelValidator vérifie ces règles.

@export var id: StringName = &""
@export var width: float = 800.0
## Sol, obstacles, murs, plafonds : position = coin haut-gauche.
@export var blocks: Array[Rect2] = []
## 0 = facile … 3 = difficile. Le séquenceur aléatoire augmente la difficulté avec la distance.
@export_range(0, 3) var difficulty: int = 0
## Mouvements sollicités (&"vault", &"slide", &"gap", &"wall"…), pour l'équilibrage.
@export var tags: Array[StringName] = []
## Poids relatif dans le tirage aléatoire.
@export var weight: float = 1.0
