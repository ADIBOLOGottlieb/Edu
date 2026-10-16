class_name HumanController
extends Controller
## Traduit les actions de l'InputMap en intention. Clavier et boutons tactiles
## déclenchent les mêmes actions : ce contrôleur ne fait aucune différence.


func fill(intent: IntentFrame) -> void:
	intent.move_axis = Input.get_axis(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT)
	intent.jump_pressed = Input.is_action_just_pressed(InputActions.JUMP)
	intent.jump_held = Input.is_action_pressed(InputActions.JUMP)
	intent.sprint_held = Input.is_action_pressed(InputActions.SPRINT)
	intent.slide_pressed = Input.is_action_just_pressed(InputActions.SLIDE)
	intent.dodge_pressed = Input.is_action_just_pressed(InputActions.DODGE)
	intent.attack_light_pressed = Input.is_action_just_pressed(InputActions.ATTACK_LIGHT)
	intent.attack_heavy_pressed = Input.is_action_just_pressed(InputActions.ATTACK_HEAVY)
	intent.block_held = Input.is_action_pressed(InputActions.BLOCK)
	intent.use_item_pressed = Input.is_action_just_pressed(InputActions.USE_ITEM)
