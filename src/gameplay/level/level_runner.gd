class_name LevelRunner
extends Node2D
## Orchestre un niveau à défilement : génère les tronçons autour du nœud suivi,
## place l'arrivée (mode ordonné), détecte les chutes hors du niveau.
## Le ChunkStreamer est un enfant nommé « Streamer ».

signal level_completed()
## Chute sous le niveau. En M3 le coureur est replacé au début du tronçon ;
## la défaite et la capture arrivent au jalon M6.
signal player_fell(at_x: float)
## Mort du joueur sur un piège ; il réapparaît au début du tronçon après DEATH_PAUSE.
signal player_died(cause: StringName)

const PIXELS_PER_METER: float = 40.0
## Pause entre la mort et la réapparition (s) : le temps de voir la chute.
const DEATH_PAUSE: float = 0.8

@export var library: ChunkLibrary
@export var mode: ChunkSequencer.Mode = ChunkSequencer.Mode.RANDOM
## 0 = graine tirée au lancement (affichée par le panneau de débogage).
@export var seed_value: int = 0
## Mode ordonné : identifiants des tronçons, dans l'ordre.
@export var ordered_ids: Array[StringName] = []
@export var player: RunnerBody
## Nœud suivi par la génération ; le joueur par défaut (un « chariot » pour le profilage).
@export var follow_target: Node2D
## Chute dans la rue : plus bas que le toit le plus bas du tronçon + cette profondeur.
@export var kill_depth: float = 600.0
@export var respawn_offset_x: float = 60.0
## Ville jouée : si elle est donnée, son parcours n° route_index remplace mode et
## ordered_ids, et son ambiance habille les tronçons (objets urbains).
@export var city: CityDefinition
@export var route_index: int = 0

var sequencer: ChunkSequencer
var seed_used: int = 0
## Abscisse la plus avancée atteinte par le joueur.
var furthest_x: float = 0.0
var fall_count: int = 0
## Morts sur un piège (les chutes sont comptées à part dans fall_count).
var death_count: int = 0
## Temps de course (s), arrêté à l'arrivée.
var elapsed: float = 0.0

var _completed: bool = false
var _respawn_left: float = 0.0

@onready var streamer: ChunkStreamer = $Streamer


func _ready() -> void:
	seed_used = seed_value if seed_value != 0 else randi_range(1, 2147483646)
	# Parcours choisi sur l'écran de la ville (SceneRouter).
	var router: SceneRouterNode = get_node_or_null(^"/root/SceneRouter") as SceneRouterNode
	if router != null and city != null and router.param("route_index") != null:
		route_index = int(router.param("route_index"))
	var route: CityRoute = current_route()
	if route != null:
		mode = ChunkSequencer.Mode.ORDERED
		ordered_ids = route.chunk_ids
	if city != null:
		streamer.theme = city.theme
	sequencer = ChunkSequencer.new(library, mode, seed_used, ordered_ids)
	streamer.sequencer = sequencer
	streamer.sequence_finished.connect(_on_sequence_finished)
	if follow_target == null:
		follow_target = player
	if player != null:
		var profile: ProfileServiceNode = get_node_or_null(^"/root/ProfileService") as ProfileServiceNode
		if profile != null:
			player.abilities = profile.abilities
		player.died.connect(_on_player_died)
	streamer.update(_target_x())


## Toutes les morts : pièges et chutes (énergie, M9).
func total_deaths() -> int:
	return death_count + fall_count


func _on_player_died(cause: StringName) -> void:
	death_count += 1
	_respawn_left = DEATH_PAUSE
	player_died.emit(cause)


## Parcours de ville joué, ou null (course libre ou parcours de test).
func current_route() -> CityRoute:
	return city.route(route_index) if city != null else null


func distance_meters() -> float:
	return furthest_x / PIXELS_PER_METER


func is_completed() -> bool:
	return _completed


func _target_x() -> float:
	return follow_target.global_position.x if follow_target != null else 0.0


func _physics_process(delta: float) -> void:
	streamer.update(_target_x())
	if player == null:
		return
	var chunk: LevelChunk = streamer.chunk_at(player.global_position.x)
	if player.is_dead():
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			player.revive(_checkpoint(chunk))
		return
	furthest_x = maxf(furthest_x, player.global_position.x)
	if not _completed:
		elapsed += delta
	var floor_limit: float = chunk.deepest_y() if chunk != null else streamer.end_y()
	if player.global_position.y > floor_limit + kill_depth:
		_respawn(chunk)


## Point de réapparition : début du tronçon (point de contrôle à chaque tronçon).
func _checkpoint(chunk: LevelChunk) -> Vector2:
	var start: Vector2 = chunk.position if chunk != null else Vector2(0.0, streamer.end_y())
	return start + Vector2(respawn_offset_x, -2.0)


func _respawn(chunk: LevelChunk) -> void:
	fall_count += 1
	player_fell.emit(player.global_position.x)
	var start: Vector2 = chunk.position if chunk != null else Vector2(0.0, streamer.end_y())
	player.global_position = start + Vector2(respawn_offset_x, -2.0)
	player.velocity = Vector2.ZERO


func _on_sequence_finished(end_x: float) -> void:
	# Mur de fin et ligne d'arrivée juste avant, à l'altitude du dernier toit
	# (le parcours a pu monter ou descendre).
	var end_y: float = streamer.end_y()
	add_child(LevelGeometry.make_block(Rect2(end_x, end_y - 900.0, 60.0, 2300.0)))
	var finish: FinishLine = FinishLine.new()
	finish.position = Vector2(end_x - 160.0, end_y)
	finish.crossed.connect(_on_finish_crossed)
	add_child(finish)


func _on_finish_crossed(body: Node2D) -> void:
	if _completed or body != player:
		return
	_completed = true
	level_completed.emit()
