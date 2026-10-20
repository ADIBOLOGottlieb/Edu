extends GutTest
## Tutoriel « Premiers pas » (ADR-051) : la leçon suit le tronçon, chaque geste
## attendu la valide, une leçon réussie le reste.


func test_lesson_follows_the_chunk() -> void:
	var steps: TutorialSteps = TutorialSteps.new()
	assert_eq(steps.current, -1)
	assert_true(steps.update(&"t_run", &"IDLE", 10.0, false))
	assert_eq(steps.current, 0)
	assert_string_contains(steps.text(), "courir")
	assert_false(steps.update(&"t_run", &"IDLE", 20.0, false), "rien de nouveau")
	assert_true(steps.update(&"t_jump", &"RUN", 10.0, false))
	assert_eq(steps.current, 1)
	steps.update(&"inconnu", &"RUN", 0.0, false)
	assert_eq(steps.current, 1, "tronçon hors tutoriel : la leçon reste")


func test_each_gesture_validates_its_lesson() -> void:
	var steps: TutorialSteps = TutorialSteps.new()
	var cases: Array[Array] = [
		[&"t_run", &"RUN", 0.0, false],
		[&"t_jump", &"JUMP", 0.0, false],
		[&"t_slide", &"SLIDE", 0.0, false],
		[&"t_vault", &"VAULT", 0.0, false],
		[&"t_climb", &"WALL_CLIMB", 0.0, false],
		[&"t_sprint", &"SPRINT", 0.0, false],
		[&"t_item", &"RUN", 0.0, true],
		[&"t_spikes", &"RUN", 600.0, false],
	]
	for c: Array in cases:
		steps.update(c[0], &"IDLE", 0.0, false)
		assert_false(steps.is_current_done(), "%s pas encore réussie" % c[0])
		steps.update(c[0], c[1], c[2], c[3])
		assert_true(steps.is_current_done(), "%s réussie" % c[0])
	assert_eq(steps.done_count(), 8)


func test_wrong_gesture_does_not_validate_and_success_stays() -> void:
	var steps: TutorialSteps = TutorialSteps.new()
	steps.update(&"t_slide", &"JUMP", 0.0, true)
	assert_false(steps.is_current_done(), "sauter ne valide pas la glissade")
	steps.update(&"t_slide", &"SLIDE", 0.0, false)
	steps.update(&"t_slide", &"RUN", 0.0, false)
	assert_true(steps.is_current_done(), "réussie, elle le reste")


func test_lessons_have_unique_chunks_and_text() -> void:
	var seen: Dictionary = {}
	for lesson: Dictionary in TutorialSteps.LESSONS:
		assert_false(seen.has(lesson["chunk"]))
		seen[lesson["chunk"]] = true
		assert_ne(str(lesson["text"]), "")
