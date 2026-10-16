class_name LocomotionMotor
extends RefCounted
## Calcule la vitesse d'un acteur pour un tick selon l'état actif.
## Logique pure (aucun nœud) : RunnerBody applique ensuite move_and_slide().


## Impulsion appliquée une seule fois, à l'entrée dans un état.
static func on_enter(
	state: PlayerState.State, velocity: Vector2, facing: int, tuning: MoveTuning
) -> Vector2:
	match state:
		PlayerState.State.JUMP:
			velocity.y = -tuning.jump_velocity
		PlayerState.State.SLIDE:
			var direction: float = signf(velocity.x) if absf(velocity.x) > 1.0 else float(facing)
			velocity.x = direction * maxf(absf(velocity.x) * tuning.slide_boost, tuning.run_speed)
	return velocity


static func step(
	state: PlayerState.State,
	velocity: Vector2,
	intent: IntentFrame,
	ctx: MovementContext,
	tuning: MoveTuning,
	delta: float
) -> Vector2:
	velocity.x = _horizontal(state, velocity.x, intent, ctx, tuning, delta)
	velocity.y = _vertical(velocity.y, intent, ctx, tuning, delta)
	return velocity


static func _axis(intent: IntentFrame) -> float:
	if absf(intent.move_axis) < MovementDecider.AXIS_DEADZONE:
		return 0.0
	return clampf(intent.move_axis, -1.0, 1.0)


static func _horizontal(
	state: PlayerState.State,
	vx: float,
	intent: IntentFrame,
	ctx: MovementContext,
	tuning: MoveTuning,
	delta: float
) -> float:
	var axis: float = _axis(intent)
	match state:
		PlayerState.State.SLIDE:
			# Aucun contrôle de direction pendant la glissade. Sous un plafond bas,
			# une vitesse minimale empêche de rester coincé accroupi.
			var floor_speed: float = 0.0 if ctx.can_stand else signf(vx) * tuning.slide_crawl_speed
			return move_toward(vx, floor_speed, tuning.slide_friction * delta)
		PlayerState.State.JUMP, PlayerState.State.FALL:
			if axis == 0.0:
				return move_toward(vx, 0.0, tuning.air_decel * delta)
			# Conserve l'élan d'un sprint tant que l'on pousse dans le même sens.
			var air_target: float = axis * maxf(tuning.run_speed, absf(vx))
			return move_toward(vx, air_target, tuning.air_accel * delta)
		PlayerState.State.LANDING:
			return _ground(vx, axis * tuning.run_speed * tuning.landing_speed_factor, false, tuning, delta)
		PlayerState.State.RUN:
			return _ground(vx, axis * tuning.run_speed, false, tuning, delta)
		PlayerState.State.SPRINT:
			return _ground(vx, axis * tuning.sprint_speed, true, tuning, delta)
		PlayerState.State.IDLE:
			return _ground(vx, 0.0, false, tuning, delta)
	return vx


## Au sol : demi-tour instantané en course, progressif en sprint.
static func _ground(
	vx: float, target: float, gradual_turn: bool, tuning: MoveTuning, delta: float
) -> float:
	var reversing: bool = target != 0.0 and vx != 0.0 and signf(target) != signf(vx)
	if reversing:
		if gradual_turn:
			return move_toward(vx, 0.0, tuning.sprint_turn_decel * delta)
		vx = 0.0
	var rate: float = tuning.ground_accel if absf(target) > absf(vx) else tuning.ground_decel
	return move_toward(vx, target, rate * delta)


## Gravité plus faible tant que Saut est maintenu en montée : saut à hauteur variable.
static func _vertical(
	vy: float, intent: IntentFrame, ctx: MovementContext, tuning: MoveTuning, delta: float
) -> float:
	if ctx.on_floor and vy >= 0.0:
		return 0.0
	var gravity: float = tuning.gravity_up if (vy < 0.0 and intent.jump_held) else tuning.gravity_down
	return minf(vy + gravity * delta, tuning.max_fall_speed)
