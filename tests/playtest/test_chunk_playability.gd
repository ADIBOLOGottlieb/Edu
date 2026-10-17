extends GutTest
## Jouabilité réelle : le pilote automatique traverse chaque tronçon livré, puis
## une course aléatoire, avec le vrai corps et la vraie physique, sans chute.
## Complète LevelValidator (calculs prudents) par une preuve en conditions de jeu.
## Ces tests durent plusieurs minutes (physique en temps réel).

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")
const LIBRARY_PATH: String = "res://data/levels/chunk_library.tres"
## Limite par tronçon : bien au-delà du temps normal de traversée (~6 s).
const MAX_FRAMES_PER_CHUNK: int = 900
const ENDLESS_CHUNKS: int = 15

var _chunk_ids: Array = _load_chunk_ids()
var _runner: LevelRunner
var _body: RunnerBody
var _trail: Array[String] = []


func _load_chunk_ids() -> Array:
	var ids: Array = []
	for layout: ChunkLayout in (load(LIBRARY_PATH) as ChunkLibrary).layouts:
		ids.append(layout.id)
	return ids


func _build(mode: ChunkSequencer.Mode, seed_value: int, order: Array[StringName]) -> void:
	_trail.clear()
	var root: Node2D = Node2D.new()
	_runner = LevelRunner.new()
	_runner.library = load(LIBRARY_PATH) as ChunkLibrary
	_runner.mode = mode
	_runner.seed_value = seed_value
	_runner.ordered_ids = order
	var streamer: ChunkStreamer = ChunkStreamer.new()
	streamer.name = "Streamer"
	_runner.add_child(streamer)

	_body = PLAYER_SCENE.instantiate() as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	var autopilot: AutopilotController = AutopilotController.new()
	autopilot.name = "Controller"
	_body.add_child(autopilot)
	_body.position = Vector2(60, -2)
	_body.state_changed.connect(_record_state)
	_runner.player = _body

	root.add_child(_runner)
	root.add_child(_body)
	add_child_autofree(root)


func _record_state(_from: PlayerState.State, to: PlayerState.State) -> void:
	_trail.append("%s@%d" % [PlayerState.name_of(to), int(_body.global_position.x)])
	if _trail.size() > 30:
		_trail.pop_front()


func test_autopilot_crosses_every_chunk_without_falling(chunk_id: Variant = use_parameters(_chunk_ids)) -> void:
	_build(ChunkSequencer.Mode.ORDERED, 1, [&"flat_run", chunk_id, &"flat_run"] as Array[StringName])
	for i: int in MAX_FRAMES_PER_CHUNK:
		await wait_physics_frames(1)
		if _runner.is_completed() or _runner.fall_count > 0:
			break
	var context: String = "%s : %s" % [chunk_id, " ".join(_trail)]
	assert_eq(_runner.fall_count, 0, "chute — " + context)
	assert_true(_runner.is_completed(), "arrivée non atteinte — " + context)


func test_autopilot_survives_a_random_course_with_rising_difficulty() -> void:
	_build(ChunkSequencer.Mode.RANDOM, 2026, [] as Array[StringName])
	for i: int in MAX_FRAMES_PER_CHUNK * ENDLESS_CHUNKS:
		await wait_physics_frames(1)
		var chunk: LevelChunk = _runner.streamer.chunk_at(_body.global_position.x)
		if _runner.fall_count > 0 or (chunk != null and chunk.index >= ENDLESS_CHUNKS):
			break
	var reached: LevelChunk = _runner.streamer.chunk_at(_body.global_position.x)
	assert_eq(_runner.fall_count, 0, "chute — " + " ".join(_trail))
	assert_not_null(reached)
	assert_gte(reached.index, ENDLESS_CHUNKS, "course interrompue — " + " ".join(_trail))
	assert_gte(_runner.sequencer.max_difficulty(), 3, "la difficulté a bien augmenté")
