extends SceneTree
## Courte poursuite sur le parcours 1 de Lomé : le coureur en pilote automatique,
## un gardien (pursuer.tscn) à ses trousses. Le coureur marque une pause au milieu
## pour montrer le contact, puis repart et s'échappe. Planche PNG : un gros plan des
## deux silhouettes à l'arrêt, puis une image toutes les SHOT_EVERY images de physique.
## Contrôle visuel (nécessite une fenêtre, pas --headless).
## Usage : godot --path . -s tools/capture_pursuer.gd -- <png_ou_dossier_absolu>

const LEVEL_SCENE: String = "res://scenes/levels/lome_run.tscn"
const PURSUER_SCENE: String = "res://src/gameplay/actors/pursuer/pursuer.tscn"
const COLUMNS: int = 3
const SHOTS: int = 12
const CELL: Vector2i = Vector2i(512, 288)
const CLOSE_UP: Vector2i = Vector2i(512, 288)
## Images de physique : départ du coureur, départ du gardien, intervalle des prises.
const RUNNER_START: int = 40
const GUARD_START: int = 70
const SHOT_EVERY: int = 50
## Zoom du gros plan, puis de la poursuite.
const CLOSE_UP_ZOOM: float = 3.2
const CHASE_ZOOM: float = 1.7
## Pause du coureur (images de physique) pour montrer le contact.
const PAUSE_FROM: int = 340
const PAUSE_TO: int = 470

var _out: String = ""
var _runner: RunnerBody
var _autopilot: AutopilotController
var _guard: RunnerBody
var _ai: PursuerAIController
var _camera: Camera2D
var _label: Label
var _frame: int = 0
var _close_up: Image
var _shots: Array[Image] = []
var _pending: bool = false


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	if not _out.to_lower().ends_with(".png"):
		_out = _out.path_join("pursuer_sheet.png")
	var scene: Node2D = (load(LEVEL_SCENE) as PackedScene).instantiate() as Node2D
	for overlay: String in ["MovementOverlay", "LevelOverlay", "TouchControls", "Camera"]:
		var node: Node = scene.get_node(overlay)
		scene.remove_child(node)
		node.free()
	_runner = scene.get_node("Player") as RunnerBody
	var human: Node = _runner.get_node("Controller")
	_runner.remove_child(human)
	human.free()
	_autopilot = AutopilotController.new()
	_autopilot.name = "Controller"
	_autopilot.direction = 0
	_runner.add_child(_autopilot)
	_runner.position = Vector2(200, -2)

	_guard = (load(PURSUER_SCENE) as PackedScene).instantiate() as RunnerBody
	_guard.position = Vector2(110, -2)
	_ai = _guard.get_node("Controller") as PursuerAIController
	_ai.target = _runner
	_ai.set_active(false)
	scene.add_child(_guard)

	_label = Label.new()
	_label.position = Vector2(-40, -130)
	_label.add_theme_font_size_override(&"font_size", 14)
	_label.add_theme_color_override(&"font_color", Color(0.75, 0.3, 0.1))
	_guard.add_child(_label)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(CLOSE_UP_ZOOM, CLOSE_UP_ZOOM)
	scene.add_child(_camera)
	root.add_child(scene)
	_camera.make_current.call_deferred()
	physics_frame.connect(_tick)
	process_frame.connect(_capture)


func _tick() -> void:
	_frame += 1
	if _frame == RUNNER_START:
		_autopilot.direction = 1
	if _frame == GUARD_START:
		_ai.set_active(true)
	# Pause du coureur : le gardien le rejoint (contact), puis il repart.
	if _frame == PAUSE_FROM:
		_autopilot.direction = 0
	if _frame == PAUSE_TO:
		_autopilot.direction = 1
	# Le directeur (M5) replacera le gardien ; ici, un simple reset s'il décroche.
	if _ai.ai_state() == &"give_up":
		_ai.reset(_runner.global_position + Vector2(-260.0, -2.0))
	_label.text = String(_ai.ai_state()).to_upper() + (" · CONTACT" if _ai.is_in_contact() else "")
	var mid: Vector2 = (_runner.global_position + _guard.global_position) * 0.5
	_camera.position = mid + Vector2(0.0, -40.0 if _close_up == null else -60.0)
	if _frame == 30 or (_frame > GUARD_START and (_frame - GUARD_START) % SHOT_EVERY == 0):
		_pending = true


func _capture() -> void:
	if not _pending:
		return
	_pending = false
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	if _close_up == null:
		# Gros plan : les deux silhouettes côte à côte, à l'arrêt.
		_close_up = image
		_close_up.resize(CLOSE_UP.x * 2, CLOSE_UP.y * 2, Image.INTERPOLATE_LANCZOS)
		_camera.zoom = Vector2(CHASE_ZOOM, CHASE_ZOOM)
		return
	# Prise de poursuite : le centre de l'écran (les deux silhouettes), agrandi.
	var crop: Vector2i = Vector2i(image.get_width() * 3 / 5, image.get_height() * 3 / 5)
	image = image.get_region(Rect2i((image.get_size() - crop) / 2, crop))
	image.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	_shots.append(image)
	print("prise %d : %s, écart %.0f px" % [
		_shots.size(), _ai.ai_state(), _runner.global_position.x - _guard.global_position.x,
	])
	if _shots.size() >= SHOTS:
		_write_sheet()
		quit()


func _write_sheet() -> void:
	var rows: int = int(ceilf(float(SHOTS) / float(COLUMNS)))
	var width: int = CELL.x * COLUMNS
	var top: int = CLOSE_UP.y * 2
	var sheet: Image = Image.create(width, top + CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	sheet.blit_rect(_close_up, Rect2i(Vector2i.ZERO, _close_up.get_size()), Vector2i((width - _close_up.get_width()) / 2, 0))
	for i: int in _shots.size():
		var at: Vector2i = Vector2i((i % COLUMNS) * CELL.x, top + (i / COLUMNS) * CELL.y)
		sheet.blit_rect(_shots[i], Rect2i(Vector2i.ZERO, CELL), at)
	sheet.save_png(_out)
	print("planche : ", _out)
