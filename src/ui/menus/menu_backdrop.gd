class_name MenuBackdrop
extends Node2D
## Fond animé des menus : le décor de la ville (CityBackdrop, mêmes plans de
## parallaxe qu'en course) et une caméra qui dérive lentement vers la droite.
## Les menus se dessinent par-dessus dans un CanvasLayer (la caméra ne les
## déplace pas).

## Caméra de départ (celle du début d'un niveau, cf. CityBackdrop.reference_camera).
const START: Vector2 = Vector2(220.0, -120.0)

@export var theme: CityTheme
## Vitesse de dérive de la caméra (px/s) ; le plan lointain défile ~8× moins vite.
@export var drift_speed: float = 46.0
## Décalage horizontal de départ (choisit le monument visible à l'ouverture).
@export var start_offset: float = 0.0
## Décalage vertical de la caméra (négatif = vue plus haute, plus de ciel).
@export var vertical_offset: float = 0.0

var backdrop: CityBackdrop
var camera: Camera2D


func _ready() -> void:
	backdrop = CityBackdrop.new()
	backdrop.name = "City"
	backdrop.theme = theme
	add_child(backdrop)
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = START + Vector2(start_offset, vertical_offset)
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	camera.position.x += drift_speed * delta
