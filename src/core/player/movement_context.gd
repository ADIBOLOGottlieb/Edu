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
