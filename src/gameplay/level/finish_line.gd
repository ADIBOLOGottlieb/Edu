class_name FinishLine
extends Area2D
## Ligne d'arrivée d'un parcours. Émet crossed quand un corps (couche joueur)
## la traverse. Visuel provisoire : bande verticale de couleur signalétique.

signal crossed(body: Node2D)

const ACCENT: Color = Color(0.91, 0.64, 0.24)
const PLAYER_LAYER: int = 2

@export var height: float = 420.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitorable = false
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(24.0, height)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -height * 0.5)
	add_child(collision)
	var band: Polygon2D = Polygon2D.new()
	band.color = ACCENT
	band.polygon = PackedVector2Array([
		Vector2(-4, -height), Vector2(4, -height), Vector2(4, 0), Vector2(-4, 0)
	])
	add_child(band)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	crossed.emit(body)
