class_name MovementDecider
extends RefCounted
## Choisit l'état de locomotion souhaité à partir de l'intention et du contexte
## physique. Logique pure : aucune dépendance au moteur, testable tick par tick.
## La PlayerFSM reste juge de l'acceptation (table + priorités).

const AXIS_DEADZONE: float = 0.1


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


static func landing_duration(ctx: MovementContext, tuning: MoveTuning) -> float:
	if ctx.impact_speed >= tuning.landing_hard_speed:
		return tuning.landing_hard_duration
	return tuning.landing_soft_duration


## Vrai si l'état courant a fini son action et peut céder la place à un état
## moins prioritaire (sert de garde à PlayerFSM.exit_allowed).
static func can_exit(
	state: PlayerState.State, ctx: MovementContext, tuning: MoveTuning
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
	return true


static func ground_state_for(intent: IntentFrame) -> PlayerState.State:
	if absf(intent.move_axis) < AXIS_DEADZONE:
		return PlayerState.State.IDLE
	if intent.sprint_held:
		return PlayerState.State.SPRINT
	return PlayerState.State.RUN


static func next_state(
	state: PlayerState.State, intent: IntentFrame, ctx: MovementContext, tuning: MoveTuning
) -> PlayerState.State:
	match state:
		PlayerState.State.IDLE, PlayerState.State.RUN, PlayerState.State.SPRINT:
			if wants_jump(ctx) and can_ground_jump(ctx):
				return PlayerState.State.JUMP
			if not ctx.on_floor and ctx.coyote_left <= 0.0:
				return PlayerState.State.FALL
			if wants_slide(ctx, tuning):
				return PlayerState.State.SLIDE
			return ground_state_for(intent)
		PlayerState.State.JUMP:
			if ctx.velocity.y >= 0.0:
				return PlayerState.State.LANDING if ctx.on_floor else PlayerState.State.FALL
			return PlayerState.State.JUMP
		PlayerState.State.FALL:
			return PlayerState.State.LANDING if ctx.on_floor else PlayerState.State.FALL
		PlayerState.State.LANDING:
			if not ctx.on_floor:
				return PlayerState.State.FALL
			if wants_jump(ctx):
				return PlayerState.State.JUMP
			# Réception enchaînée en glissade : l'élan est conservé.
			if wants_slide(ctx, tuning):
				return PlayerState.State.SLIDE
			if ctx.time_in_state >= landing_duration(ctx, tuning):
				return ground_state_for(intent)
			return PlayerState.State.LANDING
		PlayerState.State.SLIDE:
			if not ctx.on_floor:
				return PlayerState.State.FALL
			if not can_exit(state, ctx, tuning):
				return PlayerState.State.SLIDE
			if wants_jump(ctx):
				return PlayerState.State.JUMP
			return ground_state_for(intent)
	return state
