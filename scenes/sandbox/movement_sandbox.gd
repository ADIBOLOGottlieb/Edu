extends Node2D
## Bac à sable du jalon M1 : sol, marche, tunnel bas (glissade obligatoire),
## plateformes (réception dure en redescendant), fosse peu profonde.
## La géométrie est construite par code à partir de rectangles pour rester
## lisible et facile à modifier.

const BACKGROUND: Color = Color(0.93, 0.93, 0.91)
const INK: Color = Color(0.04, 0.04, 0.05)
const SKYLINE: Color = Color(0.78, 0.78, 0.77)

## Rectangles de collision du niveau : position = coin haut-gauche, y = 0 = sol.
const BLOCKS: Array[Rect2] = [
	Rect2(-440, -600, 40, 800),  # mur de gauche
	Rect2(-400, 0, 2500, 200),  # sol, partie 1
	Rect2(500, -40, 120, 40),  # marche
	Rect2(900, -400, 360, 352),  # plafond du tunnel : 48 px de hauteur libre
	Rect2(1560, -110, 140, 16),  # plateforme basse
	Rect2(1780, -230, 160, 16),  # plateforme haute : chute ≈ 230 px → réception dure
	Rect2(2100, 100, 160, 100),  # fond de la fosse (100 px de profondeur)
	Rect2(2260, 0, 2000, 200),  # sol, partie 2
]

@onready var _player: RunnerBody = $Player
@onready var _overlay: MovementDebugOverlay = $DebugOverlay


func _ready() -> void:
	_add_background()
	_add_skyline()
	for rect: Rect2 in BLOCKS:
		add_child(_make_block(rect))
	_overlay.body = _player
	_attach_camera()


func _make_block(rect: Rect2) -> StaticBody2D:
	var block: StaticBody2D = StaticBody2D.new()
	block.position = rect.position
	block.collision_layer = 1
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.size * 0.5
	block.add_child(collision)
	var visual: Polygon2D = Polygon2D.new()
	visual.color = INK
	visual.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)
	])
	block.add_child(visual)
	return block


func _add_background() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = -10
	var fill: ColorRect = ColorRect.new()
	fill.color = BACKGROUND
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fill)
	add_child(layer)


## Lignes d'immeubles en aplats sur un plan de parallaxe (générées, à graine fixe).
func _add_skyline() -> void:
	var parallax: Parallax2D = Parallax2D.new()
	# Défilement vertical à 1 : la base des immeubles reste alignée sur l'horizon.
	parallax.scroll_scale = Vector2(0.35, 1.0)
	parallax.z_index = -5
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var x: float = -1200.0
	while x < 5000.0:
		var width: float = rng.randf_range(70.0, 190.0)
		var height: float = rng.randf_range(140.0, 420.0)
		var building: Polygon2D = Polygon2D.new()
		building.color = SKYLINE
		building.polygon = PackedVector2Array([
			Vector2(x, 0), Vector2(x, -height), Vector2(x + width, -height), Vector2(x + width, 0)
		])
		parallax.add_child(building)
		x += width + rng.randf_range(4.0, 40.0)
	add_child(parallax)


func _attach_camera() -> void:
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(160, -120)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	_player.add_child(camera)
	camera.make_current()
