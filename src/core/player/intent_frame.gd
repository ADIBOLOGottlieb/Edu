class_name IntentFrame
extends RefCounted
## Ce que l'acteur veut faire pendant ce tick. Rempli par un Controller
## (joueur humain, IA ou script de test), lu par RunnerBody.
## Le corps ne sait jamais qui le pilote.

## -1 (gauche) à 1 (droite).
var move_axis: float = 0.0
## *_pressed : vrai uniquement le tick où l'entrée commence.
var jump_pressed: bool = false
var jump_held: bool = false
var sprint_held: bool = false
var slide_pressed: bool = false
# Champs réservés aux jalons suivants (lus à partir de M2 / M4 / M8).
var dodge_pressed: bool = false
var attack_light_pressed: bool = false
var attack_heavy_pressed: bool = false
var block_held: bool = false
var use_item_pressed: bool = false


func clear() -> void:
	move_axis = 0.0
	jump_pressed = false
	jump_held = false
	sprint_held = false
	slide_pressed = false
	dodge_pressed = false
	attack_light_pressed = false
	attack_heavy_pressed = false
	block_held = false
	use_item_pressed = false
