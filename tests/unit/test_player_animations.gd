extends GutTest
## Données d'animation du joueur (data/animations/player_anims.tres).

const ANIMS_PATH: String = "res://data/animations/player_anims.tres"
## États implémentés (M1 + M2).
const IMPLEMENTED_STATES: Array[int] = [
	PlayerState.State.IDLE,
	PlayerState.State.RUN,
	PlayerState.State.SPRINT,
	PlayerState.State.JUMP,
	PlayerState.State.FALL,
	PlayerState.State.LANDING,
	PlayerState.State.SLIDE,
	PlayerState.State.DOUBLE_JUMP,
	PlayerState.State.ROLL,
	PlayerState.State.VAULT,
	PlayerState.State.WALL_RUN,
	PlayerState.State.WALL_CLIMB,
	PlayerState.State.LEDGE_HANG,
]


func test_every_implemented_state_has_its_own_clip() -> void:
	var anims: AnimationSet = load(ANIMS_PATH) as AnimationSet
	assert_not_null(anims)
	for state: int in IMPLEMENTED_STATES:
		var state_name: StringName = PlayerState.name_of(state as PlayerState.State)
		assert_true(anims.has_clip(state_name), "clip manquant : %s" % state_name)


func test_future_states_fall_back_to_idle() -> void:
	var anims: AnimationSet = load(ANIMS_PATH) as AnimationSet
	var fallback: AnimClip = anims.clip_for(PlayerState.name_of(PlayerState.State.ATTACK))
	assert_eq(fallback, anims.clip_for(&"idle"))


func test_player_tuning_resource_loads() -> void:
	var tuning: MoveTuning = load("res://data/tuning/player_move.tres") as MoveTuning
	assert_not_null(tuning)
	assert_gt(tuning.sprint_speed, tuning.run_speed)
