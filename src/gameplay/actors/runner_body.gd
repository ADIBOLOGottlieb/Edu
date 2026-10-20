class_name RunnerBody
extends CharacterBody2D
## Corps physique commun au joueur et aux poursuivants.
##
## Consomme un IntentFrame fourni par un Controller enfant et ne lit jamais une
## touche directement. Ordre d'un tick de physique :
##   intention → minuteries → capteurs → décision d'état → vitesse → move_and_slide.
## La physique pilote l'état ; le visuel (RunnerVisual) ne fait que le lire.

signal state_changed(from: PlayerState.State, to: PlayerState.State)
## kind : &"ground", &"double" (double saut), &"wall" (saut mural),
## &"ledge" (se hisser depuis un rebord).
signal jump_started(kind: StringName)
signal landed(impact_speed: float)
## Une figure de parkour commence (Figure.name_of : &"kong_vault", &"front_flip"…).
signal figure_started(figure_name: StringName)
## Mort sur un piège : cause = &"spikes", &"saw", &"crusher", &"flame"… Le niveau
## replace ensuite le corps (LevelRunner → revive).
signal died(cause: StringName)

## Invulnérabilité après une réapparition (s) : pas de mort en boucle sur un piège.
const INVULNERABLE_AFTER_REVIVE: float = 1.2

@export var tuning: MoveTuning
@export var standing_shape: CollisionShape2D
@export var sliding_shape: CollisionShape2D
## Zone au-dessus de la tête testée avant de se relever d'une glissade ou d'une roulade.
@export var head_clearance: ShapeCast2D
## Demi-largeur du corps debout (rayon de la capsule), utilisée par les capteurs.
@export var half_width: float = 14.0

var fsm: PlayerFSM = PlayerFSM.new()
var intent: IntentFrame = IntentFrame.new()
## 1 = droite, -1 = gauche.
var facing: int = 1
## Capacités débloquées. Le joueur reçoit celles de ProfileService ; un
## poursuivant garde son propre jeu.
var abilities: AbilitySet = AbilitySet.new()
## Figure en cours (Figure.Kind.NONE sinon). Lue par RunnerVisual.
var figure: Figure.Kind = Figure.Kind.NONE

## Appelé par kill(cause) : vrai = coup encaissé, pas de mort (équipement, M8).
var hurt_guard: Callable

var _controller: Controller
var _ctx: MovementContext = MovementContext.new()
var _sensors: ParkourSensors = ParkourSensors.new()
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _slide_buffer_left: float = 0.0
## Dernière vitesse verticale mesurée en l'air, utilisée comme vitesse d'impact.
var _air_speed_y: float = 0.0
var _impact_speed: float = 0.0
# Ressources aériennes, rechargées au sol.
var _double_jump_used: bool = false
var _wall_run_used: bool = false
var _wall_climb_left: float = 0.0
var _ledge_cooldown_left: float = 0.0
var _air_lock_left: float = 0.0
var _air_speed_x: float = 0.0
var _figure_time: float = 0.0
var _figure_duration: float = 0.0
var _dead: bool = false
var _invulnerable_left: float = 0.0


func _ready() -> void:
	assert(tuning != null, "RunnerBody : MoveTuning manquant")
	_controller = _find_controller()
	_wall_climb_left = tuning.wall_climb_max_time
	fsm.state_changed.connect(_on_fsm_state_changed)
	_apply_collision_for(fsm.current)


func current_state() -> PlayerState.State:
	return fsm.current


func current_state_name() -> StringName:
	return PlayerState.name_of(fsm.current)


## Avancement de la figure en cours (0 → 1), d'après le temps écoulé et la
## durée prévue par la physique au départ de la figure.
func figure_progress() -> float:
	if figure == Figure.Kind.NONE or _figure_duration <= 0.0:
		return 0.0
	return clampf(_figure_time / _figure_duration, 0.0, 1.0)


func is_dead() -> bool:
	return _dead


## Faux pendant la mort et l'invulnérabilité qui suit une réapparition.
func can_be_hurt() -> bool:
	return not _dead and _invulnerable_left <= 0.0


## Tue le corps (sans effet s'il ne peut pas être blessé). Retourne vrai s'il meurt.
func kill(cause: StringName) -> bool:
	if not can_be_hurt():
		return false
	if hurt_guard.is_valid() and bool(hurt_guard.call(cause)):
		# Coup encaissé (gilet) : brève invulnérabilité pour sortir du piège.
		_invulnerable_left = INVULNERABLE_AFTER_REVIVE
		return false
	_dead = true
	velocity = Vector2.ZERO
	figure = Figure.Kind.NONE
	fsm.force(PlayerState.State.DEATH)
	died.emit(cause)
	return true


## Mort imposée (capture par le vigile) : ignore l'invulnérabilité de réapparition.
func force_kill(cause: StringName) -> bool:
	_invulnerable_left = 0.0
	return kill(cause)


## Réapparition (point de contrôle) : debout, immobile, brièvement invulnérable.
func revive(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_dead = false
	_invulnerable_left = INVULNERABLE_AFTER_REVIVE
	figure = Figure.Kind.NONE
	fsm.force(PlayerState.State.IDLE)
	# Réapparition : pas d'interpolation depuis la position de la mort.
	reset_physics_interpolation()


func _find_controller() -> Controller:
	for child: Node in get_children():
		if child is Controller:
			return child as Controller
	return null


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	if _dead:
		# Mort : immobile jusqu'à la réapparition (le visuel joue la chute).
		return
	intent.clear()
	if _controller != null:
		_controller.fill(intent)

	_update_timers(delta)
	_fill_context()

	fsm.exit_allowed = MovementDecider.can_exit(fsm.current, intent, _ctx, tuning)
	fsm.request(MovementDecider.next_state(fsm.current, intent, _ctx, tuning))

	velocity = LocomotionMotor.step(fsm.current, velocity, intent, _ctx, tuning, delta)
	_update_facing()
	if not is_on_floor():
		_air_speed_y = velocity.y
	move_and_slide()
	if fsm.current == PlayerState.State.WALL_CLIMB:
		_wall_climb_left = maxf(0.0, _wall_climb_left - delta)
	if figure != Figure.Kind.NONE:
		_figure_time += delta
	fsm.tick()


func _update_timers(delta: float) -> void:
	if intent.jump_pressed:
		_jump_buffer_left = tuning.jump_buffer_time
	else:
		_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

	if intent.slide_pressed:
		_slide_buffer_left = tuning.slide_buffer_time
	else:
		_slide_buffer_left = maxf(0.0, _slide_buffer_left - delta)

	if is_on_floor():
		_coyote_left = tuning.coyote_time
		_double_jump_used = false
		_wall_run_used = false
		_wall_climb_left = tuning.wall_climb_max_time
		_air_speed_x = 0.0
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
		_air_speed_x = maxf(_air_speed_x, absf(velocity.x))

	_ledge_cooldown_left = maxf(0.0, _ledge_cooldown_left - delta)
	_air_lock_left = maxf(0.0, _air_lock_left - delta)


func _fill_context() -> void:
	_ctx.on_floor = is_on_floor()
	_ctx.velocity = velocity
	_ctx.time_in_state = float(fsm.ticks_in_state) / float(Engine.physics_ticks_per_second)
	_ctx.can_stand = _can_stand()
	_ctx.coyote_left = _coyote_left
	_ctx.jump_buffer_left = _jump_buffer_left
	_ctx.slide_buffer_left = _slide_buffer_left
	_ctx.impact_speed = _impact_speed
	_ctx.facing = facing

	_sensors.scan(self, facing, tuning, half_width)
	_ctx.wall_ahead = _sensors.wall_ahead
	_ctx.obstacle_height = _sensors.obstacle_height
	_ctx.ledge_available = _sensors.ledge_available
	_ctx.wall_top_height = _sensors.wall_top_height
	_ctx.edge_ahead = _sensors.edge_ahead
	_ctx.air_speed_x = _air_speed_x

	_ctx.can_double_jump = abilities.has(AbilitySet.DOUBLE_JUMP) and not _double_jump_used
	_ctx.can_wall_run = not _wall_run_used
	_ctx.wall_climb_left = _wall_climb_left
	_ctx.ledge_cooldown_left = _ledge_cooldown_left
	_ctx.air_control_lock_left = _air_lock_left


static func _uses_low_shape(state: PlayerState.State) -> bool:
	return state == PlayerState.State.SLIDE or state == PlayerState.State.ROLL


func _can_stand() -> bool:
	if head_clearance == null or not _uses_low_shape(fsm.current):
		return true
	head_clearance.force_shapecast_update()
	return not head_clearance.is_colliding()


func _update_facing() -> void:
	match fsm.current:
		PlayerState.State.SLIDE, PlayerState.State.SPRINT, PlayerState.State.ROLL:
			# Pas de demi-tour visuel tant que l'élan n'est pas inversé.
			if absf(velocity.x) > 1.0:
				facing = 1 if velocity.x > 0.0 else -1
		PlayerState.State.WALL_RUN, PlayerState.State.WALL_CLIMB, PlayerState.State.LEDGE_HANG, PlayerState.State.VAULT:
			pass  # Orientation fixée par le mur ou l'obstacle.
		PlayerState.State.JUMP, PlayerState.State.FALL, PlayerState.State.DOUBLE_JUMP:
			if _air_lock_left <= 0.0 and absf(intent.move_axis) >= MovementDecider.AXIS_DEADZONE:
				facing = 1 if intent.move_axis > 0.0 else -1
		_:
			if absf(intent.move_axis) >= MovementDecider.AXIS_DEADZONE:
				facing = 1 if intent.move_axis > 0.0 else -1


func _apply_collision_for(state: PlayerState.State) -> void:
	var low: bool = _uses_low_shape(state)
	if standing_shape != null:
		standing_shape.disabled = low
	if sliding_shape != null:
		sliding_shape.disabled = not low


## Place les mains sur le rebord détecté. Correction bornée par la fenêtre de
## saisie des capteurs (quelques dizaines de pixels au plus).
func _snap_to_ledge() -> void:
	global_position = Vector2(
		_sensors.wall_x - float(facing) * (half_width + 0.5),
		_sensors.ledge_top_y + tuning.ledge_hang_offset
	)
	velocity = Vector2.ZERO


## Démarre la figure choisie, ou prolonge / termine la figure en cours.
func _update_figure(chosen: Figure.Kind, to: PlayerState.State) -> void:
	if chosen != Figure.Kind.NONE:
		figure = chosen
		_figure_time = 0.0
		_figure_duration = Figure.expected_duration(chosen, velocity, tuning)
		figure_started.emit(Figure.name_of(chosen))
	elif figure != Figure.Kind.NONE and not Figure.carries_into(figure, to):
		figure = Figure.Kind.NONE


func _on_fsm_state_changed(from: PlayerState.State, to: PlayerState.State) -> void:
	# La figure est choisie avant l'impulsion : certaines la modifient (kong, tic-tac).
	var chosen: Figure.Kind = Figure.choose(from, to, _ctx, tuning)
	_ctx.figure = chosen
	velocity = LocomotionMotor.on_enter(from, to, velocity, _ctx, tuning)
	_update_figure(chosen, to)
	if chosen == Figure.Kind.TIC_TAC:
		_wall_run_used = true
	_apply_collision_for(to)
	if from == PlayerState.State.LEDGE_HANG:
		_ledge_cooldown_left = tuning.ledge_regrab_cooldown
		_slide_buffer_left = 0.0
	match to:
		PlayerState.State.JUMP:
			_coyote_left = 0.0
			_jump_buffer_left = 0.0
			var kind: StringName = &"ground"
			if from == PlayerState.State.WALL_RUN or from == PlayerState.State.WALL_CLIMB:
				kind = &"wall"
				facing = -facing
				_air_lock_left = tuning.wall_jump_control_lock
			elif from == PlayerState.State.LEDGE_HANG:
				kind = &"ledge"
			jump_started.emit(kind)
		PlayerState.State.DOUBLE_JUMP:
			_jump_buffer_left = 0.0
			_double_jump_used = true
			jump_started.emit(&"double")
		PlayerState.State.SLIDE, PlayerState.State.ROLL:
			_slide_buffer_left = 0.0
		PlayerState.State.WALL_RUN:
			_wall_run_used = true
			_double_jump_used = false
		PlayerState.State.WALL_CLIMB:
			_double_jump_used = false
		PlayerState.State.LEDGE_HANG:
			_double_jump_used = false
			_wall_climb_left = tuning.wall_climb_max_time
			_snap_to_ledge()
		PlayerState.State.LANDING:
			_impact_speed = maxf(_air_speed_y, 0.0)
			landed.emit(_impact_speed)
	_ctx.facing = facing
	state_changed.emit(from, to)
