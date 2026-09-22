class_name Grenade
extends RigidBody3D
# A thrown explosive: it cooks off on its fuse and the blast falls away from the core.

signal exploded(position)

const HURT_LAYERS: int = 3  # player_hurt_box | enemy_hurt_box
const COVER_LAYERS: int = 12  # walls | car - what a blast will not reach through
# Both ends of the sight line ride this high. The terrain shares the WALLS
# layer, so a ray run along the floor is stopped by the floor and everybody
# ends up in cover from everything.
const SIGHT_LIFT: float = 0.9
const MAX_TARGETS: int = 32
const TUMBLE: float = 6.0  # rad/s of spin a throw imparts
# What the first bounce keeps, split by axis. HORIZONTAL carry is what skitters
# a grenade metres past the ring it was aimed with, so most of it goes; the
# VERTICAL is what makes it read as a light object rather than a sandbag, so
# nearly all of it stays. Damping both was the earlier mistake - it stopped the
# roll and made the thing land like it weighed a ton.
const LANDING_BITE: float = 0.12  # of the horizontal
const BOUNCE_KEEP: float = 0.9  # of the vertical
const FLOOR_NORMAL: float = 0.7  # above this a contact counts as ground, not wall

@export var data: ExplosiveData  # left empty in the scene; the thrower supplies it

@onready var EXPLOSION: PackedScene = load("uid://bhrwrwde4dcj3")

@onready var audio_land: AudioStreamPlayer3D = $AudioLand

var fuse: float = -1.0  # below zero while unarmed, so a dropped grenade is inert
var has_landed: bool = false


# Only the GROUND bites, and only once. A wall has to throw the grenade back
# with its speed intact - biting on any first contact made it drop dead at the
# foot of whatever it struck, while the preview drew a bounce that never
# happened. Contact normals are the only way to tell the two apart, which is
# what _integrate_forces gives and body_entered does not.
func _integrate_forces(p_state: PhysicsDirectBodyState3D):
	if has_landed:
		return
	for i in p_state.get_contact_count():
		if p_state.get_contact_local_normal(i).y <= FLOOR_NORMAL:
			continue  # a wall: let the material bounce it
		has_landed = true
		p_state.linear_velocity = Vector3(
				p_state.linear_velocity.x * LANDING_BITE,
				p_state.linear_velocity.y * BOUNCE_KEEP,
				p_state.linear_velocity.z * LANDING_BITE)
		p_state.angular_velocity *= LANDING_BITE
		audio_land.pitch_scale = randf_range(0.9, 1.1)
		audio_land.play()
		return


func _physics_process(p_delta: float):
	if fuse < 0.0:
		return
	fuse -= p_delta
	if fuse <= 0.0:
		explode()


# Takes the VELOCITY it should leave with, not a direction and a force: the
# thrower has already solved the arc, and the preview it drew is only honest if
# the grenade obeys the same numbers. Arming here rather than on spawn is what
# lets one sit in the world as a prop until something sets it off.
func throw(p_from: Vector3, p_velocity: Vector3, p_data: ExplosiveData = null):
	global_position = p_from
	linear_velocity = p_velocity
	angular_velocity = Vector3(randf_range(-TUMBLE, TUMBLE), 0.0,
			randf_range(-TUMBLE, TUMBLE))
	arm(p_data)


func arm(p_data: ExplosiveData = null):
	if p_data:
		data = p_data
	fuse = data.fuse_value if data else 0.0


func explode():
	fuse = -1.0
	var origin: Vector3 = global_position
	if data:
		damage_around(origin)
	var explosion: Node3D = EXPLOSION.instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = origin
	exploded.emit(origin)
	queue_free()


# Every hurt box in reach, hurt by how far its OWNER stands from the centre.
# Measuring to the BOX would let a crouching target duck the blast and would
# punish a tall one for its head, when what matters is where they are standing.
# Damage lands through HurtBox.hit, the same door a bullet or a melee swing
# uses, so labels, flash and blood all come along for free.
func damage_around(p_origin: Vector3):
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = data.blast_radius_value
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, p_origin)
	query.collision_mask = HURT_LAYERS
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_3d().direct_space_state.intersect_shape(query, MAX_TARGETS):
		var box: HurtBox = hit.collider as HurtBox
		if box == null:
			continue
		var target: Node3D = box.owner as Node3D
		var spot: Vector3 = target.global_position if target else box.global_position
		var distance: float = p_origin.distance_to(spot)
		var hurt: int = data.damage_at(distance)
		# Nobody is spared for being the thrower: a grenade at your own feet is
		# your own problem. A wall between the two of you is another matter.
		if hurt > 0 and reaches(p_origin, spot, target):
			box.hit(AttackData.new(hurt, p_origin, data.knockback_at(distance), self))


# Cover works: a wall or a vehicle in the way spares whoever is behind it. The
# target's OWN hull never blocks it - a car in the blast would otherwise stop
# the ray to itself and walk away clean, the same exception CharacterVision
# makes for the thing it is looking at.
func reaches(p_origin: Vector3, p_target: Vector3, p_owner: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			p_origin + Vector3.UP * SIGHT_LIFT, p_target + Vector3.UP * SIGHT_LIFT,
			COVER_LAYERS)
	var hull: CollisionObject3D = p_owner as CollisionObject3D
	if hull:
		query.exclude = [hull.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
