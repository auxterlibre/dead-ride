class_name VehicleDamage
extends Node


const RAM_MIN_SPEED: float = 3.0  # m/s; slower nudges don't hurt
const RAM_MAX_SPEED: float = 20.0  # impact scaling tops out here
const RAM_LAUNCH_SPEED: float = 8.0  # above this the victim goes AIRBORNE
const RAM_COOLDOWN: float = 0.6  # sec per victim, so a graze isn't a blender
const CRASH_MIN_DELTA_V: float = 4.0  # m/s of sudden velocity change before the hull cares
const CRASH_MAX_DELTA_V: float = 22.0  # damage scaling tops out here
const CRASH_DAMAGE_SPAN: Vector2 = Vector2(2.0, 35.0)  # HP across that delta-v range
const CRASH_COOLDOWN: float = 0.5  # sec; one damage event per pile-up, not per contact
const CRASH_HARDNESS_CHARACTER: float = 0.15  # soft bodies dent less than concrete
const CRASH_HARDNESS_VEHICLE: float = 0.8

var vehicle: Vehicle
var ram_cooldowns: Dictionary = {}  # victim instance id -> last hit time
var last_crash_time: float = -CRASH_COOLDOWN
var previous_velocity: Vector3  # pre-step capture; crash delta-v reads against it
var repair_area: InteractiveArea

@onready var EXPLOSION: PackedScene = load("uid://bhrwrwde4dcj3")  # explosion.tscn
@onready var DEBRIS: GDScript = load("uid://c86stlwv73lys")  # debris.gd
@onready var COG_MESH: ArrayMesh = load("uid://dbrtlnhjg08oi")  # the burning engine cog


func _ready():
	vehicle = get_parent() as Vehicle
	if vehicle == null:
		return
	vehicle.damage = self
	vehicle.body_entered.connect(on_body_entered)
	repair_area = vehicle.get_node_or_null("RepairInteractionArea")


func _physics_process(_delta):
	previous_velocity = vehicle.linear_velocity


func take_damage(p_attack: AttackData):
	vehicle.health = maxi(vehicle.health - p_attack.damage, 0)
	vehicle.damaged.emit(p_attack)
	update_damage_state()
	if vehicle.health == 0 and not vehicle.is_destroyed:
		explode()


func explode():
	vehicle.is_destroyed = true
	if vehicle.driver:
		var victim: Character = vehicle.driver
		vehicle.remove_driver(victim)
		victim.take_damage(AttackData.new(999, vehicle.global_position, 0.0, vehicle))
		victim.velocity = Vector3(randf_range(-2.0, 2.0), 9.0, randf_range(-2.0, 2.0))
	var explosion: Explosion = EXPLOSION.instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = vehicle.global_position + Vector3.UP * 0.9
	scatter_parts()
	vehicle.queue_free()


func scatter_parts():
	for mesh_instance in vehicle.find_children("*", "MeshInstance3D", true, false):
		if not mesh_instance.mesh is ArrayMesh or not mesh_instance.is_visible_in_tree():
			continue
		get_tree().current_scene.add_child(DEBRIS.new().setup(mesh_instance.mesh,
				mesh_instance.global_transform, vehicle.global_position,
				vehicle.linear_velocity))
	for i in randi_range(4, 5):
		var cog: Debris = DEBRIS.new()
		cog.launch_spread = 0.8
		cog.launch_lift = 2.0
		cog.flaming = true
		get_tree().current_scene.add_child(cog.setup(COG_MESH,
				vehicle.global_transform.translated_local(Vector3.UP),
				vehicle.global_position, vehicle.linear_velocity))


# Smoke from 50% health, fire below 30%, and the engine sickens along with it.
func update_damage_state():
	var data: VehicleData = vehicle.data
	var fraction: float = float(vehicle.health) / data.health_max_value if data else 1.0
	vehicle.damage_smoke.emitting = fraction <= 0.5
	if fraction <= 0.3 and not vehicle.damage_fire.burning:
		vehicle.damage_fire.fade_in()
	elif fraction > 0.3 and vehicle.damage_fire.burning:
		vehicle.damage_fire.fade_out()  # patched back above the fire tier
	update_repair_offer()
	vehicle.engine_power_scale = lerpf(0.4, 1.0, clampf(fraction / 0.5, 0.0, 1.0))
	if fraction <= 0.5 and data and data.engine_malfunction_audio \
			and vehicle.audio_engine.stream != data.engine_malfunction_audio:
		var was_playing: bool = vehicle.audio_engine.playing
		vehicle.audio_engine.stream = data.engine_malfunction_audio
		if was_playing:
			vehicle.audio_engine.play()


# Characters use SPEED, not delta-v - the solver treats a kinematic body as immovable.
func on_body_entered(p_body: Node):
	if p_body is Character:
		ram(p_body)
		crash_damage(clampf(vehicle.speed, 0.0, RAM_MAX_SPEED), CRASH_HARDNESS_CHARACTER)
	elif p_body is Vehicle:
		crash_damage(crash_delta_v(), CRASH_HARDNESS_VEHICLE)
	else:
		crash_damage(crash_delta_v(), 1.0)  # walls, terrain, props


# Impact speed decides between a shove and an airborne launch.
func ram(p_body: Character):
	if vehicle.is_destroyed or vehicle.speed < RAM_MIN_SPEED:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var victim_id: int = p_body.get_instance_id()
	if now - ram_cooldowns.get(victim_id, -RAM_COOLDOWN) < RAM_COOLDOWN:
		return
	ram_cooldowns[victim_id] = now
	var impact: float = clampf(vehicle.speed, RAM_MIN_SPEED, RAM_MAX_SPEED)
	var direction: Vector3 = p_body.global_position - vehicle.global_position
	direction.y = 0.0
	direction = direction.normalized()
	# Not a ternary: Character and Vehicle branches trip INCOMPATIBLE_TERNARY.
	var attacker: Node3D = vehicle.driver
	if attacker == null:
		attacker = vehicle
	var attack: AttackData = AttackData.new(
			roundi(remap(impact, RAM_MIN_SPEED, RAM_MAX_SPEED, 2.0, 30.0)),
			vehicle.global_position, 0.0, attacker)
	# Through the hurt box, not take_damage directly: that's where every hit
	# feedback lives (damage label, flash, spark, blood).
	if p_body.hurt_box:
		p_body.hurt_box.hit(attack)
	else:
		p_body.take_damage(attack)
	# The push RATIO flips with speed: a fast hit trades the shove for height.
	var launch: float = clampf(
			inverse_lerp(RAM_LAUNCH_SPEED, RAM_MAX_SPEED, impact), 0.0, 1.0)
	var push: Vector3 = direction * lerpf(impact * 0.9 + 3.0, impact * 0.25, launch)
	push.y = lerpf(impact * 0.2, impact * 0.75, launch)
	p_body.velocity = push


# Routed through the own HurtBox so a crash gets the same feedback as a shot.
# An inert hurt box (the delivery truck) is an invulnerable hull. The attacker
# is the VEHICLE, not this node: VehicleAI's flee test reads it to tell a
# self-inflicted landing from an enemy hit.
func crash_damage(p_delta_v: float, p_hardness: float):
	if vehicle.is_destroyed or not vehicle.hurt_box.monitorable \
			or p_delta_v < CRASH_MIN_DELTA_V:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - last_crash_time < CRASH_COOLDOWN:
		return
	last_crash_time = now
	var damage: int = maxi(1, roundi(p_hardness * remap(
			clampf(p_delta_v, CRASH_MIN_DELTA_V, CRASH_MAX_DELTA_V),
			CRASH_MIN_DELTA_V, CRASH_MAX_DELTA_V,
			CRASH_DAMAGE_SPAN.x, CRASH_DAMAGE_SPAN.y)))
	vehicle.hurt_box.hit(AttackData.new(damage, vehicle.global_position, 0.0, vehicle))


# Pre-step velocity vs post-solve: a wall scrape barely changes it, a head-on
# eats it all, and wheels-first landings never fire.
func crash_delta_v() -> float:
	return (previous_velocity - vehicle.linear_velocity).length()


# Uses the first repair tool in the player's pack; the tool is not consumed.
func repair(p_player = null):
	if vehicle.data == null or vehicle.is_destroyed or p_player == null:
		return
	var pack: CharacterInventory = null
	for child in p_player.get_children():
		if child is CharacterInventory:
			pack = child
	if pack == null:
		return
	for entry in pack.inventory.entries:
		var kit: ToolData = entry.item as ToolData
		if kit == null or kit.repair_amount <= 0:
			continue
		vehicle.health = mini(vehicle.health + roundi(vehicle.data.health_max_value
				* kit.repair_amount / 100.0), vehicle.data.health_max_value)
		update_damage_state()
		if vehicle.audio_ignition:
			vehicle.audio_ignition.play()
		return


func update_repair_offer():
	if repair_area == null or vehicle.data == null:
		return
	repair_area.enabled = not vehicle.is_destroyed \
			and vehicle.health < vehicle.data.health_max_value
