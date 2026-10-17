extends SceneTree
## Génère l'icône de l'application (assets/icon/icon.png, 512 px) : ciel doré de
## Lomé, soleil, toits noirs et coureur en silhouette, titre EDU.
## Usage (fenêtre requise) : godot --path . -s tools/make_icon.gd

const SIZE: int = 512
const OUT: String = "res://assets/icon/icon.png"


func _init() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var canvas: IconCanvas = IconCanvas.new()
	viewport.add_child(canvas)
	root.add_child(viewport)
	_save.call_deferred(viewport)


func _save(viewport: SubViewport) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT)
	print("icône : ", OUT)
	quit()


class IconCanvas:
	extends Node2D

	func _draw() -> void:
		var top: Color = Color(0.33, 0.48, 0.66)
		var horizon: Color = Color(0.99, 0.77, 0.50)
		for y: int in SIZE:
			draw_rect(Rect2(0, y, SIZE, 1), top.lerp(horizon, float(y) / SIZE))
		draw_circle(Vector2(360, 270), 64.0, Color(1.0, 0.9, 0.66))
		var ink: Color = Color(0.04, 0.035, 0.045)
		# Toits : deux immeubles et un vide entre eux.
		draw_rect(Rect2(0, 380, 230, 140), ink)
		draw_rect(Rect2(300, 400, 220, 120), ink)
		draw_rect(Rect2(160, 352, 46, 28), ink)
		# Coureur en plein saut au-dessus du vide.
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(246, 300), Vector2(262, 268), Vector2(280, 262), Vector2(292, 280),
			Vector2(318, 286), Vector2(316, 296), Vector2(286, 292), Vector2(282, 318),
			Vector2(306, 340), Vector2(296, 350), Vector2(266, 326), Vector2(240, 348),
			Vector2(228, 338), Vector2(252, 316),
		])
		draw_colored_polygon(body, ink)
		draw_circle(Vector2(288, 246), 13.0, ink)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(0, 150), "EDU", HORIZONTAL_ALIGNMENT_CENTER, SIZE, 150, ink)
