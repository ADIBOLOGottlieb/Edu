extends GutTest
## Proportions de la silhouette du protagoniste (data/animations/protagonist_style.tres).

const STYLE_PATH: String = "res://data/animations/protagonist_style.tres"
## Hauteur de la capsule de collision debout (player.tscn).
const COLLISION_HEIGHT: float = 72.0


func _style() -> SilhouetteStyle:
	return load(STYLE_PATH) as SilhouetteStyle


func test_style_matches_the_reference_runner() -> void:
	var style: SilhouetteStyle = _style()
	assert_not_null(style)
	assert_true(style.hair, "cheveux courts en casque (image de référence)")
	assert_false(style.hood, "pas de capuche visible sur la référence")
	assert_gt(style.collar_radius, style.neck_radius, "col de sweat relevé")
	assert_gt(style.sleeve_puff, 0.0, "manches bouffantes")
	assert_gte(style.finger_count, 3, "mains aux doigts écartés")
	assert_gt(style.knee_bunch, 0.0, "pantalon froissé au genou")


func test_visible_height_matches_the_collision_shape() -> void:
	var height: float = _style().standing_height()
	assert_between(height, COLLISION_HEIGHT - 4.0, COLLISION_HEIGHT + 8.0, "silhouette %.0f px" % height)


func test_adult_proportions_like_the_reference_photo() -> void:
	var style: SilhouetteStyle = _style()
	var height: float = style.standing_height()
	# Tête ovale : on mesure sa hauteur, pas sa largeur.
	var head: float = style.head_half_height * 2.0
	assert_between(head / height, 1.0 / 8.0, 1.0 / 6.0, "tête ≈ 1/7 de la hauteur")
	assert_gt(style.hip_height(), height * 0.45, "jambes : près de la moitié de la hauteur")


func test_clothes_are_loose() -> void:
	var style: SilhouetteStyle = _style()
	assert_gte(style.hem_half_width, style.thigh_radius * 1.5, "le sweat tombe plus large que le pantalon")
	assert_gte(style.ankle_radius, style.knee_radius * 0.85, "pantalon ample jusqu'à la cheville")
	assert_gt(style.calf_radius, style.ankle_radius, "mollet marqué : silhouette humaine, pas un tube")
	assert_lt(style.waist_half_width, style.chest_half_width, "taille plus fine que la poitrine")
	assert_gt(style.sleeve_radius, style.hand_radius, "manches plus larges que les mains")
