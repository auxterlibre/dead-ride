extends Node
# Player settings, persisted to user://settings.cfg. Assigning any of them
# applies, saves and emits Signals.settings_changed.

const FILE_PATH: String = "user://settings.cfg"
const MS_TO_KMH: float = 3.6
const MS_TO_MPH: float = 2.236936
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const LOOK_SLEW_SPAN: Vector2 = Vector2(400.0, 1400.0)
const MOVE_CURVE_SPAN: Vector2 = Vector2(1.8, 0.2)

var time_format: Enums.TimeFormat = Enums.TimeFormat.HOUR_24 : set = set_time_format
var unit_system: Enums.UnitSystem = Enums.UnitSystem.METRIC : set = set_unit_system
var resolution: Vector2i = Vector2i(1920, 1080) : set = set_resolution
var fullscreen: bool = false : set = set_fullscreen
var master_volume: float = 0.5 : set = set_master_volume
var sfx_volume: float = 0.5 : set = set_sfx_volume
var look_sensitivity: float = 0.5 : set = set_look_sensitivity
var move_sensitivity: float = 0.5 : set = set_move_sensitivity
var invert_look_y: bool = false : set = set_invert_look_y

var loading: bool = false


func _ready():
	loading = true
	resolution = default_resolution()
	load_settings()
	loading = false
	apply_display()


func set_time_format(p_value: Enums.TimeFormat):
	time_format = p_value
	changed()


func set_unit_system(p_value: Enums.UnitSystem):
	unit_system = p_value
	changed()


func set_resolution(p_value: Vector2i):
	resolution = p_value
	if not loading:
		apply_display()
	changed()


func set_fullscreen(p_value: bool):
	fullscreen = p_value
	if not loading:
		apply_display()
	changed()


func set_master_volume(p_value: float):
	master_volume = clampf(p_value, 0.0, 1.0)
	apply_volume("Master", master_volume)
	changed()


func set_sfx_volume(p_value: float):
	sfx_volume = clampf(p_value, 0.0, 1.0)
	apply_volume("SFX", sfx_volume)
	changed()


func set_look_sensitivity(p_value: float):
	look_sensitivity = clampf(p_value, 0.0, 1.0)
	changed()


func set_move_sensitivity(p_value: float):
	move_sensitivity = clampf(p_value, 0.0, 1.0)
	changed()


func set_invert_look_y(p_value: bool):
	invert_look_y = p_value
	changed()


func look_slew_value() -> float:
	return lerpf(LOOK_SLEW_SPAN.x, LOOK_SLEW_SPAN.y, look_sensitivity)


func move_curve_value() -> float:
	return lerpf(MOVE_CURVE_SPAN.x, MOVE_CURVE_SPAN.y, move_sensitivity)


func apply_volume(p_bus: String, p_value: float):
	var index: int = AudioServer.get_bus_index(p_bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, is_zero_approx(p_value))
	AudioServer.set_bus_volume_db(index,
			linear_to_db(maxf(p_value, 0.0001) * 2.0))


func changed():
	if loading:
		return
	save()
	Signals.settings_changed.emit()


func load_settings():
	var file: ConfigFile = ConfigFile.new()
	if file.load(FILE_PATH) != OK:
		save()  # first run: leave the defaults on disk
		return
	time_format = file.get_value("interface", "time_format", time_format)
	unit_system = file.get_value("interface", "unit_system", unit_system)
	resolution = file.get_value("display", "resolution", resolution)
	fullscreen = file.get_value("display", "fullscreen", fullscreen)
	master_volume = file.get_value("audio", "master", master_volume)
	sfx_volume = file.get_value("audio", "sfx", sfx_volume)
	look_sensitivity = file.get_value("controls", "look_sensitivity",
			look_sensitivity)
	move_sensitivity = file.get_value("controls", "move_sensitivity",
			move_sensitivity)
	invert_look_y = file.get_value("controls", "invert_look_y", invert_look_y)


func save():
	var file: ConfigFile = ConfigFile.new()
	file.set_value("interface", "time_format", time_format)
	file.set_value("interface", "unit_system", unit_system)
	file.set_value("display", "resolution", resolution)
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("audio", "master", master_volume)
	file.set_value("audio", "sfx", sfx_volume)
	file.set_value("controls", "look_sensitivity", look_sensitivity)
	file.set_value("controls", "move_sensitivity", move_sensitivity)
	file.set_value("controls", "invert_look_y", invert_look_y)
	file.save(FILE_PATH)


func apply_display():
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN \
			if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if fullscreen:
		return
	DisplayServer.window_set_size(resolution)
	center_window()


func center_window():
	var screen: int = DisplayServer.window_get_current_screen()
	var origin: Vector2i = DisplayServer.screen_get_position(screen)
	var size: Vector2i = DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(
			origin + Vector2i(Vector2(size - resolution) / 2.0))


# The saved choice stays listed even if it outgrows the monitor - dropping it
# would silently rewrite the player's setting.
func get_available_resolutions() -> Array[Vector2i]:
	var screen: Vector2i = DisplayServer.screen_get_size(
			DisplayServer.window_get_current_screen())
	if screen.x <= 0 or screen.y <= 0:
		return RESOLUTIONS.duplicate()
	var available: Array[Vector2i] = []
	for option in RESOLUTIONS:
		if option == resolution or (option.x <= screen.x and option.y <= screen.y):
			available.append(option)
	return available


func default_resolution() -> Vector2i:
	var width: int = ProjectSettings.get_setting(
			"display/window/size/window_width_override", 0)
	var height: int = ProjectSettings.get_setting(
			"display/window/size/window_height_override", 0)
	if width <= 0 or height <= 0:
		width = ProjectSettings.get_setting("display/window/size/viewport_width", 1920)
		height = ProjectSettings.get_setting("display/window/size/viewport_height", 1080)
	return Vector2i(width, height)


func format_time(p_hour: int, p_minute: int) -> String:
	if time_format == Enums.TimeFormat.HOUR_24:
		return "%02d:%02d" % [p_hour, p_minute]
	var hour: int = p_hour % 12
	if hour == 0:
		hour = 12
	return "%d:%02d %s" % [hour, p_minute, "AM" if p_hour < 12 else "PM"]


func format_speed(p_meters_per_second: float) -> String:
	if unit_system == Enums.UnitSystem.METRIC:
		return "%d km/h" % roundi(p_meters_per_second * MS_TO_KMH)
	return "%d mph" % roundi(p_meters_per_second * MS_TO_MPH)
