class_name MovementContext
extends RefCounted
## Instantané de l'état physique d'un acteur pour un tick. Rempli par
## RunnerBody avant la décision, construit à la main dans les tests.

var on_floor: bool = true
var velocity: Vector2 = Vector2.ZERO
## Secondes passées dans l'état courant.
var time_in_state: float = 0.0
## Faux si un plafond empêche de se relever (fin de glissade).
var can_stand: bool = true
## Temps restant pendant lequel un saut reste possible après avoir quitté le sol.
var coyote_left: float = 0.0
## Temps restant pendant lequel un appui sur Saut reste mémorisé.
var jump_buffer_left: float = 0.0
## Temps restant pendant lequel un appui sur Glisse reste mémorisé.
var slide_buffer_left: float = 0.0
## Vitesse verticale au moment du dernier contact avec le sol (px/s, positive).
var impact_speed: float = 0.0
## 1 = regarde à droite, -1 = à gauche.
var facing: int = 1

# Capteurs de parkour (remplis par ParkourSensors).
## Mur vertical à hauteur de poitrine, devant.
var wall_ahead: bool = false
## Hauteur (px) de l'obstacle bas devant les pieds, 0 s'il n'y en a pas.
var obstacle_height: float = 0.0
## Rebord saisissable à portée de mains.
var ledge_available: bool = false

# Ressources aériennes, rechargées au sol.
var can_double_jump: bool = false
var can_wall_run: bool = true
## Secondes d'escalade restantes.
var wall_climb_left: float = 0.0
var ledge_cooldown_left: float = 0.0
## Temps restant pendant lequel le contrôle aérien est ignoré (après un saut mural).
var air_control_lock_left: float = 0.0
