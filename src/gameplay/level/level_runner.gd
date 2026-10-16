class_name LevelRunner
extends Node2D
## Orchestre un niveau à défilement : génère les tronçons autour du nœud suivi,
## place l'arrivée (mode ordonné), détecte les chutes hors du niveau.
## Le ChunkStreamer est un enfant nommé « Streamer ».

signal level_completed()
## Chute sous le niveau. En M3 le coureur est replacé au début du tronçon ;
## la défaite et la capture arrivent au jalon M6.
signal player_fell(at_x: float)

const PIXELS_PER_METER: float = 40.0

@export var library: ChunkLibrary
@export var mode: ChunkSequencer.Mode = ChunkSequencer.Mode.RANDOM
## 0 = graine tirée au lancement (affichée par le panneau de débogage).
@export var seed_value: int = 0
## Mode ordonné : identifiants des tronçons, dans l'ordre.
@export var ordered_ids: Array[StringName] = []
@export var player: RunnerBody
## Nœud suivi par la génération ; le joueur par défaut (un « chariot » pour le profilage).
@export var follow_target: Node2D
## En dessous de cette hauteur, le coureur est considéré comme tombé.
@export var kill_y: float = 700.0
@export var respawn_offset_x: float = 60.0

var sequencer: ChunkSequencer
var seed_used: int = 0
## Abscisse la plus avancée atteinte par le joueur.
var furthest_x: float = 0.0
var fall_count: int = 0

var _completed: bool = false

@onready var streamer: ChunkStreamer = $Streamer


func _ready() -> void:
	seed_used = seed_value if seed_value != 0 else randi_range(1, 2147483646)
	sequencer = ChunkSequencer.new(library, mode, seed_used, ordered_ids)
	streamer.sequencer = sequencer
	streamer.sequence_finished.connect(_on_sequence_finished)
	if follow_target == null:
		follow_target = player
	if player != null:
		var profile: ProfileServiceNode = get_node_or_null(^"/root/ProfileService") as ProfileServiceNode
		if profile != null:
			player.abilities = profile.abilities
	streamer.update(_target_x())


func distance_meters() -> float:
	return furthest_x / PIXELS_PER_METER


func is_completed() -> bool:
	return _completed


func _target_x() -> float:
	return follow_target.global_position.x if follow_target != null else 0.0


func _physics_process(_delta: float) -> void:
	streamer.update(_target_x())
	if player == null:
		return
	furthest_x = maxf(furthest_x, player.global_position.x)
	if player.global_position.y > kill_y:
		_respawn()


func _respawn() -> void:
	var fell_at: float = player.global_position.x
	fall_count += 1
	player_fell.emit(fell_at)
	var chunk: LevelChunk = streamer.chunk_at(fell_at)
	var start_x: float = chunk.position.x if chunk != null else 0.0
	player.global_position = Vector2(start_x + respawn_offset_x, -2.0)
	player.velocity = Vector2.ZERO


func _on_sequence_finished(end_x: float) -> void:
	# Mur de fin et ligne d'arrivée juste avant : le parcours ordonné est fini.
	add_child(LevelGeometry.make_block(Rect2(end_x, -900.0, 60.0, 1100.0)))
	var finish: FinishLine = FinishLine.new()
	finish.position = Vector2(end_x - 160.0, 0.0)
	finish.crossed.connect(_on_finish_crossed)
	add_child(finish)


func _on_finish_crossed(body: Node2D) -> void:
	if _completed or body != player:
		return
	_completed = true
	level_completed.emit()
