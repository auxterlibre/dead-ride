class_name FleshImpact
extends Node3D
# Flesh hit: blood sprays out the EXIT side (along the bullet's travel) and a
# drop joins the blood pool on the floor where the droplets land.

const POOL_DELAY: float = 0.5
const POOL_TRAVEL: float = 2.0  # drops land this far along the exit direction
const SPRAY_TIME: float = 1.0   # outlive the spray's 0.7s particles
const DROPLET_DAMAGE: float = 5.0  # one extra droplet per this much damage
const MAX_DROPLETS: int = 5

@onready var SPRAY: PackedScene = load("uid://d4lkgdsw5hbic")

var spawn_position: Vector3
var exit_direction: Vector3
var floor_y: float
var damage: int


func _ready():
	global_position = spawn_position
	if exit_direction.length_squared() > 0.001:
		look_at(global_position - exit_direction.normalized(), Vector3.UP)
	var spray: GPUParticles3D = SPRAY.instantiate()
	add_child(spray)
	spray.restart()
	var tween: Tween = create_tween()
	tween.tween_interval(POOL_DELAY)
	tween.tween_callback(drop_blood)
	tween.tween_interval(SPRAY_TIME)
	tween.tween_callback(queue_free)


func setup(p_position: Vector3, p_exit_direction: Vector3, p_floor_y: float, p_damage: int):
	spawn_position = p_position
	exit_direction = p_exit_direction
	floor_y = p_floor_y
	damage = p_damage


# Blood lands where the droplets fall, POOL_TRAVEL along the exit direction.
# Damage nudges how many droplets: the first at the landing, the rest splashed
# onward along the exit and scattered sideways.
func drop_blood():
	var exit_flat: Vector3 = exit_direction.normalized() \
			if exit_direction.length_squared() > 0.001 else Vector3.ZERO
	var landing: Vector3 = global_position + exit_flat * POOL_TRAVEL
	landing.y = floor_y
	var count: int = clampi(1 + ceili(damage / DROPLET_DAMAGE), 1, MAX_DROPLETS)
	for i in count:
		var spot: Vector3 = landing
		if i == 0:
			spot += Vector3(randf_range(-0.15, 0.15), 0.0, randf_range(-0.15, 0.15))
		else:
			# far enough that outliers escape the coalescence and read as flecks
			spot += exit_flat * randf_range(0.15, 0.9) \
					+ Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
		BloodPool.drop(get_tree().current_scene, spot)
