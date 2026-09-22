class_name StorageData
extends Resource

@export_multiline var layout: String = "......" : set = set_layout

var size: Vector2i :
	get:
		parse()
		return cached_size
var open_cells: Dictionary :  # Vector2i -> true, usable cells only
	get:
		parse()
		return cached_open

var cached_size: Vector2i
var cached_open: Dictionary = {}
var parsed: bool = false


func set_layout(p_value: String):
	layout = p_value
	parsed = false  # re-read on the next query


func is_open(p_cell: Vector2i) -> bool:
	return open_cells.has(p_cell)


func open_cell_count() -> int:
	return open_cells.size()


func parse():
	if parsed:
		return
	parsed = true
	cached_size = Vector2i.ZERO
	cached_open = {}
	var rows: PackedStringArray = layout.split("\n", false)
	for y in rows.size():
		var row: String = rows[y]
		cached_size.x = maxi(cached_size.x, row.length())
		for x in row.length():
			if row[x] == "." or row[x] == " ":
				cached_open[Vector2i(x, y)] = true
	cached_size.y = rows.size()
