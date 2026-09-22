class_name CalendarInfoUI
extends VBoxContainer

@onready var clock_label: Label = %ClockLabel
@onready var date_label: Label = %DateLabel

var time: TimeData  # kept so a format change can redraw before the next tick


func _ready() -> void:
	Signals.calendar_updated.connect(update_calendar)
	Signals.settings_changed.connect(refresh)
	Signals.player_died.connect(fade_out)


func update_calendar(p_time: TimeData) -> void:
	time = p_time
	refresh()


func refresh() -> void:
	if time == null:
		return
	clock_label.text = Settings.format_time(time.hour, time.minute)
	date_label.text = "%02d %s %d" % [time.day, time.get_month_string(true),
			time.year]


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(hide)


func fade_in() -> void:
	self.modulate.a = 0
	show()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)
