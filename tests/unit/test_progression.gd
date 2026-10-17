extends GutTest
## Progression : étoiles, meilleurs temps, déblocage des parcours et des villes,
## sérialisation bornée ; réglages bornés.


func _city(count: int, id: StringName = &"c") -> CityDefinition:
	var city: CityDefinition = CityDefinition.new()
	city.id = id
	var routes: Array[CityRoute] = []
	for i: int in count:
		var route: CityRoute = CityRoute.new()
		route.id = StringName("%s_%d" % [id, i])
		routes.append(route)
	city.routes = routes
	return city


func test_stars_rules() -> void:
	assert_eq(Progression.stars_for(20.0, 0, 25.0), 3, "sans mort, sous le temps")
	assert_eq(Progression.stars_for(30.0, 0, 25.0), 2, "sans mort mais trop lent")
	assert_eq(Progression.stars_for(20.0, 2, 25.0), 2)
	assert_eq(Progression.stars_for(20.0, 3, 25.0), 1)


func test_record_keeps_best_time_and_best_stars() -> void:
	var progress: Progression = Progression.new()
	assert_eq(progress.record_finish(&"r", 40.0, 4, 30.0), 1)
	assert_eq(progress.record_finish(&"r", 28.0, 0, 30.0), 3)
	assert_eq(progress.record_finish(&"r", 35.0, 1, 30.0), 2)
	assert_eq(progress.stars(&"r"), 3, "on garde la meilleure note")
	assert_almost_eq(progress.best_time(&"r"), 28.0, 0.001)
	assert_true(progress.is_completed(&"r"))


func test_routes_unlock_one_after_another() -> void:
	var city: CityDefinition = _city(3)
	var progress: Progression = Progression.new()
	assert_true(progress.is_route_unlocked(city, 0))
	assert_false(progress.is_route_unlocked(city, 1))
	progress.record_finish(city.routes[0].id, 10.0, 0, 0.0)
	assert_true(progress.is_route_unlocked(city, 1))
	assert_false(progress.is_route_unlocked(city, 2))
	assert_false(progress.is_route_unlocked(city, 3), "hors liste")


func test_next_city_unlocks_when_previous_is_completed() -> void:
	var first: CityDefinition = _city(2, &"a")
	var second: CityDefinition = _city(2, &"b")
	var cities: Array[CityDefinition] = [first, second]
	var progress: Progression = Progression.new()
	assert_true(progress.is_city_unlocked(cities, 0))
	assert_false(progress.is_city_unlocked(cities, 1))
	progress.record_finish(first.routes[0].id, 10.0, 0, 0.0)
	assert_false(progress.is_city_unlocked(cities, 1))
	progress.record_finish(first.routes[1].id, 10.0, 0, 0.0)
	assert_true(progress.is_city_unlocked(cities, 1))
	assert_eq(progress.city_stars(first), 6)


func test_progression_round_trip_and_clamping() -> void:
	var progress: Progression = Progression.new()
	progress.record_finish(&"r", 12.5, 1, 20.0)
	var copy: Progression = Progression.new()
	copy.from_dict(progress.to_dict())
	assert_eq(copy.to_dict(), progress.to_dict())
	copy.from_dict({"routes": {"x": {"completed": true, "best_time": -5.0, "stars": 9}}})
	assert_eq(copy.stars(&"x"), 3)
	assert_eq(copy.best_time(&"x"), 0.0)


func test_settings_are_clamped_and_invalid_values_ignored() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.from_dict({"music_volume": 3.0, "touch_opacity": 0.0, "quality": "ultra", "language": "en"})
	assert_eq(settings.music_volume, 1.0)
	assert_eq(settings.touch_opacity, 0.2)
	assert_eq(settings.quality, &"high", "valeur inconnue ignorée")
	assert_eq(settings.language, &"en")
	var copy: GameSettings = GameSettings.new()
	copy.from_dict(settings.to_dict())
	assert_eq(copy.to_dict(), settings.to_dict())
	assert_eq(GameSettings.to_db(0.0), -80.0)
