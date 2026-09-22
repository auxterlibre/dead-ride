extends Control
# Hand-driven icon authoring, WINDOWED like every render tool. Click an item
# in the left list, orbit it with the mouse (Shift snaps to 15°) or ride the
# SLIDERS - 15° detents on all three axes, so a pose is exact and repeatable
# - wheel/Q/E or the zoom slider to frame it, Ctrl+arrows to resize the grid
# footprint. The drawn frame IS the icon's limits, cell lines included.
# Every item carries its own pose knobs (ItemData's Icon Render group); Save
# writes the .tres and renders the png through the same rig call every export
# uses, so what was just seen is bit-for-bit what ships. While the mouse is
# DOWN the framing freezes and re-fits on release.
# --item=/--yaw=/--pitch=/--roll=/--zoom=/--save/--export/--all/--shot user
# args drive it headless for verification.

const Rig = preload("res://_tools/asset_extractor/icon_rig.gd")
const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SHOT: String = "user://icon_studio_shot.png"  # never an absolute path - the shots lesson
const STEP: float = 5.0  # plain arrow nudge, degrees
const SNAP: float = 15.0  # Shift and the sliders land on multiples of this
const ZOOM_STEP: float = 1.05
const DRAG_DEGREES: float = 0.35  # per pixel of mouse travel
const MAX_CELLS: int = 6  # the widest grid any container draws

@onready var preview: TextureRect = %Preview
@onready var frame: Control = %Frame
@onready var item_list: ItemList = %Items
@onready var title_label: Label = %Title
@onready var values_label: Label = %Values
@onready var status_label: Label = %Status
@onready var yaw_slider: HSlider = %YawSlider
@onready var pitch_slider: HSlider = %PitchSlider
@onready var roll_slider: HSlider = %RollSlider
@onready var zoom_slider: HSlider = %ZoomSlider

var items: Array[String] = []  # every ItemData .tres under data/items, model or not
var list_rows: Array[int] = []  # item index -> its ItemList row; dividers offset them
var index: int = 0
var data: ItemData
var loaded: Vector4 = Vector4.ZERO  # yaw/pitch/roll/zoom as on disk, for U
var loaded_size: Vector2i
var viewport: SubViewport
var subject: Node3D
var camera: Camera3D
var dragging: bool = false
var drag_yaw: float = 0.0  # unsnapped accumulators, so a snapped drag stays smooth
var drag_pitch: float = 0.0


func _ready():
	# ALL of them, renderable or not - an item missing its model shows up as a
	# gap to fill instead of silently not existing here. items_under walks the
	# category folders in order, so a divider row opens each one.
	var last_bucket: String = ""
	for path in Rig.items_under(Rig.SOURCE_ROOT):
		var candidate: Resource = load(path)
		if not candidate is ItemData:
			continue
		var bucket: String = Rig.bucket_of(path)
		if bucket != last_bucket:
			last_bucket = bucket
			var divider: int = item_list.add_item(bucket.to_upper())
			item_list.set_item_selectable(divider, false)
			item_list.set_item_disabled(divider, true)
			item_list.set_item_custom_fg_color(divider, Color(1.0, 1.0, 1.0, 0.35))
		items.append(path)
		var row: int = item_list.add_item(list_label(candidate))
		item_list.set_item_metadata(row, items.size() - 1)
		list_rows.append(row)
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	Rig.add_environment(viewport)
	Rig.add_light(viewport)
	camera = Rig.add_camera(viewport)
	preview.texture = viewport.get_texture()
	preview.gui_input.connect(on_preview_input)
	frame.draw.connect(on_frame_draw)
	frame.resized.connect(frame.queue_redraw)
	item_list.item_selected.connect(on_row_selected)
	yaw_slider.value_changed.connect(func(p_value: float):
		data.icon_yaw = p_value
		refresh())
	pitch_slider.value_changed.connect(func(p_value: float):
		data.icon_pitch = p_value
		refresh())
	roll_slider.value_changed.connect(func(p_value: float):
		data.icon_roll = p_value
		refresh())
	zoom_slider.value_changed.connect(func(p_value: float):
		data.icon_zoom = p_value
		refresh())
	%ResetButton.pressed.connect(reset_pose)
	%SaveButton.pressed.connect(save_current)
	%ExportOneButton.pressed.connect(export_current)
	%ExportButton.pressed.connect(export_all)
	if items.is_empty():
		title_label.text = "No items found"
		return
	show_item(0)
	await run_shot_mode()


func show_item(p_index: int):
	index = wrapi(p_index, 0, items.size())
	data = load(items[index])
	if subject:
		subject.queue_free()
	subject = Rig.subject_for(data)
	if subject:
		Rig.strip_effects(subject)
		viewport.add_child(subject)
	loaded = knobs()
	loaded_size = data.size
	item_list.select(list_rows[index])
	status_label.text = "" if subject else "no model - set ItemData.model to render"
	refresh()


# Divider rows carry no metadata; only real items respond to a click.
func on_row_selected(p_row: int):
	var item: Variant = item_list.get_item_metadata(p_row)
	if item != null:
		show_item(item)


func list_label(p_item: ItemData) -> String:
	return "%s   %dx%d%s" % [p_item.name, p_item.size.x, p_item.size.y,
			"" if p_item.model else "   (no model)"]


func knobs() -> Vector4:
	return Vector4(data.icon_yaw, data.icon_pitch, data.icon_roll, data.icon_zoom)


# Studio state that disk has not seen - the title's asterisk, and what a plain
# export would silently leave out.
func dirty() -> bool:
	return loaded != knobs() or loaded_size != data.size


# p_refit false = mid-drag: pose and labels only, the camera stays put so the
# item spins in place instead of the fit breathing with every angle.
func refresh(p_refit: bool = true):
	viewport.size = data.size * Rig.CELL
	if subject:
		Rig.pose(subject, data)
		if p_refit:
			Rig.frame_subject(camera, viewport.size, Rig.mesh_bounds(subject),
					data.icon_zoom)
	title_label.text = "%s%s" % [data.name, "  *" if dirty() else ""]
	values_label.text = "%dx%d   yaw %.0f°   pitch %.0f°   roll %.0f°   zoom %.2fx" % [
			data.size.x, data.size.y, data.icon_yaw, data.icon_pitch,
			data.icon_roll, data.icon_zoom]
	yaw_slider.set_value_no_signal(data.icon_yaw)
	pitch_slider.set_value_no_signal(data.icon_pitch)
	roll_slider.set_value_no_signal(data.icon_roll)
	zoom_slider.set_value_no_signal(data.icon_zoom)
	item_list.set_item_text(list_rows[index], list_label(data))
	frame.queue_redraw()


# The frame IS the icon: its border is the png's edge, the inner lines the
# 128px grid cells it will span in the bar and the pack.
func on_frame_draw():
	if data == null:
		return
	var rect: Rect2 = fitted_rect(frame.size, Vector2(viewport.size))
	frame.draw_rect(rect, Color(0.918, 0.886, 0.718, 0.9), false, 3.0)
	var cell: Vector2 = rect.size / Vector2(data.size)
	for x in range(1, data.size.x):
		var fx: float = rect.position.x + cell.x * x
		frame.draw_line(Vector2(fx, rect.position.y), Vector2(fx, rect.end.y),
				Color(0.918, 0.886, 0.718, 0.25), 1.5)
	for y in range(1, data.size.y):
		var fy: float = rect.position.y + cell.y * y
		frame.draw_line(Vector2(rect.position.x, fy), Vector2(rect.end.x, fy),
				Color(0.918, 0.886, 0.718, 0.25), 1.5)


# KEEP_ASPECT_CENTERED's own math, so the frame lands exactly on the texture.
func fitted_rect(p_area: Vector2, p_texture: Vector2) -> Rect2:
	var new_scale: float = minf(p_area.x / p_texture.x, p_area.y / p_texture.y)
	var new_size: Vector2 = p_texture * new_scale
	return Rect2((p_area - new_size) * 0.5, new_size)


func on_preview_input(p_event: InputEvent):
	if data == null:
		return
	var button: InputEventMouseButton = p_event as InputEventMouseButton
	if button:
		if button.button_index == MOUSE_BUTTON_LEFT:
			dragging = button.pressed
			drag_yaw = data.icon_yaw
			drag_pitch = data.icon_pitch
			if not dragging:
				refresh()  # released: the fit tightens onto the rested pose
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			data.icon_zoom = clampf(data.icon_zoom * ZOOM_STEP, 0.2, 5.0)
			refresh()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			data.icon_zoom = clampf(data.icon_zoom / ZOOM_STEP, 0.2, 5.0)
			refresh()
		return
	var motion: InputEventMouseMotion = p_event as InputEventMouseMotion
	if motion and dragging:
		drag_yaw = wrapf(drag_yaw + motion.relative.x * DRAG_DEGREES, -180.0, 180.0)
		drag_pitch = clampf(drag_pitch - motion.relative.y * DRAG_DEGREES, -90.0, 90.0)
		data.icon_yaw = snappedf(drag_yaw, SNAP) if motion.shift_pressed else drag_yaw
		data.icon_pitch = snappedf(drag_pitch, SNAP) if motion.shift_pressed else drag_pitch
		refresh(false)


func _unhandled_key_input(p_event: InputEvent):
	var key: InputEventKey = p_event as InputEventKey
	if key == null or not key.pressed or data == null:
		return
	match key.keycode:
		KEY_LEFT:
			if key.ctrl_pressed:
				resize_item(Vector2i(-1, 0))
			else:
				data.icon_yaw = turned(data.icon_yaw, -1.0, key.shift_pressed)
		KEY_RIGHT:
			if key.ctrl_pressed:
				resize_item(Vector2i(1, 0))
			else:
				data.icon_yaw = turned(data.icon_yaw, 1.0, key.shift_pressed)
		KEY_UP:
			if key.ctrl_pressed:
				resize_item(Vector2i(0, 1))
			else:
				data.icon_pitch = clampf(turned(data.icon_pitch, 1.0, key.shift_pressed), -90.0, 90.0)
		KEY_DOWN:
			if key.ctrl_pressed:
				resize_item(Vector2i(0, -1))
			else:
				data.icon_pitch = clampf(turned(data.icon_pitch, -1.0, key.shift_pressed), -90.0, 90.0)
		KEY_E:
			data.icon_zoom = clampf(data.icon_zoom * ZOOM_STEP, 0.2, 5.0)
		KEY_Q:
			data.icon_zoom = clampf(data.icon_zoom / ZOOM_STEP, 0.2, 5.0)
		KEY_B:
			if not key.echo:
				export_all()
			return
		KEY_X:
			if not key.echo:
				export_current()
			return
		KEY_R:
			if not key.echo:
				reset_pose()
			return
		KEY_U:
			data.icon_yaw = loaded.x
			data.icon_pitch = loaded.y
			data.icon_roll = loaded.z
			data.icon_zoom = loaded.w
			data.size = loaded_size
		KEY_TAB, KEY_N:
			if not key.echo:
				show_item(index + 1)
			return
		KEY_P, KEY_BACKSPACE:
			if not key.echo:
				show_item(index - 1)
			return
		KEY_ENTER, KEY_KP_ENTER:
			if not key.echo:
				save_current()
			return
		KEY_ESCAPE:
			get_tree().quit()
			return
		_:
			return
	refresh()


# Plain steps nudge; Shift lands the value on the snap grid (0, 15, 30...).
func turned(p_value: float, p_direction: float, p_snap: bool) -> float:
	if p_snap:
		return wrapf(snappedf(p_value + SNAP * p_direction, SNAP), -180.0, 180.0)
	return wrapf(p_value + STEP * p_direction, -180.0, 180.0)


# The icon size IS the item's grid footprint - resizing here is authoring the
# item, and the png follows it on the next save.
func resize_item(p_delta: Vector2i):
	data.size = (data.size + p_delta).clamp(Vector2i.ONE, Vector2i(MAX_CELLS, MAX_CELLS))


func reset_pose():
	data.icon_yaw = 0.0
	data.icon_pitch = 0.0
	data.icon_roll = 0.0
	data.icon_zoom = 1.0
	refresh()


# The knobs into the .tres, the pixels through the SHARED rig export - what
# was just seen is what ships. The editor picks the png change up on focus.
func save_current():
	ExtractLib.save_keeping_uid(data, items[index])
	loaded = knobs()
	loaded_size = data.size
	# Knobs are worth saving ahead of the model; the png waits for one.
	if data.model == null:
		status_label.text = "saved %s (no model, png skipped)" % items[index].get_file()
		refresh()
		return
	var out_path: String = Rig.icon_path(items[index])
	var error: int = await Rig.render_png(self, data, out_path)
	if error == ERR_UNAVAILABLE:
		status_label.text = "saved %s (no visible mesh, png skipped)" \
				% items[index].get_file()
		refresh()
		return
	status_label.text = "saved %s + %s%s" % [items[index].get_file(),
			out_path.get_file(), "" if error == OK else "  PNG FAILED (%d)" % error]
	refresh()


# One item's png, from its knobs ON DISK (cache bypassed), so unsaved studio
# tweaks never leak into the shipped pngs. Both export scopes go through here,
# so a single re-render is bit-identical to the same item inside the full run.
# ERR_INVALID_DATA = no model, ERR_UNAVAILABLE = nothing visible; both skips.
func export_item(p_path: String) -> int:
	var target: ItemData = ResourceLoader.load(p_path, "",
			ResourceLoader.CACHE_MODE_IGNORE)
	if target.model == null:
		print("DBG %-14s    skipped (no model)" % target.name)
		return ERR_INVALID_DATA
	var out_path: String = Rig.icon_path(p_path)
	var error: int = await Rig.render_png(self, target, out_path)
	if error == ERR_UNAVAILABLE:
		# A model with nothing to see - the fists' invisible scene.
		print("DBG %-14s    skipped (no visible mesh)" % target.name)
		return error
	print("DBG %-14s -> %s%s" % [target.name, out_path,
			"" if error == OK else "  FAILED (%d)" % error])
	return error


# The whole set in one go.
func export_all():
	var count: int = 0
	var skipped: int = 0
	for path in items:
		var error: int = await export_item(path)
		if error == OK:
			count += 1
		elif error == ERR_INVALID_DATA or error == ERR_UNAVAILABLE:
			skipped += 1
	status_label.text = "exported %d icons, %d skipped" % [count, skipped]


# Just the item on screen - re-rendering one changed model without the whole
# set's minutes. Its knobs come off DISK like the full export, so the status
# says so out loud whenever the studio is holding unsaved ones.
func export_current():
	var error: int = await export_item(items[index])
	var file: String = items[index].get_file()
	match error:
		OK:
			status_label.text = "exported %s%s" % [
					Rig.icon_path(items[index]).get_file(),
					"  (from disk - unsaved tweaks not included)" if dirty() else ""]
		ERR_INVALID_DATA:
			status_label.text = "skipped %s (no model)" % file
		ERR_UNAVAILABLE:
			status_label.text = "skipped %s (no visible mesh)" % file
		_:
			status_label.text = "%s PNG FAILED (%d)" % [file, error]


# Verification seam: `-- --item=fuel_can --roll=30 --save --all --shot`
# stages, saves, exports and screenshots, in that order; --export is the
# one-item render of the same batch path, and either export flag without
# --shot quits when done (the CLI batch-render mode).
func run_shot_mode():
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--item="):
			for i in items.size():
				if items[i].get_file().get_basename() == arg.get_slice("=", 1):
					show_item(i)
					break
		elif arg.begins_with("--yaw="):
			data.icon_yaw = float(arg.get_slice("=", 1))
			refresh()
		elif arg.begins_with("--pitch="):
			data.icon_pitch = float(arg.get_slice("=", 1))
			refresh()
		elif arg.begins_with("--roll="):
			data.icon_roll = float(arg.get_slice("=", 1))
			refresh()
		elif arg.begins_with("--zoom="):
			data.icon_zoom = float(arg.get_slice("=", 1))
			refresh()
	if "--save" in args:
		await save_current()
		print("DBG shot-mode save: %s" % status_label.text)
	if "--export" in args:
		await export_current()
		print("DBG shot-mode export: %s" % status_label.text)
	if "--all" in args:
		await export_all()
		print("DBG shot-mode: %s" % status_label.text)
	if "--shot" in args:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(SHOT)
		print("DBG saved studio shot")
		get_tree().quit()
		return
	if "--all" in args or "--export" in args:
		get_tree().quit()
