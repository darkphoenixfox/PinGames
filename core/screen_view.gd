## Draws a (SubViewport) texture fitted into this Control, rotated clockwise by
## rotation_deg (0/90/180/270). This is how portrait/TATE output works without
## relying on OS display rotation (D-005).
extends Control

var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
var rotation_deg: int = 0:
	set(v):
		rotation_deg = posmod(v, 360)
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if texture == null:
		return
	var ts := texture.get_size()
	var quarter := rotation_deg % 180 != 0
	var src := Vector2(ts.y, ts.x) if quarter else ts
	var s := minf(size.x / src.x, size.y / src.y)
	draw_set_transform(size * 0.5, deg_to_rad(rotation_deg), Vector2(s, s))
	draw_texture_rect(texture, Rect2(-ts * 0.5, ts), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
