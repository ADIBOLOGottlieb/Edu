class_name MovementDecider
extends RefCounted
## Choisit l'état de locomotion souhaité à partir de l'intention et du contexte
## physique. Logique pure : aucune dépendance au moteur, testable tick par tick.
## La PlayerFSM reste juge de l'acceptation (table + priorités).

const AXIS_DEADZONE: float = 0.1
## Seuil de l'axe pour « pousser vers l'avant » (mur, obstacle, rebord).
const PUSH_THRESHOLD: float = 0.5


# --- Intentions dérivées -------------------------------------------------------

static func wants_jump(ctx: MovementContext) -> bool:
	return ctx.jump_buffer_left > 0.0


## Glissade demandée récemment, au sol, avec assez d'élan.
static func wants_slide(ctx: MovementContext, tuning: MoveTuning) -> bool:
	return (
		ctx.slide_buffer_left > 0.0
		and ctx.on_floor
		and absf(ctx.velocity.x) >= tuning.slide_min_speed
	)


static func can_ground_jump(ctx: MovementContext) -> bool:
	return ctx.on_floor or ctx.coyote_left > 0.0


static func pushing_forward(intent: IntentFrame, ctx: MovementContext) -> bool:
	return intent.move_axis * float(ctx.facing) >= PUSH_THRESHOLD


static func pushing_backward(intent: IntentFrame, ctx: MovementContext) -> bool:
	return intent.move_axis * float(ctx.facing) <= -PUSH_THRESHOLD


static func is_hard_landing(ctx: MovementContext, tuning: MoveTuning) -> bool:
	return ctx.impact_speed >= tuning.landing_hard_speed


static func landing_duration(ctx: MovementContext, tuning: MoveTuning) -> float:
	if is_hard_landing(ctx, tuning):
		return tuning.landing_hard_duration
	return tuning.landing_soft_duration


## Obstacle bas devant, en courant vers lui avec assez d'élan : franchissement automatique.
static func wants_vault(intent: IntentFrame, ctx: MovementContext, tuning: MoveTuning) -> bool:
	return (
		ctx.on_floor
		and pushing_forward(intent, ctx)
		and ctx.obstacle_height >= tuning.vault_min_height
		and ctx.obstacle_height <= tuning.vault_max_height
		and absf(ctx.velocity.x) >= tuning.vault_min_speed
	)


## Mur devant, en courant vers lui assez vite, une fois par phase aérienne.
static func wants_wall_run(intent: IntentFrame, ctx: MovementContext, tuning: MoveTuning) -> bool:
	return (
		ctx.wall_ahead
		and ctx.can_wall_run
		and pushing_forward(intent, ctx)
		and absf(ctx.velocity.x) >= tuning.wall_run_min_speed
		and ctx.velocity.y <= 0.0
	)


static func wants_wall_climb(intent: IntentFrame, ctx: MovementContext) -> bool:
	return (
		not ctx.on_floor
		and ctx.wall_ahead
		and pushing_forward(intent, ctx)
		and ctx.wall_climb_left > 0.0
	)


static func wants_ledge(ctx: MovementContext) -> bool:
	return not ctx.on_floor and ctx.ledge_available and ctx.ledge_cooldown_left <= 0.0


static func wants_double_jump(ctx: MovementContext) -> bool:
	return (
		wants_jump(ctx)
		and ctx.can_double_jump
		and not ctx.on_floor
		and ctx.coyote_left <= 0.0
	)


static func ground_state_for(intent: IntentFrame) -> PlayerState.State:
	if absf(intent.move_axis) < AXIS_DEADZONE:
		return PlayerState.State.IDLE
	if intent.sprint_held:
		return PlayerState.State.SPRINT
	return PlayerState.State.RUN


# --- Sortie des états prioritaires -------------------------------------------------

## Vrai si l'état courant a fini son action et peut céder la place à un état
## moins prioritaire (sert de garde à PlayerFSM.exit_allowed).
static func can_exit(
	state: PlayerState.State, intent: IntentFrame, ctx: MovementContext, tuning: MoveTuning
) -> bool:
	match state:
		PlayerState.State.LANDING:
			return (
				not ctx.on_floor
				or wants_jump(ctx)
				or ctx.time_in_state >= landing_duration(ctx, tuning)
			)
		PlayerState.State.SLIDE:
			if not ctx.on_floor:
				return true
			return ctx.can_stand and (ctx.time_in_state >= tuning.slide_duration or wants_jump(ctx))
		PlayerState.State.ROLL:
			if not ctx.on_floor:
				return true
			return ctx.can_stand and (ctx.time_in_state >= tuning.roll_duration or wants_jump(ctx))
		PlayerState.State.VAULT:
			if ctx.on_floor:
				return ctx.time_in_state >= tuning.vault_min_time
			return ctx.time_in_state >= tuning.vault_max_time
		PlayerState.State.WALL_RUN:
			return (
				wants_jump(ctx)
				or wants_ledge(ctx)
				or not ctx.wall_ahead
				or ctx.time_in_state >= tuning.wall_run_duration
			)
		PlayerState.State.WALL_CLIMB:
			return (
				wants_jump(ctx)
				or wants_ledge(ctx)
				or ctx.on_floor
				or not wants_wall_climb(intent, ctx)
			)
		PlayerState.State.LEDGE_HANG:
			if ctx.time_in_state < tuning.ledge_min_hang:
				return false
			return (
				wants_jump(ctx)
				or pushing_forward(intent, ctx)
				or pushing_backward(intent, ctx)
				or ctx.slide_buffer_left > 0.0
			)
	return true


# --- Décision ---------------------------------------------------------------------

static func next_state(
	state: PlayerState.State, intent: IntentFrame, ctx: MovementContext, tuning: MoveTuning
) -> PlayerState.State:
	match state:
		PlayerState.State.IDLE, PlayerState.State.RUN, PlayerState.State.SPRINT:
			return _from_ground(intent, ctx, tuning)
		PlayerState.State.JUMP, PlayerState.State.DOUBLE_JUMP:
			return _from_rising(state, intent, ctx, tuning)
		PlayerState.State.FALL:
			return _from_fall(intent, ctx)
		PlayerState.State.LANDING:
			return _from_landing(intent, ctx, tuning)
		PlayerState.State.SLIDE, PlayerState.State.ROLL:
			if not ctx.on_floor:
				return PlayerState.State.FALL
			if not can_exit(state, intent, ctx, tuning):
				return state
			if wants_jump(ctx):
				return PlayerState.State.JUMP
			return ground_state_for(intent)
		PlayerState.State.VAULT:
			if not can_exit(state, intent, ctx, tuning):
				return state
			return ground_state_for(intent) if ctx.on_floor else PlayerState.State.FALL
		PlayerState.State.WALL_RUN:
			return _from_wall_run(intent, ctx, tuning)
		PlayerState.State.WALL_CLIMB:
			return _from_wall_climb(intent, ctx)
		PlayerState.State.LEDGE_HANG:
			if not can_exit(state, intent, ctx, tuning):
				return state
			if wants_jump(ctx) or pushing_forward(intent, ctx):
				return PlayerState.State.JUMP
			return PlayerState.State.FALL
	return state


static func _from_ground(
	intent: IntentFrame, ctx: MovementContext, tuning: MoveTuning
) -> PlayerState.State:
	if wants_jump(ctx) and can_ground_jump(ctx):
		return PlayerState.State.JUMP
	if not ctx.on_floor and ctx.coyote_left <= 0.0:
		return PlayerState.State.FALL
	if wants_vault(intent, ctx, tuning):
		return PlayerState.State.VAULT
	if wants_wall_run(intent, ctx, tuning):
		return PlayerState.State.WALL_RUN
	if wants_slide(ctx, tuning):
		return PlayerState.State.SLIDE
	return ground_state_for(intent)


static func _from_rising(
	state: PlayerState.State, intent: IntentFrame, ctx: MovementContext, tuning: MoveTuning
) -> PlayerState.State:
	if wants_ledge(ctx):
		return PlayerState.State.LEDGE_HANG
	if state == PlayerState.State.JUMP:
		if wants_double_jump(ctx):
			return PlayerState.State.DOUBLE_JUMP
		if wants_wall_run(intent, ctx, tuning):
			return PlayerState.State.WALL_RUN
	if ctx.velocity.y >= 0.0:
		if ctx.on_floor:
			return PlayerState.State.LANDING
		if wants_wall_climb(intent, ctx):
			return PlayerState.State.WALL_CLIMB
		return PlayerState.State.FALL
	return state


static func _from_fall(intent: IntentFrame, ctx: MovementContext) -> PlayerState.State:
	if ctx.on_floor:
		return PlayerState.State.LANDING
	if wants_ledge(ctx):
		return PlayerState.State.LEDGE_HANG
	if wants_double_jump(ctx):
		return PlayerState.State.DOUBLE_JUMP
	if wants_wall_climb(intent, ctx):
		return PlayerState.State.WALL_CLIMB
	return PlayerState.State.FALL


static func _from_landing(
	intent: IntentFrame, ctx: MovementContext, tuning: MoveTuning
) -> PlayerState.State:
	if not ctx.on_floor:
		return PlayerState.State.FALL
	if wants_jump(ctx):
		return PlayerState.State.JUMP
	# Glisse pendant la réception : roulade si l'impact est dur (annule
	# l'immobilisation), glissade sinon. L'élan est conservé dans les deux cas.
	if wants_slide(ctx, tuning):
		return PlayerState.State.ROLL if is_hard_landing(ctx, tuning) else PlayerState.State.SLIDE
	if ctx.time_in_state >= landing_duration(ctx, tuning):
		return ground_state_for(intent)
	return PlayerState.State.LANDING


static func _from_wall_run(
	intent: IntentFrame, ctx: MovementContext, tuning: MoveTuning
) -> PlayerState.State:
	if wants_ledge(ctx):
		return PlayerState.State.LEDGE_HANG
	if wants_jump(ctx):
		return PlayerState.State.JUMP
	if not ctx.wall_ahead:
		return PlayerState.State.FALL
	if ctx.time_in_state >= tuning.wall_run_duration:
		return PlayerState.State.WALL_CLIMB if wants_wall_climb(intent, ctx) else PlayerState.State.FALL
	return PlayerState.State.WALL_RUN


static func _from_wall_climb(intent: IntentFrame, ctx: MovementContext) -> PlayerState.State:
	if wants_ledge(ctx):
		return PlayerState.State.LEDGE_HANG
	if wants_jump(ctx):
		return PlayerState.State.JUMP
	if ctx.on_floor:
		return ground_state_for(intent)
	if not wants_wall_climb(intent, ctx):
		return PlayerState.State.FALL
	return PlayerState.State.WALL_CLIMB
