extends Node
## InputService — garantit que les actions de jeu existent dans l'InputMap
## avant que la première scène ne lise les entrées.
## Le remappage par le joueur (via SettingsService) viendra au jalon M7.


func _enter_tree() -> void:
	InputActions.register_defaults()
