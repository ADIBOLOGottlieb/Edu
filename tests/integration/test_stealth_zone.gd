extends GutTest
## Zone d'ombre : appartenance au groupe, test géométrique contains(), détection du
## vrai joueur par l'Area2D.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")

var _world: Node2D


func before_each() -> void:
	_world = Node2D.new()
	add_child_autofree(_world)


func _zone(at: Vector2, size: Vector2) -> StealthZone:
	var zone: StealthZone = StealthZone.new()
	zone.size = size
	zone.position = at
	_world.add_child(zone)
	return zone


func _marker(at: Vector2) -> Node2D:
	var node: Node2D = Node2D.new()
	node.position = at
	_world.add_child(node)
	return node


func test_zone_joins_the_stealth_group() -> void:
	var zone: StealthZone = _zone(Vector2(100, 0), Vector2(200, 150))
	assert_true(zone.is_in_group(StealthZone.GROUP))
	assert_eq(StealthZone.GROUP, &"stealth_zones")
	assert_eq(zone.collision_layer, 0)
	assert_eq(zone.collision_mask, CollisionLayers.PLAYER)


func test_contains_tests_the_body_center_against_the_zone() -> void:
	var zone: StealthZone = _zone(Vector2(100, 0), Vector2(200, 150))
	assert_eq(zone.world_rect(), Rect2(0, -150, 200, 150))
	# Pieds au sol (y = 0) : centre du corps à y = -36, dans la zone.
	assert_true(zone.contains(_marker(Vector2(100, 0))))
	assert_true(zone.contains(_marker(Vector2(5, -2))))
	assert_false(zone.contains(_marker(Vector2(-10, 0))), "à gauche")
	assert_false(zone.contains(_marker(Vector2(210, 0))), "à droite")
	assert_false(zone.contains(_marker(Vector2(100, -200))), "au-dessus (sur l'auvent)")
	assert_false(zone.contains(null))


func test_zone_draws_a_subtle_shadow() -> void:
	var zone: StealthZone = _zone(Vector2(0, 0), Vector2(200, 150))
	await wait_process_frames(2)
	assert_true(zone.visible)
	assert_lt(StealthZone.SHADOW_ALPHA, 0.6, "ombre discrète, le décor reste lisible")


func test_area_detects_the_real_player() -> void:
	_world.add_child(LevelGeometry.make_block(Rect2(-1000, 0, 4000, 100)))
	var zone: StealthZone = _zone(Vector2(400, 0), Vector2(200, 150))
	var entered: Array[Node2D] = []
	zone.body_entered.connect(func(body: Node2D) -> void: entered.append(body))
	var body: RunnerBody = PLAYER_SCENE.instantiate() as RunnerBody
	var human: Node = body.get_node("Controller")
	body.remove_child(human)
	human.free()
	var ctrl: ScriptedController = ScriptedController.new()
	ctrl.name = "Controller"
	body.add_child(ctrl)
	body.position = Vector2(0, -2)
	_world.add_child(body)
	await wait_physics_frames(10)
	assert_false(zone.contains(body))
	ctrl.move_axis = 1.0
	for i: int in 200:
		await wait_physics_frames(1)
		if body.global_position.x > 400.0:
			break
	ctrl.move_axis = 0.0
	await wait_physics_frames(4)
	assert_true(zone.contains(body), "caché dans l'ombre")
	assert_has(entered, body, "body_entered pour le directeur")
