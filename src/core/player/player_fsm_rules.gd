class_name PlayerFsmRules
extends RefCounted
## Table explicite des transitions autorisées. Toute paire absente est refusée.
##
## Jalon M1 : locomotion de base (Idle, Run, Sprint, Jump, Fall, Landing, Slide).
## Chaque jalon suivant ajoute ses propres lignes ici, avec les tests associés.

const TRANSITIONS: Dictionary[int, Array] = {
	PlayerState.State.IDLE:
	[
		PlayerState.State.RUN,
		PlayerState.State.SPRINT,
		PlayerState.State.JUMP,
		PlayerState.State.FALL,
	],
	PlayerState.State.RUN:
	[
		PlayerState.State.IDLE,
		PlayerState.State.SPRINT,
		PlayerState.State.JUMP,
		PlayerState.State.FALL,
		PlayerState.State.SLIDE,
	],
	PlayerState.State.SPRINT:
	[
		PlayerState.State.IDLE,
		PlayerState.State.RUN,
		PlayerState.State.JUMP,
		PlayerState.State.FALL,
		PlayerState.State.SLIDE,
	],
	PlayerState.State.JUMP:
	[
		PlayerState.State.FALL,
		PlayerState.State.LANDING,
	],
	PlayerState.State.FALL:
	[
		PlayerState.State.LANDING,
	],
	PlayerState.State.LANDING:
	[
		PlayerState.State.IDLE,
		PlayerState.State.RUN,
		PlayerState.State.SPRINT,
		PlayerState.State.JUMP,
		PlayerState.State.FALL,
		PlayerState.State.SLIDE,
	],
	PlayerState.State.SLIDE:
	[
		PlayerState.State.IDLE,
		PlayerState.State.RUN,
		PlayerState.State.SPRINT,
		PlayerState.State.JUMP,
		PlayerState.State.FALL,
	],
}


static func is_allowed(from: PlayerState.State, to: PlayerState.State) -> bool:
	if not TRANSITIONS.has(from):
		return false
	return TRANSITIONS[from].has(to)
