class_name MenuStyle
extends RefCounted
## Identité visuelle des menus : palette « heure dorée » de Lomé (silhouettes
## noires, ciel chaud, accent orangé), Theme partagé construit par code et
## petites fabriques de nœuds. Police : police de repli du moteur, épaissie
## (FontVariation) pour les titres.
## Cibles tactiles : au moins TOUCH px de haut (≈ 48 dp sur un téléphone
## 1080p en paysage, où 720 px de canevas ≈ 400 dp).

const INK: Color = Color(0.04, 0.035, 0.045)
const CREAM: Color = Color(0.99, 0.95, 0.88)
const MUTED: Color = Color(0.99, 0.95, 0.88, 0.62)
const ACCENT: Color = Color(1.0, 0.72, 0.3)
const ACCENT_DARK: Color = Color(0.88, 0.5, 0.16)
const PANEL: Color = Color(0.05, 0.045, 0.06, 0.8)
const LOCKED: Color = Color(0.99, 0.95, 0.88, 0.32)
const OCEAN_TOP: Color = Color(0.1, 0.12, 0.2)
const OCEAN_BOTTOM: Color = Color(0.2, 0.17, 0.24)
const LAND: Color = Color(0.86, 0.6, 0.42)

## Hauteur minimale d'une cible tactile (px de canevas).
const TOUCH: float = 84.0
const RADIUS: int = 18
## Marge autour du contenu, ajoutée à la zone sûre.
const MARGIN: float = 32.0

static var _theme: Theme
static var _bold: FontVariation
static var _heavy: FontVariation


## Theme commun à tous les écrans (construit une fois).
static func theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme


static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.7
	return _bold


## Police des grands titres (« EDU », « ARRIVÉE »).
static func heavy_font() -> Font:
	if _heavy == null:
		_heavy = FontVariation.new()
		_heavy.base_font = ThemeDB.fallback_font
		_heavy.variation_embolden = 1.4
		_heavy.spacing_glyph = 6
	return _heavy


static func label(text: String, size: int = 26, color: Color = CREAM, bold: bool = false) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override(&"font_size", size)
	node.add_theme_color_override(&"font_color", color)
	if bold:
		node.add_theme_font_override(&"font", bold_font())
	return node


## Bouton de menu ; variation : &"" (sombre), &"PrimaryButton", &"GhostButton".
static func button(text: String, variation: StringName = &"", min_width: float = 0.0) -> Button:
	var node: Button = Button.new()
	node.text = text
	node.theme_type_variation = variation
	node.custom_minimum_size = Vector2(min_width, TOUCH)
	node.focus_mode = Control.FOCUS_ALL
	return node


static func panel_box(color: Color = PANEL, radius: int = RADIUS, margin: float = 28.0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	box.anti_aliasing = true
	return box


## Temps « 1:07.42 » (ou « 17.42 s » sous la minute) ; ≤ 0 → « — ».
static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "—"
	var minutes: int = int(seconds) / 60
	var rest: float = seconds - float(minutes * 60)
	if minutes == 0:
		return "%.2f s" % rest
	return "%d:%05.2f" % [minutes, rest]


static func _build_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font = ThemeDB.fallback_font
	t.default_font_size = 26

	t.set_color(&"font_color", &"Label", CREAM)
	t.set_color(&"font_shadow_color", &"Label", Color(0.0, 0.0, 0.0, 0.35))
	t.set_constant(&"shadow_offset_x", &"Label", 0)
	t.set_constant(&"shadow_offset_y", &"Label", 2)

	_style_button(t, &"Button", Color(INK, 0.74), Color(0.16, 0.13, 0.15, 0.9), ACCENT_DARK, CREAM, INK)
	t.set_font_size(&"font_size", &"Button", 30)
	t.set_font(&"font", &"Button", bold_font())

	t.set_type_variation(&"PrimaryButton", &"Button")
	_style_button(t, &"PrimaryButton", ACCENT, ACCENT.lightened(0.15), ACCENT_DARK, INK, INK)
	t.set_font_size(&"font_size", &"PrimaryButton", 36)

	t.set_type_variation(&"GhostButton", &"Button")
	var ghost: StyleBoxFlat = panel_box(Color(INK, 0.0), RADIUS, 12.0)
	var ghost_hover: StyleBoxFlat = panel_box(Color(INK, 0.35), RADIUS, 12.0)
	t.set_stylebox(&"normal", &"GhostButton", ghost)
	t.set_stylebox(&"hover", &"GhostButton", ghost_hover)
	t.set_stylebox(&"pressed", &"GhostButton", ghost_hover)
	t.set_stylebox(&"disabled", &"GhostButton", ghost)
	t.set_font_size(&"font_size", &"GhostButton", 22)
	t.set_color(&"font_color", &"GhostButton", MUTED)
	t.set_color(&"font_hover_color", &"GhostButton", CREAM)
	t.set_color(&"font_pressed_color", &"GhostButton", ACCENT)

	# Carte de parcours (écran de la ville) : fond sombre, bord accent au survol.
	t.set_type_variation(&"CardButton", &"Button")
	_style_button(t, &"CardButton", Color(INK, 0.78), Color(0.13, 0.1, 0.12, 0.92), Color(0.2, 0.14, 0.12, 0.95), CREAM, CREAM)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var card: StyleBoxFlat = (t.get_stylebox(state, &"CardButton") as StyleBoxFlat).duplicate() as StyleBoxFlat
		card.set_corner_radius_all(22)
		card.set_content_margin_all(0.0)
		if state == &"hover" or state == &"pressed":
			card.border_color = ACCENT
			card.set_border_width_all(3)
		if state == &"disabled":
			card.bg_color = Color(INK, 0.7)
		t.set_stylebox(state, &"CardButton", card)

	t.set_stylebox(&"panel", &"PanelContainer", panel_box())

	# Curseurs : piste épaisse, poignée ronde de 40 px.
	var track: StyleBoxFlat = panel_box(Color(CREAM, 0.18), 6, 0.0)
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0
	var fill: StyleBoxFlat = panel_box(ACCENT, 6, 0.0)
	fill.content_margin_top = 6.0
	fill.content_margin_bottom = 6.0
	t.set_stylebox(&"slider", &"HSlider", track)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	t.set_icon(&"grabber", &"HSlider", _disc_texture(40, CREAM, ACCENT))
	t.set_icon(&"grabber_highlight", &"HSlider", _disc_texture(40, Color.WHITE, ACCENT))
	t.set_icon(&"grabber_disabled", &"HSlider", _disc_texture(40, LOCKED, LOCKED))

	# Interrupteur (CheckButton).
	t.set_icon(&"checked", &"CheckButton", _switch_texture(true))
	t.set_icon(&"unchecked", &"CheckButton", _switch_texture(false))
	t.set_icon(&"checked_disabled", &"CheckButton", _switch_texture(true))
	t.set_icon(&"unchecked_disabled", &"CheckButton", _switch_texture(false))
	var flat: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		t.set_stylebox(state, &"CheckButton", flat)
	t.set_font_size(&"font_size", &"CheckButton", 26)

	# Liste déroulante.
	_style_button(t, &"OptionButton", Color(INK, 0.74), Color(0.16, 0.13, 0.15, 0.9), ACCENT_DARK, CREAM, INK)
	t.set_font(&"font", &"OptionButton", bold_font())
	t.set_font_size(&"font_size", &"OptionButton", 26)
	t.set_icon(&"arrow", &"OptionButton", _chevron_texture())
	t.set_stylebox(&"panel", &"PopupMenu", panel_box(Color(0.08, 0.07, 0.09, 0.98), 14, 10.0))
	t.set_stylebox(&"hover", &"PopupMenu", panel_box(Color(ACCENT, 0.9), 10, 8.0))
	t.set_font_size(&"font_size", &"PopupMenu", 28)
	t.set_color(&"font_color", &"PopupMenu", CREAM)
	t.set_color(&"font_hover_color", &"PopupMenu", INK)
	t.set_constant(&"v_separation", &"PopupMenu", 22)
	t.set_icon(&"radio_checked", &"PopupMenu", _disc_texture(18, ACCENT, ACCENT))
	t.set_icon(&"radio_unchecked", &"PopupMenu", _disc_texture(18, Color(0, 0, 0, 0), Color(0, 0, 0, 0)))

	# Barres de défilement fines.
	var bar: StyleBoxFlat = panel_box(Color(CREAM, 0.08), 4, 0.0)
	bar.content_margin_left = 4.0
	bar.content_margin_right = 4.0
	var grab: StyleBoxFlat = panel_box(Color(CREAM, 0.4), 4, 0.0)
	grab.content_margin_left = 4.0
	grab.content_margin_right = 4.0
	t.set_stylebox(&"scroll", &"VScrollBar", bar)
	t.set_stylebox(&"grabber", &"VScrollBar", grab)
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", grab)
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", grab)
	return t


static func _style_button(
	t: Theme, type: StringName, normal: Color, hover: Color, pressed: Color, font: Color, pressed_font: Color
) -> void:
	var base: StyleBoxFlat = panel_box(normal, RADIUS, 0.0)
	base.content_margin_left = 30.0
	base.content_margin_right = 30.0
	base.content_margin_top = 12.0
	base.content_margin_bottom = 12.0
	base.border_color = Color(CREAM, 0.14)
	base.set_border_width_all(2)
	base.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	base.shadow_size = 6
	base.shadow_offset = Vector2(0.0, 3.0)
	var hover_box: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	hover_box.bg_color = hover
	hover_box.border_color = Color(ACCENT, 0.9)
	var pressed_box: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	pressed_box.bg_color = pressed
	pressed_box.shadow_size = 2
	var disabled_box: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	disabled_box.bg_color = Color(normal, normal.a * 0.45)
	var focus_box: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	focus_box.draw_center = false
	focus_box.shadow_size = 0
	focus_box.border_color = ACCENT
	focus_box.set_border_width_all(3)
	t.set_stylebox(&"normal", type, base)
	t.set_stylebox(&"hover", type, hover_box)
	t.set_stylebox(&"pressed", type, pressed_box)
	t.set_stylebox(&"hover_pressed", type, pressed_box)
	t.set_stylebox(&"disabled", type, disabled_box)
	t.set_stylebox(&"focus", type, focus_box)
	t.set_color(&"font_color", type, font)
	t.set_color(&"font_hover_color", type, font)
	t.set_color(&"font_focus_color", type, font)
	t.set_color(&"font_pressed_color", type, pressed_font)
	t.set_color(&"font_disabled_color", type, Color(font, 0.4))


## Disque plein lissé (poignées, puces), bordé de `rim`.
static func _disc_texture(diameter: int, fill: Color, rim: Color) -> ImageTexture:
	var img: Image = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r: float = float(diameter) * 0.5
	for y: int in diameter:
		for x: int in diameter:
			var d: float = Vector2(float(x) + 0.5 - r, float(y) + 0.5 - r).length()
			var alpha: float = clampf(r - d, 0.0, 1.0)
			var color: Color = rim if d > r - 4.0 else fill
			img.set_pixel(x, y, Color(color, color.a * alpha))
	return ImageTexture.create_from_image(img)


## Interrupteur en forme de pilule : 76 × 42, pastille à droite si actif.
static func _switch_texture(on: bool) -> ImageTexture:
	var w: int = 76
	var h: int = 42
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r: float = float(h) * 0.5
	var track: Color = ACCENT if on else Color(0.35, 0.32, 0.34)
	var knob_x: float = float(w) - r if on else r
	for y: int in h:
		for x: int in w:
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var cx: float = clampf(p.x, r, float(w) - r)
			var d_track: float = p.distance_to(Vector2(cx, r))
			var a_track: float = clampf(r - d_track, 0.0, 1.0)
			var d_knob: float = p.distance_to(Vector2(knob_x, r))
			var a_knob: float = clampf(r - 4.0 - d_knob, 0.0, 1.0)
			var color: Color = Color(track, a_track).blend(Color(CREAM, a_knob))
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func _chevron_texture() -> ImageTexture:
	var s: int = 28
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y: int in s:
		for x: int in s:
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			# Deux segments en V de 3 px d'épaisseur.
			var d1: float = _segment_distance(p, Vector2(6, 10), Vector2(14, 18))
			var d2: float = _segment_distance(p, Vector2(14, 18), Vector2(22, 10))
			var alpha: float = clampf(2.0 - minf(d1, d2), 0.0, 1.0)
			img.set_pixel(x, y, Color(CREAM, alpha))
	return ImageTexture.create_from_image(img)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
