extends GutTest
## Couche de mouvement du visuel : impulsions d'appel et d'amorti données aux
## ressorts de la pose, qui reviennent ensuite d'eux-mêmes à la pose de clip.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")
const STEP: float = 1.0 / 60.0

var _body: RunnerBody
var _visual: RunnerVisual


func before_each() -> void:
	var world: Node2D = Node2D.new()
	add_child_autofree(world)
	world.add_child(LevelGeometry.make_block(Rect2(-1000, 0, 2000, 100)))
	_body = PLAYER_SCENE.instantiate() as RunnerBody
	_body.position = Vector2(0, -2)
	world.add_child(_body)
	await wait_physics_frames(15)
	_visual = _body.get_node("Visual") as RunnerVisual
	_visual.visible = true  # silhouette 2D de secours, masquée en jeu
	# Pas de temps contrôlé : le test fait avancer le visuel lui-même.
	_visual.set_process(false)
	_steps(90)


func _steps(count: int) -> void:
	for i: int in count:
		_visual._process(STEP)


func test_landing_absorbs_then_recovers() -> void:
	var rest: float = _visual.pose_value(&"crouch")
	_body.landed.emit(900.0)
	_steps(6)
	assert_gt(_visual.pose_value(&"crouch"), rest + 0.1, "le bassin descend à la réception")
	_steps(120)
	assert_almost_eq(_visual.pose_value(&"crouch"), rest, 0.03, "puis revient à la pose de repos")


func test_soft_landing_absorbs_less_than_hard_landing() -> void:
	var rest: float = _visual.pose_value(&"crouch")
	_body.landed.emit(200.0)
	_steps(6)
	var soft: float = _visual.pose_value(&"crouch") - rest
	_steps(120)
	_body.landed.emit(1000.0)
	_steps(6)
	var hard: float = _visual.pose_value(&"crouch") - rest
	assert_gt(hard, soft * 2.0, "l'amorti suit la violence de l'impact")


func test_take_off_throws_the_arms_up() -> void:
	var rest: float = _visual.pose_value(&"arm_base")
	_body.jump_started.emit(&"ground")
	_steps(5)
	assert_gt(_visual.pose_value(&"arm_base"), rest + 0.15, "bras lancés à l'appel")
