extends SceneTree
# Extracts the ammo box sources into game-ready ArrayMesh .tres, one shared
# material over the texture already copied under assets/. Multi-part sources
# merge onto one mesh the weapons extractor's way.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE: String = "res://_not_exported/items"
const OUT_DIR: String = "res://assets/meshes/items/ammo"
const MATERIAL_PATH: String = "res://assets/materials/items/ammo_material.tres"
const TEXTURE_PATH: String = "res://assets/textures/weapons/ammo.png"

# Source file -> output name.
const PIECES: Dictionary = {
	"ammo_light": "ammo_light",
}

var material: BaseMaterial3D = null


func _init():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(MATERIAL_PATH.get_base_dir()))
	for source in PIECES:
		var packed: PackedScene = load("%s/%s.glb" % [SOURCE, source])
		if packed == null:
			print("DBG %s did not load - run verify.sh import first" % source)
			continue
		var scene: Node = packed.instantiate()
		var found: Array = scene.find_children("*", "MeshInstance3D", true, false)
		if found.is_empty():
			print("DBG %s has no mesh" % source)
			scene.free()
			continue
		save_mesh(PIECES[source], found, scene)
		scene.free()
	quit()


func save_mesh(p_name: String, p_instances: Array, p_root: Node):
	var out: ArrayMesh = ArrayMesh.new()
	var parts: int = 0
	for instance: MeshInstance3D in p_instances:
		var mesh: ArrayMesh = instance.mesh as ArrayMesh
		if mesh == null:
			continue
		parts += 1
		var xform: Transform3D = relative_transform(instance, p_root)
		for surface in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			if not xform.is_equal_approx(Transform3D.IDENTITY):
				bake_transform(arrays, xform)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1,
					shared_material(mesh.surface_get_material(surface)))
	out.resource_name = p_name
	var path: String = "%s/%s.tres" % [OUT_DIR, p_name]
	out.take_over_path(path)
	ExtractLib.save_keeping_uid(out, path)
	print("DBG %-14s %d parts  %d surfaces  aabb %s -> %s" % [p_name, parts,
			out.get_surface_count(), out.get_aabb().size, path])


# Transform of p_node in p_root's space, accumulated by hand - global_transform
# needs a tree the mannequin never joins.
func relative_transform(p_node: Node3D, p_root: Node) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var node: Node = p_node
	while node != null and node != p_root:
		if node is Node3D:
			result = (node as Node3D).transform * result
		node = node.get_parent()
	return result


func bake_transform(p_arrays: Array, p_xform: Transform3D):
	var vertices: PackedVector3Array = p_arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = p_xform * vertices[i]
	p_arrays[Mesh.ARRAY_VERTEX] = vertices
	var normal_basis: Basis = p_xform.basis.inverse().transposed()
	if p_arrays[Mesh.ARRAY_NORMAL] != null:
		var normals: PackedVector3Array = p_arrays[Mesh.ARRAY_NORMAL]
		for i in normals.size():
			normals[i] = (normal_basis * normals[i]).normalized()
		p_arrays[Mesh.ARRAY_NORMAL] = normals
	if p_arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = p_arrays[Mesh.ARRAY_TANGENT]
		for i in range(0, tangents.size(), 4):
			var t: Vector3 = (p_xform.basis * Vector3(tangents[i],
					tangents[i + 1], tangents[i + 2])).normalized()
			tangents[i] = t.x
			tangents[i + 1] = t.y
			tangents[i + 2] = t.z
		p_arrays[Mesh.ARRAY_TANGENT] = tangents


# One material for every round: the source's, albedo swapped to the shipped
# copy. An existing file wins, so hand tweaks survive a re-run.
func shared_material(p_source: Material) -> BaseMaterial3D:
	if material != null:
		return material
	if FileAccess.file_exists(ProjectSettings.globalize_path(MATERIAL_PATH)):
		var existing: BaseMaterial3D = load(MATERIAL_PATH)
		if existing != null:
			material = existing
			return material
	var result: BaseMaterial3D = null
	if p_source is BaseMaterial3D:
		result = (p_source as BaseMaterial3D).duplicate()
	else:
		result = StandardMaterial3D.new()
	result.albedo_texture = load(TEXTURE_PATH)
	result.metallic_specular = 0.0
	result.resource_name = "ammo_material"
	result.take_over_path(MATERIAL_PATH)
	ExtractLib.save_keeping_uid(result, MATERIAL_PATH)
	material = result
	return material
