class_name RunnerBody
extends CharacterBody2D
## Corps physique commun au joueur et aux poursuivants.
##
## Consomme un IntentFrame fourni par un Controller enfant et ne lit jamais une
## touche directement. Ordre d'un tick de physique :
##   intention → minuteries → décision d'état → vitesse → move_and_slide.
## La physique pilote l'état ; le visuel (RunnerVisual) ne fait que le lire.

signal state_changed(from: PlayerState.State, to: PlayerState.State)
## kind : &"ground" (M1). &"double" et &"wall" arrivent au jalon M2.
signal jump_started(kind: StringName)
signal landed(impact_speed: float)

@export var tuning: MoveTuning
@export var standing_shape: CollisionShape2D
@export var sliding_shape: CollisionShape2D
## Zone au-dessus de la tête testée avant de se relever d'une glissade.
@export var head_clearance: ShapeCast2D

var fsm: PlayerFSM = PlayerFSM.new()
var intent: IntentFrame = IntentFrame.new()
## 1 = droite, -1 = gauche.
var facing: int = 1

var _controller: Controller
var _ctx: MovementContext = MovementContext.new()
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _slide_buffer_left: float = 0.0
## Dernière vitesse verticale mesurée en l'air, utilisée comme vitesse d'impact.
var _air_speed_y: float = 0.0
var _impact_speed: float = 0.0


func _ready() -> void:
	assert(tuning != null, "RunnerBody : MoveTuning manquant")
	_controller = _find_controller()
	fsm.state_changed.connect(_on_fsm_state_changed)
	_apply_collision_for(fsm.current)


func current_state() -> PlayerState.State:
	return fsm.current


func current_state_name() -> StringName:
	return PlayerState.name_of(fsm.current)


func _find_controller() -> Controller:
	for child: Node in get_children():
		if child is Controller:
			return child as Controller
	return null


func _physics_process(delta: float) -> void:
	intent.clear()
	if _controller != null:
		_controller.fill(intent)

	_update_timers(delta)
	_fill_context()

	fsm.exit_allowed = MovementDecider.can_exit(fsm.current, _ctx, tuning)
	fsm.request(MovementDecider.next_state(fsm.current, intent, _ctx, tuning))

	velocity = LocomotionMotor.step(fsm.current, velocity, intent, _ctx, tuning, delta)
	_update_facing()
	if not is_on_floor():
		_air_speed_y = velocity.y
	move_and_slide()
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
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)


func _fill_context() -> void:
	_ctx.on_floor = is_on_floor()
	_ctx.velocity = velocity
	_ctx.time_in_state = float(fsm.ticks_in_state) / float(Engine.physics_ticks_per_second)
	_ctx.can_stand = _can_stand()
	_ctx.coyote_left = _coyote_left
	_ctx.jump_buffer_left = _jump_buffer_left
	_ctx.slide_buffer_left = _slide_buffer_left
	_ctx.impact_speed = _impact_speed


func _can_stand() -> bool:
	if head_clearance == null or fsm.current != PlayerState.State.SLIDE:
		return true
	head_clearance.force_shapecast_update()
	return not head_clearance.is_colliding()


func _update_facing() -> void:
	match fsm.current:
		PlayerState.State.SLIDE, PlayerState.State.SPRINT:
			# Pas de demi-tour visuel tant que l'élan n'est pas inversé.
			if absf(velocity.x) > 1.0:
				facing = 1 if velocity.x > 0.0 else -1
		_:
			if absf(intent.move_axis) >= MovementDecider.AXIS_DEADZONE:
				facing = 1 if intent.move_axis > 0.0 else -1


func _apply_collision_for(state: PlayerState.State) -> void:
	var sliding: bool = state == PlayerState.State.SLIDE
	if standing_shape != null:
		standing_shape.disabled = sliding
	if sliding_shape != null:
		sliding_shape.disabled = not sliding


func _on_fsm_state_changed(from: PlayerState.State, to: PlayerState.State) -> void:
	velocity = LocomotionMotor.on_enter(to, velocity, facing, tuning)
	_apply_collision_for(to)
	match to:
		PlayerState.State.JUMP:
			_coyote_left = 0.0
			_jump_buffer_left = 0.0
			jump_started.emit(&"ground")
		PlayerState.State.SLIDE:
			_slide_buffer_left = 0.0
		PlayerState.State.LANDING:
			_impact_speed = maxf(_air_speed_y, 0.0)
			landed.emit(_impact_speed)
	state_changed.emit(from, to)
