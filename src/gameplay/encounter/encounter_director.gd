class_name EncounterDirector
extends Node2D
## Pilote la poursuite d'un parcours (docs/ARCHITECTURE.md §5–6) : fait entrer le
## vigile derrière le coureur, tient l'EncounterFSM et la jauge de capture.
##
## - Contact (le vigile tient le coureur) → COMBAT : la jauge se remplit.
## - Le coureur s'arrache → ESCAPE_WINDOW ; sans nouveau contact pendant
##   ESCAPE_WINDOW_TIME → retour en PURSUIT (ou RUNNING si le vigile a abandonné).
## - Jauge pleine → CAPTURED → séquence non graphique (fondu, « ATTRAPÉ », menottes
##   lumineuses) → MISSION_FAILED. En attendant l'écran de résultat (M6), le coureur
##   réapparaît au point de contrôle et une nouvelle tentative commence, le vigile
##   replacé derrière lui (réinitialisation entre deux tentatives, pas en jeu).
## - Arrivée → MISSION_COMPLETED.

signal capture_changed(value: float)
signal captured()
## Le vigile vient de saisir le coureur (bouclier : M8).
signal pursuer_grabbed()

const ESCAPE_WINDOW_TIME: float = 2.0
## Hors du niveau sous le toit le plus bas : le vigile est replacé (il a chuté).
const PURSUER_FALL_DEPTH: float = 700.0

@export var runner: LevelRunner
@export var pursuer_scene: PackedScene = preload("res://src/gameplay/actors/pursuer/pursuer.tscn")
## Délai avant l'entrée du vigile (s).
@export var start_delay: float = 2.5
## Distance derrière le coureur à laquelle le vigile entre ou revient (px).
@export var start_behind: float = 380.0

var fsm: EncounterFSM = EncounterFSM.new()
var gauge: CaptureGauge = CaptureGauge.new()
var pursuer: RunnerBody
var captures: int = 0
## Faux : aucune poursuite sur ce parcours (CityRoute.pursuit).
var enabled: bool = true

var _ai: PursuerAIController
var _start_left: float = 0.0
var _escape_left: float = 0.0
var _overlay: CaptureOverlay


func _ready() -> void:
	_start_left = start_delay
	var route: CityRoute = runner.current_route() if runner != null else null
	if route != null:
		enabled = route.pursuit
		_start_left = route.pursuer_delay
	_overlay = CaptureOverlay.new()
	add_child(_overlay)
	if enabled:
		var hud: PursuitHud = PursuitHud.new()
		hud.director = self
		add_child(hud)
	if runner != null:
		runner.level_completed.connect(_on_level_completed)


## Distance horizontale du vigile derrière le coureur (px), ou -1 sans vigile.
func pursuer_distance() -> float:
	if pursuer == null or runner == null or runner.player == null:
		return -1.0
	return absf(runner.player.global_position.x - pursuer.global_position.x)


func pursuer_ai() -> PursuerAIController:
	return _ai


func _physics_process(delta: float) -> void:
	if not enabled or runner == null or runner.player == null or fsm.is_terminal():
		return
	var player: RunnerBody = runner.player
	if pursuer == null:
		_start_left -= delta
		if _start_left <= 0.0 and not player.is_dead():
			_spawn_pursuer()
		return
	if player.is_dead():
		return
	_check_pursuer_fell()
	var in_contact: bool = _ai.is_in_contact()
	capture_changed.emit(gauge.update(delta, in_contact))
	if gauge.is_full():
		_capture()
		return
	if fsm.current == EncounterFSM.State.ESCAPE_WINDOW:
		_escape_left -= delta
		if _escape_left <= 0.0:
			var chasing: bool = _ai.ai_state() != &"give_up"
			fsm.request(EncounterFSM.State.PURSUIT if chasing else EncounterFSM.State.RUNNING, &"fuite_reussie")


func _spawn_pursuer() -> void:
	pursuer = pursuer_scene.instantiate() as RunnerBody
	_ai = pursuer.get_node("Controller") as PursuerAIController
	_ai.target = runner.player
	get_parent().add_child(pursuer)
	_ai.reset(_spawn_point())
	_ai.contact_changed.connect(_on_contact_changed)
	_ai.lost_track.connect(func() -> void: fsm.request(EncounterFSM.State.RUNNING, &"trace_perdue"))
	_ai.gave_up.connect(func() -> void: fsm.request(EncounterFSM.State.RUNNING, &"abandon"))
	fsm.request(EncounterFSM.State.PURSUIT, &"vigile_actif")


## Point d'entrée du vigile : sur le sol `start_behind` px derrière le coureur (assez
## près pour être vu, comme dans une vraie poursuite), sinon au début du tronçon.
func _spawn_point(behind: float = -1.0) -> Vector2:
	var player: RunnerBody = runner.player
	var distance: float = start_behind if behind < 0.0 else behind
	var behind_x: float = player.global_position.x - distance * float(player.facing)
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		Vector2(behind_x, player.global_position.y - 400.0),
		Vector2(behind_x, player.global_position.y + 500.0),
		CollisionLayers.WORLD,
	)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		return (hit["position"] as Vector2) + Vector2(0.0, -2.0)
	var chunk: LevelChunk = runner.streamer.chunk_at(behind_x)
	if chunk == null:
		chunk = runner.streamer.chunk_at(player.global_position.x)
	if chunk == null:
		return player.global_position - Vector2(distance, 0.0)
	return chunk.position + Vector2(runner.respawn_offset_x * 0.5, -2.0)


func _check_pursuer_fell() -> void:
	var chunk: LevelChunk = runner.streamer.chunk_at(pursuer.global_position.x)
	var floor_limit: float = chunk.deepest_y() if chunk != null else runner.streamer.end_y()
	if pursuer.global_position.y > floor_limit + PURSUER_FALL_DEPTH:
		_ai.reset(_spawn_point())


func _on_contact_changed(in_contact: bool) -> void:
	if in_contact:
		# Rattrapé : de la poursuite, d'une fuite en cours, ou après avoir perdu la trace.
		if fsm.current == EncounterFSM.State.RUNNING:
			fsm.request(EncounterFSM.State.PURSUIT, &"repere")
		fsm.request(EncounterFSM.State.COMBAT, &"contact")
		pursuer_grabbed.emit()
	elif fsm.current == EncounterFSM.State.COMBAT:
		_escape_left = ESCAPE_WINDOW_TIME
		fsm.request(EncounterFSM.State.ESCAPE_WINDOW, &"arrache")


func _capture() -> void:
	if fsm.current == EncounterFSM.State.RUNNING:
		fsm.request(EncounterFSM.State.PURSUIT, &"repere")
	fsm.request(EncounterFSM.State.CAPTURED, &"jauge_pleine")
	captures += 1
	captured.emit()
	_overlay.play()
	_ai.set_active(false)
	runner.player.kill(&"capture")
	fsm.request(EncounterFSM.State.MISSION_FAILED, &"capture")
	# Nouvelle tentative au point de contrôle (en attendant l'écran de résultat, M6).
	_restart_after(LevelRunner.DEATH_PAUSE + 0.05)


func _restart_after(seconds: float) -> void:
	await get_tree().create_timer(seconds, false, true).timeout
	if not is_instance_valid(pursuer):
		return
	fsm = EncounterFSM.new()
	gauge.reset()
	capture_changed.emit(0.0)
	_ai.reset(_spawn_point())
	_ai.set_active(true)
	fsm.request(EncounterFSM.State.PURSUIT, &"nouvelle_tentative")


func _on_level_completed() -> void:
	# Arrivée tenu par le vigile : on s'arrache d'abord (la table interdit COMBAT → fin).
	if fsm.current == EncounterFSM.State.COMBAT:
		fsm.request(EncounterFSM.State.ESCAPE_WINDOW, &"arrivee")
	if fsm.current == EncounterFSM.State.ESCAPE_WINDOW:
		fsm.request(EncounterFSM.State.RUNNING, &"arrivee")
	fsm.request(EncounterFSM.State.MISSION_COMPLETED, &"arrivee")
	if _ai != null:
		_ai.set_active(false)


## Séquence de capture non graphique : fondu sombre, « ATTRAPÉ », menottes lumineuses.
class CaptureOverlay:
	extends CanvasLayer

	const DURATION: float = 1.0
	var _time: float = -1.0
	var _canvas: Control

	func _ready() -> void:
		layer = 20
		_canvas = Control.new()
		_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
		_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.draw.connect(_on_draw)
		add_child(_canvas)

	func play() -> void:
		_time = 0.0

	func _process(delta: float) -> void:
		if _time < 0.0:
			return
		_time += delta
		if _time > DURATION:
			_time = -1.0
		_canvas.queue_redraw()

	func _on_draw() -> void:
		if _time < 0.0:
			return
		var size: Vector2 = _canvas.size
		var fade: float = sin(PI * clampf(_time / DURATION, 0.0, 1.0))
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.75 * fade))
		var center: Vector2 = size * 0.5
		var glow: Color = Color(1.0, 0.72, 0.30, fade)
		# Menottes stylisées : deux anneaux reliés.
		_canvas.draw_arc(center + Vector2(-26.0, -20.0), 18.0, 0.0, TAU, 32, glow, 5.0, true)
		_canvas.draw_arc(center + Vector2(26.0, -20.0), 18.0, 0.0, TAU, 32, glow, 5.0, true)
		_canvas.draw_line(center + Vector2(-8.0, -20.0), center + Vector2(8.0, -20.0), glow, 4.0, true)
		var font: Font = ThemeDB.fallback_font
		_canvas.draw_string(font, center + Vector2(-120.0, 40.0), "ATTRAPÉ", HORIZONTAL_ALIGNMENT_CENTER, 240.0, 34, glow)


## Affichage de poursuite : distance du vigile (en mètres) et jauge de capture,
## en haut au centre, lisible sur mobile.
class PursuitHud:
	extends CanvasLayer

	const BAR_SIZE: Vector2 = Vector2(220.0, 12.0)
	var director: EncounterDirector
	var _canvas: Control

	func _ready() -> void:
		layer = 15
		_canvas = Control.new()
		_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
		_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.draw.connect(_on_draw)
		add_child(_canvas)

	func _process(_delta: float) -> void:
		_canvas.queue_redraw()

	func _on_draw() -> void:
		var distance: float = director.pursuer_distance()
		if distance < 0.0:
			return
		var font: Font = ThemeDB.fallback_font
		var top: Vector2 = Vector2(_canvas.size.x * 0.5, 22.0)
		var danger: float = clampf(1.0 - distance / 900.0, 0.0, 1.0)
		var tint: Color = Color(1.0, 0.85 - 0.5 * danger, 0.55 - 0.45 * danger, 0.95)
		var meters: int = int(distance / LevelRunner.PIXELS_PER_METER)
		_canvas.draw_string(font, top + Vector2(-120.0, 0.0), "VIGILE  %d m" % meters,
				HORIZONTAL_ALIGNMENT_CENTER, 240.0, 18, tint)
		var value: float = director.gauge.value
		if value <= 0.005:
			return
		var bar: Rect2 = Rect2(top + Vector2(-BAR_SIZE.x * 0.5, 10.0), BAR_SIZE)
		_canvas.draw_rect(bar, Color(0.0, 0.0, 0.0, 0.55))
		_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * value, bar.size.y)), Color(0.95, 0.25, 0.15, 0.95))
		_canvas.draw_rect(bar, Color(1.0, 0.8, 0.5, 0.9), false, 1.5)


# --- Équipement (M8) : effets sur le vigile, sans combat --------------------------

func has_pursuer() -> bool:
	return pursuer != null and _ai != null and enabled and not fsm.is_terminal()


## Repousse le vigile à `distance` px derrière le coureur (sur le sol), lâche la prise.
func repel_pursuer(distance: float) -> bool:
	if not has_pursuer():
		return false
	_ai.reset(_spawn_point(maxf(distance, pursuer_distance())))
	return true


## Leurre : le vigile reste sur place tant que `on` est vrai.
func distract_pursuer(on: bool) -> void:
	if _ai != null:
		_ai.set_active(not on)


## Dissimule le coureur (camouflage, cachette) : le vigile perd sa trace.
func conceal_target(on: bool) -> void:
	if _ai != null:
		_ai.target_concealed = on


## Vide une part de la jauge de capture (surcharge : 0,6 = −60 %).
func reduce_gauge(fraction: float) -> void:
	gauge.value = maxf(0.0, gauge.value * (1.0 - clampf(fraction, 0.0, 1.0)))
	capture_changed.emit(gauge.value)
