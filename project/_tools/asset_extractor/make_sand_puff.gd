extends SceneTree
# One big soft sprite - the kit's smoke sheet ends in HOLLOW RING frames that read as donuts.

const OUT:String = "res://assets/textures/vfx/smoke/sand_puff.png"
const SIZE:int = 256
# The fade runs from near the CENTRE; a solid disc reads as a bead rather than a cloud.
const EDGE_IN:float = 0.05
const EDGE_OUT:float = 0.5
const FALLOFF:float = 1.2  # per-blob softness
const UNION:float = 1.4  # how fast overlapping blobs saturate

# Deterministic cloud of sub-blobs in 0..1 space. They must OVERLAP heavily:
# spaced apart they read as a ring of separate bubbles rather than one cloud.
const BLOBS:Array = [
	[0.50, 0.50, 0.34],
	[0.38, 0.44, 0.24], [0.62, 0.43, 0.25], [0.44, 0.61, 0.24], [0.60, 0.60, 0.23],
	[0.33, 0.56, 0.19], [0.67, 0.56, 0.19], [0.50, 0.34, 0.20], [0.50, 0.68, 0.19],
	[0.28, 0.44, 0.14], [0.72, 0.45, 0.14], [0.40, 0.72, 0.14], [0.62, 0.72, 0.14],
]


func _init():
	var image:Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var u:float = (x + 0.5) / SIZE
			var v:float = (y + 0.5) / SIZE
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha_at(u, v)))
	var error:int = image.save_png(OUT)
	print("DBG sand puff %dx%d -> %s (err %d)" % [SIZE, SIZE, OUT, error])
	quit()


func alpha_at(p_u:float, p_v:float) -> float:
	# Soft UNION, not max - taking the strongest blob leaves each edge visible and gaps read as holes.
	var total:float = 0.0
	for blob in BLOBS:
		var distance:float = Vector2(p_u - blob[0], p_v - blob[1]).length() / blob[2]
		if distance >= 1.0:
			continue
		total += pow(1.0 - distance * distance, FALLOFF)
	if total <= 0.0:
		return 0.0
	var strongest:float = 1.0 - exp(-UNION * total)
	# Global fade so the sprite never reaches the quad edge with any alpha on
	# it - a hard cut there reads as a square, which is worse than a donut.
	var from_centre:float = Vector2(p_u - 0.5, p_v - 0.5).length()
	return strongest * smoothstep(EDGE_OUT, EDGE_IN, from_centre)
