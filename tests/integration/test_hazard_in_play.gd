extends GutTest
## Pièges contre le vrai joueur (player.tscn + ScriptedController) sur une vraie
## géométrie : on meurt en touchant, on survit en sautant au bon moment.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")

var _world: Node2D
var _body: RunnerBody
var _ctrl: ScriptedController
var _deaths: Array[StringName] = []


func before_each() -> void:
	_deaths.clear()
	_world = Node2D.new()
	add_child_autofree(_world)
	_body = PLAYER_SCENE.instantiate() as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	_ctrl = ScriptedController.new()
	_ctrl.name = "Controller"
	_body.add_child(_ctrl)


func _block(rect: Rect2) -> void:
	_world.add_child(LevelGeometry.make_block(rect))


func _hazard(kind: StringName, rect: Rect2, path_to: Vector2 = Vector2.ZERO, period: float = 0.0,
		active_ratio: float = 0.5) -> Hazard:
	var spec: HazardSpec = HazardSpec.new()
	spec.kind = kind
	spec.rect = rect
	spec.path_to = path_to
	spec.period = period
	spec.active_ratio = active_ratio
	var hazard: Hazard = Hazard.create(spec, null)
	_world.add_child(hazard)
	return hazard


func _spawn(at: Vector2 = Vector2(0, -2)) -> void:
	_body.position = at
	_world.add_child(_body)
	_body.died.connect(func(cause: StringName) -> void: _deaths.append(cause))
	await wait_physics_frames(15)


func _run_until(condition: Callable, max_frames: int) -> void:
	for i: int in max_frames:
		await wait_physics_frames(1)
		if condition.call():
			return


func test_running_into_spikes_kills() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_hazard(&"spikes", Rect2(200, -16, 48, 16))
	await _spawn()
	_ctrl.move_axis = 1.0
	await _run_until(func() -> bool: return _body.is_dead() or _body.global_position.x > 400.0, 120)
	assert_true(_body.is_dead())
	assert_eq(_deaths, [&"spikes"] as Array[StringName])


func test_jumping_over_spikes_survives() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_hazard(&"spikes", Rect2(200, -16, 48, 16))
	await _spawn()
	_ctrl.move_axis = 1.0
	_ctrl.jump_held = true
	_ctrl.policy = func(intent: IntentFrame) -> void:
		if _body.is_on_floor() and _body.global_position.x > 130.0 and _body.global_position.x < 200.0:
			intent.jump_pressed = true
	await _run_until(func() -> bool:
		return _body.is_dead() or (_body.global_position.x > 400.0 and _body.is_on_floor()), 180)
	assert_false(_body.is_dead())
	assert_gt(_body.global_position.x, 400.0, "passé de l'autre côté")


func test_lit_flame_kills_and_unlit_flame_does_not() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	# Éteinte de 0 à 1 s, allumée de 1 à 2 s ; le joueur reste dans la zone.
	var flame: Hazard = _hazard(&"flame", Rect2(-30, -140, 60, 140), Vector2.ZERO, 2.0, 0.5)
	await _spawn()
	flame.set_time(0.0)
	await wait_physics_frames(30)
	assert_false(flame.is_dangerous())
	assert_false(_body.is_dead(), "une flamme éteinte ne tue pas")
	await _run_until(func() -> bool: return _body.is_dead(), 90)
	assert_true(flame.get_time() >= 1.0, "mort seulement une fois allumée")
	assert_eq(_deaths, [&"flame"] as Array[StringName], "s'allumer sur le joueur le tue")


func test_standing_under_a_crusher_when_it_slams_kills() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	var crusher: Hazard = _hazard(&"crusher", Rect2(-30, -200, 60, 50), Vector2(0, 150), 2.0, 0.4)
	await _spawn()
	crusher.set_time(0.0)
	await _run_until(func() -> bool: return _body.is_dead(), 150)
	assert_eq(_deaths, [&"crusher"] as Array[StringName])


func test_standing_beside_a_crusher_is_safe_and_its_top_holds_the_runner() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	var crusher: Hazard = _hazard(&"crusher", Rect2(-30, -200, 60, 50), Vector2(0, 150), 2.0, 0.4)
	# Debout juste à côté du point d'impact : le bloc frôle sans tuer.
	await _spawn(Vector2(52, -2))
	crusher.set_time(0.0)
	await wait_physics_frames(150)
	assert_false(_body.is_dead(), "à côté, on survit")
	# Sur le bloc baissé : il sert de marche.
	crusher.set_time(1.2)
	_body.revive(Vector2(0, -60))
	await wait_physics_frames(10)
	assert_false(_body.is_dead())
	assert_true(_body.is_on_floor())
	assert_almost_eq(_body.global_position.y, -50.0, 3.0, "posé sur le bloc")


func test_crumble_platform_drops_the_runner_after_the_delay() -> void:
	_block(Rect2(-1000, 400, 4000, 100))
	var crumble: Hazard = _hazard(&"crumble", Rect2(-60, 0, 120, 16))
	await _spawn()
	assert_true(_body.is_on_floor(), "posé sur la plateforme")
	assert_eq(crumble.crumble_state(), Hazard.CrumbleState.SHAKING, "tremble dès qu'on s'y pose")
	await _run_until(func() -> bool: return not crumble.is_solid(), 60)
	assert_false(crumble.is_solid())
	await _run_until(func() -> bool: return _body.global_position.y > 200.0, 60)
	assert_gt(_body.global_position.y, 200.0, "le coureur tombe")
	assert_true(_deaths.is_empty(), "la plateforme ne tue pas")


func test_invulnerable_runner_is_spared_then_dies_if_it_stays() -> void:
	_block(Rect2(-1000, 0, 4000, 100))
	_hazard(&"spikes", Rect2(100, -16, 48, 16))
	await _spawn()
	_body.revive(Vector2(124, -2))
	await wait_physics_frames(30)
	assert_false(_body.is_dead(), "invulnérable juste après la réapparition")
	await _run_until(func() -> bool: return _body.is_dead(), 90)
	assert_eq(_deaths, [&"spikes"] as Array[StringName], "contact continu : tue une fois vulnérable")
