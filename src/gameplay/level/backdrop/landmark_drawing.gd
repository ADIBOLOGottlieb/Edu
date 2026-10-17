class_name LandmarkDrawing
extends RefCounted
## Dessin d'un repère en coordonnées natives (origine = milieu de la base au
## sol, y négatif vers le haut), réparti par ton :
## - fill : silhouette pleine, couleur du plan ;
## - light : reliefs et ouvertures éclairés (ton du plan éclairci vers l'horizon) ;
## - dark : ombres et baies (ton du plan assombri) ;
## - tinted / tints : rares touches de couleur propre (drapeau), fondues dans
##   la couleur du plan par le peintre de plan.
## Ordre de dessin : fill, puis dark, puis light (une lame claire passe sur une
## baie sombre), puis tinted.

var fill: Array[PackedVector2Array] = []
var light: Array[PackedVector2Array] = []
var dark: Array[PackedVector2Array] = []
var tinted: Array[PackedVector2Array] = []
var tints: PackedColorArray = PackedColorArray()


func add_tinted(poly: PackedVector2Array, tint: Color) -> void:
	tinted.append(poly)
	tints.append(tint)


func is_empty() -> bool:
	return fill.is_empty()
