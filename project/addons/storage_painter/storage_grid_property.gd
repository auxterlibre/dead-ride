@tool
extends EditorProperty
# The layout as a size and checkboxes: spinners reshape the rectangle,
# each box opens or locks its cell, and every change writes the same ASCII
# string the resource always stored - through emit_changed, so undo works.
# The string<->grid conversion is STATIC so a headless probe can hold it to
# account without an inspector.

const CELL_LIMIT: int = 16  # spinner ceiling; no pack is a chessboard yet

var width_spin: SpinBox
var height_spin: SpinBox
var grid: GridContainer
var column: VBoxContainer
var updating: bool = false  # true while reflecting an external value


func _init():
	column = VBoxContainer.new()
	var row: HBoxContainer = HBoxContainer.new()
	width_spin = make_spin()
	height_spin = make_spin()
	row.add_child(width_spin)
	row.add_child(make_label("x"))
	row.add_child(height_spin)
	column.add_child(row)
	grid = GridContainer.new()
	column.add_child(grid)
	add_child(column)
	set_bottom_editor(column)  # the grid wants the label's full width
	width_spin.value_changed.connect(func(_v): reshape())
	height_spin.value_changed.connect(func(_v): reshape())


func make_spin() -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = 1
	spin.max_value = CELL_LIMIT
	spin.step = 1
	return spin


func make_label(p_text: String) -> Label:
	var label: Label = Label.new()
	label.text = p_text
	return label


# The inspector's push: the value changed under us (undo, revert, load).
func _update_property():
	var layout: String = get_edited_object()[get_edited_property()]
	var parsed: Dictionary = parse_layout(layout)
	updating = true
	width_spin.value = parsed.size.x
	height_spin.value = parsed.size.y
	rebuild_boxes(parsed)
	updating = false


# A spinner moved: same cells where the rectangles overlap, new ground open.
func reshape():
	if updating:
		return
	write_back()


func rebuild_boxes(p_parsed: Dictionary):
	for child in grid.get_children():
		child.queue_free()
	grid.columns = p_parsed.size.x
	for y in p_parsed.size.y:
		for x in p_parsed.size.x:
			var box: CheckBox = CheckBox.new()
			box.button_pressed = p_parsed.open.has(Vector2i(x, y))
			box.custom_minimum_size = Vector2(28, 28)
			box.toggled.connect(func(_pressed): write_back())
			grid.add_child(box)


# Everything visible, composed back to the string and pushed as ONE edit.
func write_back():
	if updating:
		return
	var size: Vector2i = Vector2i(int(width_spin.value), int(height_spin.value))
	var open: Dictionary = {}
	# What the boxes say, carried onto the (possibly reshaped) rectangle -
	# boxes beyond a shrink simply fall off, the visible, undoable truncation.
	var old_columns: int = maxi(grid.columns, 1)
	for i in grid.get_child_count():
		var box: CheckBox = grid.get_child(i)
		if box.is_queued_for_deletion() or not box.button_pressed:
			continue
		var at: Vector2i = Vector2i(i % old_columns, floori(i / float(old_columns)))
		if at.x < size.x and at.y < size.y:
			open[at] = true
	# Ground the old rectangle never covered starts OPEN - a grown pack is
	# usually more pack.
	var parsed: Dictionary = parse_layout(get_edited_object()[get_edited_property()])
	for y in size.y:
		for x in size.x:
			var at: Vector2i = Vector2i(x, y)
			if x >= parsed.size.x or y >= parsed.size.y:
				open[at] = true
	emit_changed(get_edited_property(), compose_layout(size, open))


# --- the conversion, static for the probe's sake ---

# "." and " " are open, anything else locked - StorageData.parse's exact rule.
static func parse_layout(p_layout: String) -> Dictionary:
	var open: Dictionary = {}
	var size: Vector2i = Vector2i.ZERO
	var rows: PackedStringArray = p_layout.split("\n", false)
	for y in rows.size():
		size.x = maxi(size.x, rows[y].length())
		for x in rows[y].length():
			if rows[y][x] == "." or rows[y][x] == " ":
				open[Vector2i(x, y)] = true
	size.y = rows.size()
	return {"size": Vector2i(maxi(size.x, 1), maxi(size.y, 1)), "open": open}


static func compose_layout(p_size: Vector2i, p_open: Dictionary) -> String:
	var rows: PackedStringArray = PackedStringArray()
	for y in p_size.y:
		var row: String = ""
		for x in p_size.x:
			row += "." if p_open.has(Vector2i(x, y)) else "x"
		rows.append(row)
	return "\n".join(rows)
