extends SceneTree
## Déclenche chaque figure de parkour tour à tour et assemble une planche PNG :
## une ligne par figure, 4 images prises au fil de la figure.
## Contrôle visuel (nécessite une fenêtre, pas --headless).
## Usage : godot --path . -s tools/capture_figures.gd -- <dossier_de_sortie_absolu>

const PLAYER_SCENE: String = "res://src/gameplay/actors/player/player.tscn"
const CELL: int = 260
const CROP: int = 320
const PROGRESS_POINTS: Array[float] = [0.1, 0.35, 0.6, 0.85]
const MAX_FRAMES: int = 600

## [figure, blocs, sprint, axe, réglage particulier]
var _scenarios: Array[Array] = [
	[&"speed_vault", [Rect2(300, -20, 100, 20)], true, 1.0, &""],
	[&"kong_vault", [Rect2(300, -40, 100, 40)], true, 1.0, &""],
	[&"lazy_vault", [Rect2(300, -40, 100, 40)], false, 1.0, &""],
	[&"tic_tac", [Rect2(300, -100, 120, 100)], true, 1.0, &""],
	[&"front_flip", [], true, 1.0, &"gap"],
	[&"wall_flip", [Rect2(300, -400, 60, 400)], true, 1.0, &"wall_jump"],
	[&"corkscrew", [], false, 0.0, &"double_jump"],
	[&"cat_leap", [Rect2(300, -200, 60, 200)], false, 0.8, &"jump_at_200"],
	[&"parkour_roll", [], true, 1.0, &"drop_roll"],
]

var _out: String = ""
var _index: int = -1
var _root: Node2D
var _body: RunnerBody
var _ctrl: ScriptedController
var _frames: int = 0
var _shots: Array[Image] = []
var _rows: Array[Array] = []
var _next_point: int = 0
var _capturing: bool = false
var _jumped: bool = false
var _double_jumped: bool = false
var _slid: bool = false


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	physics_frame.connect(_tick)
	process_frame.connect(_capture)
	_next_scenario()


func _next_scenario() -> void:
	if _root != null:
		_root.queue_free()
	_index += 1
	if _index >= _scenarios.size():
		_write_sheet()
		quit()
		return
	var scenario: Array = _scenarios[_index]
	var special: StringName = scenario[4]
	_frames = 0
	_shots = []
	_next_point = 0
	_jumped = false
	_double_jumped = false
	_slid = false
	_root = Node2D.new()
	var background: CityBackdrop = CityBackdrop.new()
	_root.add_child(background)
	if special == &"gap":
		_root.add_child(LevelGeometry.make_block(Rect2(-1000, 0, 1400, 600)))
		_root.add_child(LevelGeometry.make_block(Rect2(560, 0, 1400, 600)))
	else:
		_root.add_child(LevelGeometry.make_block(Rect2(-1000, 0, 4000, 600)))
	for rect: Rect2 in scenario[1]:
		_root.add_child(LevelGeometry.make_block(rect))

	_body = (load(PLAYER_SCENE) as PackedScene).instantiate() as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	_ctrl = ScriptedController.new()
	_ctrl.name = "Controller"
	_ctrl.move_axis = float(scenario[3])
	_ctrl.sprint_held = bool(scenario[2])
	_ctrl.jump_held = true
	_body.add_child(_ctrl)
	_body.position = Vector2(0, -400) if special == &"drop_roll" else Vector2(0, -2)
	if special == &"double_jump":
		_body.abilities.unlock(AbilitySet.DOUBLE_JUMP)

	var label: Label = Label.new()
	label.text = String(scenario[0]).replace("_", " ").to_upper()
	label.position = Vector2(-70, -150)
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", Color(0.6, 0.25, 0.05))
	_body.add_child(label)
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(0, -40)
	camera.zoom = Vector2(1.6, 1.6)
	_body.add_child(camera)
	_root.add_child(_body)
	root.add_child(_root)
	# Différé : au premier scénario, l'arbre n'est pas encore prêt (_init).
	camera.make_current.call_deferred()


func _tick() -> void:
	if _body == null or not is_instance_valid(_body):
		return
	_frames += 1
	var special: StringName = _scenarios[_index][4]
	var x: float = _body.global_position.x
	match special:
		&"gap":
			if not _jumped and _body.is_on_floor() and x > 375.0:
				_ctrl.press_jump()
				_jumped = true
		&"wall_jump":
			if not _jumped and _body.current_state() == PlayerState.State.WALL_RUN:
				_ctrl.press_jump()
				_jumped = true
		&"double_jump":
			if _frames == 20:
				_ctrl.press_jump()
			elif not _double_jumped and _frames > 30 and _body.velocity.y > -150.0:
				_ctrl.press_jump()
				_double_jumped = true
		&"jump_at_200":
			if not _jumped and _body.is_on_floor() and x > 200.0:
				_ctrl.press_jump()
				_jumped = true
			# Une fois accroché, ne plus pousser : sinon il se hisse avant la fin de la figure.
			if _body.current_state() == PlayerState.State.LEDGE_HANG:
				_ctrl.move_axis = 0.0
		&"drop_roll":
			if not _slid and _body.velocity.y > 0.0 and _body.global_position.y > -80.0:
				_ctrl.press_slide()
				_slid = true
	var wanted: StringName = _scenarios[_index][0]
	_capturing = _body.figure != Figure.Kind.NONE and Figure.name_of(_body.figure) == wanted
	if _next_point >= PROGRESS_POINTS.size() or _frames > MAX_FRAMES:
		_rows.append(_shots)
		print("%-13s %d images" % [wanted, _shots.size()])
		_body = null
		_next_scenario.call_deferred()


func _capture() -> void:
	if not _capturing or _body == null or _next_point >= PROGRESS_POINTS.size():
		return
	if _body.figure_progress() < PROGRESS_POINTS[_next_point]:
		return
	_next_point += 1
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var size: Vector2i = image.get_size()
	var region: Rect2i = Rect2i(size.x / 2 - CROP / 2, size.y / 2 - CROP / 2, CROP, CROP)
	var cell: Image = image.get_region(region)
	cell.resize(CELL, CELL, Image.INTERPOLATE_BILINEAR)
	_shots.append(cell)


func _write_sheet() -> void:
	var columns: int = PROGRESS_POINTS.size()
	var sheet: Image = Image.create(CELL * columns, CELL * _rows.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(1, 1, 1))
	for row: int in _rows.size():
		var shots: Array = _rows[row]
		for column: int in shots.size():
			var cell: Image = shots[column]
			cell.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, Vector2i(CELL, CELL)), Vector2i(column * CELL, row * CELL))
	sheet.save_png(_out.path_join("figures_sheet.png"))
	print("planche : ", _out.path_join("figures_sheet.png"))
