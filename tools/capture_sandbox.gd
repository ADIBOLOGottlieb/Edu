extends SceneTree
## Joue le parcours du bac à sable avec un ScriptedController et enregistre une
## capture PNG à la première occurrence de chaque état (jalons M1 et M2).
## Contrôle visuel de la silhouette provisoire (nécessite une fenêtre, pas --headless).
## Usage : godot --path . -s tools/capture_sandbox.gd -- <dossier_de_sortie_absolu>

const MAX_FRAMES: int = 1500

var _body: RunnerBody
var _ctrl: ScriptedController
var _frame: int = 0
var _out: String = ""
var _taken: Dictionary[String, bool] = {}
var _pending: String = ""
var _slid_tunnel: bool = false
var _jumped_platforms: bool = false
var _rolled: bool = false
var _double_jump_step: int = 0


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var scene: Node = (load("res://scenes/sandbox/movement_sandbox.tscn") as PackedScene).instantiate()
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
	if _frame == 1:
		# Après le _ready du bac à sable, qui donne au corps l'AbilitySet du profil.
		_body.abilities.unlock(AbilitySet.DOUBLE_JUMP)
	var x: float = _body.global_position.x
	var y: float = _body.global_position.y
	var state: PlayerState.State = _body.current_state()

	_ctrl.move_axis = 0.0 if _frame < 40 else 1.0
	_ctrl.sprint_held = x > 150.0
	_ctrl.jump_held = true
	if not _slid_tunnel and x > 760.0 and _body.is_on_floor():
		_ctrl.press_slide()
		_slid_tunnel = true
	if not _jumped_platforms and x > 1420.0:
		_ctrl.press_jump()
		_jumped_platforms = true
	# Redescente du mur (haut à y = -260) : Glisse juste avant le sol → roulade.
	if not _rolled and x > 2780.0 and _body.velocity.y > 0.0 and y > -80.0:
		_ctrl.press_slide()
		_rolled = true
	# Double saut au-dessus du sol plat, après le mur.
	if _double_jump_step == 0 and x > 3200.0 and _body.is_on_floor():
		_ctrl.press_jump()
		_double_jump_step = 1
	elif _double_jump_step == 1 and state == PlayerState.State.JUMP and _body.velocity.y > -250.0:
		_ctrl.press_jump()
		_double_jump_step = 2

	var name: String = String(PlayerState.name_of(state))
	match state:
		PlayerState.State.IDLE:
			if _frame == 30:
				_want("01_idle")
		PlayerState.State.RUN:
			if _frame > 55:
				_want("02_run")
		PlayerState.State.SPRINT:
			if x > 300.0:
				_want("03_sprint")
		PlayerState.State.SLIDE:
			if x > 1000.0:
				_want("05_slide")
		PlayerState.State.JUMP:
			if _body.velocity.y < -300.0:
				_want("06_jump")
		PlayerState.State.FALL:
			if _body.velocity.y > 200.0:
				_want("07_fall")
		PlayerState.State.LANDING:
			if x > 1400.0:
				_want("08_landing")
		PlayerState.State.VAULT:
			_want("04_vault")
		PlayerState.State.WALL_RUN:
			_want("09_wall_run")
		PlayerState.State.WALL_CLIMB:
			_want("10_wall_climb")
		PlayerState.State.LEDGE_HANG:
			_want("11_ledge_hang")
		PlayerState.State.ROLL:
			_want("12_roll")
		PlayerState.State.DOUBLE_JUMP:
			if _body.fsm.ticks_in_state > 4:
				_want("13_double_jump")
		_:
			push_warning("état inattendu : " + name)
	if _frame > MAX_FRAMES or _taken.size() >= 13:
		print("captures : ", _taken.keys())
		quit()


func _on_process() -> void:
	if _pending == "":
		return
	var shot: String = _pending
	_pending = ""
	_taken[shot] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(shot + ".png"))
