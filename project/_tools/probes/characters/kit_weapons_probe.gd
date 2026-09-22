extends ProbeBase
# DBG probe: the kit weapon scenes - each ranged class wraps an Apocalypse_Weapons
# assembly with its spare parts hidden, the projectile spawn at the muzzle socket
# on the +X barrel axis and the class's own audio; each melee tool carries a hit
# box up its business end; and the weapon data points at these scenes.

const RANGED: PackedStringArray = ["pistol", "revolver", "smg", "shotgun", "assault_rifle", "sniper_rifle"]
const MELEE: PackedStringArray = ["bat", "crowbar"]
const KIT_DIR: String = "res://scenes/items/weapons/kit"


func _ready():
	for name in RANGED:
		var weapon: Node3D = (load("%s/%s.tscn" % [KIT_DIR, name]) as PackedScene).instantiate()
		add_child(weapon)
		var model: Node3D = weapon.get_node_or_null("Model")
		check(weapon is WeaponRanged and model != null, "%s is a ranged weapon over a kit model" % name,
				weapon.get_class())
		var bounds: AABB = bounds_of(model, Transform3D.IDENTITY)
		var spawn: Vector3 = weapon.get_node("ProjectileSpawn").position
		check(spawn.x > bounds.end.x - 0.05 and bounds.size.x > bounds.size.z,
				"%s's muzzle sits at the front of a +X barrel" % name,
				"spawn x %.2f, model x %.2f..%.2f" % [spawn.x, bounds.position.x, bounds.end.x])
		var parts: Array[Node] = model.find_children("*", "MeshInstance3D", false, false)
		var hidden: int = 0
		for part in parts:
			if not part.visible:
				hidden += 1
		check(hidden > 0 and hidden < parts.size(), "%s hides its spare parts" % name,
				"%d of %d hidden" % [hidden, parts.size()])
		check(weapon.get_node("AudioShoot").stream != null, "%s has a shot sound" % name, "")
		weapon.free()
	var sniper: Node3D = (load("%s/sniper_rifle.tscn" % KIT_DIR) as PackedScene).instantiate()
	check(sniper.get_node_or_null("AudioEject") != null
			and sniper.get_node("AudioEject").stream != null, "the sniper rifle carries its eject sound", "")
	sniper.free()

	for name in MELEE:
		var weapon: Node3D = (load("%s/%s.tscn" % [KIT_DIR, name]) as PackedScene).instantiate()
		add_child(weapon)
		var shape: CollisionShape3D = weapon.get_node_or_null("HitBox/CollisionShape3D")
		check(weapon is WeaponMelee and shape != null and shape.position.y > 0.2,
				"%s is a melee weapon with its hit box up the handle" % name,
				"hit box at y %.2f" % (shape.position.y if shape else -1.0))
		weapon.free()

	for name in RANGED:
		var data: WeaponData = load("res://data/items/weapons/ranged/%s.tres" % name)
		check(data.model != null and data.model.resource_path.begins_with(KIT_DIR),
				"%s data points at the kit scene" % name, data.model.resource_path if data.model else "none")
	for name in MELEE:
		var data: WeaponData = load("res://data/items/weapons/melee/%s.tres" % name)
		check(data.model != null and data.model.resource_path.begins_with(KIT_DIR)
				and not data.is_ranged, "%s data is a melee weapon on the kit scene" % name,
				data.model.resource_path if data.model else "none")
	finish()


func bounds_of(p_node: Node, p_xform: Transform3D) -> AABB:
	var local: Transform3D = p_xform * p_node.transform if p_node is Node3D else p_xform
	var result: AABB = AABB()
	if p_node is MeshInstance3D and p_node.mesh and p_node.visible:
		result = local * p_node.mesh.get_aabb()
	for child in p_node.get_children():
		var sub: AABB = bounds_of(child, local)
		if sub.size == Vector3.ZERO:
			continue
		result = sub if result.size == Vector3.ZERO else result.merge(sub)
	return result
