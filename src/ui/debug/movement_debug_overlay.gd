class_name MovementDebugOverlay
extends CanvasLayer
## Affichage de débogage du bac à sable : état courant, priorité, durée,
## vitesse, contact au sol. F3 masque ou affiche le panneau.

@export var body: RunnerBody

var _label: Label


func _ready() -> void:
	layer = 40
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.06))
	_label.add_theme_font_size_override(&"font_size", 18)
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.93, 0.93, 0.91, 0.85)
	panel.set_content_margin_all(8.0)
	_label.add_theme_stylebox_override(&"normal", panel)
	add_child(_label)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		_label.visible = not _label.visible


func _process(_delta: float) -> void:
	if body == null or not _label.visible:
		return
	var state: PlayerState.State = body.current_state()
	_label.text = (
		"État : %s (priorité %d, %d ticks)\nVitesse : (%.0f, %.0f) px/s\nAu sol : %s · Sens : %s\nDouble saut : %s (F4)\n%d FPS · F3 : masquer"
		% [
			String(PlayerState.name_of(state)).to_upper(),
			PlayerState.priority_of(state),
			body.fsm.ticks_in_state,
			body.velocity.x,
			body.velocity.y,
			"oui" if body.is_on_floor() else "non",
			"→" if body.facing > 0 else "←",
			"débloqué" if body.abilities.has(AbilitySet.DOUBLE_JUMP) else "verrouillé",
			Engine.get_frames_per_second(),
		]
	)
