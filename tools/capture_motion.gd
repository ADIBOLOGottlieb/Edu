extends SceneTree
## Filme le coureur (pilote automatique) sur une suite de toits riches en figures :
## une image PNG toutes les 2 images, à assembler en vidéo avec ffmpeg.
## Contrôle de la fluidité de la gestuelle (nécessite une fenêtre, pas --headless).
## Usage : godot --path . --fixed-fps 60 -s tools/capture_motion.gd -- <dossier_de_sortie_absolu> [--model2d]
## Puis : ffmpeg -framerate 30 -i <dossier>/f_%04d.png -pix_fmt yuv420p motion.mp4

const MAX_FRAMES: int = 1500
const ROUTE: Array[StringName] = [
	&"flat_run", &"vault_pair", &"small_gap", &"wall_ledge", &"gap_drop_roll",
	&"tunnel_then_vault", &"high_wall", &"precision_hops", &"rooftop_gauntlet", &"flat_run",
]

var _runner: LevelRunner
var _frame: int = 0
var _shot: int = 0
var _out: String = ""


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var world: Node2D = Node2D.new()
	var sky: ColorRect = ColorRect.new()
	sky.color = Color(0.86, 0.88, 0.9)
	sky.size = Vector2(60000, 8000)
	sky.position = Vector2(-2000, -4000)
	sky.z_index = -10
	world.add_child(sky)
	_runner = LevelRunner.new()
	_runner.library = load("res://data/levels/chunk_library.tres") as ChunkLibrary
	_runner.mode = ChunkSequencer.Mode.ORDERED
	_runner.seed_value = 1
	_runner.ordered_ids = ROUTE
	var streamer: ChunkStreamer = ChunkStreamer.new()
	streamer.name = "Streamer"
	_runner.add_child(streamer)
	var body: RunnerBody = (load("res://src/gameplay/actors/player/player.tscn") as PackedScene).instantiate() as RunnerBody
	var human: Node = body.get_node("Controller")
	body.remove_child(human)
	human.free()
	var pilot: AutopilotController = AutopilotController.new()
	pilot.name = "Controller"
	body.add_child(pilot)
	body.position = Vector2(60, -2)
	if OS.get_cmdline_user_args().has("--model2d"):
		# Ancienne silhouette dessinée par code, pour comparaison.
		(body.get_node("Visual") as RunnerVisual).visible = true
		var model: RunnerModelVisual = body.get_node("ModelVisual") as RunnerModelVisual
		model.visible = false
		model.process_mode = Node.PROCESS_MODE_DISABLED
	_runner.player = body
	var camera: RunnerCamera = RunnerCamera.new()
	camera.target = body
	camera.zoom = Vector2(2.4, 2.4)
	camera.look_ahead = 90.0
	camera.vertical_offset = -50.0
	world.add_child(_runner)
	world.add_child(body)
	world.add_child(camera)
	root.add_child(world)
	camera.make_current.call_deferred()
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame > 20 and _frame % 2 == 0:
		await RenderingServer.frame_post_draw
		_shot += 1
		root.get_texture().get_image().save_png(_out.path_join("f_%04d.png" % _shot))
	if _frame >= MAX_FRAMES or _runner.is_completed() or _runner.fall_count > 0:
		print("capture_motion : %d images, terminé=%s, chutes=%d" % [_shot, _runner.is_completed(), _runner.fall_count])
		quit()
