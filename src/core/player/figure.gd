class_name Figure
extends RefCounted
## Figures de parkour : variantes d'un état choisies selon le contexte à
## l'entrée de cet état. Elles ont un effet de jeu (tic-tac, kong, lazy) et/ou
## une animation par images clés synchronisée sur la physique (saltos, vrille).
## Logique pure, testable sans scène.

enum Kind {
	NONE,
	SPEED_VAULT,
	KONG_VAULT,
	LAZY_VAULT,
	TIC_TAC,
	WALL_FLIP,
	FRONT_FLIP,
	CORKSCREW,
	CAT_LEAP,
	PARKOUR_ROLL,
}

## Durée d'une arrivée en cat leap (amorti contre le mur).
const CAT_LEAP_DURATION: float = 0.25


static func name_of(kind: Kind) -> StringName:
	return StringName(String(Kind.keys()[kind]).to_lower())


## Figure à jouer quand l'acteur entre dans `to` depuis `from`.
static func choose(
	from: PlayerState.State, to: PlayerState.State, ctx: MovementContext, tuning: MoveTuning
) -> Kind:
	var speed: float = absf(ctx.velocity.x)
	match to:
		PlayerState.State.VAULT:
			if ctx.wall_top_height > tuning.vault_max_height:
				return Kind.TIC_TAC
			if speed < tuning.lazy_vault_max_speed:
				return Kind.LAZY_VAULT
			if speed >= tuning.kong_min_speed and ctx.obstacle_height >= tuning.kong_min_height:
				return Kind.KONG_VAULT
			return Kind.SPEED_VAULT
		PlayerState.State.JUMP:
			if from == PlayerState.State.WALL_RUN or from == PlayerState.State.WALL_CLIMB:
				return Kind.WALL_FLIP
			if speed >= tuning.front_flip_min_speed and ctx.edge_ahead:
				return Kind.FRONT_FLIP
		PlayerState.State.DOUBLE_JUMP:
			return Kind.CORKSCREW
		PlayerState.State.LEDGE_HANG:
			var airborne: bool = (
				from == PlayerState.State.JUMP
				or from == PlayerState.State.FALL
				or from == PlayerState.State.DOUBLE_JUMP
				or from == PlayerState.State.VAULT
			)
			# Élan d'arrivée : le corps est souvent déjà plaqué au mur (vitesse nulle).
			if airborne and maxf(speed, ctx.air_speed_x) >= tuning.cat_leap_min_speed:
				return Kind.CAT_LEAP
		PlayerState.State.ROLL:
			return Kind.PARKOUR_ROLL
	return Kind.NONE


## Vrai si la figure en cours continue quand l'acteur passe dans `state`
## (ex. un salto se poursuit de la montée à la descente).
static func carries_into(kind: Kind, state: PlayerState.State) -> bool:
	match kind:
		Kind.FRONT_FLIP, Kind.WALL_FLIP, Kind.CORKSCREW:
			return state == PlayerState.State.FALL
		Kind.SPEED_VAULT, Kind.KONG_VAULT, Kind.LAZY_VAULT, Kind.TIC_TAC:
			return state == PlayerState.State.FALL
	return false


## Durée prévue de la figure (s), calculée sur la vitesse de départ réelle
## pour que l'animation finisse avec le mouvement (le salto avant l'atterrissage).
static func expected_duration(kind: Kind, velocity: Vector2, tuning: MoveTuning) -> float:
	match kind:
		Kind.CAT_LEAP:
			return CAT_LEAP_DURATION
		Kind.PARKOUR_ROLL:
			return tuning.roll_duration
		Kind.NONE:
			return 0.0
	# Vol balistique : montée à gravité réduite (Saut maintenu), descente normale,
	# jusqu'à revenir à la hauteur de départ.
	var up_speed: float = maxf(-velocity.y, 0.0)
	var rise_time: float = up_speed / tuning.gravity_up
	var apex: float = up_speed * up_speed / (2.0 * tuning.gravity_up)
	var fall_time: float = sqrt(2.0 * apex / tuning.gravity_down)
	return maxf((rise_time + fall_time) * 0.9, 0.2)
