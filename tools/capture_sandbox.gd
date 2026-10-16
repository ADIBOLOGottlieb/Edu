extends SceneTree
## Pilote le bac à sable du jalon M1 et enregistre une capture PNG par état.
## Contrôle visuel de la silhouette provisoire (nécessite une fenêtre, pas --headless).
## Usage : godot --path . -s tools/capture_sandbox.gd -- <dossier_de_sortie_absolu>

var _body: RunnerBody
var _ctrl: ScriptedController
var _frame: int = 0
var _out: String = ""
var _taken: Dictionary = {}
var _pending: String = ""
var _slid: bool = false
var _jumped: bool = false
var _jumped_step: bool = false

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var packed: PackedScene = load("res://scenes/sandbox/movement_sandbox.tscn")
	var scene: Node = packed.instantiate()
	(scene.get_node("TouchControls") as TouchControls).force_visible = true
	_body = scene.get_node("Player") as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	_ctrl = ScriptedController.new()
	_ctrl.name = "Controller"
	_body.add_child(_ctrl)
	root.add_child(scene)
	physics_frame.connect(_on_physics)
	process_frame.connect(_on_process)

func _want(shot: String) -> void:
	if not _taken.has(shot) and _pending == "":
		_pending = shot

func _on_physics() -> void:
	_frame += 1
	var x: float = _body.global_position.x
	var s: PlayerState.State = _body.current_state()
	_ctrl.move_axis = 0.0 if _frame < 40 else 1.0
	_ctrl.sprint_held = x > 150.0
	_ctrl.jump_held = true
	if not _jumped_step and x > 430.0:
		_ctrl.press_jump(); _jumped_step = true
	if not _slid and x > 760.0 and _body.is_on_floor():
		_ctrl.press_slide(); _slid = true
	if not _jumped and x > 1420.0:
		_ctrl.press_jump(); _jumped = true
	if _frame == 30: _want("1_idle")
	if s == PlayerState.State.RUN and _frame > 55: _want("2_run")
	if s == PlayerState.State.SPRINT and x > 400.0: _want("3_sprint")
	if s == PlayerState.State.SLIDE and x > 1000.0: _want("4_slide_tunnel")
	if s == PlayerState.State.JUMP and _body.velocity.y < -300.0: _want("5_jump")
	if s == PlayerState.State.FALL and _body.velocity.y > 200.0: _want("6_fall")
	if s == PlayerState.State.LANDING and x > 1400.0: _want("7_landing")
	if _frame > 900 or _taken.size() >= 7:
		print("captures : ", _taken.keys())
		quit()

func _on_process() -> void:
	if _pending == "":
		return
	var shot: String = _pending
	_pending = ""
	_taken[shot] = true
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_out.path_join(shot + ".png"))
