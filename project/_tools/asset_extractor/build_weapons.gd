extends Node

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const KIT_DIR: String = "res://assets/meshes/apocalypse_weapons"
const TOOLS_DIR: String = "res://assets/meshes/zombies"
const RANGED_BASE: String = "res://scenes/items/weapons/weapon_ranged_base.tscn"
const MELEE_SCRIPT: String = "res://scripts/weapons/weapon_melee.gd"
const HIT_BOX_SCRIPT: String = "res://scripts/components/character/hit_box.gd"
const OUT_DIR: String = "res://scenes/items/weapons/kit"
const AUDIO_DIR: String = "res://assets/audio/weapons"
const RANGED: Dictionary = {
	"pistol": {"model": "pistol/pistol_1_base", "shoot": "pistol/pistol_shoot.ogg",
			"reload": "pistol/pistol_reload.wav"},
	"revolver": {"model": "pistol/pistol_6_base", "shoot": "revolver/pistol_1.ogg"},
	"smg": {"model": "smg/smg_1_base", "shoot": "pistol/pistol_shoot.ogg",
			"reload": "pistol/pistol_reload.wav"},
	"shotgun": {"model": "shotgun/shotgun_1_base", "shoot": "shotgun/shotgun_shoot.ogg"},
	"assault_rifle": {"model": "ar/ar_1_base", "shoot": "assault_rifle/rifle_1.ogg",
			"reload": "assault_rifle/assault_rifle_reload.ogg"},
	"sniper_rifle": {"model": "sr/sr_1_base", "shoot": "assault_rifle/rifle_1.ogg",
			"reload": "assault_rifle/assault_rifle_reload.ogg",
			"eject": "sniper_rifle/sniper_rifle_eject.wav"},
}
const MELEE: Dictionary = {
	"bat": {"model": "bat/bat"},
	"crowbar": {"model": "crowbar/crowbar"},
}
const CORE_PARTS: PackedStringArray = ["Base", "Bolt", "Trigger"]
const SOCKET_EPSILON: float = 0.01
const FLASH_LEAD: float = 0.3
const MUZZLE_DROP: float = 0.03
const HIT_SHARE: float = 0.6
const HIT_MIN_SIDE: float = 0.3


func _ready():
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for name in RANGED:
		build_ranged(name, RANGED[name])
	for name in MELEE:
		build_melee(name, MELEE[name])
	get_tree().quit()


func build_ranged(p_name: String, p_spec: Dictionary):
	var weapon: Node3D = (load(RANGED_BASE) as PackedScene).instantiate()
	weapon.name = p_name.to_pascal_case()
	weapon.scene_file_path = ""
	var model: Node3D = (load("%s/%s.tscn" % [KIT_DIR, p_spec.model]) as PackedScene).instantiate()
	model.name = "Model"
	model.scene_file_path = ""
	model.basis = Basis(Vector3.UP, PI / 2.0)
	weapon.add_child(model)
	weapon.move_child(model, 0)
	var sockets: Dictionary = {}
	for child in model.get_children():
		if String(child.name).begins_with("Place_"):
			sockets[String(child.name)] = child.position
	var hidden: int = 0
	var claimed: Dictionary = {}
	for child in model.get_children():
		if not child is MeshInstance3D or core(String(child.name)):
			continue
		var socket: String = socket_of(child.position, sockets)
		if socket == "" or claimed.has(socket):
			child.visible = false
			hidden += 1
		else:
			claimed[socket] = child.name
	var bounds: AABB = visible_bounds(model, Transform3D.IDENTITY)
	var spawn: Vector3 = Vector3(bounds.end.x, bounds.end.y - MUZZLE_DROP, 0.0)
	for socket in sockets:
		if socket.ends_with("_Muzzle"):
			var muzzle: Vector3 = model.transform * sockets[socket]
			spawn = Vector3(maxf(muzzle.x, bounds.end.x), muzzle.y, muzzle.z)
	weapon.get_node("ProjectileSpawn").position = spawn
	weapon.get_node("MuzzleFlashLight").position = spawn
	weapon.get_node("MuzzleFlash").position = spawn + Vector3.RIGHT * FLASH_LEAD
	weapon.get_node("Smoke").position = spawn
	weapon.get_node("AudioShoot").stream = load("%s/%s" % [AUDIO_DIR, p_spec.shoot])
	if p_spec.has("reload"):
		weapon.get_node("AudioReload").stream = load("%s/%s" % [AUDIO_DIR, p_spec.reload])
	if p_spec.has("eject"):
		var eject: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		eject.name = "AudioEject"
		eject.stream = load("%s/%s" % [AUDIO_DIR, p_spec.eject])
		eject.bus = weapon.get_node("AudioShoot").bus
		weapon.add_child(eject)
	own(weapon, weapon)
	print("DBG %s: model %s, %d alternates hidden, muzzle %s" % [p_name, p_spec.model, hidden,
			str(spawn.snapped(Vector3.ONE * 0.001))])
	save(weapon, p_name)


func build_melee(p_name: String, p_spec: Dictionary):
	var weapon: Node3D = Node3D.new()
	weapon.name = p_name.to_pascal_case()
	weapon.set_script(load(MELEE_SCRIPT))
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = load("%s/%s.tres" % [TOOLS_DIR, p_spec.model])
	weapon.add_child(mesh_instance)
	var hit: Area3D = Area3D.new()
	hit.name = "HitBox"
	hit.set_script(load(HIT_BOX_SCRIPT))
	hit.collision_layer = 0
	hit.collision_mask = 0
	hit.monitoring = false
	hit.monitorable = false
	weapon.add_child(hit)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var bounds: AABB = mesh_instance.mesh.get_aabb()
	var top: float = bounds.end.y
	var bottom: float = top - bounds.size.y * HIT_SHARE
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(maxf(bounds.size.x, HIT_MIN_SIDE), top - bottom,
			maxf(bounds.size.z, HIT_MIN_SIDE))
	shape.shape = box
	shape.position = Vector3(bounds.get_center().x, (top + bottom) * 0.5, bounds.get_center().z)
	hit.add_child(shape)
	own(weapon, weapon)
	print("DBG %s: hit box %s at y %.2f" % [p_name, str(box.size.snapped(Vector3.ONE * 0.01)),
			shape.position.y])
	save(weapon, p_name)


func core(p_part: String) -> bool:
	var tail: String = p_part.get_slice("_", p_part.get_slice_count("_") - 1)
	return tail in CORE_PARTS


func socket_of(p_position: Vector3, p_sockets: Dictionary) -> String:
	for socket in p_sockets:
		if p_position.distance_to(p_sockets[socket]) < SOCKET_EPSILON:
			return socket
	return ""


func visible_bounds(p_node: Node, p_xform: Transform3D) -> AABB:
	var local: Transform3D = p_xform * p_node.transform if p_node is Node3D else p_xform
	var result: AABB = AABB()
	if p_node is MeshInstance3D and p_node.mesh and p_node.visible:
		result = local * p_node.mesh.get_aabb()
	for child in p_node.get_children():
		var sub: AABB = visible_bounds(child, local)
		if sub.size == Vector3.ZERO:
			continue
		result = sub if result.size == Vector3.ZERO else result.merge(sub)
	return result


func save(p_weapon: Node3D, p_name: String):
	var packed: PackedScene = PackedScene.new()
	packed.pack(p_weapon)
	var path: String = "%s/%s.tscn" % [OUT_DIR, p_name]
	packed.take_over_path(path)
	ExtractLib.save_keeping_uid(packed, path)
	p_weapon.free()


func own(p_node: Node, p_owner: Node):
	for child in p_node.get_children():
		child.owner = p_owner
		own(child, p_owner)
