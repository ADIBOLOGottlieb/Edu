class_name MoveTuning
extends Resource
## Réglages physiques d'un acteur. Les valeurs vivent dans data/tuning/*.tres :
## ajuster le ressenti ne demande aucune modification de code.
## Unités : pixels, secondes. Le personnage debout mesure environ 72 px.

@export_group("Sol")
@export var run_speed: float = 320.0
@export var sprint_speed: float = 480.0
@export var ground_accel: float = 2400.0
@export var ground_decel: float = 2800.0
## Décélération avant un demi-tour en sprint (le sprint ne se retourne pas sur place).
@export var sprint_turn_decel: float = 1800.0

@export_group("Air")
@export var air_accel: float = 1400.0
@export var air_decel: float = 300.0
@export var gravity_up: float = 1800.0
@export var gravity_down: float = 2600.0
@export var max_fall_speed: float = 1100.0
## Hauteur d'un saut maintenu ≈ jump_velocity² / (2 × gravity_up) = 144 px.
@export var jump_velocity: float = 720.0
@export var coyote_time: float = 0.08
@export var jump_buffer_time: float = 0.10

@export_group("Réception")
## Vitesse de chute (px/s) à partir de laquelle la réception est dure.
@export var landing_hard_speed: float = 900.0
@export var landing_soft_duration: float = 0.06
@export var landing_hard_duration: float = 0.22
## Fraction de la vitesse de course autorisée pendant la réception.
@export var landing_speed_factor: float = 0.5

@export_group("Glissade")
@export var slide_min_speed: float = 200.0
## Un appui sur Glisse reste mémorisé ce temps-là (ex. pendant une réception).
@export var slide_buffer_time: float = 0.12
@export var slide_duration: float = 0.55
@export var slide_boost: float = 1.15
@export var slide_friction: float = 500.0
## Vitesse conservée sous un plafond bas, pour ne jamais rester bloqué.
@export var slide_crawl_speed: float = 120.0
