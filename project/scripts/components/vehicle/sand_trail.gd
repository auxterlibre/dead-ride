class_name SandTrail
extends Node

const MIN_SPEED: float = 0.4  # m/s; a parked car must not dig a pit
const GROUND_CLEARANCE: float = 0.05  # stamp height over the contact patch

@export var stamp_scene: PackedScene

var vehicle: Vehicle
var stamps: Array[GPUParticles3D] = []


func _ready():
	vehicle = get_parent() as Vehicle
	if vehicle == null or stamp_scene == null:
		return
	# Wheels are discovered in the parent's _ready, which runs after ours.
	if not vehicle.is_node_ready():
		await vehicle.ready
	for wheel in vehicle.wheels:
		var stamp: GPUParticles3D = stamp_scene.instantiate()
		# On the BODY at the wheel's footprint, never on the wheel: the
		# VehicleWheel3D node spins with the tyre, and a child stamp orbits
		# the axle - it surfaces once a revolution and beads the track.
		vehicle.add_child.call_deferred(stamp)
		stamp.position = Vector3(wheel.position.x, GROUND_CLEARANCE, wheel.position.z)
		stamps.append(stamp)


# The ground says whether it records wheels as displacement; tarmac does not.
# The sampled surface lives on VehicleGroundFX now, reached through the vehicle.
func _physics_process(_p_delta: float):
	var rolling: bool = vehicle != null and vehicle.speed > MIN_SPEED \
			and vehicle.ground_fx != null and vehicle.ground_fx.ground != null \
			and vehicle.ground_fx.ground.displaced_tracks
	for stamp in stamps:
		stamp.emitting = rolling
