class_name InventoryCell
extends Panel
# One grid square. Purely decorative - the grid owns hit-testing, because a
# multi-cell item spans several of these. Locked cells are simply never built,
# so every instance is an open cell; the mask shows only through the shape of
# what exists.

# Both wash a CREAM panel, so the valid tint has to darken rather than lighten
# - a cream-on-cream highlight is invisible.
const VALID_TINT: Color = Color(0.0, 0.1882, 0.2863, 0.22)  # Palette.BLUE
const INVALID_TINT: Color = Color(0.839, 0.157, 0.157, 0.34)  # Palette.RED

const CORNER_RADIUS: int = 12  # the mockup's rounding, measured off the render

@onready var highlight: ColorRect = $Highlight


# Dresses the cell from its place in the mask. Seams are SINGLE-drawn: every
# cell owns its left and top edge, and closes right or bottom only against the
# outside - two neighbours both drawing a full border read as a doubled 4px
# line where the mockup has 2. Corners round wherever both edge neighbours
# across them are missing: the shape's convex corners, which is the design's
# rule for the outer silhouette while inner steps stay square.
func shape(p_close_right: bool, p_close_bottom: bool, p_corners: Array[bool]):
	var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	var line: int = style.border_width_left  # the authored seam width
	style.border_width_right = line if p_close_right else 0
	style.border_width_bottom = line if p_close_bottom else 0
	style.corner_radius_top_left = CORNER_RADIUS if p_corners[0] else 0
	style.corner_radius_top_right = CORNER_RADIUS if p_corners[1] else 0
	style.corner_radius_bottom_right = CORNER_RADIUS if p_corners[2] else 0
	style.corner_radius_bottom_left = CORNER_RADIUS if p_corners[3] else 0
	add_theme_stylebox_override("panel", style)


# Shown under a dragged item so the footprint it would take is readable before
# the drop.
func set_highlight(p_on: bool, p_valid: bool = true):
	highlight.visible = p_on
	if p_on:
		highlight.color = VALID_TINT if p_valid else INVALID_TINT
