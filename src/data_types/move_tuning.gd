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

@export_group("Roulade")
## Déclenchée par Glisse au moment d'une réception dure : annule l'immobilisation.
@export var roll_duration: float = 0.4
@export var roll_decel: float = 300.0

@export_group("Double saut")
## Utilisable une fois par phase aérienne, seulement si la capacité est débloquée.
@export var double_jump_velocity: float = 620.0

@export_group("Franchissement")
## Hauteurs (px) d'obstacle franchies automatiquement en courant.
@export var vault_min_height: float = 12.0
@export var vault_max_height: float = 50.0
## Distance de détection devant le corps : assez longue pour décoller avant l'obstacle.
@export var vault_reach: float = 60.0
@export var vault_min_speed: float = 200.0
## Marge visée au-dessus de l'obstacle par l'impulsion verticale.
@export var vault_clearance: float = 16.0
@export var vault_min_time: float = 0.08
## Au-delà, un franchissement encore en l'air devient une chute.
@export var vault_max_time: float = 0.45

@export_group("Mur")
## Portée du rayon de détection de mur au-delà du corps.
@export var wall_probe: float = 16.0
@export var wall_run_min_speed: float = 260.0
@export var wall_run_duration: float = 0.35
## Part de la vitesse horizontale convertie en montée.
@export var wall_run_conversion: float = 0.9
@export var wall_run_min_up: float = 420.0
@export var wall_run_gravity: float = 1200.0
## Poussée horizontale vers le mur pour rester en contact.
@export var wall_stick_speed: float = 120.0
@export var wall_climb_speed: float = 110.0
## Temps d'escalade disponible par phase aérienne (rechargé au sol ou à un rebord).
@export var wall_climb_max_time: float = 1.2
@export var wall_jump_velocity: float = 650.0
@export var wall_jump_push: float = 360.0
## Après un saut mural, le contrôle aérien est ignoré ce temps-là.
@export var wall_jump_control_lock: float = 0.18

@export_group("Figures")
## Tic-tac : appui du pied sur un mur bas et passage par-dessus d'un seul élan.
@export var tic_tac_min_speed: float = 300.0
## Hauteur max (au-dessus des pieds) d'un mur franchi en tic-tac ; au-delà : course murale.
@export var tic_tac_max_height: float = 150.0
@export var tic_tac_clearance: float = 18.0
## Kong vault : plongeon sur l'obstacle, plus bas et plus rapide, à pleine vitesse.
@export var kong_min_speed: float = 440.0
@export var kong_min_height: float = 30.0
@export var kong_boost: float = 1.1
@export var kong_clearance: float = 8.0
## Lazy vault : franchissement lent, en dessous de cette vitesse.
@export var lazy_vault_max_speed: float = 380.0
## Salto avant : saut en sprint au bord du vide.
@export var front_flip_min_speed: float = 440.0
## Cat leap : arrivée accroché au rebord avec cet élan horizontal minimal.
@export var cat_leap_min_speed: float = 200.0

@export_group("Rebord")
## Distance verticale entre le haut du rebord et les pieds en suspension.
@export var ledge_hang_offset: float = 76.0
## Durée minimale de suspension avant de pouvoir se hisser ou lâcher.
@export var ledge_min_hang: float = 0.12
@export var ledge_climb_velocity: float = 720.0
@export var ledge_climb_push: float = 200.0
## Après avoir quitté un rebord, impossible de s'y raccrocher pendant ce temps.
@export var ledge_regrab_cooldown: float = 0.3
