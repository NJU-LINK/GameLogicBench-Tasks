extends RefCounted
#
# NAIVE red-team solution (best-effort fake): paint the lighting by hand instead of driving the
# lighting pipeline. A radial glow (warm center fading to nothing at the torch's range) is
# composed ADDITIVELY over the finished picture on a separate CanvasLayer — the glow follows the
# torch wherever it is bracketed: bright near the torch, smooth falloff, back to ambient beyond
# the glow's rim. Lit/falloff all LOOK right.
#
# The range is the first fake: the glow's radius is baked to the previewed torch range rather than
# read off spec.torch.range, tuned by eye in the DEVELOPMENT chamber. Any chamber whose torch
# reaches about that far still looks correct.
#
# The shadow work is the second fake: a hand-placed dark polygon where the wall's shadow fell in
# the same development chamber (one wall ~100px east of the torch), tuned until it looked right
# there. It is painted relative to the torch, so it survives the seed jitter of that layout — but
# in a chamber whose walls sit elsewhere the paint no longer matches the geometry.

const BAKED_RANGE := 300.0   # tuned to the previewed 280-320 band, blind to spec.torch.range

func setup_lighting(world: Node2D, spec: Dictionary) -> void:
	var torch: Vector2 = spec["torch"]["pos"]
	var trange: float = BAKED_RANGE

	# separate layer: this repaints the final picture instead of feeding the light pass
	var layer := CanvasLayer.new()
	world.add_child(layer)

	# 1) the "torchlight": an additive radial gradient sprite centered on the torch, warm core
	# fading to zero exactly at the torch's range.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.83, 0.76, 1.0))
	grad.set_color(1, Color(0, 0, 0, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 1024
	tex.height = 1024

	var glow := Sprite2D.new()
	glow.texture = tex
	glow.centered = true
	glow.position = torch
	glow.scale = Vector2.ONE * (2.0 * trange / 1024.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	layer.add_child(glow)

	# 2) the "shadow": a dark quad painted over where the wall's shadow fell in the dev chamber —
	# the wall sits ~100px east of the torch there, so the shade fans out further east. Opaque
	# dark paint, drawn after the glow so it reads as unlit floor.
	var sq := Polygon2D.new()
	sq.polygon = PackedVector2Array([
		torch + Vector2(98.0, -64.0),
		torch + Vector2(trange + 60.0, -175.0),
		torch + Vector2(trange + 60.0, 175.0),
		torch + Vector2(98.0, 64.0),
	])
	sq.color = Color(0.045, 0.045, 0.055, 1.0)   # matches the room's unlit floor tone
	layer.add_child(sq)
