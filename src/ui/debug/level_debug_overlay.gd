class_name LevelDebugOverlay
extends CanvasLayer
## Panneau de débogage d'un niveau : distance, tronçons, réserve, nœuds,
## appels de dessin, dernier événement (chute, arrivée). F3 masque le panneau.

@export var runner: LevelRunner

var _label: Label
var _last_event: String = "—"


func _ready() -> void:
	layer = 40
	_label = Label.new()
	_label.position = Vector2(16, 196)
	_label.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.06))
	_label.add_theme_font_size_override(&"font_size", 18)
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.93, 0.93, 0.91, 0.85)
	panel.set_content_margin_all(8.0)
	_label.add_theme_stylebox_override(&"normal", panel)
	add_child(_label)
	if runner != null:
		runner.player_fell.connect(_on_player_fell)
		runner.level_completed.connect(_on_level_completed)


func _on_player_fell(at_x: float) -> void:
	_last_event = "chute à %d m — replacé au début du tronçon" % int(at_x / LevelRunner.PIXELS_PER_METER)


func _on_level_completed() -> void:
	_last_event = "ARRIVÉE ATTEINTE"


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		_label.visible = not _label.visible


func _process(_delta: float) -> void:
	if runner == null or not _label.visible:
		return
	var streamer: ChunkStreamer = runner.streamer
	_label.text = (
		"Distance : %d m · graine %d · difficulté max %d\nTronçons : %d actifs · %d en réserve · %d construits\nNœuds %d · objets %d · appels de dessin %d\nChutes : %d · dernier événement : %s"
		% [
			int(runner.distance_meters()),
			runner.seed_used,
			runner.sequencer.max_difficulty() if runner.sequencer != null else 0,
			streamer.active_count(),
			streamer.pooled_count(),
			streamer.created_count,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			runner.fall_count,
			_last_event,
		]
	)
