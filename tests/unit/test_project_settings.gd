extends GutTest
## Vérifie la configuration du socle M0 décidée dans docs/DECISIONS.md.

const EXPECTED_AUTOLOADS: Array[String] = [
	"EventBus",
	"TimeService",
	"SaveService",
	"SettingsService",
	"InputService",
	"SceneRouter",
	"ProfileService",
	"AttemptService",
	"NarrativeService",
	"InventoryService",
	"MonetizationService",
]


func test_project_name_is_edu() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "EDU")


func test_renderer_is_compatibility_on_desktop_and_mobile() -> void:
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility"
	)
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"),
		"gl_compatibility"
	)


func test_base_resolution_is_1280x720_landscape() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")


func test_physics_runs_at_60_ticks() -> void:
	assert_eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 60)


func test_main_scene_exists() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_true(ResourceLoader.exists(path), "scène principale introuvable : " + path)


func test_autoloads_are_declared_and_loaded() -> void:
	for autoload_name: String in EXPECTED_AUTOLOADS:
		assert_true(
			ProjectSettings.has_setting("autoload/" + autoload_name),
			autoload_name + " déclaré dans project.godot"
		)
		assert_not_null(
			get_tree().root.get_node_or_null(NodePath(autoload_name)),
			autoload_name + " présent dans l'arbre"
		)
