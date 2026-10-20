class_name TutorialDirector
extends CanvasLayer
## Tutoriel « Premiers pas » en jeu (ADR-051) : parcours d'entraînement de Lomé,
## sans vigile ni énergie. Un panneau affiche la leçon du tronçon (TutorialSteps)
## et « Réussi ! » quand le geste est fait. À l'arrivée, ou avec « Passer », le
## tutoriel est marqué terminé (ProfileService) et la carte du monde s'ouvre.

signal finished(skipped: bool)

const WORLD_MAP: String = "res://src/ui/menus/world_map.tscn"
## Temps laissé pour lire « Bravo » avant la carte (s).
const END_DELAY: float = 2.2

@export var runner: LevelRunner
@export var equipment: EquipmentRuntime
## false : pas de changement de scène (tests).
var use_router: bool = true

var steps: TutorialSteps = TutorialSteps.new()
var panel: PanelContainer
var header: Label
var lesson: Label
var status: Label
var skip_button: Button

var _item_used: bool = false
var _finished: bool = false


func _ready() -> void:
	layer = 20
	_build_ui()
	if equipment != null:
		equipment.effects.effect_started.connect(func(_id: StringName) -> void: _item_used = true)
		_ensure_item()
	if runner != null:
		runner.level_completed.connect(finish.bind(false))
	_refresh()


func _physics_process(_delta: float) -> void:
	if _finished or runner == null or runner.player == null:
		return
	var body: RunnerBody = runner.player
	var chunk: LevelChunk = runner.streamer.chunk_at(body.global_position.x)
	if chunk == null:
		return
	var state: StringName = StringName(PlayerState.State.keys()[body.current_state()])
	var local_x: float = body.global_position.x - chunk.position.x
	if steps.update(chunk.layout.id, state, local_x, _item_used):
		_refresh()


## Fin du tutoriel (arrivée ou « Passer ») : marqué terminé, puis la carte.
func finish(skipped: bool) -> void:
	if _finished:
		return
	_finished = true
	var profile: ProfileServiceNode = get_node_or_null(^"/root/ProfileService") as ProfileServiceNode
	if profile != null:
		profile.mark_tutorial_done()
	header.text = "PREMIERS PAS"
	lesson.text = "Tutoriel passé. Tu peux le revoir dans les Réglages." if skipped \
		else "Bravo ! Tu connais les bases. Place au tour du monde !"
	status.text = ""
	skip_button.visible = false
	finished.emit(skipped)
	if not use_router:
		return
	await get_tree().create_timer(0.3 if skipped else END_DELAY, false, true).timeout
	var router: SceneRouterNode = get_node_or_null(^"/root/SceneRouter") as SceneRouterNode
	if router != null:
		router.go_to(WORLD_MAP, {})


## Leçon OBJET : il faut un objet. Un Accélérateur est prêté s'il n'y en a aucun
## (ramassé « en parcours » : gardé seulement si le tutoriel va au bout).
func _ensure_item() -> void:
	var inventory: Inventory = equipment.inventory
	if inventory != null and inventory.count() == 0:
		inventory.try_add(&"accelerateur", true)


func _refresh() -> void:
	if steps.current < 0:
		header.text = "PREMIERS PAS"
		lesson.text = "Bienvenue à Lomé ! Apprenons les bases du parkour."
		status.text = ""
		return
	header.text = "PREMIERS PAS · %d / %d" % [steps.current + 1, TutorialSteps.LESSONS.size()]
	lesson.text = steps.text()
	status.text = "Réussi !" if steps.is_current_done() else ""


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "TutorialPanel"
	panel.add_theme_stylebox_override(&"panel", MenuStyle.panel_box(Color(MenuStyle.INK, 0.84), 14, 16.0))
	panel.position = Vector2(270.0, 120.0)
	panel.custom_minimum_size = Vector2(740.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lines)
	header = MenuStyle.label("", 18, MenuStyle.ACCENT, true)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(header)
	lesson = MenuStyle.label("", 27, MenuStyle.CREAM, true)
	lesson.name = "Lesson"
	lesson.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lesson.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson.custom_minimum_size.x = 708.0
	lines.add_child(lesson)
	status = MenuStyle.label("", 22, Color(0.55, 0.9, 0.45), true)
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(status)
	skip_button = MenuStyle.button("Passer le tutoriel")
	skip_button.name = "SkipButton"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_size_override(&"font_size", 20)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_button.position = Vector2(get_viewport().get_visible_rect().size.x - 300.0, 112.0)
	skip_button.pressed.connect(finish.bind(true))
	add_child(skip_button)
