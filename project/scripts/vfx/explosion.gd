class_name Explosion
extends Node3D

const LIFETIME:float = 4.0
const SCORCH_MASK:int = 20  # walls | ground
const SCORCH_REACH:float = 4.0
const SCORCH_RAYS:int = 8  # around the blast, looking for surfaces to mark
const SCORCH_SPACING:float = 2.5  # m between marks, so one wall gets one mark
const SCORCH_SAME_FACE:float = 0.8  # normals this aligned count as one surface
const LIGHT_ENERGY:float = 16.0
const CAMERA_KICK:float = 0.9

@onready var SCORCH:GDScript = load("uid://i5t40437kupv")

@onready var light:OmniLight3D = $ExplosionLight
@onready var audio:AudioStreamPlayer3D = $AudioExplosion


func _ready():
	for burst in [$Fireball, $Sparks, $Flare]:
		burst.restart()
	light.light_energy = LIGHT_ENERGY
	var tween:Tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.9)
	if Globals.camera_follow:
		Globals.camera_follow.kick(
				Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
				.normalized() * CAMERA_KICK)
	if audio.stream:
		audio.play()
	spawn_scorch.call_deferred()
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func spawn_scorch():
	var marked:Array = []
	for node in get_tree().current_scene.get_children():
		if node is ScorchMark:
			marked.append({"position": node.hit_position, "normal": node.hit_normal})
	mark_toward(Vector3.DOWN, marked)
	for i in SCORCH_RAYS:
		var angle:float = TAU * i / SCORCH_RAYS
		mark_toward(Vector3(cos(angle), 0.0, sin(angle)), marked)


func mark_toward(p_direction:Vector3, p_marked:Array):
	var query:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			global_position, global_position + p_direction * SCORCH_REACH, SCORCH_MASK)
	var hit:Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	for existing in p_marked:
		if hit.position.distance_to(existing.position) < SCORCH_SPACING \
				and hit.normal.dot(existing.normal) > SCORCH_SAME_FACE:
			return
	p_marked.append({"position": hit.position, "normal": hit.normal})
	get_tree().current_scene.add_child(
			SCORCH.new().setup(hit.position, hit.normal))
