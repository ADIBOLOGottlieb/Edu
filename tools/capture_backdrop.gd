extends SceneTree
## Rend le décor de Lomé (CityBackdrop + data/cities/lome_theme.tres) à 1280x720
## pour plusieurs positions de caméra (départ, une vue cadrée sur chaque repère,
## en altitude, plus bas), avec une bande de toits noirs au premier plan et un
## coureur factice de 74 px pour l'échelle, puis assemble une planche PNG (et
## garde chaque vue en _N.png).
## Mode « landmarks » : planche des repères seuls, agrandis, sur fond de ciel.
## Contrôle visuel (nécessite une fenêtre, pas --headless).
## Usage : godot --path . --resolution 1280x720 -s tools/capture_backdrop.gd -- <png_absolu> [landmarks]

const THEME_PATH: String = "res://data/cities/lome_theme.tres"
## Repères proposés pour Lomé, ajoutés en mémoire s'ils manquent aux données.
const LOME_LANDMARKS: Array[StringName] = [
	&"cathedral", &"colombe_paix", &"deux_lions", &"beach_palms", &"palais_lome", &"hotel_tower",
]
const RUNNER_HEIGHT: float = 74.0
const REFERENCE: Vector2 = Vector2(220.0, -120.0)
const EXTRA_SHOTS: Array[Vector2] = [
	Vector2(17000.0, -720.0),
	Vector2(20500.0, 180.0),
]
const THUMB: Vector2i = Vector2i(640, 360)

var _out: String = ""
var _camera: Camera2D
var _foreground: Foreground
var _frame: int = 0
var _shot: int = 0
var _shots: Array[Vector2] = []
var _images: Array[Image] = []
var _sheet_mode: bool = false


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	_sheet_mode = args.size() > 1 and args[1] == "landmarks"
	var theme: CityTheme = (load(THEME_PATH) as CityTheme).duplicate() as CityTheme
	for key: StringName in LOME_LANDMARKS:
		if not theme.landmarks.has(key):
			theme.landmarks.append(key)
	if _sheet_mode:
		_build_sheet(theme)
	else:
		_build_scene(theme)
	process_frame.connect(_tick)


func _build_scene(theme: CityTheme) -> void:
	var world: Node2D = Node2D.new()
	var backdrop: CityBackdrop = CityBackdrop.new()
	backdrop.theme = theme
	world.add_child(backdrop)
	_shots = _frame_landmarks(backdrop)
	_foreground = Foreground.new()
	_foreground.ink = theme.ink
	_foreground.shots = _shots
	world.add_child(_foreground)
	_camera = Camera2D.new()
	world.add_child(_camera)
	root.add_child(world)
	_camera.global_position = _shots[0]


## Départ, puis une caméra par repère qui le place au milieu de l'écran, puis
## les vues en altitude et en contrebas.
func _frame_landmarks(backdrop: CityBackdrop) -> Array[Vector2]:
	var shots: Array[Vector2] = [REFERENCE]
	var layers: Array[Vector3] = [
		Vector3(CityBackdrop.FAR_SPAN, backdrop.far_scroll.x, LandmarkPainter.Layer.FAR),
		Vector3(CityBackdrop.MID_SPAN, backdrop.mid_scroll.x, LandmarkPainter.Layer.MID),
	]
	var half_view: float = 640.0
	for l: Vector3 in layers:
		for s: BackdropLayerPainter.Slot in BackdropLayerPainter.landmark_slots(backdrop.theme, int(l.z) as LandmarkPainter.Layer, l.x):
			if s.key == backdrop.theme.monument or s.key == &"beach_palms":
				continue
			# À la caméra de référence, x motif + 420 = x écran ; le plan défile à l.y.
			var cam_x: float = REFERENCE.x + (s.x + (half_view - REFERENCE.x) - half_view) / l.y
			print("%s : plan %d, x = %.0f, caméra %.0f (≈ %.0f s à 400 px/s)" % [s.key, int(l.z), s.x, cam_x, cam_x / 400.0])
			shots.append(Vector2(cam_x, REFERENCE.y))
	shots.append_array(EXTRA_SHOTS)
	return shots


func _tick() -> void:
	_frame += 1
	if _frame % 4 != 0:
		return
	await RenderingServer.frame_post_draw
	if _sheet_mode:
		if _images.is_empty():
			var img: Image = root.get_texture().get_image()
			_images.append(img)
			img.save_png(_out)
			print("planche des repères : ", _out)
			quit()
		return
	if _shot >= _shots.size() or _images.size() > _shot:
		return
	var shot_img: Image = root.get_texture().get_image()
	shot_img.save_png(_out.get_basename() + "_%d.png" % _shot)
	_images.append(shot_img)
	_shot += 1
	if _shot < _shots.size():
		_camera.global_position = _shots[_shot]
		return
	var rows: int = (_images.size() + 1) / 2
	var sheet: Image = Image.create(THUMB.x * 2, THUMB.y * rows, false, Image.FORMAT_RGBA8)
	for i: int in _images.size():
		var thumb: Image = _images[i]
		thumb.convert(Image.FORMAT_RGBA8)
		thumb.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(thumb, Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % 2) * THUMB.x, (i / 2) * THUMB.y))
	sheet.save_png(_out)
	print("planche : ", _out)
	quit()


## Planche des repères : chaque repère agrandi dans la couleur de son plan.
func _build_sheet(theme: CityTheme) -> void:
	# Espace de l'étirement « canvas_items » : la taille de base du projet.
	var size: Vector2 = Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width") as float,
		ProjectSettings.get_setting("display/window/size/viewport_height") as float)
	var canvas: BackdropCanvas = BackdropCanvas.new()
	canvas.add_gradient(PackedVector2Array([
		Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, size.y), Vector2(0.0, size.y),
	]), PackedColorArray([theme.sky_top, theme.sky_top, theme.sky_horizon, theme.sky_horizon]))
	var keys: Array[StringName] = BackdropLayerPainter.theme_landmarks(theme)
	keys.erase(&"beach_palms")
	var per_row: int = ceili(float(keys.size()) / 2.0)
	var cell: float = size.x / float(per_row)
	for i: int in keys.size():
		var key: StringName = keys[i]
		var row: int = i / per_row
		var ground: float = size.y * (0.5 if row == 0 else 0.97)
		var scale: float = minf((cell - 30.0) / LandmarkPainter.width(key), 1.1)
		var color: Color = theme.far_color if LandmarkPainter.layer_of(key) == LandmarkPainter.Layer.FAR else theme.mid_color
		var slot: BackdropLayerPainter.Slot = BackdropLayerPainter.Slot.new(key, cell * (float(i % per_row) + 0.5), scale)
		BackdropLayerPainter.paint_landmark(canvas, theme, slot, color, ground)
	root.add_child(canvas)


## Premier plan factice : toits noirs (avec climatiseurs, citernes, garde-corps)
## et silhouette du coureur sous chaque position de caméra.
class Foreground:
	extends Node2D

	var ink: Color = Color.BLACK
	var shots: Array[Vector2] = []

	func _draw() -> void:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 5
		for cam: Vector2 in shots:
			var runner: Vector2 = cam + Vector2(-220.0, 120.0)
			var x: float = cam.x - 800.0
			while x < cam.x + 800.0:
				var w: float = rng.randf_range(220.0, 520.0)
				var top: float = runner.y + [0.0, -70.0, 50.0, -30.0][rng.randi() % 4]
				draw_rect(Rect2(x, top, w, 3000.0), ink)
				draw_rect(Rect2(x + w * 0.2, top - 18.0, 30.0, 18.0), ink)
				draw_rect(Rect2(x + w * 0.62, top - 34.0, 22.0, 34.0), ink)
				draw_rect(Rect2(x, top - 10.0, 3.0, 10.0), ink)
				draw_rect(Rect2(x + w - 3.0, top - 10.0, 3.0, 10.0), ink)
				draw_rect(Rect2(x, top - 10.0, w, 2.0), ink)
				x += w + rng.randf_range(70.0, 160.0)
			# Toujours un toit sous le coureur.
			draw_rect(Rect2(runner.x - 90.0, runner.y, 200.0, 3000.0), ink)
			draw_rect(Rect2(runner.x - 11.0, runner.y - RUNNER_HEIGHT, 22.0, RUNNER_HEIGHT), ink)
			draw_circle(runner + Vector2(0.0, -RUNNER_HEIGHT - 6.0), 9.0, ink)
