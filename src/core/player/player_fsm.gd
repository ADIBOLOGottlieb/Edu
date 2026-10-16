class_name PlayerFSM
extends RefCounted
## Machine à états du personnage : un seul état actif à la fois, ce qui rend
## impossible l'exécution simultanée de deux animations incompatibles.
##
## Une requête vers B depuis A est acceptée si :
##   - la paire (A → B) figure dans PlayerFsmRules, et
##   - B est au moins aussi prioritaire que A, ou A a signalé qu'il peut céder
##     la place (exit_allowed, recalculé à chaque tick par le propriétaire).

signal state_changed(from: PlayerState.State, to: PlayerState.State)

var current: PlayerState.State = PlayerState.State.IDLE
## Nombre de ticks de physique passés dans l'état courant.
var ticks_in_state: int = 0
## Vrai quand l'état courant a terminé son action et accepte d'être remplacé
## par un état moins prioritaire. Remis à faux à chaque changement d'état.
var exit_allowed: bool = false


func _init(initial: PlayerState.State = PlayerState.State.IDLE) -> void:
	current = initial


func can_transition(to: PlayerState.State) -> bool:
	if to == current:
		return false
	if not PlayerFsmRules.is_allowed(current, to):
		return false
	if PlayerState.priority_of(to) < PlayerState.priority_of(current) and not exit_allowed:
		return false
	return true


## Retourne vrai si la transition a eu lieu.
func request(to: PlayerState.State) -> bool:
	if not can_transition(to):
		return false
	var from: PlayerState.State = current
	current = to
	ticks_in_state = 0
	exit_allowed = false
	state_changed.emit(from, to)
	return true


func tick() -> void:
	ticks_in_state += 1
