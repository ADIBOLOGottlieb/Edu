extends GutTest
## Figures de parkour : choix, poursuite, durée, tic-tac, impulsions, images clés.

const FIGURES_PATH: String = "res://data/animations/player_figures.tres"

var _tuning: MoveTuning
var _intent: IntentFrame
var _ctx: MovementContext


func before_each() -> void:
	_tuning = MoveTuning.new()
	_intent = IntentFrame.new()
	_ctx = MovementContext.new()
	_ctx.on_floor = true
	_ctx.facing = 1
	_ctx.wall_climb_left = _tuning.wall_climb_max_time


func _choose(from: PlayerState.State, to: PlayerState.State) -> Figure.Kind:
	return Figure.choose(from, to, _ctx, _tuning)


# --- Choix des figures ---------------------------------------------------------------

func test_vault_variant_depends_on_speed_and_obstacle() -> void:
	_ctx.obstacle_height = 40.0
	_ctx.velocity.x = 300.0
	assert_eq(_choose(PlayerState.State.RUN, PlayerState.State.VAULT), Figure.Kind.LAZY_VAULT)
	_ctx.velocity.x = 400.0
	assert_eq(_choose(PlayerState.State.RUN, PlayerState.State.VAULT), Figure.Kind.SPEED_VAULT)
	_ctx.velocity.x = 480.0
	assert_eq(_choose(PlayerState.State.SPRINT, PlayerState.State.VAULT), Figure.Kind.KONG_VAULT)
	_ctx.obstacle_height = 20.0
	assert_eq(_choose(PlayerState.State.SPRINT, PlayerState.State.VAULT), Figure.Kind.SPEED_VAULT, "obstacle trop bas pour un kong")


func test_vault_over_a_low_wall_is_a_tic_tac() -> void:
	_ctx.wall_top_height = 100.0
	_ctx.velocity.x = 480.0
	assert_eq(_choose(PlayerState.State.SPRINT, PlayerState.State.VAULT), Figure.Kind.TIC_TAC)
	assert_eq(_choose(PlayerState.State.JUMP, PlayerState.State.VAULT), Figure.Kind.TIC_TAC)


func test_jump_figures() -> void:
	_ctx.velocity.x = 480.0
	assert_eq(_choose(PlayerState.State.WALL_RUN, PlayerState.State.JUMP), Figure.Kind.WALL_FLIP)
	assert_eq(_choose(PlayerState.State.WALL_CLIMB, PlayerState.State.JUMP), Figure.Kind.WALL_FLIP)
	assert_eq(_choose(PlayerState.State.SPRINT, PlayerState.State.JUMP), Figure.Kind.NONE, "pas de vide devant")
	_ctx.edge_ahead = true
	assert_eq(_choose(PlayerState.State.SPRINT, PlayerState.State.JUMP), Figure.Kind.FRONT_FLIP)
	_ctx.velocity.x = 320.0
	assert_eq(_choose(PlayerState.State.RUN, PlayerState.State.JUMP), Figure.Kind.NONE, "trop lent pour un salto")


func test_double_jump_is_a_corkscrew_and_roll_a_parkour_roll() -> void:
	assert_eq(_choose(PlayerState.State.JUMP, PlayerState.State.DOUBLE_JUMP), Figure.Kind.CORKSCREW)
	assert_eq(_choose(PlayerState.State.LANDING, PlayerState.State.ROLL), Figure.Kind.PARKOUR_ROLL)


func test_cat_leap_needs_an_airborne_arrival_with_momentum() -> void:
	_ctx.velocity.x = 0.0
	_ctx.air_speed_x = 256.0
	assert_eq(_choose(PlayerState.State.JUMP, PlayerState.State.LEDGE_HANG), Figure.Kind.CAT_LEAP, "élan d'arrivée, corps plaqué au mur")
	assert_eq(_choose(PlayerState.State.WALL_CLIMB, PlayerState.State.LEDGE_HANG), Figure.Kind.NONE, "arrivée en escaladant")
	_ctx.air_speed_x = 100.0
	assert_eq(_choose(PlayerState.State.FALL, PlayerState.State.LEDGE_HANG), Figure.Kind.NONE, "trop peu d'élan")


func test_flips_carry_through_the_fall_but_stop_on_landing() -> void:
	assert_true(Figure.carries_into(Figure.Kind.FRONT_FLIP, PlayerState.State.FALL))
	assert_false(Figure.carries_into(Figure.Kind.FRONT_FLIP, PlayerState.State.LANDING))
	assert_true(Figure.carries_into(Figure.Kind.TIC_TAC, PlayerState.State.FALL))
	assert_false(Figure.carries_into(Figure.Kind.CAT_LEAP, PlayerState.State.JUMP))


func test_expected_duration_follows_the_real_flight_time() -> void:
	var v: Vector2 = Vector2(480, -_tuning.jump_velocity)
	var flight: float = _tuning.jump_velocity / _tuning.gravity_up + sqrt(
		2.0 * LevelValidator.jump_apex(_tuning) / _tuning.gravity_down
	)
	assert_almost_eq(Figure.expected_duration(Figure.Kind.FRONT_FLIP, v, _tuning), flight * 0.9, 0.001)
	assert_eq(Figure.expected_duration(Figure.Kind.CAT_LEAP, v, _tuning), Figure.CAT_LEAP_DURATION)
	assert_eq(Figure.expected_duration(Figure.Kind.PARKOUR_ROLL, v, _tuning), _tuning.roll_duration)


# --- Tic-tac dans le décideur et le moteur ----------------------------------------------

func test_sprinting_at_a_low_wall_tic_tacs_and_a_tall_wall_is_wall_run() -> void:
	_intent.move_axis = 1.0
	_ctx.wall_ahead = true
	_ctx.velocity = Vector2(480, 0)
	_ctx.wall_top_height = 100.0
	assert_eq(MovementDecider.next_state(PlayerState.State.SPRINT, _intent, _ctx, _tuning), PlayerState.State.VAULT)
	_ctx.wall_top_height = 0.0  # mur plus haut que la zone analysée
	assert_eq(MovementDecider.next_state(PlayerState.State.SPRINT, _intent, _ctx, _tuning), PlayerState.State.WALL_RUN)


func test_tic_tac_needs_speed_and_the_air_resource() -> void:
	_intent.move_axis = 1.0
	_ctx.wall_ahead = true
	_ctx.wall_top_height = 100.0
	_ctx.velocity = Vector2(_tuning.tic_tac_min_speed - 1.0, 0)
	assert_false(MovementDecider.wants_tic_tac(_intent, _ctx, _tuning))
	_ctx.velocity = Vector2(480, 0)
	_ctx.can_wall_run = false
	assert_false(MovementDecider.wants_tic_tac(_intent, _ctx, _tuning), "une fois par phase aérienne")


func test_fast_airborne_runner_tic_tacs_instead_of_hanging() -> void:
	_intent.move_axis = 1.0
	_ctx.on_floor = false
	_ctx.velocity = Vector2(480, -100)
	_ctx.wall_ahead = true
	_ctx.ledge_available = true
	_ctx.wall_top_height = 70.0
	assert_eq(MovementDecider.next_state(PlayerState.State.JUMP, _intent, _ctx, _tuning), PlayerState.State.VAULT)
	_ctx.velocity.x = 150.0
	assert_eq(MovementDecider.next_state(PlayerState.State.JUMP, _intent, _ctx, _tuning), PlayerState.State.LEDGE_HANG, "lent : s'accroche")


func test_tic_tac_and_kong_impulses() -> void:
	_ctx.figure = Figure.Kind.TIC_TAC
	_ctx.wall_top_height = 100.0
	var tic: Vector2 = LocomotionMotor.on_enter(PlayerState.State.SPRINT, PlayerState.State.VAULT, Vector2(480, 0), _ctx, _tuning)
	assert_almost_eq(tic.y * tic.y / (2.0 * _tuning.gravity_down), 100.0 + _tuning.tic_tac_clearance, 0.01)
	_ctx.figure = Figure.Kind.KONG_VAULT
	_ctx.obstacle_height = 40.0
	var kong: Vector2 = LocomotionMotor.on_enter(PlayerState.State.SPRINT, PlayerState.State.VAULT, Vector2(480, 0), _ctx, _tuning)
	assert_almost_eq(kong.x, 480.0 * _tuning.kong_boost, 0.01, "plongeon plus rapide")
	assert_almost_eq(kong.y * kong.y / (2.0 * _tuning.gravity_down), 40.0 + _tuning.kong_clearance, 0.01, "et plus bas")


func test_airborne_states_may_enter_vault_for_a_tic_tac() -> void:
	for from: PlayerState.State in [PlayerState.State.JUMP, PlayerState.State.FALL, PlayerState.State.DOUBLE_JUMP]:
		assert_true(PlayerFsmRules.is_allowed(from, PlayerState.State.VAULT), PlayerState.name_of(from))


# --- Images clés ----------------------------------------------------------------------

func test_every_figure_has_a_valid_animation() -> void:
	var library: FigureLibrary = load(FIGURES_PATH) as FigureLibrary
	assert_not_null(library)
	for kind: int in Figure.Kind.values():
		if kind == Figure.Kind.NONE:
			continue
		var figure_name: StringName = Figure.name_of(kind as Figure.Kind)
		var animation: FigureAnimation = library.get_animation(figure_name)
		assert_not_null(animation, "animation manquante : %s" % figure_name)
		if animation != null:
			assert_true(animation.is_valid(), "images clés invalides : %s" % figure_name)


func test_flips_end_upright_after_full_turns() -> void:
	var library: FigureLibrary = load(FIGURES_PATH) as FigureLibrary
	for figure_name: StringName in [&"front_flip", &"wall_flip", &"corkscrew", &"parkour_roll"]:
		var start: Dictionary[StringName, float] = library.get_animation(figure_name).sample(0.0)
		var finish: Dictionary[StringName, float] = library.get_animation(figure_name).sample(1.0)
		assert_eq(start[&"rotation"], 0.0, "%s commence droit" % figure_name)
		assert_almost_eq(absf(finish[&"rotation"]), TAU, 0.001, "%s fait un tour complet" % figure_name)
	var back: Dictionary[StringName, float] = library.get_animation(&"wall_flip").sample(1.0)
	assert_lt(back[&"rotation"], 0.0, "le wall flip tourne vers l'arrière")


func test_sampling_interpolates_between_keys() -> void:
	var animation: FigureAnimation = (load(FIGURES_PATH) as FigureLibrary).get_animation(&"corkscrew")
	var middle: float = animation.sample(0.25)[&"rotation"]
	assert_between(middle, 0.0, PI, "entre la 1re et la 2e image clé")
	assert_eq(animation.sample(-1.0)[&"rotation"], 0.0, "borné au début")
	assert_almost_eq(animation.sample(2.0)[&"rotation"], TAU, 0.001, "borné à la fin")
