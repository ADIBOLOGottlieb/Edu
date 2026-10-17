extends SceneTree
## Rend le décor de Lomé (CityBackdrop + data/cities/lome_theme.tres) à 1280x720
## pour plusieurs positions de caméra (départ, plus loin, en altitude, plus bas),
## avec une bande de toits noirs au premier plan et un coureur factice de 74 px
## pour l'échelle, puis assemble une planche PNG (et garde chaque vue en _N.png).
## Contrôle visuel (nécessite une fenêtre, pas --headless).
## Usage : godot --path . --resolution 1280x720 -s tools/capture_backdrop.gd -- <png_absolu>

const THEME_PATH: String = "res://data/cities/lome_theme.tres"
const RUNNER_HEIGHT: float = 74.0
## Centres de caméra (le coureur est 120 px sous le centre, 220 px en retrait).
const SHOTS: Array[Vector2] = [
	Vector2(220.0, -120.0),
	Vector2(3200.0, -120.0),
	Vector2(7400.0, -160.0),
	Vector2(14000.0, -120.0),
	Vector2(5200.0, -720.0),
	Vector2(10200.0, 180.0),
]
const THUMB: Vector2i = Vector2i(640, 360)

var _out: String = ""
var _camera: Camera2D
var _foreground: Foreground
var _frame: int = 0
var _shot: int = 0
var _images: Array[Image] = []


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var world: Node2D = Node2D.new()
	var backdrop: CityBackdrop = CityBackdrop.new()
	backdrop.theme = load(THEME_PATH) as CityTheme
	world.add_child(backdrop)
	_foreground = Foreground.new()
	_foreground.ink = backdrop.theme.ink
	_foreground.shots = SHOTS
	world.add_child(_foreground)
	_camera = Camera2D.new()
	world.add_child(_camera)
	root.add_child(world)
	_camera.global_position = SHOTS[0]
	process_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	if _frame % 4 != 0:
		return
	await RenderingServer.frame_post_draw
	if _shot >= SHOTS.size() or _images.size() > _shot:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png(_out.get_basename() + "_%d.png" % _shot)
	_images.append(img)
	_shot += 1
	if _shot < SHOTS.size():
		_camera.global_position = SHOTS[_shot]
		return
	var sheet: Image = Image.create(THUMB.x * 2, THUMB.y * 3, false, Image.FORMAT_RGBA8)
	for i: int in _images.size():
		var thumb: Image = _images[i]
		thumb.convert(Image.FORMAT_RGBA8)
		thumb.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(thumb, Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % 2) * THUMB.x, (i / 2) * THUMB.y))
	sheet.save_png(_out)
	print("planche : ", _out)
	quit()


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
