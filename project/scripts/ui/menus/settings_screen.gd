class_name SettingsScreen
extends Control

signal closed

enum Tab {GAMEPLAY, CONTROLS, VIDEO, AUDIO}
enum Row {UNIT_SYSTEM, TIME_FORMAT,
	GAMEPAD_HEADER, LOOK_SENSITIVITY, MOVE_SENSITIVITY, INVERT_LOOK_Y,
	DISPLAY_MODE, RESOLUTION,
	MASTER_VOLUME, SFX_VOLUME}

const TAB_NAMES: Array[String] = ["Gameplay", "Controls", "Video", "Audio"]
const DISPLAY_NAMES: Array[String] = ["Windowed", "Fullscreen"]
const UNIT_NAMES: Array[String] = ["Metric", "Imperial"]
const TIME_NAMES: Array[String] = ["24h", "12h"]
const BOOL_NAMES: Array[String] = ["False", "True"]

@onready var ROW_SCENE: PackedScene = load("res://scenes/ui/settings/settings_row.tscn")
@onready var TAB_SCENE: PackedScene = load("res://scenes/ui/settings/settings_tab.tscn")

@onready var tab_bar: HBoxContainer = %TabBar
@onready var row_container: VBoxContainer = %RowContainer
@onready var apply_button: MenuActionButton = %ApplyButton
@onready var bindings_button: MenuActionButton = %BindingsButton
@onready var reset_button: MenuActionButton = %ResetButton

var tabs: Dictionary = {}
var rows: Dictionary = {}
var data: Dictionary = {}  # Row -> row_data(), snapshot taken at open
var pending: Dictionary = {}  # Row -> staged value
var current_tab: Tab = Tab.GAMEPLAY
var focused_row: int = -1  # index into eligible_rows(); -1 = the pad isn't on one


func _ready():
	hide()  # the scene's visible flag is for editing the panel, not for play
	apply_button.pressed.connect(apply)
	bindings_button.disabled = true
	reset_button.disabled = true
	build_tabs()
	build_rows()


func _unhandled_input(p_event: InputEvent):
	if not visible:
		return
	if p_event.is_action_pressed("pause_game") or p_event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif p_event.is_action_pressed("ui_accept") and not apply_button.disabled:
		get_viewport().set_input_as_handled()
		apply()
	elif p_event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		move_focus(1)
	elif p_event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		move_focus(-1)
	elif p_event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		nudge_focused(1)
	elif p_event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		nudge_focused(-1)
	# The shoulders page the tabs - raw buttons, since LB/RB's world actions
	# (crouch, build_rotate) have no business lending a menu their names.
	elif p_event is InputEventJoypadButton and p_event.pressed \
			and p_event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		get_viewport().set_input_as_handled()
		var step: int = 1 if p_event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
		show_tab(wrapi(current_tab + step, 0, Tab.values().size()) as Tab)


# The rows the pad can stand on: this tab's, live, and never a header.
func eligible_rows() -> Array:
	var found: Array = []
	for row in rows:
		var widget: SettingsRow = rows[row]
		if widget.visible and widget.enabled and widget.kind != SettingsRow.Kind.HEADER:
			found.append(widget)
	return found


func move_focus(p_step: int):
	var eligible: Array = eligible_rows()
	if eligible.is_empty():
		return
	focused_row = wrapi(focused_row + p_step, 0, eligible.size()) \
			if focused_row >= 0 else (0 if p_step > 0 else eligible.size() - 1)
	for i in eligible.size():
		eligible[i].set_focused(i == focused_row)


func nudge_focused(p_step: int):
	var eligible: Array = eligible_rows()
	if focused_row >= 0 and focused_row < eligible.size():
		eligible[focused_row].nudge(p_step)


func clear_focus():
	focused_row = -1
	for row in rows:
		rows[row].set_focused(false)


func row_data(p_row: Row) -> Dictionary:
	match p_row:
		Row.UNIT_SYSTEM:
			return {"tab": Tab.GAMEPLAY, "kind": SettingsRow.Kind.LIST,
					"title": "Unit system", "labels": UNIT_NAMES,
					"values": [Enums.UnitSystem.METRIC, Enums.UnitSystem.IMPERIAL],
					"live": Settings.unit_system}
		Row.TIME_FORMAT:
			return {"tab": Tab.GAMEPLAY, "kind": SettingsRow.Kind.LIST,
					"title": "Time format", "labels": TIME_NAMES,
					"values": [Enums.TimeFormat.HOUR_24, Enums.TimeFormat.HOUR_12],
					"live": Settings.time_format}
		Row.GAMEPAD_HEADER:
			return {"tab": Tab.CONTROLS, "kind": SettingsRow.Kind.HEADER,
					"title": "Gamepad", "live": null}
		Row.LOOK_SENSITIVITY:
			return {"tab": Tab.CONTROLS, "kind": SettingsRow.Kind.SLIDER,
					"title": "Look sensitivity", "live": Settings.look_sensitivity}
		Row.MOVE_SENSITIVITY:
			return {"tab": Tab.CONTROLS, "kind": SettingsRow.Kind.SLIDER,
					"title": "Move sensitivity", "live": Settings.move_sensitivity}
		Row.INVERT_LOOK_Y:
			return {"tab": Tab.CONTROLS, "kind": SettingsRow.Kind.LIST,
					"title": "Invert Y axis", "labels": BOOL_NAMES,
					"values": [false, true], "live": Settings.invert_look_y}
		Row.DISPLAY_MODE:
			return {"tab": Tab.VIDEO, "kind": SettingsRow.Kind.LIST,
					"title": "Display mode", "values": [false, true],
					"labels": DISPLAY_NAMES, "live": Settings.fullscreen}
		Row.RESOLUTION:
			var sizes: Array = Settings.get_available_resolutions()
			return {"tab": Tab.VIDEO, "kind": SettingsRow.Kind.LIST,
					"title": "Resolution", "values": sizes,
					"labels": sizes.map(format_resolution),
					"live": Settings.resolution}
		Row.MASTER_VOLUME:
			return {"tab": Tab.AUDIO, "kind": SettingsRow.Kind.SLIDER,
					"title": "Master volume", "live": Settings.master_volume}
		Row.SFX_VOLUME:
			return {"tab": Tab.AUDIO, "kind": SettingsRow.Kind.SLIDER,
					"title": "Effects volume", "live": Settings.sfx_volume}
	return {}


func build_tabs():
	for tab in Tab.values():
		var button: SettingsTab = TAB_SCENE.instantiate()
		button.text = TAB_NAMES[tab].to_upper()
		button.pressed.connect(show_tab.bind(tab))
		button.focus_mode = FOCUS_NONE  # the shoulders page tabs; rows own the dpad
		tab_bar.add_child(button)
		tabs[tab] = button


func build_rows():
	for row in Row.values():
		var widget: SettingsRow = ROW_SCENE.instantiate()
		row_container.add_child(widget)
		widget.value_changed.connect(on_row_changed.bind(row))
		rows[row] = widget


func show_tab(p_tab: Tab):
	current_tab = p_tab
	for tab in tabs:
		tabs[tab].selected = tab == p_tab
	for row in rows:
		rows[row].visible = data.get(row, {}).get("tab", Tab.GAMEPLAY) == p_tab
	clear_focus()
	if InputManager.pad_active:
		move_focus(1)  # land on the tab's first row rather than on nothing


func open():
	refresh()
	show_tab(current_tab)
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close():
	hide()
	closed.emit()


func refresh():
	for row in rows:
		data[row] = row_data(row)
		pending[row] = data[row].live
		var entry: Dictionary = data[row]
		match entry.kind:
			SettingsRow.Kind.HEADER:
				rows[row].setup_header(entry.title)
			SettingsRow.Kind.SLIDER:
				rows[row].setup_slider(entry.title, entry.live)
			_:
				rows[row].setup_list(entry.title, entry.labels,
						entry.values.find(entry.live))
	update_state()


func apply():
	Settings.unit_system = pending[Row.UNIT_SYSTEM]
	Settings.time_format = pending[Row.TIME_FORMAT]
	Settings.look_sensitivity = pending[Row.LOOK_SENSITIVITY]
	Settings.move_sensitivity = pending[Row.MOVE_SENSITIVITY]
	Settings.invert_look_y = pending[Row.INVERT_LOOK_Y]
	Settings.master_volume = pending[Row.MASTER_VOLUME]
	Settings.sfx_volume = pending[Row.SFX_VOLUME]
	Settings.resolution = pending[Row.RESOLUTION]
	Settings.fullscreen = pending[Row.DISPLAY_MODE]
	close()


func on_row_changed(p_value, p_row: Row):
	pending[p_row] = data[p_row].values[p_value] \
			if data[p_row].kind == SettingsRow.Kind.LIST else p_value
	update_state()


func update_state():
	rows[Row.RESOLUTION].set_enabled(not pending[Row.DISPLAY_MODE])
	apply_button.disabled = not has_changes()


func has_changes() -> bool:
	for row in pending:
		if data[row].kind != SettingsRow.Kind.HEADER \
				and pending[row] != data[row].live:
			return true
	return false


func format_resolution(p_size: Vector2i) -> String:
	return "%d x %d" % [p_size.x, p_size.y]
