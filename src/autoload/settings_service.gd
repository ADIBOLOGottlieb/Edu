class_name SettingsServiceNode
extends Node
## Autoload « SettingsService » — volumes, vibrations, opacité et taille des
## commandes tactiles, qualité, langue (GameSettings), persistés dans la section
## « settings » de la sauvegarde.

signal changed()

var settings: GameSettings = GameSettings.new()

var _fps_label: Label
var _fps_refresh: float = 0.0


func _ready() -> void:
	reload()


func reload() -> void:
	var save: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	if save != null:
		var saved: Dictionary = save.section("settings")
		settings.from_dict(saved)
		# Première partie sur téléphone : qualité moyenne (rendu 3D plus léger).
		if saved.is_empty() and OS.has_feature("mobile"):
			settings.quality = &"medium"
	apply()


## Applique aux bus audio existants (Master, Music, SFX).
func apply() -> void:
	_set_bus("Music", settings.music_volume)
	_set_bus("SFX", settings.sfx_volume)
	_update_fps_overlay()
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


## Compteur d'images par seconde (réglage « Afficher les FPS »), au-dessus de tout.
func _update_fps_overlay() -> void:
	if settings.show_fps and _fps_label == null:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 120
		add_child(layer)
		_fps_label = Label.new()
		_fps_label.position = Vector2(12.0, 6.0)
		_fps_label.add_theme_font_size_override(&"font_size", 22)
		_fps_label.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
		_fps_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0))
		_fps_label.add_theme_constant_override(&"outline_size", 6)
		layer.add_child(_fps_label)
	if _fps_label != null:
		_fps_label.visible = settings.show_fps


func _process(delta: float) -> void:
	if _fps_label == null or not _fps_label.visible:
		return
	_fps_refresh -= delta
	if _fps_refresh <= 0.0:
		_fps_refresh = 0.5
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
