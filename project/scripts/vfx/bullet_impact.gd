class_name BulletImpact
extends Node3D
# Hole, burst and sound all come from the body's SurfaceData; ricochet surfaces leave no hole.

const HOLE_SIZE: float = 0.3
const LIFETIME: float = 8.0
const FADE_TIME: float = 5.0
const BURST_LIFETIME: float = 3.0  # holeless impacts outlive burst + audio

var spawn_position: Vector3
var spawn_normal: Vector3
var spawn_direction: Vector3  # bullet travel; ZERO = unknown, no deflection
var data: SurfaceData


func setup(p_position: Vector3, p_normal: Vector3, p_surface: String = "cement",
		p_direction: Vector3 = Vector3.ZERO):
	spawn_position = p_position
	spawn_normal = p_normal
	spawn_direction = p_direction
	data = SurfaceData.of(p_surface)
	if data == null:
		data = SurfaceData.of("cement")  # an untagged body still gets a hole


func _ready():
	global_position = spawn_position + spawn_normal * 0.01
	var up: Vector3 = Vector3.UP if absf(spawn_normal.y) < 0.9 else Vector3.RIGHT
	look_at(global_position - spawn_normal, up)  # +Z out along the wall normal
	rotate(spawn_normal, randf() * TAU)
	var hole: MeshInstance3D = null
	if data.ricochet:
		make_ricochet()
	else:
		hole = make_hole()
	make_burst()
	play_audio()
	var tween: Tween = create_tween()
	if hole:
		tween.tween_interval(LIFETIME)
		tween.tween_property(hole, "material_override:albedo_color:a",
				0.0, FADE_TIME)
	else:
		tween.tween_interval(BURST_LIFETIME)
	tween.tween_callback(queue_free)


func make_hole() -> MeshInstance3D:
	var hole: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(HOLE_SIZE, HOLE_SIZE)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = data.atlas
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.uv1_scale = Vector3(0.25, 0.25, 1.0)
	material.uv1_offset = Vector3(randi_range(0, 3) * 0.25,
			randi_range(0, 3) * 0.25, 0.0)
	hole.mesh = quad
	hole.material_override = material
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hole)
	return hole


# Impacts are arrival-delayed, so a fresh streak leaving the hit point reads
# as the same bullet glancing off.
func make_ricochet():
	ImpactSpark.spawn(self, spawn_position + spawn_normal * 0.05,
			Color(1.0, 0.9, 0.55), randf_range(0.4, 0.6))
	if spawn_direction == Vector3.ZERO:
		return
	var out: Vector3 = spawn_direction.bounce(spawn_normal).normalized()
	var pivot: Vector3 = out.cross(spawn_normal)
	if pivot.length_squared() < 0.001:  # head-on: the bounce sits on the normal
		pivot = out.cross(Vector3.UP)
	if pivot.length_squared() < 0.001:
		pivot = Vector3.RIGHT
	out = out.rotated(pivot.normalized(), randf_range(-0.35, 0.35))
	out = out.rotated(spawn_normal, randf_range(-0.7, 0.7))
	if out.dot(spawn_normal) < 0.05:  # never scatter back into the surface
		out = (out + spawn_normal * 0.2).normalized()
	var tracer: Tracer = Tracer.new()
	tracer.setup(spawn_position + spawn_normal * 0.02,
			spawn_position + out * randf_range(4.0, 8.0), randf_range(2.0, 4.0))
	get_tree().current_scene.add_child(tracer)


func make_burst():
	var burst: Node3D = data.burst.instantiate()
	add_child(burst)
	# The editor saves one_shot emitters as emitting=false after previewing.
	for emitter in burst.find_children("*", "GPUParticles3D", true, false):
		emitter.restart()


func play_audio():
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = data.audio
	player.pitch_scale = randf_range(0.88, 1.12)
	player.unit_size = 20.0  # carries across the arena; listener sits on the player
	player.bus = &"SFX"
	add_child(player)
	player.play()
