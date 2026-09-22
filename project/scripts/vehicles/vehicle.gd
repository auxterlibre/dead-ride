class_name Vehicle
extends VehicleBody3D

signal damaged(attack)  # mirrors Character.damaged; AI brains listen for it

@export var data:VehicleData

@export var camera_lead:float = 0.3  # camera shift per m/s of travel
@export var camera_lead_max:float = 4.5

# Per-vehicle stats, overwritten by apply_data() when a VehicleData is set.
var engine_power:float = 1000.0
var top_speed:float = 18.0  # m/s reference for pitch/dust/camera scaling
var brake_force:float = 150.0
var steer_angle_max:float = 0.5
var steer_speed:float = 2.5
var pitch_idle:float = 0.85
var pitch_full:float = 1.5
var drift_min_speed:float = 8.0  # braking+turning above this breaks the rear loose
var drift_rear_grip:float = 0.7  # rear friction_slip while drifting
var drift_brake_force:float = 10.0  # soft brake mid-drift keeps momentum
var drift_yaw_assist:float = 4000.0  # extra rotation torque while drifting
var health: int = 100 :
	set(p_value):
		health = p_value
		if is_player_driven():
			Signals.vehicle_health_updated.emit(health, data.health_max_value)

const EXIT_MAX_SPEED:float = 10.0 / 3.6  # m/s; no jumping out above 10 km/h
const FUEL_IDLE_BURN:float = 0.02  # liters/sec with the engine running
const FUEL_THROTTLE_BURN:float = 0.2  # liters/sec at full throttle

var driver:Character = null
# The physics reads ONLY these three, so a keyboard and an AI drive through the same pedals.
var control_throttle:float = 0.0  # -1 reverse .. 1 forward
var control_steer:float = 0.0  # + is LEFT, matching VehicleBody3D.steering
var control_brake:bool = false
var controller:VehicleSteering = null  # an AI working the pedals, if any
var ground_fx:VehicleGroundFX = null  # registers itself, the way controller does
var damage:VehicleDamage = null  # likewise; take_damage/repair delegate to it
var speed:float = 0.0
var is_dead:bool :  # target interface (CharacterVision duck-types this)
	get: return is_destroyed
var seated:bool = false  # entry ceremony done; the exit gate may manage the prompt
var exit_allowed:bool = false  # tracks the EXIT VEHICLE prompt's presence
var engine_power_scale:float = 1.0  # drops with health below the smoke tier
var is_destroyed:bool = false
var is_drifting:bool = false
var trunk_open:bool = false  # this vehicle put the container view on screen
var engine_tween:Tween
var wheels:Array[VehicleWheel3D] = []
var rear_grip:float = 1.5
var storage:Inventory = Inventory.new()  # the trunk; empty unless data.storage is set

@onready var hurt_box:HurtBox = %HurtBox
@onready var driver_seat:Node3D = %DriverSeat
@onready var driver_spawn_point = %DriverSpawnPoint
@onready var audio_ignition:AudioStreamPlayer3D = %AudioIgnition
@onready var audio_engine:AudioStreamPlayer3D = %AudioEngine
@onready var audio_trunk_open:AudioStreamPlayer3D = %AudioTrunkOpen
@onready var audio_trunk_close:AudioStreamPlayer3D = %AudioTrunkClose
@onready var exhaust_smoke:GPUParticles3D = %ExhaustSmoke
@onready var damage_smoke:GPUParticles3D = %DamageSmoke
@onready var damage_fire:Flame = $Flame


func _ready() -> void:
	add_to_group("vehicle")  # what VehicleSteering's traffic sensor scans
	add_to_group("persistent")  # runtime spawns are filtered out by owner
	for child in get_children():
		if child is VehicleWheel3D:
			wheels.append(child)
	for wheel in wheels:
		if wheel.use_as_traction:
			rear_grip = wheel.wheel_friction_slip
			break
	exhaust_smoke.emitting = false
	damage_smoke.emitting = false
	damage_fire.visible = false
	Signals.backpack_state_changed.connect(on_backpack_state)
	if data:
		# Duplicated so runtime state (fuel) isn't shared between vehicles
		# reading the same .tres (CharacterWeapons does the same for magazines).
		data = data.duplicate()
		apply_data()
		if data.storage:
			storage.setup(data.storage)


func _physics_process(delta):
	speed = Vector2(linear_velocity.x, linear_velocity.z).length()
	if driver:
		if is_player_driven():
			Signals.vehicle_speed_updated.emit(speed)
		if seated:
			update_exit_availability()
		gather_player_control()
	elif controller:
		controller.gather_intent()
	if is_controlled():
		apply_control(delta)
	else:
		# Throttle and steering are only written while driven, so an exit under
		# power would otherwise leave the car driving itself.
		engine_force = 0.0
		steering = 0.0
		brake = brake_force
		is_drifting = false
		if speed < 1.0:
			linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
			angular_velocity = Vector3.ZERO
	update_drift_grip()


func is_controlled() -> bool:
	return driver != null or controller != null


# Only a seated human polls the inputs; NPC traffic has its control_* fields
# written by a VehicleSteering component instead. The car_* actions carry BOTH
# devices (W/RT, S/LT, Shift/B) so this reads one set; steering rides the same
# move_left/right the feet use, which already hold the stick.
func gather_player_control():
	control_throttle = Input.get_axis("car_reverse", "car_accelerate")
	control_steer = Input.get_axis("move_right", "move_left")
	control_brake = Input.is_action_pressed("car_brake")


func apply_control(p_delta:float):
	var throttle:float = control_throttle
	if data.current_fuel <= 0.0:
		throttle = 0.0  # dry tank: it coasts; brakes and steering stay
	burn_fuel(p_delta, absf(throttle))
	update_drift(control_brake)
	brake = (drift_brake_force if is_drifting else brake_force) \
			if control_brake else 0.0
	engine_force = engine_power * engine_power_scale * throttle
	steering = move_toward(steering, control_steer * steer_angle_max,
			p_delta * steer_speed)
	if is_drifting:
		# Arcade yaw assist; fades with speed so a slow slide cannot pirouette on the spot.
		apply_torque(Vector3.UP * steering * drift_yaw_assist
				* clampf(speed / drift_min_speed, 0.0, 1.0))
	update_engine_audio()
	if is_player_driven():
		update_camera_lead()  # the shared camera is the player's, not traffic's
	if speed < 1.0 and throttle == 0.0:
		linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)


# Single-knob remaps: each 0..1 dial in VehicleData drives several internals
# at once. Ranges are calibrated so 0.5 lands on the original tuned values.
func apply_data():
	mass = data.mass_value
	health = data.health_max_value
	engine_power = data.engine_power_value
	top_speed = data.speed_max_value
	brake_force = data.brake_force_value
	steer_angle_max = lerpf(0.3, 0.7, data.handling_value)
	steer_speed = lerpf(1.5, 3.5, data.handling_value)
	rear_grip = lerpf(1.0, 2.0, data.handling_value)
	for wheel in wheels:
		wheel.wheel_friction_slip = rear_grip \
				if wheel.use_as_traction else rear_grip - 0.1
	drift_min_speed = data.speed_max_value * 0.45
	drift_rear_grip = lerpf(1.0, 0.4, data.drift_value)
	drift_yaw_assist = lerpf(2.0, 8.0, data.drift_value) * data.mass_value
	drift_brake_force = lerpf(15.0, 5.0, data.drift_value)
	pitch_idle = lerpf(0.6, 1.1, data.engine_tone_value)
	pitch_full = lerpf(1.1, 1.9, data.engine_tone_value)
	data.current_fuel = data.fuel_tank_size_value  # rolls out with a full tank
	if data.engine_audio:
		audio_engine.stream = data.engine_audio


# The world's damage entry point; the mechanics live in VehicleDamage.
func take_damage(p_attack:AttackData):
	if damage:
		damage.take_damage(p_attack)


# Ignition is split out of add_driver because NPC traffic has no occupant to
# seat: a VehicleSteering starts the engine and the car drives off empty.
# p_crank = false skips the starter sound: a SPAWNED vehicle was already
# driving somewhere beyond the map edge, and hearing it crank up out there
# breaks the fiction - only a car that visibly stood still cranks (a driver
# getting in, the truck leaving its bay, a repair).
func start_engine(p_crank: bool = true):
	if p_crank:
		audio_ignition.play()
	audio_engine.play()
	exhaust_smoke.emitting = true
	if engine_tween: engine_tween.kill()
	audio_engine.volume_db = -16.0


func stop_engine():
	engine_tween = create_tween()
	engine_tween.tween_property(audio_engine, "volume_db", -50.0, 1.0)
	engine_tween.tween_callback(audio_engine.stop)
	exhaust_smoke.emitting = false


func add_driver(p_character: Character):
	driver = p_character
	driver.enter_vehicle(self)
	start_engine()
	if is_player_driven():
		Signals.drive_state_changed.emit(true)
		push_hud_state()  # the dials are right the moment the panel appears
	await get_tree().create_timer(0.5).timeout
	seated = true
	exit_allowed = true
	if is_player_driven():
		enabled_drive_input(true)
		Signals.input_device_changed.connect(on_device_changed)
		offer_exit()
		Globals.camera_follow.target = self


func remove_driver(_driver: Character):
	var was_player: bool = is_player_driven()
	driver.global_position = driver_spawn_point.global_position
	driver.exit_vehicle()
	if was_player:
		Signals.drive_state_changed.emit(false)
		if Globals.camera_follow:
			Globals.camera_follow.target = driver
			Globals.camera_follow.look_ahead = Vector3.ZERO
	driver = null
	control_throttle = 0.0
	control_steer = 0.0
	control_brake = false
	stop_engine()
	seated = false
	exit_allowed = false
	if was_player:
		InputManager.remove_interaction(self, "remove_driver")
		enabled_drive_input(false)
		if Signals.input_device_changed.is_connected(on_device_changed):
			Signals.input_device_changed.disconnect(on_device_changed)


# A vehicle's allegiance is its driver's: hostile senses treat the occupied
# car as the target. Driverless = -1, which is nobody's enemy.
func get_faction() -> int:
	return driver.get_faction() if driver else -1


func burn_fuel(p_delta: float, p_throttle: float):
	data.current_fuel = maxf(data.current_fuel - p_delta
			* lerpf(FUEL_IDLE_BURN, FUEL_THROTTLE_BURN, p_throttle), 0.0)
	if is_player_driven():
		Signals.vehicle_fuel_updated.emit(data.current_fuel,
				data.fuel_tank_size_value)


# Third interaction, offered only while there is damage to undo; the scene's
# RepairInteractionArea targets the root, so the delegate stays.
func repair(p_player = null):
	if damage:
		damage.repair(p_player)


# Position as flat coords + yaw (vehicles live on the ground), the tank, the
# hull, and the trunk. Damage visuals re-derive from the restored health.
func save_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"health": health,
		"fuel": data.current_fuel if data else 0.0,
		"trunk": storage.save_entries() if data and data.storage else [],
	}


func load_state(p_state: Dictionary):
	global_position = Vector3(p_state.position[0], p_state.position[1],
			p_state.position[2])
	rotation.y = float(p_state.yaw)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	health = int(p_state.health)
	if data:
		data.current_fuel = float(p_state.fuel)
	if data and data.storage:
		storage.load_entries(p_state.trunk)
	if damage:
		damage.update_damage_state()


# Secondary interaction: the trunk opens beside the player's backpack. A
# wreck has nothing left worth rummaging through.
func open_trunk(_p_player = null):
	if data == null or data.storage == null or is_destroyed:
		return
	trunk_open = true
	audio_trunk_open.play()
	Signals.container_opened.emit(data.name, storage)


# The lid drops when the SCREEN closes, not when the container bit blinks:
# open_container() emits (true, false) mid-open, before its panel shows, and
# reading that as "container gone" slams the lid during opening.
func on_backpack_state(p_open:bool, _p_container:bool):
	if trunk_open and not p_open:
		trunk_open = false
		audio_trunk_close.play()


func refuel(p_liters: float):
	data.current_fuel = clampf(data.current_fuel + p_liters, 0.0,
			data.fuel_tank_size_value)
	if is_player_driven():
		Signals.vehicle_fuel_updated.emit(data.current_fuel,
				data.fuel_tank_size_value)


# The HUD is the PLAYER's dashboard: NPC traffic burning fuel or taking damage
# must not write to it.
func is_player_driven() -> bool:
	return driver != null and driver == InputManager.player


func push_hud_state():
	Signals.vehicle_speed_updated.emit(speed)
	Signals.vehicle_fuel_updated.emit(data.current_fuel, data.fuel_tank_size_value)
	Signals.vehicle_health_updated.emit(health, data.health_max_value)


# The EXIT VEHICLE prompt (and the action behind it) only exists while
# slow enough to step out - it returns as the car brakes back under the cap.
func update_exit_availability():
	var allowed:bool = speed <= EXIT_MAX_SPEED
	if allowed == exit_allowed:
		return
	exit_allowed = allowed
	if allowed:
		offer_exit()
	else:
		InputManager.remove_interaction(self, "remove_driver")


# Corner-placed like the rest of the driving help: the driver is inside the
# car, so a prompt pinned to them would sit under the roof.
func offer_exit():
	InputManager.create_interaction(self, "remove_driver", "EXIT VEHICLE", null,
			"interact", false, Enums.PromptPlacement.CORNER)


# The engine reads as revving: pitch rides speed (smoothed so collisions
# don't snap it), volume just supports it instead of blowing past 0 dB.
func update_engine_audio():
	var fraction:float = clampf(speed / top_speed, 0.0, 1.0)
	audio_engine.pitch_scale = lerpf(audio_engine.pitch_scale,
			lerpf(pitch_idle, pitch_full, fraction), 0.1)
	audio_engine.volume_db = lerpf(-16.0, -6.0, fraction)


# PlayerAim is off while driving, so the vehicle owns look_ahead until the driver exits.
func update_camera_lead():
	if Globals.camera_follow == null:
		return
	var flat:Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	Globals.camera_follow.look_ahead = (flat * camera_lead) \
			.limit_length(camera_lead_max)


# The drift survives to half the entry speed, so scrubbing speed cannot snap the brakes back.
func update_drift(p_braking:bool):
	if is_drifting:
		is_drifting = p_braking and speed > drift_min_speed * 0.5
	else:
		is_drifting = p_braking and speed > drift_min_speed \
				and absf(steering) > 0.05


# Rear grip drops fast into the drift and eases back on exit so the regrip
# doesn't snap the car straight. Handling physics - the dust, skid ribbons and
# squeal that USED to live alongside it are VehicleGroundFX's now.
func update_drift_grip():
	var target_grip:float = drift_rear_grip if is_drifting else rear_grip
	for wheel in wheels:
		if not wheel.use_as_traction:
			continue
		wheel.wheel_friction_slip = lerpf(wheel.wheel_friction_slip,
				target_grip, 0.3 if is_drifting else 0.08)


# The shown key arrays, remembered so a re-badge withdraws EXACTLY what it
# raised - the corner list is keyed by those arrays, and a device switch
# mid-drive would otherwise strand the old device's labels.
var drive_prompts:Array = []


# Resolved through key_for, so the labels follow the hand: W/S/A+D/SHIFT on the
# keys, RT/LT/LS/B on a pad - where both steer keys resolve to the one stick,
# the pair collapses to a single badge instead of saying LS twice.
func enabled_drive_input(p_value:bool):
	for keys in drive_prompts:
		Signals.input_info_removed.emit(keys)
	drive_prompts.clear()
	if not p_value:
		return
	var steer:Array = [InputManager.key_for("move_left"),
			InputManager.key_for("move_right")]
	if steer[0] == steer[1]:
		steer = [steer[0]]
	var corner:Enums.PromptPlacement = Enums.PromptPlacement.CORNER
	var prompts:Array = [
		[[InputManager.key_for("car_accelerate")], "ACCELERATE"],
		[[InputManager.key_for("car_reverse")], "REVERSE"],
		[steer, "STEER"],
		[[InputManager.key_for("car_brake")], "BRAKE"],
	]
	for prompt in prompts:
		Signals.input_info_added.emit(prompt[0], prompt[1], corner, "")
		drive_prompts.append(prompt[0])


# A hand moving between the keys and the pad mid-drive re-badges the corner.
func on_device_changed(_p_pad:bool):
	if is_player_driven() and seated:
		enabled_drive_input(true)
