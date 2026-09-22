class_name TimeData
extends Resource
# Game-calendar state: 28-day months, cascading carry from seconds to years.

const MONTH_STRING: Array[String] = ["January", "February", "March", "April",
		"May", "June", "July", "August", "September", "October", "November",
		"December"]
const DAYS_PER_MONTH: int = 28
const MONTHS_PER_YEAR: int = 12

var second: int = 0
var minute: int = 0
var hour: int = 8
var day: int = 1
var month: int = 1
var year: int = 1989


func copy_data(p_data: TimeData):
	second = p_data.second
	minute = p_data.minute
	hour = p_data.hour
	day = p_data.day
	month = p_data.month
	year = p_data.year


func add_second():
	second += 1
	if second == 60:
		second = 0
		add_minute()


func add_minute():
	minute += 1
	if minute == 60:
		minute = 0
		add_hour()


func add_hour():
	hour += 1
	if hour == 24:
		hour = 0
		add_day()


func add_day():
	day += 1
	if day > DAYS_PER_MONTH:
		day = 1
		add_month()


func add_month():
	month += 1
	if month > MONTHS_PER_YEAR:
		month = 1
		add_year()


func add_year():
	year += 1


func get_minutes_of_day() -> int:
	return hour * 60 + minute


func get_month_string(p_abbreviate: bool = false) -> String:
	var output: String = MONTH_STRING[month - 1]
	return output.left(3) if p_abbreviate else output


func get_save_dict() -> Dictionary:
	return {"year": year, "month": month, "day": day, "hour": hour,
			"minute": minute, "second": second}


func get_data_from_file(p_data: Dictionary):
	year = p_data["year"]
	month = p_data["month"]
	day = p_data["day"]
	hour = p_data["hour"]
	minute = p_data["minute"]
	second = p_data["second"]


static func get_timestamp_string(p_timestamp: Dictionary) -> String:
	return "%02d/%02d/%d %02d:%02d" % [p_timestamp["day"], p_timestamp["month"],
			p_timestamp["year"], p_timestamp["hour"], p_timestamp["minute"]]
