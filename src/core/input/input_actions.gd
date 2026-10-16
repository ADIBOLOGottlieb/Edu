class_name InputActions
extends RefCounted
## Actions de jeu et leurs touches clavier par défaut (développement / PC).
##
## Le gameplay ne lit jamais une touche directement : il lit ces actions.
## Les boutons tactiles Android (jalon M1) déclencheront les mêmes actions,
## ce qui rend le portage PC sans réécriture.
##
## Les actions sont enregistrées par code plutôt que dans project.godot
## (voir docs/DECISIONS.md, ADR-007).

const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const JUMP: StringName = &"jump"
const SLIDE: StringName = &"slide"
const SPRINT: StringName = &"sprint"
const ATTACK_LIGHT: StringName = &"attack_light"
const ATTACK_HEAVY: StringName = &"attack_heavy"
const BLOCK: StringName = &"block"
const DODGE: StringName = &"dodge"
const USE_ITEM: StringName = &"use_item"
const NEXT_ITEM: StringName = &"next_item"
const PAUSE: StringName = &"pause"

const DEADZONE: float = 0.2

## Touches physiques (disposition QWERTY ; AZERTY obtient les mêmes positions).
const DEFAULT_KEYS: Dictionary[StringName, Array] = {
	MOVE_LEFT: [KEY_A, KEY_LEFT],
	MOVE_RIGHT: [KEY_D, KEY_RIGHT],
	JUMP: [KEY_SPACE, KEY_W, KEY_UP],
	SLIDE: [KEY_S, KEY_DOWN],
	SPRINT: [KEY_SHIFT],
	ATTACK_LIGHT: [KEY_J],
	ATTACK_HEAVY: [KEY_K],
	BLOCK: [KEY_L],
	DODGE: [KEY_Q],
	USE_ITEM: [KEY_E],
	NEXT_ITEM: [KEY_TAB],
	PAUSE: [KEY_ESCAPE, KEY_P],
}


static func all() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(DEFAULT_KEYS.keys())
	return result


## Ajoute à l'InputMap les actions absentes. N'écrase jamais une action déjà
## définie (réglage du joueur ou project.godot). Retourne le nombre d'actions
## ajoutées, ce qui rend l'appel idempotent et vérifiable.
static func register_defaults() -> int:
	var added: int = 0
	for action: StringName in DEFAULT_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEADZONE)
		for keycode: int in DEFAULT_KEYS[action]:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, event)
		added += 1
	return added
