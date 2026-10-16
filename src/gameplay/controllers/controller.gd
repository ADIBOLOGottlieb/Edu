class_name Controller
extends Node
## Source d'intentions d'un RunnerBody (enfant direct du corps).
## Sous-classes : HumanController (clavier / tactile), ScriptedController
## (tests, cinématiques) et, au jalon M5, PursuerAIController.


## Appelé une fois par tick de physique avec un IntentFrame déjà remis à zéro.
func fill(_intent: IntentFrame) -> void:
	pass
