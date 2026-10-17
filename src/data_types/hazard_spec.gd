class_name HazardSpec
extends Resource
## Un piège d'un tronçon (coordonnées locales au tronçon, comme ChunkLayout.blocks).
## Contact = mort (RunnerBody.kill), sauf pendant l'invulnérabilité de réapparition.

## &"spikes" : pics posés sur une surface (rect = zone mortelle, au ras du sol).
## &"saw" : scie circulaire (rect = carré englobant ; se déplace de path_to et revient).
## &"crusher" : bloc qui s'abat puis remonte (rect = position haute ; descend de path_to.y).
## &"flame" : jet de flammes intermittent (rect = zone de la flamme allumée).
## &"crumble" : plateforme qui s'effondre peu après qu'on s'y pose (rect = plateforme ; non mortelle).
@export var kind: StringName = &"spikes"
@export var rect: Rect2 = Rect2(0, -16, 64, 16)
## Déplacement aller (scie mobile, écraseur) ; zéro = immobile.
@export var path_to: Vector2 = Vector2.ZERO
## Durée d'un cycle complet (s) pour les pièges animés ; 0 = permanent.
@export var period: float = 0.0
## Décalage dans le cycle (0..1), pour désynchroniser des pièges voisins.
@export_range(0.0, 1.0) var phase: float = 0.0
## Part du cycle pendant laquelle le piège est dangereux (flamme allumée, écraseur en bas).
@export_range(0.0, 1.0) var active_ratio: float = 0.5
