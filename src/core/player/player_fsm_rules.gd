class_name PlayerFsmRules
extends RefCounted
## Table explicite des transitions autorisées. Toute paire absente est refusée.
##
## M1 : Idle, Run, Sprint, Jump, Fall, Landing, Slide.
## M2 : DoubleJump, Roll, Vault, WallRun, WallClimb, LedgeHang.
## M3b : tic-tac (VAULT depuis les airs).
## Chaque jalon suivant ajoute ses propres lignes ici, avec les tests associés.
## La table dit ce qui est *possible* ; les conditions (capacité débloquée,
## capteurs, minuteries) sont vérifiées par MovementDecider.

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
		PlayerState.State.VAULT,
		PlayerState.State.WALL_RUN,
	],
	PlayerState.State.SPRINT:
	[
		PlayerState.State.IDLE,
		PlayerState.State.RUN,
		PlayerState.State.JUMP,
		PlayerState.State.FALL,
		PlayerState.State.SLIDE,
		PlayerState.State.VAULT,
		PlayerState.State.WALL_RUN,
	],
	PlayerState.State.JUMP:
	[
		PlayerState.State.FALL,
		PlayerState.State.LANDING,
		PlayerState.State.DOUBLE_JUMP,
		PlayerState.State.WALL_RUN,
		PlayerState.State.WALL_CLIMB,
		PlayerState.State.LEDGE_HANG,
		PlayerState.State.VAULT,
	],
	PlayerState.State.DOUBLE_JUMP:
	[
		PlayerState.State.FALL,
		PlayerState.State.LANDING,
		PlayerState.State.WALL_CLIMB,
		PlayerState.State.LEDGE_HANG,
		PlayerState.State.VAULT,
	],
	PlayerState.State.FALL:
	[
		PlayerState.State.LANDING,
		PlayerState.State.DOUBLE_JUMP,
		PlayerState.State.WALL_CLIMB,
		PlayerState.State.LEDGE_HANG,
		PlayerState.State.VAULT,
	],
	PlayerState.State.LANDING:
	[
		PlayerState.State.IDLE,
		PlayerState.State.RUN,
		PlayerState.State.SPRINT,
		PlayerState.State.JUMP,
		PlayerState.State.FALL,
		PlayerState.State.SLIDE,
		PlayerState.State.ROLL,
	],
	PlayerState.State.SLIDE:
	[
		PlayerState.State.IDLE,
		PlayerState.State.RUN,
		PlayerState.State.SPRINT,
		PlayerState.State.JUMP,
		PlayerState.State.FALL,
	],
	PlayerState.State.ROLL:
	[
		PlayerState.State.IDLE,
		PlayerState.State.RUN,
		PlayerState.State.SPRINT,
		PlayerState.State.JUMP,
		PlayerState.State.FALL,
	],
	PlayerState.State.VAULT:
	[
		PlayerState.State.IDLE,
		PlayerState.State.RUN,
		PlayerState.State.SPRINT,
		PlayerState.State.FALL,
	],
	PlayerState.State.WALL_RUN:
	[
		PlayerState.State.WALL_CLIMB,
		PlayerState.State.FALL,
		PlayerState.State.JUMP,
		PlayerState.State.LEDGE_HANG,
	],
	PlayerState.State.WALL_CLIMB:
	[
		PlayerState.State.FALL,
		PlayerState.State.JUMP,
		PlayerState.State.LEDGE_HANG,
		PlayerState.State.IDLE,
		PlayerState.State.RUN,
		PlayerState.State.SPRINT,
	],
	PlayerState.State.LEDGE_HANG:
	[
		PlayerState.State.JUMP,
		PlayerState.State.FALL,
	],
}


static func is_allowed(from: PlayerState.State, to: PlayerState.State) -> bool:
	if not TRANSITIONS.has(from):
		return false
	return TRANSITIONS[from].has(to)
