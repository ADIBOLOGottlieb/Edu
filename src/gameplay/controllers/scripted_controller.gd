class_name ScriptedController
extends Controller
## Pilote déterministe pour les tests et les cinématiques.
## Les valeurs continues sont posées par l'appelant ; les appuis (press_*)
## ne durent qu'un seul tick, comme une vraie touche.

var move_axis: float = 0.0
var jump_held: bool = false
var sprint_held: bool = false
## Optionnel : appelé après les valeurs de base, ex. « glisser quand x > 100 ».
## Signature : func(intent: IntentFrame) -> void
var policy: Callable = Callable()

var _queued_jump: bool = false
var _queued_slide: bool = false


func press_jump() -> void:
	_queued_jump = true


func press_slide() -> void:
	_queued_slide = true


func fill(intent: IntentFrame) -> void:
	intent.move_axis = move_axis
	intent.jump_pressed = _queued_jump
	intent.jump_held = jump_held or _queued_jump
	intent.sprint_held = sprint_held
	intent.slide_pressed = _queued_slide
	_queued_jump = false
	_queued_slide = false
	if policy.is_valid():
		policy.call(intent)
