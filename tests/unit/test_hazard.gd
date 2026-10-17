extends GutTest
## Pièges (Hazard) hors physique : fenêtres de danger sur un cycle, annonce avant le
## danger, déterminisme de l'horloge, remise à zéro et zone mortelle bornée.

const STEP: float = 1.0 / 60.0


func _spec(kind: StringName, rect: Rect2, path_to: Vector2 = Vector2.ZERO, period: float = 0.0,
		active_ratio: float = 0.5, phase: float = 0.0) -> HazardSpec:
	var spec: HazardSpec = HazardSpec.new()
	spec.kind = kind
	spec.rect = rect
	spec.path_to = path_to
	spec.period = period
	spec.active_ratio = active_ratio
	spec.phase = phase
	return spec


func _make(spec: HazardSpec) -> Hazard:
	var hazard: Hazard = Hazard.create(spec, null)
	autofree(hazard)
	return hazard


## Part du cycle pendant laquelle le piège est dangereux (échantillonnage fin).
func _danger_fraction(hazard: Hazard, period: float) -> float:
	var hits: int = 0
	const SAMPLES: int = 600
	for i: int in SAMPLES:
		if hazard.is_dangerous_at(period * float(i) / float(SAMPLES)):
			hits += 1
	return float(hits) / float(SAMPLES)


func _contains(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(0.01).encloses(inner)


func test_spikes_are_always_lethal_inside_their_rect() -> void:
	var spec: HazardSpec = _spec(&"spikes", Rect2(100, -16, 64, 16))
	var hazard: Hazard = _make(spec)
	for t: float in [0.0, 0.7, 5.3]:
		hazard.set_time(t)
		assert_true(hazard.is_dangerous())
		assert_true(_contains(spec.rect, hazard.danger_rect()), "zone mortelle dans le rectangle")
		assert_gt(hazard.danger_rect().size.x, 50.0, "pas réduite à rien")


func test_saw_moves_back_and_forth_smoothly_and_is_always_lethal() -> void:
	var spec: HazardSpec = _spec(&"saw", Rect2(0, -120, 60, 60), Vector2(200, 0), 2.0)
	var hazard: Hazard = _make(spec)
	var start: Vector2 = spec.rect.get_center()
	hazard.set_time(0.0)
	assert_almost_eq(hazard.danger_rect().get_center(), start, Vector2.ONE * 0.01)
	hazard.set_time(1.0)
	assert_almost_eq(hazard.danger_rect().get_center(), start + spec.path_to, Vector2.ONE * 0.01)
	hazard.set_time(2.0)
	assert_almost_eq(hazard.danger_rect().get_center(), start, Vector2.ONE * 0.01)
	var bounds: Rect2 = spec.rect.merge(Rect2(spec.rect.position + spec.path_to, spec.rect.size))
	var previous: Vector2 = start
	for i: int in 121:
		hazard.set_time(float(i) / 60.0)
		assert_true(hazard.is_dangerous())
		var rect: Rect2 = hazard.danger_rect()
		assert_true(_contains(bounds, rect), "reste sur son rail")
		assert_lt(rect.get_center().distance_to(previous), 6.0, "pas de saut")
		previous = rect.get_center()


func test_saw_phase_offsets_the_cycle() -> void:
	var spec: HazardSpec = _spec(&"saw", Rect2(0, -120, 60, 60), Vector2(0, 100), 2.0, 0.5, 0.5)
	var hazard: Hazard = _make(spec)
	assert_almost_eq(hazard.danger_rect().get_center(), spec.rect.get_center() + spec.path_to,
			Vector2.ONE * 0.01, "à mi-cycle dès le départ")


func test_crusher_shakes_then_slams_then_rises_slowly() -> void:
	var spec: HazardSpec = _spec(&"crusher", Rect2(-30, -200, 60, 50), Vector2(0, 150), 3.0, 0.4)
	var hazard: Hazard = _make(spec)
	assert_eq(hazard.crusher_offset(), Vector2.ZERO, "en haut au départ")
	assert_false(hazard.is_dangerous())
	assert_almost_eq(_danger_fraction(hazard, 3.0), 0.4, 0.02, "danger = active_ratio du cycle")
	# Repère les phases en avançant pas à pas.
	var shake_time: float = 0.0
	var danger_start: float = -1.0
	var bottom_time: float = -1.0
	var rise_start: float = -1.0
	var previous: float = 0.0
	for i: int in 180:
		hazard.advance(STEP)
		var t: float = hazard.get_time()
		if hazard.is_telegraphing():
			shake_time += STEP
			assert_eq(hazard.crusher_offset(), Vector2.ZERO, "tremble sur place")
		if hazard.is_dangerous() and danger_start < 0.0:
			danger_start = t
		if bottom_time < 0.0 and hazard.crusher_offset().y >= 150.0:
			bottom_time = t
		if danger_start >= 0.0 and not hazard.is_dangerous() and rise_start < 0.0:
			rise_start = t
			assert_almost_eq(hazard.crusher_offset().y, 150.0, 5.0, "inoffensif dès qu'il remonte")
		if rise_start > 0.0:
			assert_lt(hazard.crusher_offset().y, previous + 0.001, "remonte sans redescendre")
		previous = hazard.crusher_offset().y
	assert_almost_eq(shake_time, Hazard.CRUSHER_SHAKE, 0.04, "tremblement d'annonce ~0,3 s")
	assert_gt(danger_start, 0.3, "annoncé avant de frapper")
	assert_lt(bottom_time - danger_start, 0.16, "chute très rapide")
	assert_gt(rise_start, bottom_time)
	assert_gt(3.0 - rise_start, 0.6, "remonte lentement")


func test_crusher_danger_rect_follows_the_block() -> void:
	var spec: HazardSpec = _spec(&"crusher", Rect2(-30, -200, 60, 50), Vector2(0, 150), 3.0, 0.4)
	var hazard: Hazard = _make(spec)
	var bounds: Rect2 = spec.rect.merge(Rect2(spec.rect.position + spec.path_to, spec.rect.size)).grow_side(
			SIDE_BOTTOM, Hazard.CRUSHER_LIP)
	for i: int in 180:
		hazard.set_time(float(i) / 60.0)
		var rect: Rect2 = hazard.danger_rect()
		if hazard.is_dangerous():
			assert_true(_contains(bounds, rect), "dans la course du bloc")
			assert_almost_eq(rect.end.y, spec.rect.end.y + hazard.crusher_offset().y + Hazard.CRUSHER_LIP, 0.01,
					"le bas du bloc tue")
			assert_gt(rect.position.y, spec.rect.position.y + hazard.crusher_offset().y, "le dessus ne tue pas")
		else:
			assert_eq(rect, Rect2(), "vide quand inoffensif")


func test_flame_is_lit_for_active_ratio_and_warns_before_igniting() -> void:
	var spec: HazardSpec = _spec(&"flame", Rect2(0, -140, 40, 140), Vector2.ZERO, 2.0, 0.4)
	var hazard: Hazard = _make(spec)
	assert_false(hazard.is_dangerous(), "éteinte au départ")
	assert_almost_eq(_danger_fraction(hazard, 2.0), 0.4, 0.01)
	var warn_time: float = 0.0
	var lit_at: float = -1.0
	for i: int in 120:
		hazard.advance(STEP)
		if hazard.is_telegraphing():
			warn_time += STEP
			assert_false(hazard.is_dangerous(), "l'annonce est inoffensive")
			assert_eq(hazard.danger_rect(), Rect2())
		if hazard.is_dangerous() and lit_at < 0.0:
			lit_at = hazard.get_time()
			assert_true(_contains(spec.rect, hazard.danger_rect()))
	assert_almost_eq(warn_time, Hazard.FLAME_TELEGRAPH, 0.04, "crépite ~0,35 s avant")
	assert_almost_eq(lit_at, 1.2, 0.03)


func test_flame_without_period_burns_forever() -> void:
	var hazard: Hazard = _make(_spec(&"flame", Rect2(0, -140, 40, 140)))
	for t: float in [0.0, 1.0, 9.0]:
		assert_true(hazard.is_dangerous_at(t))


func test_flame_danger_rect_excludes_the_nozzle_for_each_direction() -> void:
	var up: Hazard = _make(_spec(&"flame", Rect2(0, -140, 40, 140)))
	assert_almost_eq(up.danger_rect().end.y, -Hazard.FLAME_NOZZLE, 0.01)
	var down: Hazard = _make(_spec(&"flame", Rect2(0, -140, 40, 140), Vector2(0, 1)))
	assert_almost_eq(down.danger_rect().position.y, -140.0 + Hazard.FLAME_NOZZLE, 0.01)
	var right: Hazard = _make(_spec(&"flame", Rect2(0, -40, 160, 40)))
	assert_almost_eq(right.danger_rect().position.x, Hazard.FLAME_NOZZLE, 0.01)
	var left: Hazard = _make(_spec(&"flame", Rect2(0, -40, 160, 40), Vector2(-1, 0)))
	assert_almost_eq(left.danger_rect().end.x, 160.0 - Hazard.FLAME_NOZZLE, 0.01)


func test_clock_is_deterministic_and_set_time_matches_advance() -> void:
	var spec: HazardSpec = _spec(&"crusher", Rect2(0, -200, 60, 50), Vector2(0, 150), 2.5, 0.35, 0.3)
	var a: Hazard = _make(spec)
	var b: Hazard = _make(spec)
	var c: Hazard = _make(spec)
	for i: int in 200:
		a.advance(STEP)
		b.advance(STEP)
		c.set_time(STEP * float(i + 1))
		assert_eq(a.is_dangerous(), b.is_dangerous())
		assert_almost_eq(a.crusher_offset(), b.crusher_offset(), Vector2.ONE * 0.0001)
		assert_almost_eq(a.crusher_offset(), c.crusher_offset(), Vector2.ONE * 0.001)


func test_reset_restores_the_initial_state() -> void:
	var crusher: Hazard = _make(_spec(&"crusher", Rect2(0, -200, 60, 50), Vector2(0, 150), 2.0, 0.4))
	crusher.set_time(1.3)
	assert_ne(crusher.crusher_offset(), Vector2.ZERO)
	crusher.reset()
	assert_eq(crusher.get_time(), 0.0)
	assert_eq(crusher.crusher_offset(), Vector2.ZERO)
	var crumble: Hazard = _make(_spec(&"crumble", Rect2(0, 0, 120, 16)))
	crumble.trigger()
	crumble.advance(1.0)
	assert_false(crumble.is_solid())
	crumble.reset()
	assert_true(crumble.is_solid())
	assert_eq(crumble.crumble_state(), Hazard.CrumbleState.SOLID)


func test_crumble_falls_after_the_delay_and_comes_back() -> void:
	var hazard: Hazard = _make(_spec(&"crumble", Rect2(0, 0, 120, 16)))
	assert_true(hazard.is_solid())
	assert_false(hazard.is_dangerous(), "jamais mortelle")
	hazard.advance(2.0)
	assert_true(hazard.is_solid(), "ne tombe pas sans qu'on s'y pose")
	hazard.trigger()
	assert_true(hazard.is_telegraphing(), "tremble")
	var fall_time: float = 0.0
	while hazard.is_solid() and fall_time < 2.0:
		hazard.advance(STEP)
		fall_time += STEP
	assert_almost_eq(fall_time, Hazard.CRUMBLE_DELAY, 0.02)
	var back: float = 0.0
	while not hazard.is_solid() and back < 6.0:
		hazard.advance(STEP)
		back += STEP
	assert_almost_eq(back, Hazard.CRUMBLE_RESPAWN, 0.02)
	assert_false(hazard.is_dangerous())
	assert_eq(hazard.danger_rect(), Rect2())


func test_collision_layers() -> void:
	var spikes: Hazard = _make(_spec(&"spikes", Rect2(0, -16, 64, 16)))
	var area: Area2D = spikes.get_child(0) as Area2D
	assert_eq(area.collision_layer, CollisionLayers.HAZARD)
	assert_eq(area.collision_mask, CollisionLayers.PLAYER)
	var crusher: Hazard = _make(_spec(&"crusher", Rect2(0, -200, 60, 50), Vector2(0, 150), 2.0))
	var body: AnimatableBody2D = crusher.get_child(0) as AnimatableBody2D
	assert_not_null(body, "écraseur solide")
	assert_eq(body.collision_layer, CollisionLayers.WORLD)
	var crumble: Hazard = _make(_spec(&"crumble", Rect2(0, 0, 120, 16)))
	var platform: StaticBody2D = crumble.get_child(0) as StaticBody2D
	assert_not_null(platform)
	assert_eq(platform.collision_layer, CollisionLayers.WORLD)


func test_theme_colours_are_used() -> void:
	var theme: CityTheme = CityTheme.new()
	theme.ink = Color(0.1, 0.0, 0.0)
	theme.accent = Color(0.0, 1.0, 0.0)
	var hazard: Hazard = Hazard.create(_spec(&"spikes", Rect2(0, -16, 64, 16)), theme)
	autofree(hazard)
	assert_eq(hazard.ink, theme.ink)
	assert_eq(hazard.accent, theme.accent)
	var plain: Hazard = _make(_spec(&"spikes", Rect2(0, -16, 64, 16)))
	assert_eq(plain.ink, Hazard.DEFAULT_INK)
