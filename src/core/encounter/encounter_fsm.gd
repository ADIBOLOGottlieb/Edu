class_name EncounterFSM
extends RefCounted
## Machine à états d'une poursuite (une par parcours), docs/ARCHITECTURE.md §5.1.
## Toute transition absente de la table est refusée et journalisée.
##
## Sans combat (décision de l'utilisateur) : COMBAT est le corps-à-corps où le
## vigile tient le coureur ; la jauge de capture s'y remplit, et s'arracher à sa
## prise ouvre la fenêtre de fuite.

signal state_changed(from: State, to: State, reason: StringName)

enum State {
	RUNNING,
	PURSUIT,
	COMBAT,
	ESCAPE_WINDOW,
	CAPTURED,
	MISSION_FAILED,
	MISSION_COMPLETED,
}

## Transitions autorisées (table §5.1).
const TABLE: Dictionary[State, Array] = {
	State.RUNNING: [State.PURSUIT, State.MISSION_FAILED, State.MISSION_COMPLETED],
	State.PURSUIT: [State.RUNNING, State.COMBAT, State.CAPTURED, State.MISSION_COMPLETED],
	State.COMBAT: [State.ESCAPE_WINDOW, State.CAPTURED],
	State.ESCAPE_WINDOW: [State.RUNNING, State.PURSUIT, State.COMBAT, State.CAPTURED],
	State.CAPTURED: [State.COMBAT, State.MISSION_FAILED],
	State.MISSION_FAILED: [],
	State.MISSION_COMPLETED: [],
}

var current: State = State.RUNNING
## Transitions refusées : « DE→VERS (raison) », pour le débogage et les tests.
var refused: Array[String] = []


static func name_of(state: State) -> StringName:
	return StringName(String(State.keys()[state]).to_lower())


static func is_allowed(from: State, to: State) -> bool:
	return TABLE[from].has(to)


func is_terminal() -> bool:
	return TABLE[current].is_empty()


## Retourne vrai si la transition a eu lieu ; sinon elle est journalisée.
func request(to: State, reason: StringName = &"") -> bool:
	if to == current:
		return false
	if not is_allowed(current, to):
		var entry: String = "%s→%s (%s)" % [name_of(current), name_of(to), reason]
		refused.append(entry)
		push_warning("EncounterFSM : transition refusée " + entry)
		return false
	var from: State = current
	current = to
	state_changed.emit(from, to, reason)
	return true
