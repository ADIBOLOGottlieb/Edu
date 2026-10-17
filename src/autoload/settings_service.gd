class_name SettingsServiceNode
extends Node
## Autoload « SettingsService » — volumes, vibrations, opacité et taille des
## commandes tactiles, qualité, langue (GameSettings), persistés dans la section
## « settings » de la sauvegarde.

signal changed()

var settings: GameSettings = GameSettings.new()


func _ready() -> void:
	reload()


func reload() -> void:
	var save: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	if save != null:
		settings.from_dict(save.section("settings"))
	apply()


## Applique aux bus audio existants (Master, Music, SFX).
func apply() -> void:
	_set_bus("Music", settings.music_volume)
	_set_bus("SFX", settings.sfx_volume)
	changed.emit()


## Applique puis enregistre (appelé par l'écran Réglages).
func save() -> void:
	apply()
	var save_service: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	if save_service != null:
		save_service.set_section("settings", settings.to_dict())


func _set_bus(bus_name: String, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, GameSettings.to_db(volume))
