extends GutTest
## Caméra de course : suit la cible et ne recule pas au-delà de la borne.

var _target: Node2D
var _camera: RunnerCamera


func before_each() -> void:
	var root: Node2D = Node2D.new()
	_target = Node2D.new()
	_camera = RunnerCamera.new()
	_camera.target = _target
	root.add_child(_target)
	root.add_child(_camera)
	add_child_autofree(root)


func test_camera_follows_with_look_ahead() -> void:
	_target.global_position = Vector2(1000, 0)
	await wait_process_frames(60)
	assert_gt(_camera.global_position.x, 1000.0, "regarde devant le coureur")
	assert_lte(_camera.global_position.x, 1000.0 + _camera.look_ahead + 1.0)


func test_camera_never_backtracks_past_the_limit() -> void:
	_target.global_position = Vector2(2000, 0)
	await wait_process_frames(30)
	_target.global_position = Vector2(0, 0)
	await wait_process_frames(30)
	assert_almost_eq(_camera.min_center_x(), 2000.0 - _camera.max_backtrack, 0.01)
	assert_gte(_camera.global_position.x, 2000.0 - _camera.max_backtrack - 0.01)
	var half_width: float = _camera.get_viewport_rect().size.x * 0.5
	assert_almost_eq(float(_camera.limit_left), _camera.min_center_x() - half_width, 1.0)
