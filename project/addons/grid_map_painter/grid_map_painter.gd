@tool
extends EditorPlugin
# Ground Brush for the hills terrain. Raise mode: a void cell gets flat ground,
# a ground cell gains a level; Lower mode: a level-0 cell is erased back to
# void, higher cells drop a level. Dragging spreads the stroke. Terrain lives
# in TWO sibling GridMaps - "Terrain" (walls) and "TerrainFloors" (floors, the
# height authority) - and selecting either arms the brush. Piece selection
# lives in autotiler.gd. Roads are splines now, not a painted map.

const Autotiler = preload("res://addons/grid_map_painter/autotiler.gd")
const LEVEL_MAX:int = 6
const SCRUB_MARGIN:int = 2

var floors:GridMap = null
var walls:GridMap = null
var ground:Ground = null  # the single flat floor mesh; its footprint is level 0
var toolbar:HBoxContainer = null
var brush_button:Button = null
var raise_button:Button = null
var lower_button:Button = null
var size_spin:SpinBox = null
var cursor:MeshInstance3D = null
var hovered:Vector2i = Vector2i.ZERO
var hover_valid:bool = false
var painting:bool = false
var stroke_target:int = 0
var stroke_heights:Dictionary = {}
var stroke_before:Dictionary = {}
var cached_heights:Dictionary = {}


func _enter_tree():
	toolbar = HBoxContainer.new()
	brush_button = Button.new()
	brush_button.text = "Ground Brush"
	brush_button.toggle_mode = true
	brush_button.tooltip_text = "Paint terrain: drag spreads the stroke's level"
	brush_button.toggled.connect(on_brush_toggled)
	toolbar.add_child(brush_button)

	var modes:ButtonGroup = ButtonGroup.new()
	raise_button = Button.new()
	raise_button.text = "Raise"
	raise_button.toggle_mode = true
	raise_button.button_group = modes
	raise_button.button_pressed = true
	raise_button.tooltip_text = "Void gets flat ground, ground gains a level"
	toolbar.add_child(raise_button)
	lower_button = Button.new()
	lower_button.text = "Lower"
	lower_button.toggle_mode = true
	lower_button.button_group = modes
	lower_button.tooltip_text = "Drop a level; level 0 erases back to void"
	toolbar.add_child(lower_button)

	size_spin = SpinBox.new()
	size_spin.min_value = 1
	size_spin.max_value = 4
	size_spin.value = 2
	size_spin.tooltip_text = "Brush size (cells). Size 1 paints 1-wide ridges: lone cells become caps, lines connect with strip and end pieces"
	size_spin.value_changed.connect(func(_value): refresh_cursor())
	toolbar.add_child(size_spin)
	toolbar.visible = false
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar)


func _exit_tree():
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	toolbar.queue_free()
	free_cursor()


func _handles(p_object) -> bool:
	if not (p_object is GridMap) or p_object.mesh_library == null:
		return false
	return p_object.mesh_library.find_item_by_name("hill_top_e_center") != -1


func _edit(p_object):
	var map:GridMap = p_object as GridMap
	floors = null
	walls = null
	ground = null
	if map != null and map.get_parent() != null:
		var parent:Node = map.get_parent()
		walls = parent.get_node_or_null("Terrain") as GridMap
		floors = parent.get_node_or_null("TerrainFloors") as GridMap
		ground = parent.get_node_or_null("Ground") as Ground
		if floors == null or walls == null:
			push_warning("Ground Brush needs sibling GridMaps 'Terrain' + 'TerrainFloors'")
			floors = null
			walls = null
	toolbar.visible = floors != null
	if floors == null:
		end_stroke()
		free_cursor()
	else:
		cached_heights = Autotiler.derive(floors, ground_columns())


# Empty when there is no ground mesh, which puts the y0 tiles back in charge.
func ground_columns() -> Rect2i:
	return ground.columns() if ground != null else Rect2i()


func _forward_3d_gui_input(p_camera:Camera3D, p_event:InputEvent) -> int:
	if floors == null or not brush_button.button_pressed:
		return AFTER_GUI_INPUT_PASS

	if p_event is InputEventMouseMotion:
		hover_valid = pick_column(p_camera, p_event.position)
		refresh_cursor()
		if painting and hover_valid:
			stamp(hovered)
		return AFTER_GUI_INPUT_STOP if painting else AFTER_GUI_INPUT_PASS

	if p_event is InputEventMouseButton and p_event.button_index == MOUSE_BUTTON_LEFT:
		if p_event.pressed and hover_valid:
			begin_stroke()
		elif not p_event.pressed and painting:
			end_stroke()
		# Swallow LMB entirely while the brush is on, so the builtin GridMap
		# painter (active whenever its palette has a selection) can't double-
		# handle the same click at its own floor.
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


# The stroke's target level comes from the first clicked cell and its mode.
func begin_stroke():
	stroke_heights = Autotiler.derive(floors, ground_columns())
	var start:int = Autotiler.level_of(stroke_heights, hovered)
	if raise_button.button_pressed:
		stroke_target = 0 if start == Autotiler.VOID else mini(start + 1, LEVEL_MAX)
	else:
		if start == Autotiler.VOID:
			return
		# Over the ground mesh, level 0 IS the floor - there is no hole to
		# lower into, and erasing the column would only rim its neighbours
		# against land that is still plainly there.
		if start == 0:
			if ground_columns().has_point(hovered):
				return
			stroke_target = Autotiler.VOID
		else:
			stroke_target = start - 1
	painting = true
	stroke_before = {"floors": {}, "walls": {}}
	stamp(hovered)


# Ray-picks the hovered column: physics first (real terrain surface), ground
# plane as the fallback so the brush works over unpainted void.
func pick_column(p_camera:Camera3D, p_position:Vector2) -> bool:
	var origin:Vector3 = p_camera.project_ray_origin(p_position)
	var direction:Vector3 = p_camera.project_ray_normal(p_position)
	var space:PhysicsDirectSpaceState3D = floors.get_world_3d().direct_space_state
	var query:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin, origin + direction * 500.0, 16)
	var hit:Dictionary = space.intersect_ray(query)
	var point:Vector3
	if hit.is_empty():
		var plane:Plane = Plane(Vector3.UP, 0.0)
		var on_plane = plane.intersects_ray(origin, direction)
		if on_plane == null:
			return false
		point = on_plane
	else:
		point = hit.position + Vector3.UP * 0.1
	var cell:Vector3i = floors.local_to_map(floors.to_local(point))
	hovered = Vector2i(cell.x, cell.z)
	return true


# Raise strokes only lift cells below the target; lower strokes only drop
# cells above it. The touched neighborhood retiles immediately.
func stamp(p_column:Vector2i):
	var size:int = brush_size()
	var dirty:Array = []
	var scrub_low:int = stroke_target if stroke_target != Autotiler.VOID else 0
	var scrub_high:int = scrub_low
	for dx in size:
		for dz in size:
			# Same anchoring as the cursor: odd sizes center, even extend SE.
			var column:Vector2i = p_column + Vector2i(dx - (size - 1) / 2, dz - (size - 1) / 2)
			var level:int = Autotiler.level_of(stroke_heights, column)
			var raising:bool = raise_button.button_pressed
			var applies:bool = (raising and (level == Autotiler.VOID or level < stroke_target)) \
					or (not raising and level != Autotiler.VOID and (stroke_target == Autotiler.VOID or level > stroke_target))
			if not applies:
				continue
			if level != Autotiler.VOID:
				scrub_low = mini(scrub_low, level)
				scrub_high = maxi(scrub_high, level)
			if stroke_target == Autotiler.VOID:
				stroke_heights.erase(column)
			else:
				stroke_heights[column] = stroke_target
			dirty.append(column)
	if dirty.is_empty():
		return
	var columns:Array = Autotiler.affected_columns(dirty)
	for column in columns:
		var level:int = Autotiler.level_of(stroke_heights, column)
		if level != Autotiler.VOID:
			scrub_low = mini(scrub_low, level)
			scrub_high = maxi(scrub_high, level)
	var parts:Dictionary = Autotiler.retile(stroke_heights, columns,
			scrub_low - SCRUB_MARGIN, scrub_high + SCRUB_MARGIN, ground_columns())
	record_previous("floors", Autotiler.apply(floors, parts.floors))
	record_previous("walls", Autotiler.apply(walls, parts.walls))
	refresh_cursor()


# First-touch snapshot per map, so undo restores the pre-stroke cells.
func record_previous(p_map:String, p_previous:Dictionary):
	for cell in p_previous:
		if not stroke_before[p_map].has(cell):
			stroke_before[p_map][cell] = p_previous[cell]


func end_stroke():
	if not painting:
		return
	painting = false
	if stroke_before.floors.is_empty() and stroke_before.walls.is_empty():
		return
	var undo:EditorUndoRedoManager = get_undo_redo()
	undo.create_action("Paint ground")
	for pair in [[floors, stroke_before.floors], [walls, stroke_before.walls]]:
		var after:Dictionary = {}
		for cell in pair[1]:
			after[cell] = pair[0].get_cell_item(cell)
		undo.add_do_method(self, "restore_cells", pair[0], after)
		undo.add_undo_method(self, "restore_cells", pair[0], pair[1])
	undo.commit_action(false)
	stroke_before = {"floors": {}, "walls": {}}
	cached_heights = stroke_heights


func restore_cells(p_gridmap:GridMap, p_cells:Dictionary):
	for cell in p_cells:
		p_gridmap.set_cell_item(cell, p_cells[cell])


func brush_size() -> int:
	return int(size_spin.value)


func on_brush_toggled(p_pressed:bool):
	if not p_pressed:
		end_stroke()
	refresh_cursor()


# The translucent hover square. Lives under the GridMap with no owner, so it
# never serializes into the scene.
func refresh_cursor():
	if floors == null or not brush_button.button_pressed or not hover_valid:
		if cursor != null:
			cursor.visible = false
		return
	if cursor == null or not cursor.is_inside_tree():
		free_cursor()
		cursor = MeshInstance3D.new()
		var box:BoxMesh = BoxMesh.new()
		var material:StandardMaterial3D = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.9, 0.2, 0.35)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material = material
		cursor.mesh = box
		cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		floors.add_child(cursor)
	var size:int = brush_size()
	var box:BoxMesh = cursor.mesh as BoxMesh
	var level:int = Autotiler.level_of(
			stroke_heights if painting else cached_heights, hovered)
	if level == Autotiler.VOID:
		level = 0
	var height:float = level * floors.cell_size.y + 0.3
	box.size = Vector3(floors.cell_size.x * size, 0.4, floors.cell_size.z * size)
	var center:Vector3 = floors.map_to_local(Vector3i(hovered.x, level, hovered.y))
	var offset:float = floors.cell_size.x * (1 - size % 2) * 0.5
	cursor.position = Vector3(center.x + offset, height, center.z + offset)
	cursor.visible = true


func free_cursor():
	if cursor != null and is_instance_valid(cursor):
		cursor.queue_free()
	cursor = null
