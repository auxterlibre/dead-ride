class_name VehicleData
extends Resource

const HEALTH_SPAN := Vector2(50.0, 550.0)
const MASS_SPAN := Vector2(400.0, 2400.0)
const ENGINE_POWER_SPAN := Vector2(500.0, 3000.0)
const SPEED_MAX_SPAN := Vector2(8.0, 28.0)  # m/s
const BRAKE_FORCE_SPAN := Vector2(50.0, 450.0)
const DIAL_SPAN := Vector2(0.0, 1.0)  # handling/drift/engine_tone
const FUEL_TANK_SIZE_SPAN := Vector2(35.0, 120.0)

@export var name:String
@export_range(0, 100) var health_max: int = 10
@export_range(0, 100) var mass: int = 20
@export_range(0, 100) var engine_power: int = 20
@export_range(0, 100) var speed_max:int = 50
@export_range(0, 100) var brake_force: int = 25
@export_range(0, 100) var handling: int = 50  # steer angle + steer speed + tire grip
@export_range(0, 100) var fuel_tank_size: int = 50
@export_range(0, 100) var drift: int = 50  # how loose the rear breaks in a brake-turn
@export_range(0, 100) var engine_tone: int = 50
@export var storage: StorageData  # trunk grid; empty = no trunk to open
@export var engine_audio: AudioStream  # empty keeps the scene's default loop
@export var engine_malfunction_audio: AudioStream  # engine loop once damaged

# Runtime state, liters - Vehicle duplicates its data at ready so two vehicles
# reading the same .tres don't share a tank.
var current_fuel: float

var health_max_value:int :
	get: return roundi(from_knob(health_max, HEALTH_SPAN))
var mass_value:float :
	get: return from_knob(mass, MASS_SPAN)
var engine_power_value:float :
	get: return from_knob(engine_power, ENGINE_POWER_SPAN)
var speed_max_value:float :
	get: return from_knob(speed_max, SPEED_MAX_SPAN)
var brake_force_value:float :
	get: return from_knob(brake_force, BRAKE_FORCE_SPAN)
var handling_value:float :
	get: return from_knob(handling, DIAL_SPAN)
var fuel_tank_size_value:float :
	get: return from_knob(fuel_tank_size, FUEL_TANK_SIZE_SPAN)
var drift_value:float :
	get: return from_knob(drift, DIAL_SPAN)
var engine_tone_value:float :
	get: return from_knob(engine_tone, DIAL_SPAN)


func from_knob(p_knob:int, p_span:Vector2) -> float:
	return remap(p_knob, 0.0, 100.0, p_span.x, p_span.y)
