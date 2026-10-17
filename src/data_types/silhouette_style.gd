class_name SilhouetteStyle
extends Resource
## Proportions et volumes d'une silhouette humaine (px), séparés du code de dessin.
## Protagoniste : adulte athlétique (≈ 7,5 têtes), sweat à capuche ample,
## pantalon cargo, baskets (images de référence). Un poursuivant élancé n'est
## qu'un autre fichier de style (M5).

@export_group("Proportions")
@export var thigh: float = 18.0
@export var shin: float = 17.0
@export var torso: float = 23.0
@export var neck: float = 4.0
## Tête ovale : demi-largeur et demi-hauteur.
@export var head_radius: float = 4.7
@export var head_half_height: float = 5.6
@export var upper_arm: float = 13.0
@export var forearm: float = 12.0

@export_group("Buste (sweat ample)")
## Demi-largeurs, de bas en haut : ourlet, taille, poitrine, épaules (tombantes), cou.
@export var hem_half_width: float = 8.8
@export var waist_half_width: float = 8.0
@export var chest_half_width: float = 8.6
@export var shoulder_half_width: float = 7.8
@export var neck_radius: float = 2.6
## Léger renflement devant (poche kangourou).
@export var belly_bulge: float = 1.2

@export_group("Jambes (cargo)")
@export var thigh_radius: float = 4.9
@export var knee_radius: float = 3.8
@export var calf_radius: float = 3.9
@export var ankle_radius: float = 3.3

@export_group("Bras (manches)")
@export var sleeve_radius: float = 3.5
@export var elbow_radius: float = 3.0
@export var cuff_radius: float = 2.8
@export var hand_radius: float = 2.6

@export_group("Chaussures")
@export var shoe_height: float = 4.5
@export var shoe_length: float = 11.0
@export var heel_length: float = 3.0

@export_group("Détails (image de référence du coureur)")
## Capuche relevée (désactivée : la référence montre des cheveux courts).
@export var hood: bool = false
## Cheveux courts en casque arrondi, frange sur le front.
@export var hair: bool = true
## Col de sweat relevé autour du cou.
@export var collar_radius: float = 3.6
## Manches bouffantes : plis gonflés le long du bras, poignets resserrés.
@export var sleeve_puff: float = 1.1
## Grandes mains aux doigts écartés.
@export var finger_length: float = 4.2
@export var finger_count: int = 3
## Pantalon froissé au genou et resserré à la cheville.
@export var knee_bunch: float = 1.0
@export var cargo_pockets: bool = false

@export_group("Couleurs")
@export var ink: Color = Color(0.04, 0.04, 0.05)
## Membres arrière légèrement plus clairs pour lire la profondeur.
@export var back_ink: Color = Color(0.15, 0.15, 0.17)


## Hauteur des hanches au-dessus du sol, debout (jambes + chaussure).
func hip_height() -> float:
	return thigh + shin + shoe_height


## Hauteur totale debout, du sol au haut de la tête (capuche comprise).
func standing_height() -> float:
	return hip_height() + torso + neck + head_half_height * 2.0 + (1.5 if hood or hair else 0.0)
