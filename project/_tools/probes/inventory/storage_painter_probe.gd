extends ProbeBase
# DBG probe: the storage painter's string<->grid conversion - the statics the
# inspector widget rides. The widget itself is editor chrome; the conversion
# is what could silently eat a pack shape, so it answers here.


func _ready():
	var GridProperty: GDScript = load(
			"res://addons/storage_painter/storage_grid_property.gd")

	# --- the hiker pack's authored mask survives the round trip
	var hiker: StorageData = load("res://data/storage/hiker_layout.tres")
	var parsed: Dictionary = GridProperty.parse_layout(hiker.layout)
	check(parsed.size == hiker.size,
			"the painter reads the authored mask's size", str(parsed.size))
	check(parsed.open.size() == hiker.open_cell_count(),
			"and its exact open cells", "%d cells" % parsed.open.size())
	var composed: String = GridProperty.compose_layout(parsed.size, parsed.open)
	var reparsed: Dictionary = GridProperty.parse_layout(composed)
	check(reparsed.size == parsed.size and reparsed.open == parsed.open,
			"and the round trip changes nothing", composed.replace("\n", "/"))

	# --- what it writes is what StorageData reads
	var fresh: StorageData = StorageData.new()
	fresh.layout = composed
	check(fresh.size == hiker.size \
			and fresh.open_cell_count() == hiker.open_cell_count(),
			"StorageData parses the composed string identically",
			"%s, %d open" % [fresh.size, fresh.open_cell_count()])

	# --- blanks compose back as x, not as vanishing spaces
	var gapped: Dictionary = GridProperty.parse_layout("x.\n. ")
	check(gapped.open.size() == 3 and not gapped.open.has(Vector2i.ZERO),
			"a space reads open, an x reads locked", str(gapped.open.keys()))
	var solid: String = GridProperty.compose_layout(gapped.size, gapped.open)
	check(not " " in solid and solid.length() == 5,
			"and the composer writes only . and x", solid.replace("\n", "/"))

	# --- ragged rows read as the widest rectangle
	var ragged: Dictionary = GridProperty.parse_layout("..\n....")
	check(ragged.size == Vector2i(4, 2),
			"ragged rows widen to the longest", str(ragged.size))
	check(not ragged.open.has(Vector2i(3, 0)),
			"and the short row's missing cells stay locked", "locked")

	# --- an empty string is a 1x1, never a zero rectangle
	var empty: Dictionary = GridProperty.parse_layout("")
	check(empty.size == Vector2i.ONE and empty.open.is_empty(),
			"an empty layout is a locked 1x1, not a crash", str(empty.size))

	finish()
