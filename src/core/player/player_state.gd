class_name PlayerState
extends RefCounted
## États du personnage, catégories et priorités (docs/ARCHITECTURE.md §3.2).
##
## Tous les états sont déclarés dès maintenant pour que les valeurs de l'enum
## restent stables entre les jalons. Seuls ceux qui ont des lignes dans
## PlayerFsmRules sont atteignables.

enum State {
	IDLE,
	RUN,
	SPRINT,
	JUMP,
	DOUBLE_JUMP,
	FALL,
	LANDING,
	SLIDE,
	ROLL,
	VAULT,
	WALL_RUN,
	WALL_CLIMB,
	LEDGE_HANG,
	DODGE,
	ATTACK,
	BLOCK,
	HIT,
	STAGGER,
	ESCAPE,
	CAPTURE,
	DEATH,
	VICTORY,
}

enum Category { GROUND, AIR, TRAVERSAL, COMBAT, REACTION, ESCAPE, SYSTEM }


static func category_of(state: State) -> Category:
	match state:
		State.IDLE, State.RUN, State.SPRINT:
			return Category.GROUND
		State.JUMP, State.DOUBLE_JUMP, State.FALL, State.LANDING:
			return Category.AIR
		State.SLIDE, State.ROLL, State.VAULT, State.WALL_RUN, State.WALL_CLIMB, State.LEDGE_HANG:
			return Category.TRAVERSAL
		State.DODGE, State.ATTACK, State.BLOCK:
			return Category.COMBAT
		State.HIT, State.STAGGER:
			return Category.REACTION
		State.ESCAPE:
			return Category.ESCAPE
	return Category.SYSTEM


## Plus la valeur est haute, plus l'état est difficile à interrompre.
static func priority_of(state: State) -> int:
	match category_of(state):
		Category.GROUND:
			return 0
		Category.AIR:
			return 20
		Category.TRAVERSAL:
			return 40
		Category.COMBAT:
			return 60
		Category.REACTION:
			return 80
		Category.ESCAPE:
			return 90
	return 100


## Nom en minuscules, utilisé comme clé dans les AnimationSet (&"idle", &"wall_run"…).
static func name_of(state: State) -> StringName:
	return StringName(String(State.keys()[state]).to_lower())
