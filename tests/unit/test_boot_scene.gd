extends GutTest
## Vérifie que la scène de démarrage se charge et affiche le titre.

const BOOT_SCENE: String = "res://scenes/boot.tscn"


func test_boot_scene_instantiates_and_shows_title() -> void:
	var scene: PackedScene = load(BOOT_SCENE) as PackedScene
	assert_not_null(scene, "scène introuvable : " + BOOT_SCENE)
	var boot: Control = scene.instantiate() as Control
	add_child_autofree(boot)

	var labels: Array[Node] = boot.find_children("*", "Label", true, false)
	assert_eq(labels.size(), 1)
	assert_string_starts_with((labels[0] as Label).text, "EDU")
