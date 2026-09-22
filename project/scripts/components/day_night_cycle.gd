class_name DayNightCycle
extends Node

const SUNRISE_HOUR: float = 6.0
const SUNSET_HOUR: float = 18.0

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment

# All seven are sampled on the day PHASE, not the clock: 0 midnight, 0.25
# sunrise, 0.5 noon, 0.75 sunset, 1 midnight.
@export var sun_elevation: Curve  # degrees above the horizon
@export var sun_energy: Curve
@export var ambient_energy: Curve
@export var sun_color: Gradient
@export var ambient_color: Gradient
@export var vignette_color: Gradient
@export var vignette_radius: Curve

var vignette: PostProcessVignette


func _ready():
	if sun == null or world_environment == null:
		set_process(false)  # unwired (the gym): stay inert
		return
	if world_environment.compositor:
		for effect in world_environment.compositor.compositor_effects:
			if effect is PostProcessVignette:
				vignette = effect
				break


func _process(_delta):
	apply_day_fraction(Calendar.get_day_fraction())


# Split out so probes can drive arbitrary times. Only the pitch moves - the
# authored yaw sets the shadow direction.
func apply_day_fraction(p_fraction: float):
	var phase: float = day_phase(p_fraction)
	sun.rotation.x = deg_to_rad(-sun_elevation.sample_baked(phase))
	sun.light_energy = sun_energy.sample_baked(phase)
	sun.light_color = sun_color.sample(phase)
	var environment: Environment = world_environment.environment
	environment.ambient_light_color = ambient_color.sample(phase)
	environment.ambient_light_energy = ambient_energy.sample_baked(phase)
	if vignette:
		vignette.vignette_color = vignette_color.sample(phase)
		vignette.radius = vignette_radius.sample_baked(phase)


# Clock -> curve axis: the night and day stretches scale so crossings land on 0.25/0.75.
func day_phase(p_fraction: float) -> float:
	var hour: float = p_fraction * 24.0
	if hour < SUNRISE_HOUR:
		return remap(hour, 0.0, SUNRISE_HOUR, 0.0, 0.25)
	if hour < SUNSET_HOUR:
		return remap(hour, SUNRISE_HOUR, SUNSET_HOUR, 0.25, 0.75)
	return remap(hour, SUNSET_HOUR, 24.0, 0.75, 1.0)
