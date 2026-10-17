class_name CityTheme
extends Resource
## Ambiance visuelle d'une ville : couleurs du ciel et des plans de décor,
## style des objets urbains du premier plan et monument de la ligne d'horizon.
## Partagé par PropPainter (premier plan) et CityBackdrop (arrière-plans).

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Ciel")
@export var sky_top: Color = Color(0.55, 0.68, 0.80)
@export var sky_horizon: Color = Color(0.96, 0.82, 0.62)
## Soleil (position relative à l'écran, 0..1) ; rayon nul = pas de soleil.
@export var sun_position: Vector2 = Vector2(0.72, 0.62)
@export var sun_radius: float = 0.0
@export var sun_color: Color = Color(1.0, 0.9, 0.7)

@export_group("Plans de décor (du plus lointain au plus proche)")
## Ligne d'horizon lointaine, avec le monument.
@export var far_color: Color = Color(0.70, 0.66, 0.66)
## Quartiers intermédiaires (immeubles, palmiers).
@export var mid_color: Color = Color(0.45, 0.42, 0.44)
## Rue proche, juste derrière les toits de course.
@export var near_color: Color = Color(0.24, 0.23, 0.26)

@export_group("Premier plan")
## Couleur des objets sur lesquels on court (silhouette pure, comme le coureur).
@export var ink: Color = Color(0.04, 0.04, 0.05)
## Fenêtres éclairées, enseignes : petites touches lisibles sur l'encre.
@export var accent: Color = Color(0.95, 0.70, 0.30)
## Style des objets urbains (&"lome", &"modern"…) : choisit les variantes dessinées.
@export var prop_style: StringName = &"modern"
## Toits de tôle ondulée, palmiers, paraboles, câbles électriques.
@export var tin_roofs: bool = false
@export var palm_trees: bool = false
@export var satellite_dishes: bool = true
@export var power_lines: bool = false

@export_group("Horizon")
## Monument dessiné sur le plan lointain (&"" = aucun). Évocation stylisée originale.
@export var monument: StringName = &""
## Autres repères de la ville (&"cathedral", &"hotel_tower", &"lighthouse"…).
@export var landmarks: Array[StringName] = []
@export var seed_value: int = 7
