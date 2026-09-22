class_name Wind
extends Node

# Incommensurate periods, phase-offset, so the weather never repeats on an audible beat.
const GUST_PERIODS: Array[float] = [27.0, 15.0, 57.0]
const GUST_WEIGHTS: Array[float] = [0.5, 0.3, 0.2]
const SWING_PERIODS: Array[float] = [90.0, 37.0]
const SWING_WEIGHTS: Array[float] = [0.6, 0.4]

@export_range(0.0, 360.0, 1.0) var heading: float = 200.0  # degrees around +Y from -Z
@export var swing: float = 22.0  # degrees the heading wanders either side of it
@export var lull_speed: float = 1.5  # m/s in the quiet between gusts
@export var gust_speed: float = 4.5  # extra m/s at the peak of one
@export var gust_bias: float = 1.6  # >1 leans the middle of the swell back down

var direction: Vector3 = Vector3.FORWARD  # unit, always horizontal
var gust: float = 0.0  # 0 lull, 1 the peak of a gust
var strength: float = 0.0  # m/s
var time: float = 0.0


func _ready():
	Globals.wind = self
	advance(0.0)


func _process(delta):
	advance(delta)


# Split out so a probe can step the weather without waiting on real seconds.
func advance(p_delta: float):
	time += p_delta
	# The WHOLE swell, not just its crest - clamping the trough left the air dead flat.
	gust = pow(clampf(wave(GUST_PERIODS, GUST_WEIGHTS) * 0.5 + 0.5, 0.0, 1.0),
			gust_bias)
	strength = lull_speed + gust_speed * gust
	direction = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(
			heading + swing * wave(SWING_PERIODS, SWING_WEIGHTS)))


# What a drifting thing is pushed by, in m/s.
func flow() -> Vector3:
	return direction * strength


func wave(p_periods: Array[float], p_weights: Array[float]) -> float:
	var total: float = 0.0
	for i in p_periods.size():
		total += sin(TAU * (time / p_periods[i] + i * 0.37)) * p_weights[i]
	return total
