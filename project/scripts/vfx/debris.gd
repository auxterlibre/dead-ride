class_name Debris
extends RigidBody3D
# A vehicle part torn off by an explosion: takes over the source mesh in
# place, gets blasted outward, tumbles on the ground, then sinks and frees.

const SINK_DELAY_MIN:float = 2.5
const SINK_DELAY_MAX:float = 4.5
const SINK_DEPTH:float = 1.5
const SINK_TIME:float = 1.4
const FLAME_EXTRA_BURN:float = 1.5  # a burning piece smolders on the ground a beat longer
const HEAT_COLOR:Color = Color(1.0, 0.45, 0.12, 0.9)  # forge-hot orange
const HEAT_HOLD:float = 1.2  # sec glowing full before the metal starts cooling
const HEAT_COOL:float = 2.2  # sec fading back to bare metal
const BURN_TIME:Vector2 = Vector2(1.4, 2.0)  # sec of open flame - it dies
					# around touchdown while the glow lingers on the metal

static var char_material:StandardMaterial3D

var source_mesh:Mesh
var source_transform:Transform3D
var launch_center:Vector3
var inherited_velocity:Vector3
var launch_spread:float = 1.0  # horizontal share of the blast
var launch_lift:float = 1.0  # vertical share - the cogs ride HIGH, not far,
							 # so they land on screen instead of leaving it
var flaming:bool = false  # glows hot, drags a fire trail, keeps its own material
var trail:GPUParticles3D


func _ready():
	if char_material == null:
		char_material = StandardMaterial3D.new()
		char_material.albedo_color = Color(0.16, 0.15, 0.14)
	collision_layer = 0
	collision_mask = 4 | 16  # walls + ground
	gravity_scale = 1.5
	var visual:MeshInstance3D = MeshInstance3D.new()
	visual.mesh = source_mesh
	visual.material_override = char_material  # everything burns black in the end
	add_child(visual)
	# Box from the mesh AABB, not a convex hull: hull generation for a full
	# car cost ~400ms on the death frame, and these only tumble for seconds.
	var aabb:AABB = source_mesh.get_aabb()
	var box:BoxShape3D = BoxShape3D.new()
	box.size = aabb.size
	var shape:CollisionShape3D = CollisionShape3D.new()
	shape.shape = box
	shape.position = aabb.get_center()
	add_child(shape)
	global_transform = source_transform
	var direction:Vector3 = global_position - launch_center
	direction.y = 0.0
	direction = direction.normalized() if direction.length_squared() > 0.01 \
			else Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	linear_velocity = inherited_velocity \
			+ direction * randf_range(3.0, 7.0) * launch_spread \
			+ Vector3.UP * randf_range(5.0, 9.0) * launch_lift
	angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)) * randf_range(4.0, 10.0) \
			* maxf(launch_spread, launch_lift)
	glow_hot(visual)  # the whole wreck sprays out hot and cools to the char
	if flaming:
		trail = build_trail()
		add_child(trail)
		get_tree().create_timer(
				randf_range(BURN_TIME.x, BURN_TIME.y)).timeout.connect(put_out)
	get_tree().create_timer(randf_range(SINK_DELAY_MIN, SINK_DELAY_MAX) \
			+ (FLAME_EXTRA_BURN if flaming else 0.0)).timeout.connect(sink)


func setup(p_mesh:Mesh, p_transform:Transform3D, p_center:Vector3,
		p_velocity:Vector3 = Vector3.ZERO) -> Debris:
	source_mesh = p_mesh
	source_transform = p_transform
	launch_center = p_center
	inherited_velocity = p_velocity
	return self


# Every piece leaves the blast forge-hot - the hurt flash's overlay trick -
# then cools onto the char. The hold and cool are jittered per piece, so the
# wreck dims unevenly instead of switching off on one clock.
func glow_hot(p_visual:MeshInstance3D):
	var heat:StandardMaterial3D = StandardMaterial3D.new()
	heat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	heat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	heat.albedo_color = HEAT_COLOR
	p_visual.material_overlay = heat
	var cooling:Tween = create_tween()
	cooling.tween_interval(HEAT_HOLD * randf_range(0.5, 0.75))
	cooling.tween_property(heat, "albedo_color:a", 0.0,
			HEAT_COOL * randf_range(0.8, 1.4))


func build_trail() -> GPUParticles3D:
	var flame:GPUParticles3D = GPUParticles3D.new()
	var process:ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 50.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.7
	process.gravity = Vector3(0.0, 1.6, 0.0)
	var fade:Curve = Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.1))
	var fade_texture:CurveTexture = CurveTexture.new()
	fade_texture.curve = fade
	process.scale_curve = fade_texture
	var ramp:Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.86, 0.4, 0.95),
			Color(1.0, 0.42, 0.1, 0.75), Color(0.3, 0.06, 0.02, 0.0)])
	var ramp_texture:GradientTexture1D = GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	flame.process_material = process
	flame.amount = 48
	flame.lifetime = 0.55
	flame.local_coords = false  # the fire stays where the flight left it
	flame.fixed_fps = 0  # spawn-spaced, never beaded - the sand-trail lesson
	# Pre-simulated, so the piece is ALREADY burning the frame it launches -
	# without this the emitter's first visible puffs appear a metre up the arc.
	flame.preprocess = 0.12
	var quad:QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.45, 0.45)
	var material:StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load("res://assets/textures/vfx/smoke/sand_puff.png")
	quad.material = material
	flame.draw_pass_1 = quad
	return flame


# The flame dies on its own clock; the puffs already in the air live out
# their half second, so it gutters rather than switching off.
func put_out():
	if trail:
		trail.emitting = false


func sink():
	freeze = true
	if trail:
		trail.emitting = false  # in case the piece sinks before the burn ends
	var tween:Tween = create_tween()
	tween.tween_property(self, "position:y", position.y - SINK_DEPTH, SINK_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
