class_name VehicleGroundFX
extends Node
# The vehicle's conversation with the ground, split out of the body: dust
# plumes coloured by the surface, skid ribbons under slipping wheels, and the
# tire squeal. Reads the parent's motion, never steers it.

const GROUND_MASK: int = 16
const GROUND_SAMPLE_TIME: float = 0.25  # sec between ground checks
const DUST_ADAPT_RATE: float = 0.5  # dust_pace change per second

# Only a real slide should scar the ground; the surface alpha quiets it.
@export var skid_grip_threshold: float = 0.55  # skidinfo below this = slipping
@export var squeal_min_slide: float = 2.0  # m/s of sideways slide before tires sing
# Puff size/lifetime factor at standstill and at top speed; authored look ~= mid-speed.
@export var dust_speed_size: Vector2 = Vector2(0.7, 1.3)
@export var dust_speed_life: Vector2 = Vector2(0.8, 1.25)
@export var audio_squeal: AudioStreamPlayer3D
@export var dust_left: GPUParticles3D
@export var dust_right: GPUParticles3D
@export var dust_left_alt: GPUParticles3D
@export var dust_right_alt: GPUParticles3D

var vehicle: Vehicle
var dust_banks: Array = []
var ground: SurfaceData = null  # what is under the wheels; dust and skids read it
var ground_timer: float = 0.0
var dust_bank: int = 0  # which bank is currently emitting
var dust_pace: float = 0.0  # smoothed speed fraction the plume follows
var dust_scale_base: float = 16.0  # authored scale_max, captured at ready
var dust_life_base: float = 3.0  # authored lifetime, captured at ready
var skid_trails: Dictionary = {}  # wheel -> the ribbon it is currently drawing

@onready var SKID_MARK: GDScript = load("uid://bej0t270dpqtx")  # skid_mark.gd


func _ready():
	vehicle = get_parent() as Vehicle
	if vehicle:
		# SandTrail reads the sampled ground through this, the way the physics
		# pulls pedals through `controller`.
		vehicle.ground_fx = self
	dust_banks = [[dust_left, dust_right], [dust_left_alt, dust_right_alt]]
	# A material each: the whole point of two banks is that one can hold the
	# colour its live particles were born with while the other emits a new one.
	for bank in dust_banks:
		var material: ParticleProcessMaterial = bank[0].process_material.duplicate()
		for emitter in bank:
			emitter.process_material = material
			emitter.emitting = false
	dust_scale_base = dust_banks[0][0].process_material.scale_max
	dust_life_base = dust_banks[0][0].lifetime


# Runs driverless too, so a shoved or coasting car still throws dust. Parents
# process before children, so the vehicle's speed is already this tick's.
func _physics_process(_delta):
	if vehicle == null:
		return
	var worst_slip: float = 0.0
	for wheel in vehicle.wheels:
		if not wheel.is_in_contact():
			continue
		var grip: float = wheel.get_skidinfo()
		worst_slip = maxf(worst_slip, 1.0 - grip)
		if grip < skid_grip_threshold and vehicle.speed > 2.0:
			drop_skid_mark(wheel)
	sample_ground()
	update_dust(worst_slip)
	update_squeal()


# The plume is the main read on speed over the desert; what the ground gives up scales it.
func update_dust(p_worst_slip: float):
	var dust_scale: float = ground.dust_amount if ground else 1.0
	var lifting: bool = dust_scale > 0.0 and (vehicle.speed > 2.5 \
			or (p_worst_slip > 0.4 and vehicle.speed > 1.0))
	var ratio: float = clampf(maxf(vehicle.speed / vehicle.top_speed, p_worst_slip),
			0.35, 1.0) * dust_scale
	# Puffs grow and linger with speed - SMOOTHED, because scale and lifetime
	# are live on airborne particles (scale re-reads its uniform per frame, a
	# lifetime write rephases every fade), so a snap deflates the plume mid-air.
	var pace: float = clampf(vehicle.speed / vehicle.top_speed, 0.0, 1.0)
	if not is_equal_approx(dust_pace, pace):
		dust_pace = move_toward(dust_pace, pace,
				DUST_ADAPT_RATE * get_physics_process_delta_time())
		var size: float = dust_scale_base \
				* lerpf(dust_speed_size.x, dust_speed_size.y, dust_pace)
		var life: float = dust_life_base \
				* lerpf(dust_speed_life.x, dust_speed_life.y, dust_pace)
		for bank in dust_banks:
			bank[0].process_material.scale_max = size
			for dust in bank:
				dust.lifetime = life
	for i in dust_banks.size():
		for dust in dust_banks[i]:
			# Only the active bank emits; the other is still drawing whatever it
			# put in the air before the ground changed.
			dust.emitting = lifting and i == dust_bank
			dust.amount_ratio = ratio


# One ray on a timer; the material is local-to-scene so the recolour is this car's alone.
func sample_ground():
	ground_timer -= get_physics_process_delta_time()
	if ground_timer > 0.0:
		return
	ground_timer = GROUND_SAMPLE_TIME
	var surface: SurfaceData = SurfaceData.under(vehicle, GROUND_MASK, 1.2)
	if surface == null or surface == ground:
		return  # untagged, or the same ground: nothing to hand over
	ground = surface
	# Hand the new colour to the OTHER bank and emit from that one from now on,
	# leaving the plume already behind the car untouched.
	dust_bank = 1 - dust_bank
	var material: ParticleProcessMaterial = dust_banks[dust_bank][0].process_material
	if material:
		material.color = surface.dust_color


# One ribbon per slide, chopped into chunks so the tail fades before the head
# and the tint can change at a kerb. Chunks butt on a shared point.
func drop_skid_mark(p_wheel: VehicleWheel3D):
	var contact: Vector3 = p_wheel.get_contact_point()
	# Under the WHEEL, not the dust's ground: that one rays the chassis centre
	# on a timer, so it is metres off and laid tarmac-black marks on sand.
	var surface: SurfaceData = SurfaceData.at(vehicle.get_world_3d(), contact,
			GROUND_MASK, 0.5)
	# Sand records the wheel itself; a ribbon crossing onto it ends on idle.
	if surface and not surface.skid_marks:
		return
	var tint: Color = surface.skid_color if surface else SkidMark.DEFAULT_COLOR
	# Checked before the TYPED assignment: assigning a freed instance is what
	# errors, not using it.
	var trail: SkidMark = null
	if is_instance_valid(skid_trails.get(p_wheel)):
		trail = skid_trails[p_wheel]
	if trail == null or trail.finished or trail.is_full() or trail.mark_color != tint:
		var fresh: SkidMark = SKID_MARK.new().setup(tint)
		get_tree().current_scene.add_child(fresh)
		if trail != null and not trail.finished:
			fresh.continue_from(trail)  # full, or crossed a kerb: same slide
		skid_trails[p_wheel] = fresh
		trail = fresh
	trail.add_point(contact)


# Keys off the actual sideways slide - skidinfo is near-binary and sang on every mild turn.
func update_squeal():
	if audio_squeal.stream == null:
		return
	var flat: Vector3 = Vector3(vehicle.linear_velocity.x, 0.0, vehicle.linear_velocity.z)
	var slide: float = absf(flat.dot(vehicle.global_basis.x))
	var squealing: bool = slide > squeal_min_slide
	if squealing and not audio_squeal.playing:
		audio_squeal.play()
	var target: float = remap(clampf(slide, squeal_min_slide, squeal_min_slide * 3.0),
			squeal_min_slide, squeal_min_slide * 3.0, -12.0, 0.0)
	audio_squeal.volume_db = lerpf(audio_squeal.volume_db,
			target if squealing else -40.0, 0.15)
	if not squealing and audio_squeal.playing and audio_squeal.volume_db < -35.0:
		audio_squeal.stop()
