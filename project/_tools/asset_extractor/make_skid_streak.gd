extends SceneTree
# Soft across the WIDTH, TILING down the length; the stroke's own ends taper by vertex alpha.

const OUT:String = "res://assets/textures/vfx/smoke/skid_streak.png"
const WIDTH:int = 64
const HEIGHT:int = 128
const EDGE:float = 0.42  # half-width where the sides start fading
const RIBS:float = 7.0  # faint tread banding across the streak; keep it WHOLE to tile
const RIB_DEPTH:float = 0.12


func _init():
	var image:Image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in HEIGHT:
		for x in WIDTH:
			var u:float = (x + 0.5) / WIDTH
			var v:float = (y + 0.5) / HEIGHT
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha_at(u, v)))
	var error:int = image.save_png(OUT)
	print("DBG skid streak %dx%d -> %s (err %d)" % [WIDTH, HEIGHT, OUT, error])
	quit()


func alpha_at(p_u:float, p_v:float) -> float:
	# Across the width: solid core, soft shoulders, nothing at the very edge.
	var across:float = smoothstep(0.5, EDGE, absf(p_u - 0.5))
	# Faint banding so a long track is not a flat smear. Whole cycles per tile,
	# so it meets itself at the repeat.
	var tread:float = 1.0 - RIB_DEPTH * (0.5 + 0.5 * sin(p_v * RIBS * TAU))
	return across * tread
