class_name ItemPickup
extends Area2D
## Caisse d'équipement posée dans un tronçon. Émet touched quand un corps de la
## couche joueur la touche ; EquipmentRuntime décide (ramassé, ou laissé au sol
## si l'inventaire est plein).

signal touched(pickup: ItemPickup, body: Node2D)

const SIZE: Vector2 = Vector2(34.0, 30.0)
const INK: Color = Color(0.04, 0.04, 0.05)
const ACCENT: Color = Color(0.95, 0.70, 0.30)
## Flottement vertical (px) et vitesse.
const BOB: float = 4.0
const BOB_SPEED: float = 3.0

var item_id: StringName = &""
var label: String = ""

var _time: float = 0.0
var _art: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = CollisionLayers.PLAYER
	monitorable = false
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = SIZE + Vector2(10.0, 10.0)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(func(body: Node2D) -> void: touched.emit(self, body))
	_art = Node2D.new()
	_art.draw.connect(_draw_crate)
	add_child(_art)


func _process(delta: float) -> void:
	_time += delta
	_art.position.y = sin(_time * BOB_SPEED) * BOB


func _draw_crate() -> void:
	var rect: Rect2 = Rect2(-SIZE * 0.5, SIZE)
	_art.draw_rect(rect, INK)
	_art.draw_rect(rect.grow(-3.0), ACCENT, false, 2.0)
	_art.draw_line(rect.position + Vector2(3.0, 3.0), rect.end - Vector2(3.0, 3.0), ACCENT, 2.0)
	_art.draw_line(Vector2(rect.position.x + 3.0, rect.end.y - 3.0), Vector2(rect.end.x - 3.0, rect.position.y + 3.0), ACCENT, 2.0)
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	_art.draw_string_outline(font, Vector2(-text_size.x * 0.5, rect.position.y - 8.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, INK)
	_art.draw_string(font, Vector2(-text_size.x * 0.5, rect.position.y - 8.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACCENT)
