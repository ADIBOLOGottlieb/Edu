class_name TouchControls
extends CanvasLayer
## Boutons tactiles Android. Chaque bouton déclenche une action de l'InputMap :
## le gameplay ne sait pas si l'entrée vient d'un doigt ou d'une touche.
## Multi-touch natif (TouchScreenButton). La disposition est recalculée quand
## la taille d'écran change et tient compte de la zone sûre (encoches).

const RADIUS: float = 58.0
const GAP: float = 22.0
const MARGIN: float = 34.0

## side : -1 = bord gauche, 1 = bord droit. col / row : 0 = le plus près du coin.
## passby : le bouton s'active quand un doigt glisse dessus (déplacement).
const LAYOUT: Array[Dictionary] = [
	{"action": InputActions.MOVE_LEFT, "label": "◀", "side": -1, "col": 0, "row": 0, "passby": true},
	{"action": InputActions.MOVE_RIGHT, "label": "▶", "side": -1, "col": 1, "row": 0, "passby": true},
	{"action": InputActions.JUMP, "label": "SAUT", "side": 1, "col": 0, "row": 0, "passby": false},
	{"action": InputActions.SLIDE, "label": "GLISSE", "side": 1, "col": 1, "row": 0, "passby": false},
	{"action": InputActions.SPRINT, "label": "SPRINT", "side": 1, "col": 0, "row": 1, "passby": false},
	{"action": InputActions.USE_ITEM, "label": "OBJET", "side": 1, "col": 1, "row": 1, "passby": false},
]

## Affiche les boutons même sans écran tactile (test sur PC avec l'option
## « Émuler le toucher depuis la souris »).
@export var force_visible: bool = false
@export_range(0.1, 1.0) var opacity: float = 0.55

var _buttons: Array[TouchScreenButton] = []
## Taille réglée par le joueur (Réglages > Taille des boutons).
var _scale: float = 1.0


func _ready() -> void:
	layer = 50
	visible = force_visible or DisplayServer.is_touchscreen_available()
	for entry: Dictionary in LAYOUT:
		_buttons.append(_create_button(entry))
	get_viewport().size_changed.connect(_relayout)
	var settings_service: SettingsServiceNode = get_node_or_null(^"/root/SettingsService") as SettingsServiceNode
	if settings_service != null:
		settings_service.changed.connect(_apply_settings)
	_apply_settings()
	_relayout()


func _create_button(entry: Dictionary) -> TouchScreenButton:
	var button: TouchScreenButton = TouchScreenButton.new()
	button.action = String(entry["action"])
	button.passby_press = bool(entry["passby"])
	button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = RADIUS
	button.shape = circle
	button.set_meta(&"layout", entry)

	var face: ButtonFace = ButtonFace.new()
	face.label = String(entry["label"])
	face.radius = RADIUS
	face.modulate.a = opacity
	button.add_child(face)
	button.pressed.connect(face.set_pressed.bind(true))
	button.released.connect(face.set_pressed.bind(false))
	add_child(button)
	return button


func _relayout() -> void:
	var area: Rect2 = _safe_rect()
	# Espacement à l'échelle des boutons : jamais de chevauchement (◀ ▶ annulés).
	var radius: float = RADIUS * _scale
	var step: float = radius * 2.0 + GAP
	for button: TouchScreenButton in _buttons:
		var entry: Dictionary = button.get_meta(&"layout")
		var side: int = int(entry["side"])
		var x_from_edge: float = MARGIN + radius + float(entry["col"]) * step
		var x: float = area.position.x + x_from_edge if side < 0 else area.end.x - x_from_edge
		var y: float = area.end.y - MARGIN - radius - float(entry["row"]) * step
		button.position = Vector2(x, y)


## Zone sûre convertie en coordonnées du canevas. Sans information de
## l'appareil (PC, mode headless), on utilise tout l'écran visible.
func _safe_rect() -> Rect2:
	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
		return visible_rect
	var to_canvas: Vector2 = visible_rect.size / window_size
	var converted: Rect2 = Rect2(Vector2(safe.position) * to_canvas, Vector2(safe.size) * to_canvas)
	var clipped: Rect2 = converted.intersection(visible_rect)
	return clipped if clipped.has_area() else visible_rect


## Rendu provisoire d'un bouton : disque et libellé.
class ButtonFace:
	extends Node2D

	var label: String = ""
	var radius: float = 58.0
	var _pressed: bool = false

	func set_pressed(value: bool) -> void:
		_pressed = value
		queue_redraw()

	func _draw() -> void:
		var fill: Color = Color(0.05, 0.05, 0.06, 0.75 if _pressed else 0.4)
		draw_circle(Vector2.ZERO, radius, fill)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.8), 3.0, true)
		var font: Font = ThemeDB.fallback_font
		var size: int = 22
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
		draw_string(
			font,
			Vector2(-text_size.x * 0.5, text_size.y * 0.3),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			size,
			Color(1, 1, 1, 0.95)
		)


## Opacité et taille réglées par le joueur (écran Réglages, SettingsService).
func _apply_settings() -> void:
	var settings_service: SettingsServiceNode = get_node_or_null(^"/root/SettingsService") as SettingsServiceNode
	if settings_service == null:
		return
	opacity = settings_service.settings.touch_opacity
	var size: float = settings_service.settings.touch_scale
	_scale = size
	for button: TouchScreenButton in _buttons:
		button.scale = Vector2(size, size)
		for child: Node in button.get_children():
			if child is CanvasItem:
				(child as CanvasItem).modulate.a = opacity
	_relayout()


## Pause (menu, choix d'objet, appli en arrière-plan) : les boutons sont relâchés,
## sinon un doigt posé pendant la pause laisserait l'action enfoncée à la reprise.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		for button: TouchScreenButton in _buttons:
			button.visible = false
	elif what == NOTIFICATION_UNPAUSED:
		for button: TouchScreenButton in _buttons:
			button.visible = true
