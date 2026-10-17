extends SceneTree
## Planche de contrôle des objets urbains du premier plan (PropPainter) :
## une ligne par type de bloc, 4 variantes en style moderne puis 4 en style Lomé,
## à taille réelle, sur le ciel de Lomé, avec un bonhomme de 74 px pour l'échelle.
## Contrôle visuel (nécessite une fenêtre, pas --headless).
## Usage : godot --path . --resolution 1280x720 -s tools/capture_props.gd -- <png_absolu> [--crops]
## --crops écrit aussi une image par ligne et par style (<png>_<type>_<style>.png).

const LOME_PATH: String = "res://data/cities/lome_theme.tres"
const CELL_W: int = 560
const VARIANTS: int = 4
const FIGURE_HEIGHT: float = 74.0

## [type, hauteur de cellule, niveau du toit dans la cellule, blocs (un par colonne)]
var _rows: Array[Array] = [
	[BlockKind.Kind.BUILDING, 560, 200, [Rect2(0, 0, 520, 1400), Rect2(0, 0, 480, 1400),
			Rect2(0, 0, 380, 1400), Rect2(0, 0, 520, 1400)]],
	[BlockKind.Kind.PILLAR, 320, 250, [Rect2(0, -40, 90, 1400), Rect2(0, -90, 90, 1400),
			Rect2(0, -40, 90, 1400), Rect2(0, -90, 90, 1400)]],
	[BlockKind.Kind.LOW_OBSTACLE, 200, 160, [Rect2(0, -40, 100, 40), Rect2(0, -36, 90, 36),
			Rect2(0, -44, 70, 44), Rect2(0, -40, 80, 40)]],
	[BlockKind.Kind.WALL, 380, 330, [Rect2(0, -220, 90, 220), Rect2(0, -260, 100, 260),
			Rect2(0, -200, 90, 200), Rect2(0, -260, 100, 260)]],
	[BlockKind.Kind.PLATFORM, 300, 260, [Rect2(0, -100, 300, 100), Rect2(0, -150, 400, 150),
			Rect2(0, -200, 500, 200), Rect2(0, -120, 360, 120)]],
	[BlockKind.Kind.CEILING, 520, 480, [Rect2(0, -420, 380, 372), Rect2(0, -420, 320, 372),
			Rect2(0, -420, 240, 372), Rect2(0, -420, 300, 372)]],
	[BlockKind.Kind.BEAM, 220, 190, [Rect2(0, -130, 140, 16), Rect2(0, -130, 220, 16),
			Rect2(0, -130, 200, 16), Rect2(0, -130, 180, 16)]],
]

var _out: String = ""
var _crops: bool = false
var _viewport: SubViewport
var _frames: int = 0
var _lome: CityTheme


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	_crops = args.has("--crops")
	_lome = load(LOME_PATH) as CityTheme
	var height: int = 0
	for row: Array in _rows:
		height += int(row[1])
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(CELL_W * VARIANTS * 2, height)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	root.add_child(_viewport)
	var y: int = 0
	for row: Array in _rows:
		for column: int in VARIANTS * 2:
			_add_cell(row, column, y)
		y += int(row[1])
	process_frame.connect(_tick)


func _add_cell(row: Array, column: int, y: int) -> void:
	var kind: BlockKind.Kind = row[0]
	var cell_h: int = row[1]
	var ground: float = float(row[2])
	var blocks: Array = row[3]
	var lome: bool = column >= VARIANTS
	var variant: int = column % VARIANTS
	var rect: Rect2 = blocks[variant]
	var theme: CityTheme = _lome if lome else CityTheme.new()
	var cell: Control = Control.new()
	cell.position = Vector2(column * CELL_W, y)
	cell.size = Vector2(CELL_W, cell_h)
	cell.clip_contents = true
	_viewport.add_child(cell)
	var drawer: Node2D = Node2D.new()
	var origin_x: float = CELL_W - 30.0 - rect.size.x
	drawer.position = Vector2(origin_x, ground)
	cell.add_child(drawer)
	var shapes: Array[PropShape] = PropPainter.shapes_for(rect, kind, variant, theme)
	var label: String = "%s  %s v%d  (%d poly)" % [BlockKind.name_of(kind), "lome" if lome else "modern",
			variant, shapes.size()]
	drawer.draw.connect(func() -> void:
		_draw_sky(drawer, Rect2(-origin_x, -ground, CELL_W, cell_h))
		if kind != BlockKind.Kind.BUILDING:
			drawer.draw_rect(Rect2(-origin_x, 0, CELL_W, cell_h), theme.ink)
		for shape: PropShape in shapes:
			drawer.draw_colored_polygon(shape.points, shape.color)
		var feet_y: float = rect.position.y if kind == BlockKind.Kind.BUILDING else 0.0
		_draw_figure(drawer, Vector2(-origin_x + 40.0 if kind != BlockKind.Kind.BUILDING else 60.0, feet_y), theme.ink)
		drawer.draw_string(ThemeDB.fallback_font, Vector2(-origin_x + 8.0, -ground + 18.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.25, 0.12, 0.08))
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
		var y: int = 0
		for row: Array in _rows:
			var cell_h: int = row[1]
			for style: int in 2:
				var crop: Image = image.get_region(Rect2i(style * CELL_W * VARIANTS, y, CELL_W * VARIANTS, cell_h))
				crop.save_png("%s_%s_%s.png" % [base, BlockKind.name_of(row[0]), "lome" if style == 1 else "modern"])
			y += cell_h
	quit()
