extends GutTest
## Le corps réel (player.tscn) dans un monde physique, piloté par un
## ScriptedController. Vérifie la synchronisation physique / état / collisions
## et que chaque signal n'est émis qu'une fois par événement.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")

var _world: Node2D
var _body: RunnerBody
var _ctrl: ScriptedController
var _slid: bool = false
## Échantillons par tick : [x, état, forme debout désactivée].
var _samples: Array[Array] = []


func before_each() -> void:
	_slid = false
	_samples.clear()
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


func _spawn(at: Vector2) -> void:
	_body.position = at
	_world.add_child(_body)


## Pose le corps au sol et attend qu'il soit stable, avant d'observer les signaux.
func _spawn_settled() -> void:
	_spawn(Vector2(0, -2))
	await wait_physics_frames(15)
	watch_signals(_body)


func _record_sample() -> void:
	_samples.append([_body.global_position.x, _body.current_state(), _body.standing_shape.disabled])


func test_falling_body_lands_exactly_once() -> void:
	_spawn(Vector2(0, -200))
	watch_signals(_body)
	await wait_physics_frames(90)
	assert_signal_emit_count(_body, "landed", 1)
	assert_signal_emit_count(_body, "jump_started", 0)
	assert_true(_body.is_on_floor())
	assert_eq(_body.current_state(), PlayerState.State.IDLE)


func test_high_fall_is_a_hard_landing() -> void:
	_spawn(Vector2(0, -400))
	watch_signals(_body)
	await wait_physics_frames(90)
	assert_signal_emit_count(_body, "landed", 1)
	var impact: float = get_signal_parameters(_body, "landed")[0]
	assert_gte(impact, _body.tuning.landing_hard_speed)


func test_jump_emits_one_start_and_one_landing_and_reaches_expected_height() -> void:
	await _spawn_settled()
	var start_y: float = _body.position.y
	var peak_y: float = start_y

	_ctrl.jump_held = true
	_ctrl.press_jump()
	for i: int in 80:
		await wait_physics_frames(1)
		peak_y = minf(peak_y, _body.position.y)

	assert_signal_emit_count(_body, "jump_started", 1)
	assert_signal_emit_count(_body, "landed", 1)
	assert_eq(_body.current_state(), PlayerState.State.IDLE)
	var height: float = start_y - peak_y
	assert_between(height, 125.0, 160.0, "hauteur d'un saut maintenu ≈ 144 px")


func test_running_right_then_turning_updates_facing() -> void:
	await _spawn_settled()
	_ctrl.move_axis = 1.0
	await wait_physics_frames(30)
	assert_eq(_body.current_state(), PlayerState.State.RUN)
	assert_almost_eq(_body.velocity.x, _body.tuning.run_speed, 1.0)
	assert_eq(_body.facing, 1)

	_ctrl.move_axis = -1.0
	await wait_physics_frames(2)
	assert_eq(_body.facing, -1)
	assert_lt(_body.velocity.x, 0.0, "demi-tour instantané en course")


func test_sprint_is_faster_than_run_on_the_real_body() -> void:
	await _spawn_settled()
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	await wait_physics_frames(40)
	assert_eq(_body.current_state(), PlayerState.State.SPRINT)
	assert_gt(_body.velocity.x, _body.tuning.run_speed)


func test_slide_under_a_low_ceiling_never_stands_up_inside_the_tunnel() -> void:
	# Plafond de x = 300 à 600, à 48 px du sol : debout (72 px) impossible.
	_world.add_child(_make_block(Rect2(300, -400, 300, 352)))
	await _spawn_settled()
	_ctrl.move_axis = 1.0
	_ctrl.sprint_held = true
	_ctrl.policy = func(intent: IntentFrame) -> void:
		if not _slid and _body.global_position.x > 200.0:
			intent.slide_pressed = true
			_slid = true
	for i: int in 300:
		await wait_physics_frames(1)
		_record_sample()
		if _body.global_position.x > 700.0:
			break

	assert_gt(_body.global_position.x, 700.0, "le joueur doit traverser le tunnel")
	assert_signal_emit_count(_body, "landed", 0, "aucune fausse réception")
	var inside: int = 0
	for sample: Array in _samples:
		var x: float = sample[0]
		if x > 290.0 and x < 610.0:
			inside += 1
			assert_eq(sample[1], PlayerState.State.SLIDE, "debout sous le plafond à x = %.0f" % x)
			assert_true(sample[2], "forme debout active sous le plafond à x = %.0f" % x)
	assert_gt(inside, 10, "le test doit réellement observer la traversée")
	assert_ne(_body.current_state(), PlayerState.State.SLIDE, "relevé après le tunnel")
