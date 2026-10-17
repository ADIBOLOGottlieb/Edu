class_name MenuIcon
extends Control
## Petite icône vectorielle dessinée par code (aucune image importée) : étoile,
## cadenas, flèche retour, pause, poursuite (vigile), chronomètre. Elle se
## dessine dans son rectangle, centrée, en `color`.

enum Kind { STAR, STAR_EMPTY, LOCK, BACK, PAUSE, CHASE, CLOCK, GEAR, INFO }

@export var kind: Kind = Kind.STAR
@export var color: Color = MenuStyle.ACCENT:
	set(value):
		color = value
		queue_redraw()


static func make(icon_kind: Kind, icon_size: float, icon_color: Color = MenuStyle.ACCENT) -> MenuIcon:
	var icon: MenuIcon = MenuIcon.new()
	icon.kind = icon_kind
	icon.color = icon_color
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	match kind:
		Kind.STAR:
			draw_colored_polygon(star_points(c, s * 0.5, s * 0.22), color)
		Kind.STAR_EMPTY:
			var outline: PackedVector2Array = star_points(c, s * 0.46, s * 0.2)
			outline.append(outline[0])
			draw_polyline(outline, color, maxf(2.0, s * 0.07), true)
		Kind.LOCK:
			var w: float = s * 0.62
			var h: float = s * 0.46
			var body: Rect2 = Rect2(c.x - w * 0.5, c.y - h * 0.12, w, h)
			draw_arc(Vector2(c.x, body.position.y), s * 0.2, PI, TAU, 16, color, s * 0.1, true)
			draw_line(Vector2(c.x - s * 0.2, body.position.y), Vector2(c.x - s * 0.2, body.position.y + 2.0), color, s * 0.1)
			draw_line(Vector2(c.x + s * 0.2, body.position.y), Vector2(c.x + s * 0.2, body.position.y + 2.0), color, s * 0.1)
			var box: StyleBoxFlat = MenuStyle.panel_box(color, int(s * 0.08), 0.0)
			draw_style_box(box, body)
		Kind.BACK:
			var t: float = s * 0.11
			draw_polyline(PackedVector2Array([
				c + Vector2(s * 0.1, -s * 0.26), c + Vector2(-s * 0.16, 0.0), c + Vector2(s * 0.1, s * 0.26),
			]), color, t, true)
			draw_circle(c + Vector2(-s * 0.16, 0.0), t * 0.5, color)
		Kind.PAUSE:
			var bar: Vector2 = Vector2(s * 0.14, s * 0.5)
			var b1: StyleBoxFlat = MenuStyle.panel_box(color, int(s * 0.05), 0.0)
			draw_style_box(b1, Rect2(c + Vector2(-s * 0.2, -bar.y * 0.5), bar))
			draw_style_box(b1, Rect2(c + Vector2(s * 0.06, -bar.y * 0.5), bar))
		Kind.CHASE:
			# Triangle d'alerte arrondi et point d'exclamation (vigile à vos trousses).
			var tri: PackedVector2Array = PackedVector2Array([
				c + Vector2(0.0, -s * 0.42), c + Vector2(s * 0.46, s * 0.38), c + Vector2(-s * 0.46, s * 0.38),
			])
			draw_colored_polygon(tri, color)
			var closed: PackedVector2Array = tri.duplicate()
			closed.append(tri[0])
			draw_polyline(closed, color, s * 0.08, true)
			var ink: Color = MenuStyle.INK
			draw_line(c + Vector2(0.0, -s * 0.16), c + Vector2(0.0, s * 0.12), ink, s * 0.1)
			draw_circle(c + Vector2(0.0, s * 0.25), s * 0.06, ink)
		Kind.CLOCK:
			draw_arc(c, s * 0.4, 0.0, TAU, 32, color, s * 0.09, true)
			draw_line(c, c + Vector2(0.0, -s * 0.24), color, s * 0.08)
			draw_line(c, c + Vector2(s * 0.18, 0.0), color, s * 0.08)
			draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.56), Vector2(s * 0.2, s * 0.09)), color)
		Kind.GEAR:
			for i: int in 8:
				var a: float = TAU * float(i) / 8.0
				var dir: Vector2 = Vector2.from_angle(a)
				draw_line(c + dir * s * 0.2, c + dir * s * 0.46, color, s * 0.14)
			draw_circle(c, s * 0.32, color)
			draw_circle(c, s * 0.13, MenuStyle.INK)
		Kind.INFO:
			draw_arc(c, s * 0.4, 0.0, TAU, 32, color, s * 0.09, true)
			draw_line(c + Vector2(0.0, -s * 0.04), c + Vector2(0.0, s * 0.22), color, s * 0.1)
			draw_circle(c + Vector2(0.0, -s * 0.2), s * 0.06, color)


static func star_points(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var radius: float = outer if i % 2 == 0 else inner
		var angle: float = -PI * 0.5 + PI * float(i) / 5.0
		points.append(center + Vector2.from_angle(angle) * radius)
	return points
