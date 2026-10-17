class_name EquipmentRuntime
extends Node2D
## Équipement pendant un parcours (M8) : caisses d'objets dans les tronçons,
## utilisation de l'objet choisi (action use_item, bouton OBJET), effets actifs.
## Aucun combat : les objets protègent, accélèrent, cachent ou repoussent le
## vigile (ADR-047). Les chronos avancent en _physics_process : ils sont gelés
## pendant la pause et quand l'application passe en arrière-plan.

## Message court à afficher (ramassage, refus, effet terminé).
signal message(text: String)
## Inventaire, sélection ou effets modifiés : le HUD se redessine.
signal changed()

## Une caisse tous les N tronçons (à partir du deuxième).
const PICKUP_EVERY: int = 2
## Position de la caisse depuis le début du tronçon (près du point de contrôle).
const PICKUP_OFFSET: Vector2 = Vector2(110.0, -44.0)
## Caisses laissées loin derrière : retirées.
const PICKUP_CLEANUP_BEHIND: float = 1600.0
## Cachette : vitesse au-delà de laquelle on « bouge », et délai de grâce.
const STILL_SPEED: float = 40.0
const HIDE_GRACE: float = 0.3
## Pas de temps maximal (reprise après une longue image).
const MAX_STEP: float = 0.1

const REJECT_TEXT: Dictionary[StringName, String] = {
	&"incompatible": "Incompatible avec un effet actif",
	&"category_busy": "Un objet de ce type est déjà actif",
	&"already_active": "Déjà actif",
	&"no_pursuer": "Pas de vigile à semer",
	&"dead": "",
}

@export var runner: LevelRunner
@export var encounter: EncounterDirector

var effects: EffectRunner = EffectRunner.new()
var inventory: Inventory
var catalog: EquipmentCatalog
## Identifiant de l'objet choisi (raccourci du HUD).
var selected: StringName = &""

var _base_tuning: MoveTuning
var _hide_grace_left: float = 0.0
var _pickups: Array[ItemPickup] = []
var _finished: bool = false


func _ready() -> void:
	var service: InventoryServiceNode = get_node_or_null(^"/root/InventoryService") as InventoryServiceNode
	if service != null:
		inventory = service.inventory
		catalog = service.catalog
	else:
		catalog = load(InventoryServiceNode.CATALOG_PATH) as EquipmentCatalog
		inventory = Inventory.new(catalog)
	effects.effect_expired.connect(_on_effect_expired)
	inventory.item_added.connect(_on_item_added)
	inventory.item_removed.connect(_on_item_removed)
	if runner != null:
		runner.streamer.chunk_spawned.connect(_on_chunk_spawned)
		runner.level_completed.connect(_on_level_completed)
		if runner.player != null:
			_base_tuning = runner.player.tuning
			runner.player.hurt_guard = _absorb_hit
		# Tronçons créés avant nous (le niveau se remplit dans son _ready).
		for chunk: LevelChunk in runner.streamer.active_chunks():
			_on_chunk_spawned(chunk.index, chunk.layout.id)
	if encounter != null:
		encounter.pursuer_grabbed.connect(_on_pursuer_grabbed)
		encounter.captured.connect(_on_defeat)
	_on_inventory_changed()


func _exit_tree() -> void:
	# Parcours abandonné (pause → carte, recommencer) : défaite pour les objets ramassés.
	if not _finished and inventory != null:
		_finished = true
		effects.end_mission()
		inventory.lose_on_defeat()
	if inventory != null:
		inventory.item_added.disconnect(_on_item_added)
		inventory.item_removed.disconnect(_on_item_removed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.USE_ITEM):
		use_selected()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputActions.NEXT_ITEM):
		select_next()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var step: float = minf(delta, MAX_STEP)
	effects.tick(step)
	_update_hiding(step)
	_cleanup_pickups()
	if not effects.active_ids().is_empty():
		changed.emit()


# --- Sélection et utilisation ---------------------------------------------------

## Objets possédés, dans l'ordre du catalogue : [{id, name, count}].
func owned_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for data: EquipmentData in catalog.items:
		var count: int = inventory.quantity(data.id)
		if count > 0:
			result.append({"id": data.id, "name": data.display_name, "count": count})
	return result


func select_next() -> void:
	var owned: Array[Dictionary] = owned_items()
	if owned.is_empty():
		selected = &""
	else:
		var index: int = -1
		for i: int in owned.size():
			if owned[i]["id"] == selected:
				index = i
		selected = owned[(index + 1) % owned.size()]["id"]
	changed.emit()


func use_selected() -> bool:
	return use_item(selected)


## Utilise un objet de l'inventaire. Refusé → l'objet est conservé.
func use_item(id: StringName) -> bool:
	var slot: int = inventory.find(id)
	var data: EquipmentData = catalog.get_item(id)
	if slot < 0 or data == null or _finished:
		return false
	var reason: StringName = _precondition(data)
	if reason != &"":
		_say_reject(reason)
		return false
	if effects.activate(data) == EffectRunner.ActivateResult.REJECTED:
		_say_reject(effects.last_reject_reason)
		return false
	inventory.remove(slot, &"used")
	_on_effect_started(data)
	message.emit(data.display_name)
	changed.emit()
	return true


func _precondition(data: EquipmentData) -> StringName:
	if runner == null or runner.player == null or runner.player.is_dead():
		return &"dead"
	var needs_pursuer: bool = data.category in [
		EquipmentData.Category.RANGED, EquipmentData.Category.STEALTH, EquipmentData.Category.UTILITY,
	]
	if needs_pursuer and (encounter == null or not encounter.has_pursuer()):
		return &"no_pursuer"
	return &""


# --- Effets ---------------------------------------------------------------------

func _on_effect_started(data: EquipmentData) -> void:
	match data.id:
		&"gants", &"accelerateur":
			_apply_tuning()
		&"impulsion":
			encounter.repel_pursuer(data.power)
		&"leurre":
			encounter.distract_pursuer(true)
		&"camouflage":
			encounter.conceal_target(true)
		&"cachette":
			_hide_grace_left = HIDE_GRACE
		&"piratage":
			_hack_hazards(data.power, data.duration)
		&"surcharge":
			encounter.reduce_gauge(data.power)


func _on_effect_expired(id: StringName, reason: StringName) -> void:
	match id:
		&"gants", &"accelerateur":
			_apply_tuning()
		&"leurre":
			if encounter != null:
				encounter.distract_pursuer(false)
		&"camouflage", &"cachette":
			if encounter != null:
				encounter.conceal_target(effects.is_active(&"camouflage") or effects.is_active(&"cachette"))
	if reason == &"moved":
		message.emit("Cachette annulée : tu as bougé")
	changed.emit()


## Vitesse (accélérateur) et escalade (gants) : copie du réglage de base modifiée.
func _apply_tuning() -> void:
	if runner == null or runner.player == null or _base_tuning == null:
		return
	if not effects.is_active(&"gants") and not effects.is_active(&"accelerateur"):
		runner.player.tuning = _base_tuning
		return
	var tuning: MoveTuning = _base_tuning.duplicate() as MoveTuning
	if effects.is_active(&"accelerateur"):
		var speed: float = effects.power(&"accelerateur")
		tuning.run_speed *= speed
		tuning.sprint_speed *= speed
	if effects.is_active(&"gants"):
		var climb: float = effects.power(&"gants")
		tuning.wall_climb_speed *= climb
		tuning.wall_climb_max_time *= climb
	runner.player.tuning = tuning


## Gilet : encaisse un piège (pas la capture, qui n'est pas un coup).
func _absorb_hit(cause: StringName) -> bool:
	if cause == &"capture" or not effects.is_active(&"gilet"):
		return false
	effects.consume_charge(&"gilet")
	message.emit("Gilet : piège encaissé")
	return true


## Bouclier : la prise du vigile est brisée (une charge par prise).
func _on_pursuer_grabbed() -> void:
	if not effects.is_active(&"bouclier"):
		return
	effects.consume_charge(&"bouclier")
	encounter.repel_pursuer(encounter.start_behind * 0.5)
	message.emit("Bouclier : prise brisée")


## Cachette : invisible tant qu'on reste immobile ; bouger l'annule.
func _update_hiding(delta: float) -> void:
	if not effects.is_active(&"cachette") or runner == null or runner.player == null:
		return
	var still: bool = absf(runner.player.velocity.x) <= STILL_SPEED
	if still:
		_hide_grace_left = 0.0
	elif _hide_grace_left > 0.0:
		_hide_grace_left -= delta
	else:
		effects.cancel(&"cachette", &"moved")
		return
	if encounter != null:
		encounter.conceal_target(still or effects.is_active(&"camouflage"))


## Piratage : pièges dont le centre est à moins de `radius` px du coureur.
func _hack_hazards(radius: float, seconds: float) -> void:
	var origin: Vector2 = runner.player.global_position
	for node: Node in get_tree().get_nodes_in_group(LevelChunk.HAZARD_GROUP):
		var hazard: Hazard = node as Hazard
		if hazard == null or hazard.spec == null:
			continue
		if hazard.to_global(hazard.spec.rect.get_center()).distance_to(origin) <= radius:
			hazard.disable_for(seconds)


func _say_reject(reason: StringName) -> void:
	var text: String = REJECT_TEXT.get(reason, "Impossible maintenant")
	if text != "":
		message.emit(text)


# --- Ramassage ------------------------------------------------------------------

func _on_chunk_spawned(index: int, _layout_id: StringName) -> void:
	if index < 1 or index % PICKUP_EVERY != 1 or catalog == null or catalog.items.is_empty():
		return
	var chunk: LevelChunk = _chunk_by_index(index)
	if chunk == null:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([runner.seed_used, index])
	var data: EquipmentData = catalog.items[rng.randi_range(0, catalog.items.size() - 1)]
	var pickup: ItemPickup = ItemPickup.new()
	pickup.item_id = data.id
	pickup.label = data.display_name
	pickup.position = chunk.position + PICKUP_OFFSET
	pickup.touched.connect(_on_pickup_touched)
	add_child(pickup)
	_pickups.append(pickup)


func _chunk_by_index(index: int) -> LevelChunk:
	for chunk: LevelChunk in runner.streamer.active_chunks():
		if chunk.index == index:
			return chunk
	return null


func _on_pickup_touched(pickup: ItemPickup, body: Node2D) -> void:
	if runner == null or body != runner.player or _finished:
		return
	match inventory.try_add(pickup.item_id, true):
		Inventory.AddResult.OK:
			message.emit("+ %s" % pickup.label)
			_pickups.erase(pickup)
			pickup.queue_free()
		Inventory.AddResult.FULL:
			# L'objet reste au sol (§7.1).
			message.emit("Inventaire plein")


func _cleanup_pickups() -> void:
	if runner == null or runner.player == null:
		return
	var limit: float = runner.player.global_position.x - PICKUP_CLEANUP_BEHIND
	for pickup: ItemPickup in _pickups.duplicate():
		if pickup.global_position.x < limit:
			_pickups.erase(pickup)
			pickup.queue_free()


func pickup_count() -> int:
	return _pickups.size()


# --- Fin de parcours ------------------------------------------------------------

func _on_level_completed() -> void:
	if _finished:
		return
	_finished = true
	effects.end_mission()
	inventory.keep_mission_items()
	_save()


## Capture : défaite, les objets ramassés pendant ce parcours sont perdus (ADR-005).
func _on_defeat() -> void:
	effects.end_mission()
	var lost: Array[StringName] = inventory.lose_on_defeat()
	if not lost.is_empty():
		message.emit("Capturé : %d objet(s) perdu(s)" % lost.size())


func _save() -> void:
	var service: InventoryServiceNode = get_node_or_null(^"/root/InventoryService") as InventoryServiceNode
	if service != null:
		service.save()


func _on_inventory_changed() -> void:
	if selected == &"" or inventory.quantity(selected) == 0:
		var owned: Array[Dictionary] = owned_items()
		selected = owned[0]["id"] if not owned.is_empty() else &""
	changed.emit()


func _on_item_added(_slot: int, _id: StringName) -> void:
	_on_inventory_changed()


func _on_item_removed(_slot: int, _id: StringName, _reason: StringName) -> void:
	_on_inventory_changed()
