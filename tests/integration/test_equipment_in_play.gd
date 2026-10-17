extends GutTest
## Équipement dans un vrai niveau (M8) : caisses ramassées, effets sur le coureur
## (accélérateur, gilet), sur le vigile (bouclier, impulsion, surcharge), sur les
## pièges (piratage), refus sans perte d'objet, perte des objets ramassés à la
## capture. Sauvegarde isolée dans un dossier de test (jamais celle du joueur).

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/actors/player/player.tscn")
const LIBRARY_PATH: String = "res://data/levels/chunk_library.tres"
const DIR: String = "user://test_saves/equipment"

var _runner: LevelRunner
var _body: RunnerBody
var _ctrl: ScriptedController
var _director: EncounterDirector
var _equipment: EquipmentRuntime
var _save: SaveServiceNode
var _service: InventoryServiceNode


func before_all() -> void:
	_save = get_node("/root/SaveService") as SaveServiceNode
	_service = get_node("/root/InventoryService") as InventoryServiceNode


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	_save.use_store(SaveStore.new(DIR, "save.json"))
	_service.reload()


func after_all() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	_save.reload()
	_service.reload()


func _build(pursuit: bool = true, start_x: float = 60.0) -> void:
	var root: Node2D = Node2D.new()
	_runner = LevelRunner.new()
	_runner.library = load(LIBRARY_PATH) as ChunkLibrary
	_runner.mode = ChunkSequencer.Mode.ORDERED
	_runner.seed_value = 1
	_runner.ordered_ids = [&"flat_run", &"flat_run", &"flat_run", &"flat_run", &"flat_run", &"flat_run"] as Array[StringName]
	var streamer: ChunkStreamer = ChunkStreamer.new()
	streamer.name = "Streamer"
	_runner.add_child(streamer)
	_body = PLAYER_SCENE.instantiate() as RunnerBody
	var human: Node = _body.get_node("Controller")
	_body.remove_child(human)
	human.free()
	_ctrl = ScriptedController.new()
	_ctrl.name = "Controller"
	_body.add_child(_ctrl)
	_body.position = Vector2(start_x, -2)
	_runner.player = _body
	_director = EncounterDirector.new()
	_director.runner = _runner
	_director.start_delay = 0.2 if pursuit else 9999.0
	_director.start_behind = 500.0
	_equipment = EquipmentRuntime.new()
	_equipment.runner = _runner
	_equipment.encounter = _director
	root.add_child(_runner)
	root.add_child(_body)
	root.add_child(_director)
	root.add_child(_equipment)
	add_child_autofree(root)


func _frames(count: int) -> void:
	for i: int in count:
		await wait_physics_frames(1)


func _give(id: StringName) -> void:
	assert_eq(_service.inventory.try_add(id, false), Inventory.AddResult.OK)


func test_pickups_are_placed_and_collected() -> void:
	_build(false)
	await _frames(2)
	assert_gt(_equipment.pickup_count(), 0, "des caisses dans les tronçons")
	var before: int = _service.inventory.count()
	_ctrl.move_axis = 1.0
	await _frames(240)
	assert_gt(_service.inventory.count(), before, "caisse ramassée en courant")
	var lost: Array[StringName] = _service.inventory.lose_on_defeat()
	assert_gt(lost.size(), 0, "objet ramassé pendant le parcours = perdu en cas de défaite")


func test_full_inventory_leaves_the_crate() -> void:
	_build(false)
	while not _service.inventory.is_full():
		_service.inventory.try_add(&"gilet", false)
	await _frames(2)
	var crates: int = _equipment.pickup_count()
	_ctrl.move_axis = 1.0
	await _frames(240)
	assert_gt(crates, 0)
	assert_true(_service.inventory.is_full())
	assert_eq(_service.inventory.quantity(&"gilet"), _service.inventory.capacity() - InventoryServiceNode.STARTER_KIT.size(), "rien n'est remplacé")
	assert_eq(_equipment.pickup_count(), crates, "la caisse reste au sol")


func test_accelerator_speeds_up_then_restores() -> void:
	_build(false)
	await _frames(2)
	var base: float = _body.tuning.run_speed
	_equipment.selected = &"accelerateur"
	assert_true(_equipment.use_selected())
	assert_eq(_service.inventory.quantity(&"accelerateur"), 0, "objet consommé")
	assert_almost_eq(_body.tuning.run_speed, base * 1.25, 0.01)
	_equipment.effects.tick(30.0)
	assert_almost_eq(_body.tuning.run_speed, base, 0.01, "réglage de base rendu")


func test_vest_absorbs_one_trap() -> void:
	_build(false)
	await _frames(2)
	_give(&"gilet")
	assert_true(_equipment.use_item(&"gilet"))
	assert_false(_body.kill(&"spikes"), "piège encaissé")
	assert_false(_body.is_dead())
	assert_false(_equipment.effects.is_active(&"gilet"), "une seule charge")
	assert_false(_body.kill(&"capture"), "invulnérable juste après")


func test_pursuer_items_refused_without_pursuer_and_kept() -> void:
	_build(false)
	await _frames(2)
	_give(&"impulsion")
	assert_false(_equipment.use_item(&"impulsion"))
	assert_eq(_service.inventory.quantity(&"impulsion"), 1, "objet conservé")


func test_incompatible_item_is_kept() -> void:
	_build(true)
	await _frames(30)
	assert_true(_director.has_pursuer())
	_give(&"cachette")
	assert_true(_equipment.use_item(&"accelerateur"))
	assert_false(_equipment.use_item(&"cachette"), "accélérateur et cachette incompatibles")
	assert_eq(_service.inventory.quantity(&"cachette"), 1)


func test_impulse_and_overload_act_on_the_guard() -> void:
	_build(true, 900.0)
	await _frames(30)
	assert_true(_director.has_pursuer())
	_director.gauge.value = 0.5
	assert_true(_equipment.use_item(&"surcharge"))
	assert_almost_eq(_director.gauge.value, 0.2, 0.01, "−60 %")
	_give(&"impulsion")
	assert_true(_equipment.use_item(&"impulsion"))
	await _frames(2)
	assert_gt(_director.pursuer_distance(), 250.0, "vigile repoussé")


func test_shield_breaks_a_grab_and_capture_loses_mission_items() -> void:
	_build(true)
	_give(&"bouclier")
	assert_eq(_service.inventory.try_add(&"gants", true), Inventory.AddResult.OK)
	await _frames(30)
	assert_true(_equipment.use_item(&"bouclier"))
	# Coureur immobile : le vigile le saisit deux fois (bouclier), puis le capture.
	for i: int in 1500:
		await wait_physics_frames(1)
		if _director.captures > 0:
			break
	assert_false(_equipment.effects.is_active(&"bouclier"), "deux prises brisées")
	assert_eq(_director.captures, 1)
	assert_eq(_service.inventory.quantity(&"gants"), 0, "objet ramassé perdu à la capture")
	assert_eq(_service.inventory.quantity(&"accelerateur"), 1, "objet possédé conservé")


func test_hacking_disables_nearby_traps() -> void:
	_build(false)
	await _frames(2)
	var spec: HazardSpec = HazardSpec.new()
	spec.kind = Hazard.SPIKES
	spec.rect = Rect2(100, -16, 64, 16)
	var near: Hazard = Hazard.create(spec, null)
	near.add_to_group(LevelChunk.HAZARD_GROUP)
	var far_spec: HazardSpec = spec.duplicate() as HazardSpec
	far_spec.rect = Rect2(4000, -16, 64, 16)
	var far: Hazard = Hazard.create(far_spec, null)
	far.add_to_group(LevelChunk.HAZARD_GROUP)
	add_child_autofree(near)
	add_child_autofree(far)
	_give(&"piratage")
	assert_true(_equipment.use_item(&"piratage"))
	assert_true(near.is_disabled())
	assert_false(near.is_dangerous())
	assert_false(far.is_disabled(), "hors de portée")
	near.advance(9.0)
	assert_false(near.is_disabled(), "le piège se réarme")
	assert_true(near.is_dangerous())
