extends SceneTree
## Mesure du coût par image du niveau de Lomé (pilote automatique, parcours 2 avec
## vigile), sans vsync. Options pour isoler un poste : --no3d (silhouettes 3D
## masquées), --nobackdrop (arrière-plan masqué), --nochunks (premier plan masqué),
## --nohud (HUD et boutons masqués). Nécessite une fenêtre (pas --headless).
## Usage : godot --path . -s tools/profile_level.gd -- [options]

const SCENE: String = "res://scenes/levels/lome_run.tscn"
const WARMUP: int = 120
const MEASURE: int = 600

var _level: Node
var _runner: LevelRunner
var _args: PackedStringArray
var _frame: int = 0
var _last_usec: int = 0
var _sum: Dictionary = {"frame": 0.0, "process": 0.0, "physics": 0.0, "draw_calls": 0.0, "objects": 0.0, "primitives": 0.0}
var _worst: float = 0.0


func _init() -> void:
	_args = OS.get_cmdline_user_args()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_level = (load(SCENE) as PackedScene).instantiate()
	_runner = _level.get_node("LevelRunner") as LevelRunner
	_runner.route_index = 1
	var body: RunnerBody = _level.get_node("Player") as RunnerBody
	var human: Node = body.get_node("Controller")
	body.remove_child(human)
	human.free()
	var pilot: AutopilotController = AutopilotController.new()
	pilot.name = "Controller"
	body.add_child(pilot)
	if _args.has("--nobackdrop"):
		(_level.get_node("Backdrop") as CanvasItem).visible = false
	if _args.has("--nohud"):
		for name: String in ["TouchControls", "EquipmentHud"]:
			(_level.get_node(name) as CanvasLayer).visible = false
	root.add_child.call_deferred(_level)


func _process(_delta: float) -> bool:
	_frame += 1
	if _args.has("--no3d"):
		for node: Node in root.find_children("*", "RunnerModelVisual", true, false):
			(node as CanvasItem).visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
	if _args.has("--nochunks"):
		for chunk: LevelChunk in _runner.streamer.active_chunks():
			chunk.visible = false
	var now: int = Time.get_ticks_usec()
	if _frame > WARMUP and _last_usec > 0:
		var ms: float = float(now - _last_usec) / 1000.0
		_sum["frame"] += ms
		_worst = maxf(_worst, ms)
		_sum["process"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_sum["physics"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_sum["draw_calls"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_sum["objects"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		_sum["primitives"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_last_usec = now
	if _frame >= WARMUP + MEASURE:
		var n: float = float(MEASURE)
		print("PROFIL %s : image %.2f ms (pire %.1f), process %.2f ms, physique %.2f ms, appels de dessin %d, objets %d, primitives %d, noeuds %d" % [
			" ".join(_args) if not _args.is_empty() else "complet",
			_sum["frame"] / n, _worst, _sum["process"] / n, _sum["physics"] / n,
			roundi(_sum["draw_calls"] / n), roundi(_sum["objects"] / n), roundi(_sum["primitives"] / n),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
		return true
	return false
