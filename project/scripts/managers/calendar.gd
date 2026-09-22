extends Node

const HOUR_DURATION: float = 60.0  # real seconds per game hour
const MINUTES_PER_DAY: float = 1440.0
const DAYS_PER_YEAR: int = 336  # 12 months of 28

var time_data: TimeData
var timer: Timer


func _ready():
	time_data = TimeData.new()
	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(on_timer_timeout)
	timer.one_shot = false
	timer.start(HOUR_DURATION / 60.0)
	# Autoloads are ready before the HUD, so the first emit waits for it.
	Signals.calendar_updated.emit.call_deferred(time_data)


func on_timer_timeout():
	time_data.add_minute()
	Signals.calendar_updated.emit(time_data)


# An earlier hour rolls to the next day - time never rewinds.
func set_time(p_hour: int, p_minute: int = 0):
	# Minutes-of-day, not hours: sleeping at 08:06 must land on TOMORROW'S
	# 08:00, not rewind six minutes. Exactly-equal stays a same-day no-op so a
	# debug scrub landing on the current time doesn't leap a day.
	if time_data.hour * 60 + time_data.minute > p_hour * 60 + p_minute:
		time_data.add_day()
	time_data.hour = p_hour
	time_data.minute = p_minute
	time_data.second = 0
	Signals.calendar_updated.emit(time_data)


# AT OR PAST, never `hour == x`: the clock JUMPS (a debug scrub, a sleep, a
# loaded save), so an exact test can miss its instant and stall the day forever.
func past_hour(p_hour: int, p_minute: int = 0) -> bool:
	return time_data.get_minutes_of_day() >= p_hour * 60 + p_minute


# Continuous 0-1 midnight to midnight; the in-flight minute is interpolated
# from the timer so the sun glides instead of stepping.
func get_day_fraction() -> float:
	var minutes: float = time_data.get_minutes_of_day()
	if timer and not timer.is_stopped():
		minutes += 1.0 - timer.time_left / timer.wait_time
	return minutes / MINUTES_PER_DAY


func get_current_date() -> Vector3i:
	return Vector3i(time_data.day, time_data.month, time_data.year)


func get_date_string(p_date: Vector3i, p_str_month: bool = true,
		p_short: bool = true) -> String:
	if p_str_month:
		return "%02d %s %d" % [p_date.x, get_month_string(p_date.y, p_short),
				p_date.z]
	return "%02d/%02d/%d" % [p_date.x, p_date.y, p_date.z]


func get_month_string(p_month: int, p_short: bool = false) -> String:
	var output: String = TimeData.MONTH_STRING[p_month - 1]
	return output.left(3) if p_short else output


func get_age_in_days(p_date: Vector3i) -> int:
	return get_total_days(get_current_date()) - get_total_days(p_date)


func get_years_from_vec3i(p_date: Vector3i) -> float:
	return get_age_in_days(p_date) / float(DAYS_PER_YEAR)


func get_total_days(p_date: Vector3i) -> int:
	return (p_date.z * DAYS_PER_YEAR) + ((p_date.y - 1) * TimeData.DAYS_PER_MONTH) \
			+ p_date.x
