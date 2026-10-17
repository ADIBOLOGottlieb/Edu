extends SceneTree
## Planche de contrôle des pièges (Hazard) : une ligne par type, une colonne par
## instant du cycle (repos, annonce, coup, retour), à taille réelle sur le ciel de
## Lomé, toit noir et bonhomme de 74 px pour l'échelle.
## Contrôle visuel (nécessite une fenêtre, pas --headless).
## Usage : godot --path . --resolution 1280x720 -s tools/capture_hazards.gd -- <png_absolu> [--crops]
## --crops écrit aussi une image par ligne (<png>_<ligne>.png).

const LOME_PATH: String = "res://data/cities/lome_theme.tres"
const CELL_W: int = 320
const CELL_H: int = 280
const GROUND: float = 230.0
const FIGURE_HEIGHT: float = 74.0

## [nom, type, rect, path_to, period, active_ratio, instants (s) ou états de la plateforme,
##  (option) un rect par colonne]
var _rows: Array[Array] = [
	["spikes", &"spikes", Rect2(110, -16, 96, 16), Vector2.ZERO, 0.0, 0.5, [0.0, 0.0, 0.0, 0.0, 0.0],
			[Rect2(110, -16, 48, 16), Rect2(110, -16, 96, 16), Rect2(110, -24, 112, 24), Rect2(90, -16, 180, 16),
			Rect2(110, -20, 64, 20)]],
	["saw", &"saw", Rect2(60, -170, 64, 64), Vector2(130, 0), 2.4, 0.5, [0.0, 0.3, 0.6, 1.2, 1.8]],
	["crusher", &"crusher", Rect2(110, -186, 72, 56), Vector2(0, 130), 3.0, 0.4, [0.3, 0.75, 0.97, 1.08, 2.5]],
	["flame", &"flame", Rect2(130, -150, 44, 150), Vector2.ZERO, 2.0, 0.4, [0.3, 0.95, 1.15, 1.23, 1.6]],
	["flame_side", &"flame", Rect2(60, -70, 200, 40), Vector2.ZERO, 2.0, 0.4, [0.3, 0.95, 1.15, 1.23, 1.6]],
	["crumble", &"crumble", Rect2(90, -110, 150, 18), Vector2.ZERO, 0.0, 0.5,
			["solid", "shake:0.2", "shake:0.45", "fallen:0.18", "fallen:1.5"]],
]

var _out: String = ""
var _crops: bool = false
var _viewport: SubViewport
var _frames: int = 0
var _lome: CityTheme
var _hazards: Array[Hazard] = []


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	_crops = args.has("--crops")
	_lome = load(LOME_PATH) as CityTheme
	var columns: int = 5
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(CELL_W * columns, CELL_H * _rows.size())
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	root.add_child(_viewport)
	for row_index: int in _rows.size():
		for column: int in columns:
			_add_cell(_rows[row_index], column, row_index * CELL_H)
	process_frame.connect(_tick)


func _add_cell(row: Array, column: int, y: int) -> void:
	var spec: HazardSpec = HazardSpec.new()
	spec.kind = row[1]
	spec.rect = row[2] if row.size() <= 7 else (row[7] as Array)[column]
	spec.path_to = row[3]
	spec.period = row[4]
	spec.active_ratio = row[5]
	var moments: Array = row[6]
	var moment: Variant = moments[column]
	var cell: Control = Control.new()
	cell.position = Vector2(column * CELL_W, y)
	cell.size = Vector2(CELL_W, CELL_H)
	cell.clip_contents = true
	_viewport.add_child(cell)
	var back: Node2D = Node2D.new()
	back.position = Vector2(0, GROUND)
	cell.add_child(back)
	var crumble: bool = spec.kind == &"crumble"
	back.draw.connect(func() -> void:
		_draw_sky(back, Rect2(0, -GROUND, CELL_W, CELL_H))
		if crumble:
			# Toit coupé : la plateforme fragile enjambe un vide.
			back.draw_rect(Rect2(0, 0, 70, CELL_H), _lome.ink)
			back.draw_rect(Rect2(260, 0, CELL_W - 260, CELL_H), _lome.ink)
		elif row[0] == "flame_side":
			back.draw_rect(Rect2(0, 0, CELL_W, CELL_H), _lome.ink)
			back.draw_rect(Rect2(0, -110, 60, 110), _lome.ink)
		else:
			back.draw_rect(Rect2(0, 0, CELL_W, CELL_H), _lome.ink)
	)
	var hazard: Hazard = Hazard.create(spec, _lome)
	hazard.position = Vector2(0, GROUND)
	var label: String = row[0]
	if crumble:
		var parts: PackedStringArray = String(moment).split(":")
		if parts[0] != "solid":
			hazard.trigger()
			if parts[0] == "fallen":
				hazard.advance(Hazard.CRUMBLE_DELAY)
			hazard.advance(float(parts[1]))
		label += "  " + String(moment)
	else:
		hazard.set_time(float(moment))
		label += "  t=%.2f%s%s" % [float(moment), "  DANGER" if hazard.is_dangerous() else "",
				"  annonce" if hazard.is_telegraphing() else ""]
	# Horloge figée : la planche montre exactement l instant demandé.
	hazard.process_mode = Node.PROCESS_MODE_DISABLED
	cell.add_child(hazard)
	_hazards.append(hazard)
	var front: Node2D = Node2D.new()
	front.position = Vector2(0, GROUND)
	cell.add_child(front)
	front.draw.connect(func() -> void:
		var feet: Vector2 = Vector2(30, 0)
		if crumble:
			feet = Vector2(165, -110) if String(moment) == "solid" or String(moment).begins_with("shake") else Vector2(30, 0)
		_draw_figure(front, feet, _lome.ink)
		front.draw_string(ThemeDB.fallback_font, Vector2(8, -GROUND + 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.25, 0.12, 0.08))
	)


func _draw_sky(canvas: Node2D, area: Rect2) -> void:
	var top: Color = _lome.sky_top.lerp(_lome.sky_horizon, 0.55)
	var bottom: Color = _lome.sky_horizon
	var colors: PackedColorArray = PackedColorArray([top, top, bottom, bottom])
	canvas.draw_polygon(PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end,
			Vector2(area.position.x, area.end.y)]), colors)
	canvas.draw_rect(Rect2(area.position, Vector2(area.size.x, 1)), Color(0, 0, 0, 0.25))
	canvas.draw_rect(Rect2(area.position, Vector2(1, area.size.y)), Color(0, 0, 0, 0.25))


## Bonhomme bâton de 74 px, pieds en `feet`.
func _draw_figure(canvas: Node2D, feet: Vector2, ink: Color) -> void:
	var hip: Vector2 = feet + Vector2(0, -36)
	var neck: Vector2 = feet + Vector2(0, -60)
	canvas.draw_circle(feet + Vector2(0, -67), 7.0, ink)
	canvas.draw_line(hip, neck, ink, 7.0)
	canvas.draw_line(hip, feet + Vector2(-9, 0), ink, 5.0)
	canvas.draw_line(hip, feet + Vector2(9, 0), ink, 5.0)
	canvas.draw_line(neck + Vector2(0, 4), hip + Vector2(-12, 2), ink, 4.0)
	canvas.draw_line(neck + Vector2(0, 4), hip + Vector2(12, -2), ink, 4.0)


func _tick() -> void:
	_frames += 1
	if _frames < 4:
		return
	process_frame.disconnect(_tick)
	_save.call_deferred()


func _save() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	image.save_png(_out)
	print("planche : ", _out)
	if _crops:
		var base: String = _out.get_basename()
		for i: int in _rows.size():
			var crop: Image = image.get_region(Rect2i(0, i * CELL_H, image.get_width(), CELL_H))
			crop.save_png("%s_%s.png" % [base, String(_rows[i][0])])
	quit()
