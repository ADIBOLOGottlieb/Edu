extends GutTest
## Parkour du jalon M2 avec le vrai corps (player.tscn) et le moteur physique.
## Le ScriptedController joue le rôle du joueur ; les capteurs lisent la vraie géométrie.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")

var _world: Node2D
var _body: RunnerBody
var _ctrl: ScriptedController
## États successifs, enregistrés depuis le signal state_changed du corps.
var _states: Array[int] = []
var _flag: bool = false


func before_each() -> void:
	_states.clear()
	_flag = false
	_world = Node2D.new()
	_world.add_child(_make_block(Rect2(-1000, 0, 4000, 100)))
	add_child_autofree(_world)

	_body = PLAYER_SCENE.instantiate() as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	_ctrl = ScriptedController.new()
	_ctrl.name = "Controller"
	_body.add_child(_ctrl)


func _make_block(rect: Rect2) -> StaticBody2D:
	var block: StaticBody2D = StaticBody2D.new()
	block.position = rect.position
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.size * 0.5
	block.add_child(collision)
	return block


func _on_state_changed(_from: PlayerState.State, to: PlayerState.State) -> void:
	_states.append(to)


func _spawn(at: Vector2) -> void:
	_body.position = at
	_world.add_child(_body)
	_body.state_changed.connect(_on_state_changed)


func _spawn_settled() -> void:
	_spawn(Vector2(0, -2))
	await wait_physics_frames(15)
	_states.clear()
	watch_signals(_body)


func _seen(state: PlayerState.State) -> int:
	return _states.count(state)


func _run_until(condition: Callable, max_frames: int) -> void:
	for i: int in max_frames:
		await wait_physics_frames(1)
		if condition.call():
			return


func _sprint_right() -> void:
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true


func _jump_kinds() -> Array:
	var kinds: Array = []
	for index: int in get_signal_emit_count(_body, "jump_started"):
		kinds.append(get_signal_parameters(_body, "jump_started", index)[0])
	return kinds


func test_sprinting_into_a_low_obstacle_vaults_over_it_without_stopping() -> void:
	_world.add_child(_make_block(Rect2(300, -40, 120, 40)))
	await _spawn_settled()
	_sprint_right()
	await _run_until(func() -> bool: return _body.global_position.x > 600.0, 120)
	assert_gt(_body.global_position.x, 600.0, "obstacle franchi en moins de 2 s")
	assert_eq(_seen(PlayerState.State.VAULT), 1)
	assert_gt(absf(_body.velocity.x), _body.tuning.run_speed, "l'élan est conservé")


## Appuie sur Saut près du sommet du premier saut, puis une seconde fois pendant
## le double saut. Déclenché par l'état du corps et non par un numéro de frame :
## wait_physics_frames(1) de GUT peut laisser passer plus d'un tick.
func _press_jump_near_apex_then_again() -> void:
	var pressed_at_apex: bool = false
	var pressed_again: bool = false
	for i: int in 150:
		await wait_physics_frames(1)
		var state: PlayerState.State = _body.current_state()
		if not pressed_at_apex and state == PlayerState.State.JUMP and _body.velocity.y > -250.0:
			_ctrl.press_jump()
			pressed_at_apex = true
		elif pressed_at_apex and not pressed_again and state == PlayerState.State.DOUBLE_JUMP:
			_ctrl.press_jump()  # ce troisième appui en l'air ne doit rien donner
			pressed_again = true
		if pressed_at_apex and _body.is_on_floor() and state == PlayerState.State.IDLE:
			return


func test_double_jump_is_refused_while_the_ability_is_locked() -> void:
	await _spawn_settled()
	_ctrl.jump_held = true
	_ctrl.press_jump()
	await _press_jump_near_apex_then_again()
	assert_signal_emit_count(_body, "jump_started", 1)
	assert_eq(_seen(PlayerState.State.DOUBLE_JUMP), 0)


func test_double_jump_once_unlocked_goes_higher_and_only_once() -> void:
	_body.abilities.unlock(AbilitySet.DOUBLE_JUMP)
	await _spawn_settled()
	var start_y: float = _body.position.y
	# Le pic est relevé à chaque tick par le contrôleur (appelé par le corps lui-même).
	var peak_y: Array[float] = [start_y]
	_ctrl.jump_held = true
	_ctrl.policy = func(_intent: IntentFrame) -> void:
		peak_y[0] = minf(peak_y[0], _body.position.y)
	_ctrl.press_jump()
	await _press_jump_near_apex_then_again()
	assert_signal_emit_count(_body, "jump_started", 2)
	assert_eq(_jump_kinds(), [&"ground", &"double"])
	assert_eq(_seen(PlayerState.State.DOUBLE_JUMP), 1)
	assert_gt(start_y - peak_y[0], 200.0, "plus haut qu'un saut simple (≈ 144 px)")


func test_wall_run_then_ledge_then_climb_brings_the_runner_on_top() -> void:
	_world.add_child(_make_block(Rect2(300, -200, 60, 200)))
	await _spawn_settled()
	_sprint_right()
	await _run_until(
		func() -> bool: return _body.is_on_floor() and _body.global_position.y < -150.0, 240
	)
	assert_eq(_seen(PlayerState.State.WALL_RUN), 1)
	assert_eq(_seen(PlayerState.State.LEDGE_HANG), 1)
	assert_true(_body.is_on_floor())
	assert_almost_eq(_body.global_position.y, -200.0, 2.0, "debout sur le haut du mur")
	assert_has(_jump_kinds(), &"ledge", "s'est hissé depuis le rebord")


func test_hanging_holds_still_and_dropping_does_not_regrab() -> void:
	_world.add_child(_make_block(Rect2(300, -200, 60, 200)))
	await _spawn_settled()
	_sprint_right()
	await _run_until(func() -> bool: return _body.current_state() == PlayerState.State.LEDGE_HANG, 240)
	assert_eq(_body.current_state(), PlayerState.State.LEDGE_HANG, "rebord atteint")
	_ctrl.move_axis = 0.0
	_ctrl.sprint_held = false
	var hang_position: Vector2 = _body.global_position
	await wait_physics_frames(20)
	assert_eq(_body.current_state(), PlayerState.State.LEDGE_HANG, "reste suspendu sans entrée")
	assert_almost_eq(_body.global_position.distance_to(hang_position), 0.0, 0.5, "immobile")

	_ctrl.press_slide()
	await wait_physics_frames(40)
	assert_eq(_seen(PlayerState.State.LEDGE_HANG), 1, "aucune reprise immédiate du rebord")
	assert_ne(_body.current_state(), PlayerState.State.LEDGE_HANG)
	var hang_index: int = _states.find(PlayerState.State.LEDGE_HANG)
	assert_eq(_states[hang_index + 1], PlayerState.State.FALL, "lâcher = chute")


func test_too_tall_wall_exhausts_the_climb_and_the_runner_falls_back() -> void:
	_world.add_child(_make_block(Rect2(300, -1000, 60, 1000)))
	await _spawn_settled()
	_sprint_right()
	await wait_physics_frames(200)
	assert_eq(_seen(PlayerState.State.WALL_RUN), 1)
	assert_eq(_seen(PlayerState.State.WALL_CLIMB), 1, "une seule escalade par phase aérienne")
	assert_eq(_seen(PlayerState.State.LEDGE_HANG), 0)
	var climb_index: int = _states.find(PlayerState.State.WALL_CLIMB)
	assert_eq(_states[climb_index + 1], PlayerState.State.FALL)
	assert_true(_body.is_on_floor(), "revenu au sol")


func test_slide_at_a_hard_landing_rolls_out_immediately() -> void:
	_spawn(Vector2(0, -400))
	watch_signals(_body)
	_sprint_right()
	_ctrl.policy = func(intent: IntentFrame) -> void:
		if not _flag and _body.velocity.y > 0.0 and _body.global_position.y > -80.0:
			intent.slide_pressed = true
			_flag = true
	await wait_physics_frames(90)
	assert_signal_emit_count(_body, "landed", 1)
	assert_gte(get_signal_parameters(_body, "landed")[0], _body.tuning.landing_hard_speed)
	var landing_index: int = _states.find(PlayerState.State.LANDING)
	assert_gte(landing_index, 0)
	assert_eq(_states[landing_index + 1], PlayerState.State.ROLL, "la roulade annule la réception dure")
	assert_gt(absf(_body.velocity.x), 0.0)
