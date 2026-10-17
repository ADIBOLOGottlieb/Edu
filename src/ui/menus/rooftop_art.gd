class_name RooftopArt
extends Control
## Premier plan illustré des menus : toits en silhouette noire (citernes,
## antennes, garde-corps, câbles) et le coureur en plein saut au-dessus d'une
## ruelle, dessinés par code dans l'encre de la ville. Ancré en bas de l'écran.

@export var ink: Color = MenuStyle.INK
@export var accent: Color = MenuStyle.ACCENT
## Position horizontale relative (0..1) du saut du coureur.
@export var runner_x: float = 0.74
## Hauteur du coureur (px).
@export var runner_height: float = 118.0
@export var show_runner: bool = true

var _time: float = 0.0
var _feet: Vector2 = Vector2.ZERO
var _k: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	if show_runner:
		queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var gap_x: float = w * runner_x
	var gap_w: float = 150.0
	# Toit gauche (long, en escalier) et toit droit, la ruelle entre les deux.
	var left_top: float = h - 92.0
	var right_top: float = h - 64.0
	_roof(Rect2(-20.0, left_top + 26.0, gap_x * 0.46 + 20.0, 400.0), 1)
	_roof(Rect2(gap_x * 0.46 - 2.0, left_top, gap_x * 0.54 - gap_w * 0.5 + 2.0, 400.0), 2)
	_roof(Rect2(gap_x + gap_w * 0.5, right_top, w - gap_x - gap_w * 0.5 + 20.0, 400.0), 3)
	# Câbles électriques au-dessus de la ruelle.
	var pole_a: Vector2 = Vector2(gap_x - gap_w * 0.5 - 30.0, left_top - 70.0)
	var pole_b: Vector2 = Vector2(gap_x + gap_w * 0.5 + 60.0, right_top - 84.0)
	draw_line(Vector2(pole_a.x, left_top), pole_a, ink, 4.0)
	draw_line(Vector2(pole_b.x, right_top), pole_b, ink, 4.0)
	for k: int in 2:
		var sag: float = 26.0 + 10.0 * float(k)
		var a: Vector2 = pole_a + Vector2(0.0, 6.0 * float(k))
		var b: Vector2 = pole_b + Vector2(0.0, 6.0 * float(k))
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in 17:
			var t: float = float(i) / 16.0
			points.append(a.lerp(b, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t)))
		draw_polyline(points, Color(ink, 0.9), 2.0, true)
	if show_runner:
		# Léger flottement : suspension au sommet du saut.
		var bob: float = sin(_time * 1.6) * 4.0
		_runner(Vector2(gap_x - 10.0, left_top - 54.0 + bob), runner_height)


## Un toit : bloc plein, rebord, et selon `style` citerne, antenne ou parabole.
func _roof(rect: Rect2, style: int) -> void:
	draw_rect(rect, ink)
	var top: float = rect.position.y
	draw_rect(Rect2(rect.position.x - 6.0, top - 6.0, rect.size.x + 12.0, 8.0), ink)
	var x0: float = rect.position.x
	var x1: float = rect.end.x
	match style:
		1:
			# Citerne sur pieds et petite cabane d'escalier.
			var cx: float = x0 + rect.size.x * 0.55
			draw_rect(Rect2(cx - 4.0, top - 34.0, 4.0, 34.0), ink)
			draw_rect(Rect2(cx + 40.0, top - 34.0, 4.0, 34.0), ink)
			draw_rect(Rect2(cx - 10.0, top - 70.0, 60.0, 38.0), ink)
			draw_circle(Vector2(cx + 20.0, top - 70.0), 30.0, ink, true)
			draw_rect(Rect2(x0 + rect.size.x * 0.12, top - 46.0, 70.0, 46.0), ink)
		2:
			# Garde-corps et antenne.
			for i: int in int(rect.size.x / 26.0):
				draw_rect(Rect2(x0 + 8.0 + float(i) * 26.0, top - 26.0, 3.0, 26.0), ink)
			draw_rect(Rect2(x0, top - 28.0, rect.size.x, 4.0), ink)
			var ax: float = x0 + rect.size.x * 0.3
			draw_line(Vector2(ax, top - 28.0), Vector2(ax, top - 120.0), ink, 3.0)
			draw_line(Vector2(ax - 22.0, top - 96.0), Vector2(ax + 22.0, top - 96.0), ink, 3.0)
			draw_line(Vector2(ax - 14.0, top - 110.0), Vector2(ax + 14.0, top - 110.0), ink, 3.0)
			# Fenêtre de cage d'escalier éclairée.
			var hut: Rect2 = Rect2(x0 + rect.size.x * 0.55, top - 58.0, 84.0, 58.0)
			draw_rect(hut, ink)
			draw_rect(Rect2(hut.position + Vector2(18.0, 16.0), Vector2(16.0, 20.0)), Color(accent, 0.85))
		3:
			# Parabole et climatiseurs.
			var dx: float = x0 + 110.0
			draw_arc(Vector2(dx, top - 40.0), 26.0, deg_to_rad(110.0), deg_to_rad(290.0), 16, ink, 7.0, true)
			draw_line(Vector2(dx, top - 40.0), Vector2(dx + 6.0, top), ink, 4.0)
			draw_rect(Rect2(x0 + 190.0, top - 26.0, 46.0, 26.0), ink)
			draw_rect(Rect2(x1 - 140.0, top - 20.0, 60.0, 20.0), ink)


## Coureur en suspension (silhouette à capuche, de profil vers la droite) ;
## `feet` = point sous les pieds, `height` = taille totale.
func _runner(feet: Vector2, height: float) -> void:
	_feet = feet
	_k = height / 110.0
	var k: float = _k
	var hip: Vector2 = _p(Vector2(0.0, -54.0))
	var shoulder: Vector2 = _p(Vector2(4.0, -88.0))
	# Jambes : avant tendue vers l'avant, arrière repliée (grand écart de saut).
	_limb([hip, _p(Vector2(22.0, -40.0)), _p(Vector2(40.0, -20.0))], 15.0 * k, 11.0 * k)
	_shoe(_p(Vector2(40.0, -20.0)), _p(Vector2(52.0, -18.0)), k)
	_limb([hip, _p(Vector2(-18.0, -40.0)), _p(Vector2(-40.0, -50.0))], 15.0 * k, 11.0 * k)
	_shoe(_p(Vector2(-40.0, -50.0)), _p(Vector2(-46.0, -40.0)), k)
	# Buste ample (sweat) et capuche.
	_limb([hip, shoulder], 27.0 * k, 30.0 * k)
	draw_circle(_p(Vector2(10.0, -101.0)), 12.5 * k, ink, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([
		_p(Vector2(-6.0, -92.0)), _p(Vector2(-2.0, -108.0)), _p(Vector2(10.0, -113.0)), _p(Vector2(6.0, -88.0)),
	]), ink)
	# Bras : avant tendu vers l'avant, arrière en arrière (équilibre).
	_limb([shoulder, _p(Vector2(24.0, -78.0)), _p(Vector2(42.0, -88.0))], 9.0 * k, 8.0 * k)
	_limb([shoulder, _p(Vector2(-16.0, -76.0)), _p(Vector2(-30.0, -62.0))], 9.0 * k, 8.0 * k)


## Point du gabarit du coureur (110 px, pieds en 0) incliné de 12° vers l'avant.
func _p(v: Vector2) -> Vector2:
	return _feet + v.rotated(deg_to_rad(12.0)) * _k


func _limb(points: Array[Vector2], width_start: float, width_end: float) -> void:
	for i: int in points.size() - 1:
		var t0: float = float(i) / float(points.size() - 1)
		var t1: float = float(i + 1) / float(points.size() - 1)
		var w0: float = lerpf(width_start, width_end, t0)
		var w1: float = lerpf(width_start, width_end, t1)
		_capsule(points[i], points[i + 1], w0, w1)


func _capsule(a: Vector2, b: Vector2, wa: float, wb: float) -> void:
	var dir: Vector2 = (b - a).normalized()
	var n: Vector2 = Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5]), ink)
	draw_circle(a, wa * 0.5, ink, true, -1.0, true)
	draw_circle(b, wb * 0.5, ink, true, -1.0, true)


func _shoe(ankle: Vector2, toe: Vector2, k: float) -> void:
	_capsule(ankle, toe, 11.0 * k, 8.0 * k)
