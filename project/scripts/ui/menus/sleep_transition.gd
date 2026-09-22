class_name SleepTransition
extends Control
# The night, watched instead of skipped: the bedroll hands its jump here when
# the overlay exists (game.tscn), and the clock SWEEPS to morning behind a
# dimmed world - the sun arcs, the readout spins - before the wake lands.
# Headless probes without the overlay keep the bedroll's direct path.

signal finished

const SWEEP_TIME: float = 3.5  # real seconds the night takes, whatever its span
const FADE_TIME: float = 0.5

@onready var scrim: ColorRect = %Scrim
@onready var clock_label: Label = %ClockLabel
@onready var date_label: Label = %DateLabel

var running: bool = false
var swept: int = 0  # whole minutes already applied this sweep


func _ready():
	hide()  # designed visible in the editor; never trust the saved flag
	Globals.sleep_transition = self


# Everything is asleep, including the keys: TAB and F9 land here first
# (last-child-first) and go no further while the night plays.
func _unhandled_input(_p_event: InputEvent):
	if running:
		get_viewport().set_input_as_handled()


func begin(p_bedroll: Bedroll, p_player = null):
	if running:
		return
	running = true
	swept = 0
	# Minutes to morning; zero (slept AT the wake minute) sweeps nothing but
	# still fades, so the act reads the same.
	var now: int = Calendar.time_data.hour * 60 + Calendar.time_data.minute
	var span: int = wrapi(p_bedroll.WAKE_HOUR * 60 - now, 0, 1440)
	get_tree().paused = true
	scrim.modulate.a = 0.0
	clock_label.modulate.a = 0.0
	date_label.modulate.a = 0.0
	update_readout()
	show()
	var t: Tween = create_tween()  # this node is ALWAYS, so the tween runs paused
	t.tween_property(scrim, "modulate:a", 0.82, FADE_TIME)
	t.parallel().tween_property(clock_label, "modulate:a", 1.0, FADE_TIME)
	t.parallel().tween_property(date_label, "modulate:a", 1.0, FADE_TIME)
	if span > 0:
		t.tween_method(advance_to, 0.0, float(span), SWEEP_TIME)
	t.tween_callback(land.bind(p_bedroll, p_player))
	t.tween_interval(FADE_TIME * 0.6)
	t.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	t.tween_callback(release)


# One tween tick: apply the whole minutes since the last, then ONE emit - the
# listeners (clock HUD, the crops' midnight verdicts) see time only advance.
func advance_to(p_minutes: float):
	while swept < floori(p_minutes):
		Calendar.time_data.add_minute()
		swept += 1
	Signals.calendar_updated.emit(Calendar.time_data)
	update_readout()


# The sweep has arrived on the wake minute, so the bedroll's own set_time is
# the exactly-equal no-op - one wake() serves both the watched and the direct
# path, and the refill and the save land HERE, at the end, never at the press.
func land(p_bedroll: Bedroll, p_player):
	p_bedroll.wake(p_player)
	update_readout()


func release():
	get_tree().paused = false
	hide()
	modulate.a = 1.0
	running = false
	finished.emit()


func update_readout():
	clock_label.text = Settings.format_time(Calendar.time_data.hour,
			Calendar.time_data.minute)
	date_label.text = Calendar.get_date_string(Calendar.get_current_date())
