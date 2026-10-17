class_name StealthZone
extends Area2D
## Zone d'ombre (renfoncement sombre, dessous d'un grand auvent) : un coureur
## caché dedans échappe à la vue des poursuivants, qui fouillent alors sa dernière
## position vue (PursuerAIController, ARCHITECTURE §5.2).
##
## Repère : origine au sol, au milieu ; la zone s'étend de size.y vers le haut.
## contains() est un test géométrique (centre du corps dans le rectangle) : il ne
## dépend pas de l'ordre des ticks de physique. L'Area2D (masque PLAYER) émet
## aussi body_entered / body_exited pour qui veut les écouter.
## Ombre discrète dessinée par le code, plus dense au centre.

const GROUP: StringName = &"stealth_zones"
## Hauteur du centre d'un RunnerBody au-dessus des pieds (capsule de 72 px).
const BODY_CENTER_Y: float = -36.0
## Ombre : opacité au cœur et largeur du fondu sur les bords (px).
const SHADOW_ALPHA: float = 0.42
const SHADOW_FEATHER: float = 28.0
const SHADOW_LAYERS: int = 6

@export var size: Vector2 = Vector2(220.0, 150.0)
@export var shadow_color: Color = Color(0.02, 0.02, 0.05)


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = CollisionLayers.PLAYER
	monitorable = false
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -size.y * 0.5)
	add_child(collision)
	queue_redraw()


## Rectangle de la zone dans le repère du monde.
func world_rect() -> Rect2:
	return Rect2(global_position + Vector2(-size.x * 0.5, -size.y), size)


## Vrai si le centre du corps (pieds + BODY_CENTER_Y) est dans la zone.
func contains(body: Node2D) -> bool:
	if body == null or not is_inside_tree():
		return false
	return world_rect().has_point(body.global_position + Vector2(0.0, BODY_CENTER_Y))


func _draw() -> void:
	# Rectangles emboîtés de plus en plus petits : un fondu doux vers les bords.
	var rect: Rect2 = Rect2(Vector2(-size.x * 0.5, -size.y), size)
	var step: float = SHADOW_FEATHER / float(SHADOW_LAYERS)
	for i: int in SHADOW_LAYERS:
		var inner: Rect2 = rect.grow(-step * float(i))
		if inner.size.x <= 0.0 or inner.size.y <= 0.0:
			break
		draw_rect(inner, Color(shadow_color, SHADOW_ALPHA / float(SHADOW_LAYERS)))
