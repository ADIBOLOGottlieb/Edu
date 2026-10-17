extends SceneTree
## Profilage de la course infinie : un « chariot » avance à vitesse de sprint
## (le coureur est désactivé pour ne mesurer que le niveau et le rendu), puis
## l'outil affiche FPS, nœuds, objets et appels de dessin.
## Nécessite une fenêtre (pas --headless). Mesure de PC, pas d'Android.
## Usage : godot --path . -s tools/profile_run.gd -- <secondes> [dossier_capture_absolu]

const SPEED: float = 480.0
const WARMUP_FRAMES: int = 60

var _seconds: float = 60.0
var _capture_dir: String = ""
var _runner: LevelRunner
var _dolly: Node2D
var _frame: int = 0
var _elapsed: float = 0.0
var _fps_samples: PackedFloat32Array = PackedFloat32Array()
var _draw_calls: PackedFloat32Array = PackedFloat32Array()
var _nodes_start: float = 0.0
var _nodes_max: float = 0.0
var _objects_start: float = 0.0
var _captured: bool = false


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_seconds = float(args[0])
	if args.size() > 1:
		_capture_dir = args[1]
	var scene: Node = (load("res://scenes/levels/endless_run.tscn") as PackedScene).instantiate()
	_runner = scene.get_node("LevelRunner") as LevelRunner
	_runner.seed_value = 2026
	var player: RunnerBody = scene.get_node("Player") as RunnerBody
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	_runner.player = null
	_dolly = Node2D.new()
	_dolly.position = Vector2(60, -2)
	scene.add_child(_dolly)
	_runner.follow_target = _dolly
	(scene.get_node("Camera") as RunnerCamera).target = _dolly
	root.add_child(scene)
	physics_frame.connect(_on_physics)
	process_frame.connect(_on_process)


func _on_physics() -> void:
	_dolly.position.x += SPEED / float(Engine.physics_ticks_per_second)


func _on_process() -> void:
	_frame += 1
	if _frame == WARMUP_FRAMES:
		_nodes_start = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		_objects_start = Performance.get_monitor(Performance.OBJECT_COUNT)
	if _frame <= WARMUP_FRAMES:
		return
	var delta: float = root.get_process_delta_time()
	_elapsed += delta
	_fps_samples.append(1.0 / maxf(delta, 0.0001))
	_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_nodes_max = maxf(_nodes_max, Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if _elapsed >= _seconds:
		_report()
		quit()
		return
	if not _captured and _capture_dir != "" and _elapsed > _seconds * 0.5:
		_captured = true
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_capture_dir.path_join("profile_mid_run.png"))


func _report() -> void:
	var sorted: Array = Array(_fps_samples)
	sorted.sort()
	var count: int = sorted.size()
	var total: float = 0.0
	for value: float in _fps_samples:
		total += value
	var low_count: int = maxi(1, count / 100)
	var low_total: float = 0.0
	for i: int in low_count:
		low_total += sorted[i]
	var draw_total: float = 0.0
	for value: float in _draw_calls:
		draw_total += value
	print("=== Profil course infinie (%s, %.0f s, %d images) ===" % [
		RenderingServer.get_video_adapter_name(), _elapsed, count
	])
	print("Distance parcourue : %.0f m · tronçons générés : %d · construits : %d" % [
		_dolly.position.x / LevelRunner.PIXELS_PER_METER,
		_runner.sequencer.index(),
		_runner.streamer.created_count,
	])
	print("FPS moyen %.1f · 1 %% bas %.1f · min %.1f" % [total / count, low_total / low_count, sorted[0]])
	print("Appels de dessin moyens : %.0f" % (draw_total / count))
	print("Nœuds : %d au départ → %d au maximum → %d à la fin" % [
		_nodes_start, _nodes_max, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	])
	print("Objets : %d au départ → %d à la fin" % [
		_objects_start, Performance.get_monitor(Performance.OBJECT_COUNT)
	])
