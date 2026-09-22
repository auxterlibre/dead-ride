class_name WeaponRanged
extends Weapon

const SURFACES_MASK:int = 4 | 8  # physics layers 3 (walls) + 4 (car)
const HURT_PRIORITY_MARGIN:float = 0.1  # HurtBox wins ties vs its own coincident body
const DAMAGE_FALLOFF_PER_METER:float = 0.1  # damage lost per meter past effective range
const SMOKE_POOL_SIZE:int = 6  # covers full puff lifetime at the fastest fire rate
const FLASH_HOLD:float = 0.016  # one frame at full, so the spike can't fall between frames
const FLASH_TIME:float = 0.045  # ...then the drop
const FLASH_ENERGY:Vector2 = Vector2(10.0, 14.0)  # per shot, so repeat fire flickers
const CORE_SHARE:float = 1.2  # the barrel bloom leads; it is what lights the shooter

@export var projectile_template:PackedScene

@onready var TRACER: GDScript = load("uid://cpnbvgjbgpeaa")
@onready var IMPACT: GDScript = load("uid://cvkksvmyimsl")

@onready var projectile_spawn:Marker3D = $ProjectileSpawn
@onready var audio_shoot:AudioStreamPlayer3D = $AudioShoot
@onready var audio_empty:AudioStreamPlayer3D = $AudioEmpty
@onready var audio_reload:AudioStreamPlayer3D = $AudioReload
# Only MANUAL weapons carry one; the base scene has no such node.
@onready var audio_eject:AudioStreamPlayer3D = get_node_or_null("AudioEject")
@onready var muzzle_flash: SpotLight3D = $MuzzleFlashLight
@onready var muzzle_core: OmniLight3D = get_node_or_null("MuzzleFlashLight/Core")
@onready var smoke: GPUParticles3D = get_node_or_null("Smoke")
@onready var flash_sprite: MeshInstance3D = get_node_or_null("MuzzleFlash")
@onready var FLASH_TEXTURES: Array = [
	load("uid://dvfql8k2raa4b"), load("uid://b6b1aho3ls35g"),
	load("uid://bfmjrd0ry21wg"), load("uid://5cxptmfjtd1g"),
	load("uid://dllb8b6dgc1dd"),
]

var flash_sprite_tween:Tween
var smoke_pool:Array[GPUParticles3D] = []
var smoke_index:int = 0

var character:CharacterBody3D
var effective_range:float
var projectiles_per_shot:int
var projectiles_spread:float


func _ready():
	if smoke == null:
		return
	smoke.one_shot = true
	smoke.emitting = false
	smoke_pool.append(smoke)
	for i in SMOKE_POOL_SIZE - 1:
		var copy:GPUParticles3D = smoke.duplicate()
		add_child(copy)
		smoke_pool.append(copy)


# HurtBoxes and surfaces are cast SEPARATELY, so a body that is both takes damage AND gets the hole.
func fire(p_attack:AttackData, p_from:Vector3, p_aim_point:Vector3):
	var flat:Vector3 = p_aim_point - p_from
	flat.y = 0.0
	var aim_direction:Vector3 = flat.normalized()
	var max_travel:float = effective_range + 1.0 / DAMAGE_FALLOFF_PER_METER
	var space:PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for i in projectiles_per_shot:
		var direction:Vector3 = aim_direction.rotated(Vector3.UP,
				deg_to_rad(randf_range(-0.5, 0.5) * projectiles_spread))
		var to:Vector3 = p_from + direction * max_travel * 2.0
		var hurt_query:PhysicsRayQueryParameters3D = \
				PhysicsRayQueryParameters3D.create(p_from, to, layer)
		hurt_query.collide_with_areas = true
		hurt_query.collide_with_bodies = false
		var hurt_hit:Dictionary = space.intersect_ray(hurt_query)
		# Non-HurtBox areas on a hurt layer (e.g. interaction zones) must not
		# soak bullets: step past them until flesh or nothing.
		while hurt_hit and not (hurt_hit.collider is HurtBox):
			hurt_query.exclude = hurt_query.exclude + [hurt_hit.collider.get_rid()]
			hurt_hit = space.intersect_ray(hurt_query)
		var surface_hit:Dictionary = space.intersect_ray(
				PhysicsRayQueryParameters3D.create(p_from, to, SURFACES_MASK))
		var hurt_distance:float = p_from.distance_to(hurt_hit.position) \
				if hurt_hit else INF
		var surface_distance:float = p_from.distance_to(surface_hit.position) \
				if surface_hit else INF
		var distance:float = minf(hurt_distance, surface_distance)
		if is_inf(distance):
			spawn_tracer(p_from + direction * max_travel, max_travel)
			continue
		var delay:float = distance / TRACER.SPEED
		if distance > max_travel:
			# Spent bullet: fading streak stops at the obstacle, no damage.
			spawn_tracer(p_from + direction * max_travel, distance - max_travel)
		elif hurt_distance <= surface_distance + HURT_PRIORITY_MARGIN:
			spawn_tracer(hurt_hit.position)
			schedule_hit(delay, hurt_hit.collider,
					attack_at_distance(p_attack, distance))
			# The surface body belongs to the same object (HurtBox wraps it):
			# mark it too - damage and bullet hole are not exclusive.
			if surface_hit and surface_hit.collider.is_ancestor_of(hurt_hit.collider):
				schedule_impact(surface_distance / TRACER.SPEED,
						surface_hit.collider, surface_hit.position,
						surface_hit.normal,
						surface_hit.collider.get_meta("surface", "cement"),
						direction)
		else:
			spawn_tracer(surface_hit.position)
			schedule_impact(delay, surface_hit.collider, surface_hit.position,
					surface_hit.normal,
					surface_hit.collider.get_meta("surface", "cement"),
					direction)
	audio_shoot.pitch_scale = randf_range(0.92, 1.08)
	audio_shoot.play()
	flash()
	if smoke_pool.size() > 0:
		smoke_pool[smoke_index].restart()
		smoke_index = (smoke_index + 1) % smoke_pool.size()


# Captures INSTANCE IDS, not nodes - a target freed mid-flight logs "Lambda capture was freed".
func schedule_hit(p_delay:float, p_target:HurtBox, p_attack:AttackData):
	var target_id:int = p_target.get_instance_id()
	get_tree().create_timer(p_delay).timeout.connect(func():
		var target:HurtBox = instance_from_id(target_id) as HurtBox
		if target:
			target.hit(p_attack))


# Stored in the collider's local space so holes ride along when it moves.
func schedule_impact(p_delay: float, p_collider: Node3D, p_position: Vector3,
		p_normal: Vector3, p_surface: String, p_direction: Vector3):
	var collider_id: int = p_collider.get_instance_id()
	var local_position: Vector3 = p_collider.global_transform.affine_inverse() \
			* p_position
	var local_normal: Vector3 = p_collider.global_basis.inverse() * p_normal
	var local_direction: Vector3 = p_collider.global_basis.inverse() * p_direction
	var impact_script: GDScript = IMPACT
	get_tree().create_timer(p_delay).timeout.connect(func():
		var collider: Node3D = instance_from_id(collider_id) as Node3D
		if collider == null or not collider.is_inside_tree():
			return
		var impact: BulletImpact = impact_script.new()
		impact.setup(collider.global_transform * local_position,
				(collider.global_basis * local_normal).normalized(), p_surface,
				(collider.global_basis * local_direction).normalized())
		collider.add_child(impact))


func attack_at_distance(p_attack:AttackData, p_distance:float) -> AttackData:
	if p_distance <= effective_range:
		return p_attack
	var multiplier:float = 1.0 - DAMAGE_FALLOFF_PER_METER * (p_distance - effective_range)
	return AttackData.new(maxi(1, roundi(p_attack.damage * multiplier)),
			p_attack.knockback_origin, p_attack.knockback_distance, p_attack.attacker)


func play_empty():
	audio_empty.play()


func play_reload():
	audio_reload.play()


func play_eject():
	if audio_eject == null:
		return
	audio_eject.pitch_scale = randf_range(0.95, 1.05)
	audio_eject.play()


func spawn_tracer(p_end:Vector3, p_overshoot:float = 0.0):
	var tracer:Tracer = TRACER.new()
	tracer.setup(projectile_spawn.global_position, p_end, p_overshoot)
	get_tree().current_scene.add_child(tracer)


# Forward cone for direction, hot core at the barrel for the shooter.
func flash() -> void:
	var energy:float = randf_range(FLASH_ENERGY.x, FLASH_ENERGY.y)
	muzzle_flash.light_energy = energy
	if muzzle_core:
		muzzle_core.light_energy = energy * CORE_SHARE
	var t := create_tween()
	t.tween_interval(FLASH_HOLD)
	t.tween_property(muzzle_flash, "light_energy", 0.0, FLASH_TIME) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if muzzle_core:
		# parallel() binds only the NEXT step, so the smoke below still follows.
		t.parallel().tween_property(muzzle_core, "light_energy", 0.0, FLASH_TIME) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(smoke, "emitting", false, 0.0).set_delay(smoke.lifetime)
	if flash_sprite == null:
		return
	# The flash cone points along texture U = the quad's local X = the barrel.
	flash_sprite.mesh.material.albedo_texture = FLASH_TEXTURES.pick_random()
	flash_sprite.scale = Vector3(randf_range(0.85, 1.25), 1.0,
			randf_range(0.7, 1.1) * (1.0 if randf() < 0.5 else -1.0))
	flash_sprite.visible = true
	if flash_sprite_tween != null and flash_sprite_tween.is_valid():
		flash_sprite_tween.kill()
	flash_sprite_tween = create_tween()
	flash_sprite_tween.tween_interval(0.05)
	flash_sprite_tween.tween_callback(func(): flash_sprite.visible = false)
